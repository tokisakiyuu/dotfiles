hs.loadSpoon("Seal")

local wp = require("lua.webview-panel")
local secrets = require("lua.secret")
local yddict = require("lua.yddict")

local M = {}

--- https://www.hammerspoon.org/Spoons/Seal.html#toggle
local actions = {
	["Google"] = {
		keyword = "g",
		url = "https://www.google.com/search?q=${query}+-site%3Acsdn.net",
	},
	["Youdao Dictionary"] = {
		keyword = "w",
		fn = function(str)
			wp.open("https://www.youdao.com/result?word=" .. str .. "&lang=en")
		end,
	},
	["Metaso Search"] = {
		keyword = "ai",
		url = "https://metaso.cn/?q=${query}&ref=xyz",
	},
	["DuckDuckGo"] = {
		keyword = "ddg",
		url = "https://duckduckgo.com/?q=${query}",
	},
	["Github Search"] = {
		keyword = "git",
		url = "https://github.com/search?q=${query}&ref=opensearch",
	},
	["Npm Search"] = {
		keyword = "npm",
		url = "https://www.npmjs.com/search?q=${query}",
	},
	["Jira issue"] = {
		keyword = "issue",
		url = secrets.jira_issue_url_template,
	},
	["Jira Dashboard"] = {
		keyword = "jira",
		url = secrets.jira_dashboard_url,
	},
	["Google Translator"] = {
		keyword = "t",
		url = "https://translate.google.com/?hl=zh-CN&sl=auto&tl=en&text=${query}&op=translate",
	},
	["ChatGPT"] = {
		keyword = "gpt",
		url = "https://chatgpt.com/",
	},
	["Youdao Translator"] = {
		keyword = "y",
		fn = function(query)
			yddict.youdaoInstantTrans(query)
		end,
	},
}

function M.init()
	local Seal = spoon.Seal
	Seal:loadPlugins({ "apps", "useractions", "urlformats" })
	Seal.plugins.useractions.actions = actions

	CmdSpaceWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
		local flags = event:getFlags()
		local keyCode = event:getKeyCode()

		if
			keyCode == hs.keycodes.map["space"]
			and flags["cmd"]
			and not (flags["alt"] or flags["ctrl"] or flags["shift"])
		then
			Seal:toggle()
			if not CmdSpaceWatcher:isEnabled() then
				CmdSpaceWatcher:start()
			end
			return true
		end
	end)

	CmdSpaceWatcher:start()
end

return M
