function ll --wraps=ls --wraps=exa --description 'List contents of directory using exa'
    exa --icons --color always --classify --sort modified $argv
end
