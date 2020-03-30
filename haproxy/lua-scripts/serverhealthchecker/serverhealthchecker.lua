--[[
	ServerHealthChecker
	Calls a 'notification' function for reporting server health changes.
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
	self.ignorestates23 = nil
	self.servers_include = nil
	self.servers_exclude = nil
	local serverhealthchecker_runchecks = function()
		self:runchecktask()
	end
	core.register_task(serverhealthchecker_runchecks)
	return self
end

function fliparray(arr)
	if (arr == nil) then
		return nil
	end
	local result = {}
	for p,v in pairs(arr) do
		result[v]=1
	end
	return result 
end

function Serverhealthchecker:monitorservers(servers_include, servers_exclude)
	self.servers_include = fliparray(servers_include)
	self.servers_exclude = fliparray(servers_exclude)
end

function Serverhealthchecker:ignoreserverstate23(ignorestates)
	self.ignorestates23 = fliparray(ignorestates)
end

function Serverhealthchecker:getServerStatuses()
	local result = {}
	for p,v in pairs(core.backends) do
		for s,server in pairs(v.servers) do
			local servername = p.."/"..s
			if (self.servers_include ~= nil and self.servers_include[servername] == nil) then
				break -- skip this server..
			end
			if (self.servers_exclude ~= nil and self.servers_exclude[servername] ~= nil) then
				break -- skip this server..
			end
			local stats = server:get_stats()
			result[servername] = stats.status
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

	local currentstate = self:getServerStatuses()
	core.sleep(self.checkinterval)
	local previousstate
	local message = ""
	repeat
		local previousstate = currentstate
		currentstate = self:getServerStatuses()
		local sendmessage = false
		local statecounter = {}
		
		if firstrun then
		end
		local allstates = "";
		for i, serverstate in pairs(currentstate) do
			srv_state_previous = previousstate[i]
			if (self.ignorestates23 ~= nil and self.ignorestates23[i] ~= nil) then
				if (serverstate == "UP 2/3") then
					serverstate = "UP"
				end
				if (srv_state_previous == "UP 2/3") then
					srv_state_previous = "UP"
				end
			end
			if ((serverstate ~= srv_state_previous) or firstrun) then
				message = message .." - "..i.." is: "..serverstate.." was: "..srv_state_previous.."\r\n"
				sendmessage = true
			end
			allstates = allstates .." - "..i.." is: "..serverstate.." was: "..srv_state_previous.."\r\n"
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