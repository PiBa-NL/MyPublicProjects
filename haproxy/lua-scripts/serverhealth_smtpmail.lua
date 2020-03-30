--[[
  HAProxy server healthcheck monitor/mailer.
  By PiBa-NL
]]--

local monitoring_exclude_serverstate23 = { 
  "wordpress_ipvANY/wordpress_v4",
  "wordpress_ipvANY/wordpress_v6"
}
local monitoring_include_servers = nil -- nil=ALL
local monitoring_exclude_servers = { "test/excluded_server" }

local smtpmailer = Smtpmailqueue("luamailer",5)
smtpmailer:setserver("127.0.0.1","25")

local checknotifier = function(subject, message, serverstatecounters, allstates)
	local info = core.get_info()
	local mailbody = message.."\r\n"..serverstatecounters.."\r\n\r\n<span style='margin-left:10px;'>"..allstates.."</span>\r\n\r\nReported by node: "..info.node
	mailbody = "<html><body>"..string.gsub(mailbody,"\r\n","<br/>").."</body></html>"

	smtpmailer:addmail("haproxy@domain.local","itguy@domain.local","[srv-checker] "..subject, mailbody)
end
local mychecker = Serverhealthchecker("hapchecker",3,2,checknotifier)
mychecker:monitorservers(monitoring_include_servers, monitoring_exclude_servers)
mychecker:ignoreserverstate23(monitoring_exclude_serverstate23)

webstats = function(applet)
	if string.match(applet['path'],"/webstats/mailstat") then
		return smtpmailer:webstats(applet)
	end
    response = "<html><body>Webstats<br/>"
    response = response .. "<a href='/webstats/mailstat'>MailStats</a><br/>"
    response = response .. "<br/></body></html>"
    applet:add_header("Server", "haproxy/webstats")
    applet:add_header("Content-Length", string.len(response))
    applet:add_header("Content-Type", "text/html")
    applet:start_response()
    applet:send(response)
end
core.register_service("haproxy-webstats", "http", webstats)
