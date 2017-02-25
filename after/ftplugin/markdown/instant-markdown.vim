" # Configuration
if !exists('g:instant_markdown_slow')
    let g:instant_markdown_slow = 0
endif

if !exists('g:instant_markdown_autostart')
    let g:instant_markdown_autostart = 1
endif

if !exists('g:instant_markdown_open_to_the_world')
    let g:instant_markdown_open_to_the_world = 0
endif

if !exists('g:instant_markdown_allow_unsafe_content')
    let g:instant_markdown_allow_unsafe_content = 0
endif

if !exists('g:instant_markdown_allow_external_content')
    let g:instant_markdown_allow_external_content = 1
endif

" # Utility Functions
" Simple system wrapper that ignores empty second args
function! s:system(cmd, stdin)
    if strlen(a:stdin) == 0
        call system(a:cmd)
    else
        call system(a:cmd, a:stdin)
    endif
endfu

" Wrapper function to automatically execute the command asynchronously and
" redirect output in a cross-platform way. Note that stdin must be passed as a
" List of lines.
function! s:systemasync(cmd, stdinLines)
    if has('win32') || has('win64')
        call s:winasync(a:cmd, a:stdinLines)
    else
        let cmd = a:cmd . '&>/dev/null &'
        call s:system(cmd, join(a:stdinLines, "\n"))
    endif
endfu

" Executes a system command asynchronously on Windows. The List stdinLines will
" be concatenated and passed as stdin to the command. If the List is empty,
" stdin will also be empty.
function! s:winasync(cmd, stdinLines)
    " To execute a command asynchronously on windows, the script must use the
    " "!start" command. However, stdin can't be passed to this command like
    " system(). Instead, the lines are saved to a file and then piped into the
    " command.
    if len(a:stdinLines)
        let tmpfile = tempname()
        call writefile(a:stdinLines, tmpfile)
        let command = 'type ' . tmpfile . ' | ' . a:cmd
    else
        let command = a:cmd
    endif
    exec 'silent !start /b cmd /c ' . command . ' > NUL'
endfu

function! s:refreshView()
    let bufnr = expand('<bufnr>')
    let folder = expand('%:p:h')
    if isdirectory(folder)
        call s:systemasync("curl -X POST -d \"" . folder . "\" http://localhost:8090", [])
    endif
    call s:systemasync("curl -X PUT -T - http://localhost:8090",
                \ s:bufGetLines(bufnr))
endfu

function! s:bufGetLines(bufnr)
  return getbufline(a:bufnr, 1, "$")
endfu

" I really, really hope there's a better way to do this.
fu! s:myBufNr()
    return str2nr(expand('<abuf>'))
endfu

" # Functions called by autocmds
"

" ## Refresh if there's something new worth showing
"
" 'All things in moderation'
fu! s:temperedRefresh()
    if !exists('b:changedtickLast')
        let b:changedtickLast = b:changedtick
    elseif b:changedtickLast != b:changedtick
        let b:changedtickLast = b:changedtick
        call s:refreshView()
    endif
endfu

fu! s:previewMarkdown()
  aug instant-markdown
    if g:instant_markdown_slow
      au CursorHold,BufWrite,InsertLeave <buffer> call s:temperedRefresh()
    else
      au CursorHold,CursorHoldI,CursorMoved,CursorMovedI <buffer> call s:temperedRefresh()
    endif
  aug END
endfu

if g:instant_markdown_autostart
    " # Define the autocmds "
    aug instant-markdown
        au! * <buffer>
        au BufEnter <buffer> call s:refreshView()
        if g:instant_markdown_slow
          au CursorHold,BufWrite,InsertLeave <buffer> call s:temperedRefresh()
        else
          au CursorHold,CursorHoldI,CursorMoved,CursorMovedI <buffer> call s:temperedRefresh()
        endif
    aug END
else
    command! -buffer InstantMarkdownPreview call s:previewMarkdown()
endif

