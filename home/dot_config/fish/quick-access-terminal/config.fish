set -l base ~/.config/fish/quick-access-terminal

source $base/lib.fish
source $base/variables.secret.fish
source $base/built-in.fish

__shortcuts w Youdao

__search ai "https://metaso.cn/?q={keyword}&ref=xyz"
__search g "https://www.google.com/search?q={keyword}+-site%3Acsdn.net" "Keyword: "
__search ddg "https://duckduckgo.com/?q={keyword}" "Keyword: "
__search git "https://github.com/search?q={keyword}&ref=opensearch" "Keywork: "
__search npm "https://www.npmjs.com/search?q={keyword}" "Keyword:"
__search issue $jira_issue_url_template
__search t "https://translate.google.com/?hl=zh-CN&sl=auto&tl=en&text={keyword}&op=translate" "Content: "

__open jira $jira_url
__open gpt "https://chatgpt.com/"

__cmd youdao "node ~/.config/fish/quick-access-terminal/youdao-translator.js"
