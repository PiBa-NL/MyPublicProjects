--[[
  HAProxy server healthcheck monitor/mailer.
  By PiBa-NL
]]--

local smtpmailer = Smtpmailqueue("luamailer",5)
smtpmailer:setserver("127.0.0.1","25")

local checknotifier = function(subject, message, serverstatecounters, allstates)
	smtpmailer:addmail("haproxy@domain.local","itguy@domain.local","[srv-checker]"..subject, message.."\r\n"..serverstatecounters.."\r\n\r\n"..allstates)
end
local mychecker = Serverhealthchecker("hapchecker",3,2,checknotifier)

testitweb = {}
testitweb.webrequest = function(applet)
	if string.match(applet['path'],"/webrequest/mailstat") then
		return smtpmailer:webstats(applet)
	end
end
core.register_service("testitweb-webrequest", "http", testitweb.webrequest)
