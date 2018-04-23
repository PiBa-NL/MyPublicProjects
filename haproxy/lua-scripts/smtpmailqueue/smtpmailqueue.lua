--[[
	Smtpmailqueue for sending mails over plain smtp with retries and webstats page to view send/failed mails.
	upon restart pending mails and history are lost as there is no disk storage used.
	Copyright PiBa-NL
]]--

Smtpmailqueue = {}
Smtpmailqueue.__index = Smtpmailqueue
setmetatable(Smtpmailqueue, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})
function Smtpmailqueue:Info(logtext)
	core.Info("["..self.mailername .. "] "..logtext)
	self.status = logtext
end
function Smtpmailqueue.new(mailername, interval)
	local self = setmetatable({}, Smtpmailqueue)
	
	self.mailername = mailername
	self.interval = interval
	self.mailserver = "127.0.0.1"
	self.mailserverport = "25"
	self.status = "initializing"
	self.mailqueue = {}
	self.queuemaxsize = 10

	local Smtpmailqueue_processqueue = function()
		self:processqueue()
	end
	core.register_task(Smtpmailqueue_processqueue)
	self:addmail("","","Smtpmailqueue initialized","Smtpmailqueue has been initialized\r\n")
	return self
end
function Smtpmailqueue:setserver(server, port)
	self.mailserver = server
	self.mailserverport = port
end
function Smtpmailqueue:sendmail_senddata(data)
	local mailitem = self.currentmailitem
	if not mailitem.processing then
		self:Info("SKIP sendata:"..data)
		return
	end
	mailitem.status = "SMTP sending:"..data
	self:Info(mailitem.status)
	self.mailconnection:send(data)
end
function Smtpmailqueue:sendmail_waitfor(code)
	local mailitem = self.currentmailitem	
	if not mailitem.processing then
		self:Info("SKIP waitfor:"..code)
		return
	end
	local itsok = false
	local receive
	self:Info("######## MAIL WAIT for result status: "..code)
	repeat
		receive = self.mailconnection:receive("*l")
		if receive == nil then
			self:Info("SMTP Received: NIL")
			return -2
		end
		self:Info("SMTP Received:"..receive)
		local retcode = string.match(receive,"^%d%d%d ")
		if retcode ~= nil then
			if retcode ~= code.." " then
				mailitem.status = "FAILED (smtp reply: "..receive..")"
				mailitem.processing = false
				mailitem.retries = mailitem.retries - 1
			end
			return receive
		end
	until itsok
	return -1
end
function Smtpmailqueue:createmailitem(from, to, subject, content)
	--local to = "notreal"
	return { 
		['sendtime']=os.time(), 
		['status']="queued", 
		['from']=from, 
		['to']=to, 
		['subject']=subject, 
		['content']=content, 
		['retries']=3
	}
end
function Smtpmailqueue:addmail(from,to,subject,content)
	self:addmailitem(self:createmailitem(from,to,subject,content))
end
function Smtpmailqueue:addmailitem(mailitem)
	if #self.mailqueue >= self.queuemaxsize then
		local dummy
		table.remove(self.mailqueue, 1)
	end
	table.insert(self.mailqueue, mailitem)
