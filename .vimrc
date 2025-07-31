" Always Wrap Long Lines
set wrap

" Show Line Numbers Always
set number

" Autoindent
set autoindent

" Highlight Cursor Line
set cursorcolumn
:highlight CursorColumn ctermfg=White ctermbg=Black cterm=bold gui=bold

set cursorline
:highlight CursorLine ctermbg=Black cterm=bold gui=bold

" Syntax
syntax on

" Show Mode you Are Editing In
set showmode

"Set Line Number Colour
:highlight LineNr term=bold cterm=NONE ctermfg=DarkGrey ctermbg=NONE gui=NONE guifg=DarkGrey guibg=NONE

" Custom Commands
command! Bul %s/^.\+/• &/
command! Unbul %s/^• //

set termguicolors

set background=dark

colorscheme lunaperche
