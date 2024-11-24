function rm --wraps=rm --description 'rm command is banned'
    echo "rm command is banned, please use mv ./path/to/file ~/.Trash"
end
