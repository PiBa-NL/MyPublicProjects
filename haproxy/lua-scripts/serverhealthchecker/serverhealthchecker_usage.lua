--[[
	Example showing usage of the Serverhealthchecker
	checknotifier is called when server health changes are detected.
	this example outputs text on haproxy's console which by itself is probably not that useful.
	it is however possible to combine this with the Smtpmailqueue to send notification mails about server state changes
	Copyright PiBa-NL
]]--

local checknotifier = function(subject, message, serverstatecounters, allstates)
	core.Warning("NOTIFY ----------- "..subject.." -----------")
	core.Warning("NOTIFY " .. message)
	core.Warning("NOTIFY " .. serverstatecounters)
	core.Warning("NOTIFY " .. allstates)
	core.Warning("NOTIFY ---------------------------------------------------")
end
local mychecker = Serverhealthchecker("checker",3,2,checknotifier)
