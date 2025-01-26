function ll --wraps=eza --description 'List contents of directory using exa'
    eza --icons --color always --classify --sort modified $argv
end
