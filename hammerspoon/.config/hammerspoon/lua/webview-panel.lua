local M = {}

---@param url string
function M.open(url)
	local original = hs.window.focusedWindow()
	local screen = hs.screen.mainScreen():frame()
	local w, h = 900, 700
	local x = screen.x + (screen.w - w) / 2
	local y = screen.y + (screen.h - h) / 3
	local chromeUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
		.. "AppleWebKit/537.36 (KHTML, like Gecko) "
		.. "Chrome/115.0.0.0 Safari/537.36"

	local wv = hs.webview.new(hs.geometry.rect(x, y, w, h), {
		javaScriptEnabled = true,
		developerExtrasEnabled = true,
		javaScriptCanOpenWindowsAutomatically = true,
	})
	if not wv then
		return
	end

	wv:windowCallback(function(action)
		if action == "closing" then
			wv:delete(true)
			if original and original:application():isRunning() then
				original:focus()
			end
		end
	end)

	wv:windowStyle({ "titled", "closable", "resizable", "nonactivating" })
		:titleVisibility("visible")
		:closeOnEscape(true)
		:allowTextEntry(true)
		:shadow(true)
		:userAgent(chromeUA)
		:url(url)
		:show()
		:bringToFront(true)
end

return M
