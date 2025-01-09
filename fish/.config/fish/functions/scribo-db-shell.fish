function scribo-db-shell --wraps=mongosh
    set -lx SCRIBO_MONGO_SHELL_ENV $argv[1]
    mongosh --file ~/space/work/scribo-mongosh.js --nodb --shell
end