end
function Smtpmailqueue:sendmailitem(mailitem)
	if not mailitem.to then
		mailitem.status = "<to> not set"
		mailitem.retries = -mailitem.retries
		mailitem.sendout = os.time()
		mailitem.processing = false
		return false
	end
		
	self:Info("##### send MAIL #####")
	self:Info("##### to: "..mailitem.to)
	self:Info("##### subject: "..mailitem.subject)

	self.currentmailitem = mailitem
	mailitem.processing = true
	mailitem.status = "connecting"
	
	local mailconnection = core.tcp()
	mailconnection:settimeout(1)
	self.mailconnection = mailconnection
	ret = mailconnection:connect(self.mailserver, self.mailserverport)
	if ret ~= 1 then
		mailitem.status = "connecting failed to "..self.mailserver..":".. self.mailserverport
		self:Info("Connect failed")
		return 1
	end
	self:sendmail_waitfor("220")

	self:sendmail_senddata("EHLO haproxymailer.local\r\n")
	self:sendmail_waitfor("250")

	self:sendmail_senddata("MAIL FROM:<"..mailitem.from..">\r\n")
	self:sendmail_waitfor("250")

	self:sendmail_senddata("RCPT TO:<"..mailitem.to..">\r\n")
	self:sendmail_waitfor("250")

	self:sendmail_senddata("DATA\r\n")
	self:sendmail_waitfor("354")
	
	local mailcontent = "From: "..mailitem.from.."\r\n" ..
		"To: "..mailitem.to.."\r\n" ..
		--"Date: Mon, 21 May 2018 01:03 (CET)\r\n" ..
		"Subject: "..mailitem.subject.."\r\n" ..
		"\r\n" ..
		mailitem.content .. "\r\n" ..
		"\r\n" ..
		".\r\n" 
	self:sendmail_senddata(mailcontent)
	self:sendmail_waitfor("250")
	
	if mailitem.processing then
		mailitem.status = "delivered"
		mailitem.retries = -mailitem.retries
		mailitem.sendout = os.time()
	end
	mailitem.processing = false
	
	self:Info("Closing SMTP connection")
	mailconnection.close(mailconnection)
end
function Smtpmailqueue:sendmail(from,to,subject,content)
  local mailitem = self:createmailitem(from,to,subject,content)
  self:sendmailitem(mailitem)
end
function Smtpmailqueue:webstats(applet)
	local queue = self.mailqueue
	local info = core.get_info()
	
	response = "<h2>haproxy mailqueue viewer</h2>"
	response = response .. "Mailqueue has items:" .. #queue
	response = response .. "<br/>Last status message:" .. self.status
	response = response .. "<br/><table border=1>"
	response = response .. "<tr><td>Time</td><td>Status</td><td>From/To</td><td>Subject/Body</td></tr>"
	for k, item in pairs(queue) do
		response = response .. "<tr><td>"..os.date("%a, %d %b %Y %H:%M:%S",item.sendtime).."</td><td>"
		if item.processing then
			response = response .. "<b>"
		end
		response = response .. item.status
		if item.processing then
			response = response .. "</b>"
		end
		response = response .. "</td><td>FROM:"..item.from.."<br/>TO:"..item.to.."</td>"
		response = response .. "<td><div style='max-width: 500px; max-height: 50px; overflow: auto'>" .. string.gsub(item.subject,"\r\n","<br/>") .. "</div>"
		response = response .. "<div style='max-width: 500px; max-height: 50px; overflow: auto'>" .. string.gsub(item.content,"\r\n","<br/>") .. "</div></td>"
		response = response .. "</tr>"
	end
	response = response .. "</table>"
	response = response .. "<h6>Running on node:"..info.node.." name: "..info.Name.." version:"..info.Version.."<br/>"
	response = response .. "Current time: "..os.date("%a, %d %b %Y %H:%M:%S",os.time()).."<br/>"
	response = response .. "UTC time: "..os.date("!%a, %d %b %Y %H:%M:%S",os.time()).."</h6>"

	applet:add_header("Server", "haproxy/webstats")
	--applet:add_header("Content-Length", string.len(response))
	applet:add_header("Content-Type", "text/html")
	applet:add_header("Refresh", "10")
	applet:start_response()
	applet:send(response)
end
function Smtpmailqueue:processqueue()
	repeat
		self.status = "sleeping"
		core.sleep(self.interval)
		self:Info("Mails in queue: " .. #self.mailqueue)
		local c = 0
		local unsend = 0
		for key, mail in pairs(self.mailqueue) do
			if mail.retries > 0 then
				self:sendmailitem(mail)
			end
			c = c + 1
		end
		self:Info("Smtpmailqueue.processqueue done")
	until false
end
