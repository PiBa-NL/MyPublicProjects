--[[
	Smtpmailqueue usage example.
	Copyright PiBa-NL
]]--

local mysmtpmailqueue = Smtpmailqueue("luamailer",5)
mysmtpmailqueue:setserver("127.0.0.1","25")

local mailerwebstats = function(applet)
	mysmtpmailqueue:webstats(applet)
end
core.register_service("mailerwebstats", "http", mailerwebstats)



-- Now add a new mail to the queue from any lua script:
mysmtpmailqueue:addmail("haproxy@domain.local","itguy@domain.local","MyTestSubject", "MyTestMessage\r\nLine2\r\nLine3")

