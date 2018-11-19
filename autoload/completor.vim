" vim: et ts=2 sts=2 sw=2

let s:save_cpo = &cpo
set cpo&vim

let s:python_imported = v:false
let s:prev = []


function! s:import_python()
  if !s:python_imported
    call completor#utils#setup_python()
    let s:python_imported = v:true
  endif
endfunction


function! s:skip()
  let buftype = &buftype
  let name = bufname('')
  let fsize = getfsize(name)
  let skip = buftype ==? 'quickfix'
        \ || name ==? '[Command Line]'
        \ || fsize == -2
        \ || fsize > g:completor_filesize_limit
        \ || index(g:completor_blacklist, &ft) != -1
        \ || &paste
        \ || mode() !=# 'i'
  if exists('g:completor_whitelist') && type(g:completor_whitelist) == v:t_list
    let skip = skip || index(g:completor_whitelist, &ft) == -1
  endif
  return skip || get(b:, 'completor_disabled', v:false)
endfunction


function! s:key_ignore(pos)
  if a:pos[:1] != s:prev[:1]
    return v:false
  endif
  return a:pos[2] <= s:prev[2]
endfunction


function! s:on_text_change()
  let pos = getcurpos()
  if !s:key_ignore(pos) && !s:skip()
    if !(exists('s:timer') && !empty(timer_info(s:timer)))
      let s:timer = timer_start(g:completor_completion_delay, {t->completor#do('complete')})
    endif
  endif
  let s:prev = pos
endfunction


function! s:on_insert_char_pre()
  if pumvisible()
    let s:prev = getcurpos()
    let s:prev[2] += 1
  endif
endfunction


function! s:set_events()
  augroup completor
    autocmd!
    if get(g:, 'completor_auto_trigger', 1)
      autocmd TextChangedI * call s:on_text_change()
      autocmd InsertCharPre * call s:on_insert_char_pre()
    endif
    if get(g:, 'completor_auto_close_doc', 1)
      autocmd! CompleteDone * call completor#action#_on_complete_done()
    endif
  augroup END
endfunction


function! completor#disable_autocomplete()
  autocmd! completor
endfunction


function! completor#enable_autocomplete()
  if &diff
    return
  endif
  call s:set_events()
endfunction


func s:do_action(action, meta)
  call s:import_python()
  call completor#action#update_status()

  let status = completor#action#get_status()

  if a:action ==# 'complete'
    let info = completor#utils#get_completer(status.ft, status.input)
  else
    let info = completor#utils#load(status.ft, a:action, status.input, a:meta)
  endif
  call completor#action#do(a:action, info, status)
  return ''
endfunction


function! completor#do(action) range
  let meta = {'range': [a:firstline, a:lastline]}
  try
    return s:do_action(a:action, meta)
  catch /\(E858\|\(py\(thon\|3\|x\)\)\)/
    return ''
  endtry
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
