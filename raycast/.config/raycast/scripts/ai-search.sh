#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title AI Search
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Question" }

# Documentation:
# @raycast.author tokisakiyuu
# @raycast.authorURL tokisakiyuu.com

echo $1 | shortcuts run "Mac AI Search"
