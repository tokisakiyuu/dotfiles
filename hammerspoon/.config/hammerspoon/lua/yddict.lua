local M = {}

---https://github.com/ashfinal/awesome-hammerspoon/blob/master/Spoons/HSearch.spoon/hs_yddict.lua
---@param querystr string
function M.youdaoInstantTrans(querystr)
	local youdao_keyfrom = "hsearch"
	local youdao_apikey = "1199732752"
	local youdao_baseurl = "http://fanyi.youdao.com/openapi.do?keyfrom="
		.. youdao_keyfrom
		.. "&key="
		.. youdao_apikey
		.. "&type=data&doctype=json&version=1.1&q="

	if string.len(querystr) > 0 then
		local encoded_query = hs.http.encodeForQuery(querystr)
		local query_url = youdao_baseurl .. encoded_query

		hs.http.asyncGet(query_url, nil, function(status, data)
			if status == 200 then
				if pcall(function()
					hs.json.decode(data)
				end) then
					local decoded_data = hs.json.decode(data)
					if decoded_data.errorCode == 0 then
						local basictrans = basic_extract(decoded_data.basic)
						local webtrans = web_extract(decoded_data.web)
						local dictpool = hs.fnutils.concat(basictrans, webtrans)
						if #dictpool > 0 then
							local chooser_data = hs.fnutils.imap(dictpool, function(item)
								return {
									text = item,
									output = "clipboard",
									arg = item,
								}
							end)
							print(chooser_data)
						end
					end
				end
			end
		end)
	end
end

return M
