function scribo-db-shell --wraps=mongosh
    mongosh --file ~/space/mywork/scribo-mongosh.js --nodb --shell
end
