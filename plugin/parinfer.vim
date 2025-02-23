
" VIM PARINFER PLUGIN
" v 1.1.0
" brian@brianhurlow.com

let g:_VIM_PARINFER_DEFAULTS = {
    \ 'filetypes':  ['clojure', 'racket', 'lisp', 'scheme', 'lfe', 'fennel'],
    \ 'mode':       "indent",
    \ 'script_dir': resolve(expand("<sfile>:p:h:h"))
    \ }

for s:key in keys(g:_VIM_PARINFER_DEFAULTS)
    if !exists('g:vim_parinfer_' . s:key)
        let g:vim_parinfer_{s:key} = copy(g:_VIM_PARINFER_DEFAULTS[s:key])
    endif
endfor

runtime autoload/parinfer_lib.vim

function! g:Select_full_form()

  let delims = {
      \ 'parens': {'left': '(', 'right': ')'},
      \ 'curlies': {'left': '{', 'right': '}'},
      \ 'brackets': {'left': '[', 'right': ']'}
      \}

  let full_form_delimiters = delims['parens']

  "search backward for a ( on first col. Do not move the cursor
  let topline = search('^(', 'bn')

  if topline == 0
    let topline = search('^{', 'bn')
    let full_form_delimiters = delims['curlies']
  endif

  if topline == 0
    let topline = search('^[', 'bn')
    let full_form_delimiters = delims['brackets']
  endif

  let current_line = getline('.')

  " handle case when cursor is ontop of start mark
  " (search backwards misses this)
  if current_line[0] == '('
    let topline = line('.')
  elseif current_line[0] == '{'
    let topline = line('.')
    let full_form_delimiters = delims['curlies']
  elseif current_line[0] == '['
    let topline = line('.')
    let full_form_delimiters = delims['brackets']
  endif

  if topline == 0
    return []
  endif

  " temp, set cursor to form start
  call setpos('.', [0, topline, 1, 0])

  " next paren match
  " only usable when parens are balanced
  let matchline = searchpair(full_form_delimiters['left'],'',full_form_delimiters['right'], 'nW')

  let bottomline = search('^' . full_form_delimiters['left'], 'nW') - 1

  " if no subsequent form can be found
  " assume we've hit the bottom of the file
  if bottomline == -1
    let bottomline = line('$')
  endif

  let lines = getline(topline, bottomline)
  let section = join(lines, "\n")
  return [topline, bottomline, section]

endfunction

function! parinfer#draw(res, top, bottom)
  let lines = split(a:res, "\n")

  try
    " Don't clutter the undo history with parinfer specific changes.
    "
    " `undojoin` will throw E790 if used inside undo/redo, but since we don't
    " want parinfer to get in the way when the user is playing with the undo
    " history, we can simply swallow the error and avoid the setline() call
    undojoin | call setline(a:top, lines)
  catch /E790/
  endtry
endfunction

function! parinfer#process_form_insert()
  if strcharpart(getline('.')[col('.') - 2:], 0, 1) == " "
    return
  endif

  call parinfer#process_form()
endfunction

function! parinfer#process_form()
  let save_cursor = getpos(".")
  let data = g:Select_full_form()

  if len(data) == 3
    let form = data[2]

    " TODO! pass in cursor to second ard
    if g:vim_parinfer_mode == 'indent'
      let res = g:ParinferLib.IndentMode(form, {})
    else
      let res = g:ParinferLib.ParenMode(form, {})
    endif
    let text = res.text

    if form != text
      call parinfer#draw(text, data[0], data[1])
    endif
  endif

  " reset cursor to where it was
  call setpos('.', save_cursor)

endfunction

function! parinfer#do_indent()
  normal! >>
  call parinfer#process_form()
endfunction

function! parinfer#do_undent()
  normal! <<
  call parinfer#process_form()
endfunction

function! parinfer#delete_line()
  delete
  call parinfer#process_form()
endfunction

function! parinfer#put_line()
  put
  call parinfer#process_form()
endfunction

function! parinfer#del_char()
  let pos = getpos('.')
  let row = pos[2]
  let line = getline('.')

  let newline = ""
  let mark = row - 2

  if mark <= 0
    let newline = line[1:len(line) - 1]
  elseif
    let start = line[0:mark]
    let end = line[row:len(line)]
    let newline = start . end
  endif

  call setline('.', newline)
  call parinfer#process_form()
endfunction

function! parinfer#ToggleParinferMode()
  if g:vim_parinfer_mode == 'indent'
    let g:vim_parinfer_mode = 'paren'
  else
    let g:vim_parinfer_mode = 'indent'
  endif
endfunction

com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode()

nnoremap <Plug>ParinferDoIndent :call parinfer#do_indent()<cr>
nnoremap <Plug>ParinferDoUndent :call parinfer#do_undent()<cr>
vnoremap <Plug>ParinferDoIndent :call parinfer#do_indent()<cr>
vnoremap <Plug>ParinferDoUndent :call parinfer#do_undent()<cr>
nnoremap <Plug>ParinferDeleteLine :call parinfer#delete_line()<cr>
nnoremap <Plug>ParinferPutLine :call parinfer#put_line()<cr>

augroup parinfer
  autocmd!
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " autocmd InsertLeave <buffer> call parinfer#process_form()"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " autocmd TextChangedI <buffer> call parinfer#process_form_insert()"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " autocmd TextChanged <buffer> call parinfer#process_form()"
augroup END
