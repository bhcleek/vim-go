" Copyright 2015 Auburn University and The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.

" Vim integration for the Go Doctor.

" NOTE: this code has been copied and adapted from github.com/godoctor/godoctor.vim

" TODO: If a refactoring only affects a single file, allow unsaved buffers
" and pipe the current buffer's contents into the godoctor via stdin
" (n.b. the quickfix list needs to be given a real filename to point to
" errors, so the godoctor's use of -.go and /dev/stdin in the log aren't good
" enough)
" TODO: Pass an option to the godoctor to limit the number of modifications.
" If it's going to try to open 100 new buffers, fail.  Consider a fallback
" option to write files in-place.

" don't spam the user when Vim is started in Vi compatibility mode
let s:cpo_save = &cpo
set cpo&vim

" Run the Extract refactoring with the given arguments.  If a new name is not
" provided, prompt for one.
function! go#doctor#Extract(selected, ...) range abort
  if a:selected == -1
    call go#util#EchoError("extraction requires a selection (range) of code")
    return
  endif

  let to_identifier = ""
  if a:0 == 0
    let l:ask = "vim-go: extract to: "
    let l:to_identifier = input(ask)
    redraw!
    if empty(l:to_identifier)
      return
    endif
  else
    let l:to_identifier = a:1
  endif

  let l:bin_path = go#path#CheckBinPath(go#config#GodoctorBin())
  if empty(l:bin_path)
    return
  endif

  let l:pos = printf("%d,%d:%d,%d",
    \ line("'<"), col("'<"),
    \ line("'>"), col("'>"))

  " TODO(bc): use stdin instead of writing the file
  "   1. pass '-complete'
  "   2. pass buffer contents to godoctor using 'in_io'
  "   3. use 'complete' callback to replace the buffer contents when the exit
  "      code is 0.
  let l:cmd = [l:bin_path, '-w', '-file', expand('%:p'), '-pos', l:pos, 'extract', l:to_identifier]

  " autowrite is not enabled for jobs
  call go#cmd#autowrite()

  if go#util#has_job()
    call s:doctor_job(l:cmd, {
          \ 'statustype': 'extract',
          \ 'for': 'GoExtract',
          \})
    return
  endif

  let l:buffer = join(go#util#GetLines(), "\n")
  let [l:out, l:err] = go#tool#ExecuteInDir(l:cmd)
  call s:parse_errors(l:err, split(l:out, '\n'))
endfunction

function! s:doctor_job(cmd, job_opts)
  " autowrite is not enabled for jobs
  call go#cmd#autowrite()
  let l:cbs = go#job#Options(a:job_opts)

  " TODO(bc): use 'complete' to reload the buffer only when the exit code is 0 instead of reloading all
  " changed buffers unconditionally.
  " wrap l:cbs.exit_cb in s:exit_cb.
  let l:cbs.exit_cb = funcref('s:exit_cb', [l:cbs.exit_cb])

  call go#job#Start(a:cmd, l:cbs)
endfunction

function! s:reload_changed() abort
  " reload all files to reflect the new changes. We explicitly call
  " checktime to trigger a reload of all files. See
  " http://www.mail-archive.com/vim@vim.org/msg05900.html for more info
  " about the autoread bug
  let current_autoread = &autoread
  set autoread
  silent! checktime
  let &autoread = current_autoread
endfunction

" s:exit_cb reloads any changed buffers and then calls next.
function! s:exit_cb(next, job, exitval) abort
  call s:reload_changed()
  call call(a:next, [a:job, a:exitval])
endfunction

function! s:parse_errors(exit_val, out)
  " reload all files to reflect the new changes. We explicitly call
  " checktime to trigger a reload of all files. See
  " http://www.mail-archive.com/vim@vim.org/msg05900.html for more info
  " about the autoread bug
  let current_autoread = &autoread
  set autoread
  silent! checktime
  let &autoread = current_autoread

  let l:listtype = go#list#Type("GoExtract")
  if a:exit_val != 0
    call go#util#EchoError("FAILED")
    let errors = go#tool#ParseErrors(a:out)
    call go#list#Populate(l:listtype, errors, 'Rename')
    call go#list#Window(l:listtype, len(errors))
    if !empty(errors) && !a:bang
      call go#list#JumpToFirst(l:listtype)
    elseif empty(errors)
      " failed to parse errors, output the original content
      call go#util#EchoError(a:out)
    endif

    return
  endif

  " strip out newline on the end that gorename puts. If we don't remove, it
  " will trigger the 'Hit ENTER to continue' prompt
  call go#list#Clean(l:listtype)
  call go#util#EchoSuccess(a:out[0])

  " refresh the buffer so we can see the new content
  silent execute ":e"
endfunction

" restore Vi compatibility settings
let &cpo = s:cpo_save
unlet s:cpo_save

" vim:ts=2:sw=2:et
