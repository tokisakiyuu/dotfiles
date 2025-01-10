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

shortcuts run "Mac AI Search" --input-path "$1"
