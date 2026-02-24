function delete-upstream-gone-branchs --description ''
   git fetch -p
   for branch in $(git branch -vv | grep 'origin/.*: gone]' | awk '/: gone]/{if ($1!="*") print $1}')
     git branch -D $branch
   end
end
