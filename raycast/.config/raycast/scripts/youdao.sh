#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Youdao
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Words" }

# Documentation:
# @raycast.author tokisakiyuu
# @raycast.authorURL tokisakiyuu.com

echo $1 | shortcuts run "Youdao"
