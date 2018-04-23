--[[
	Serverhealthchecker
	Calls a 'notification' function to reporting server health changes.
	Copyright PiBa-NL
]]--

--[[
	Upon starting all the server states are notified once after 'warmup' period has passed
	After this on each set interval the server states are checked for changes and if found a new 'notification' is generated
]]--

Serverhealthchecker = {}
Serverhealthchecker.__index = Serverhealthchecker
setmetatable(Serverhealthchecker, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})
function Serverhealthchecker:Info(message)
	core.Info("["..self.name.."] "..message)
end
function Serverhealthchecker.new(name, warmuptime, checkinterval, notifyfunc)
	local self = setmetatable({}, Serverhealthchecker)
	self.name = name
	self.warmuptime = warmuptime
	self.checkinterval = checkinterval
	self.notify = notifyfunc
	local serverhealthchecker_runchecks = function()
		self:runchecktask()
	end
	core.register_task(serverhealthchecker_runchecks)
	return self
end
function Serverhealthchecker:getServerStatuses()
	local result = {}
	for p,v in pairs(core.backends) do
		for s,server in pairs(v.servers) do
			local stats = server:get_stats()
			result[p.."/"..s] = stats.status
		end
	end
	return result
end
function Serverhealthchecker:runchecktask()
	self.startuptime = os.time()
	local firstrun = true
	local hapmailer = smtpmailer

	--self.notify("HAProxy server state monitor initialized", "Initialized")

	-- Allow some time for haproxy to startup and check all server health to avoid mail-bombs on start-up..
	core.sleep(self.warmuptime)

	local currentstate = self.getServerStatuses()
	core.sleep(self.checkinterval)
	local previousstate
	local message = ""
	repeat
		local previousstate = currentstate
		currentstate = self.getServerStatuses()
		local sendmessage = false
		local statecounter = {}
		
		if firstrun then
		end
		local allstates = "";
		for i, serverstate in pairs(currentstate) do
			if ((serverstate ~= previousstate[i]) or firstrun) then
				message = message ..i.." is: "..serverstate.." was: "..previousstate[i].."\r\n"
				sendmessage = true
			end
			allstates = allstates ..i.." is: "..serverstate.." was: "..previousstate[i].."\r\n"
			if (not statecounter[serverstate]) then
				statecounter[serverstate] = 0
			end
			statecounter[serverstate] = statecounter[serverstate] + 1
		end

		if sendmessage then
			self:Info("############# notify !!!!!!!!!!!!!!!!")
			self:Info(message)
			if firstrun then
				message = "Server states after start-up."
			end
			local srvstates = ""
			for s,c in pairs(statecounter) do
				srvstates = srvstates.."\r\n"..c.." "..s
			end
			self.notify("HAProxy server states have changed", message, "Server state counts:" .. srvstates,"All Server states:\r\n"..allstates)
		end
		message = "Some server states have changed\r\n"
		core.sleep(self.checkinterval)
		firstrun = false
	until false
	-- tasks must never end else a core dump will happen..
end