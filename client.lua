--TODO's
--check alt on mouseup for line/box snap
-------------------------------------------------------

--CHANGES:
--Lots of new api functions, nearly everything syncs
--Most things synced.  Awaiting new tpt api functions for full sync
--It connects to server! and chat
--Basic inputbox
--Basic chat box, moving window
--Cleared everything

local issocket,socket = pcall(require,"socket")
if not sim.loadSave then error"Tpt version not supported" end
if MANAGER_EXISTS then using_manager=true else MANAGER_PRINT=print end

local PORT = 34403 --Change 34403 to your desired port
local KEYBOARD = 1 --only change if you have issues. Only other option right now is 2(finnish).
--Local player vars we need to keep
local L = {mousex=0, mousey=0, brushx=0, brushy=0, sell=1, sela=296, selr=0, mButt=0, mEvent=0, dcolour=0,
shift=false, alt=false, ctrl=false, z=false, downInside=nil, skipClick=false, pauseNextFrame=false, copying=false, stamp=false, placeStamp=false, lastStamp=nil, lastCopy=nil, smoved=false, rotate=false, sendScreen=false}

local tptversion = tpt.version.build
local jacobsmod = tpt.version.jacob1s_mod~=nil
math.randomseed(os.time())
local username = tpt.get_name()
if username=="" then error"Please Identify" end
local con = {connected = false,
		 socket = nil,
		 members = nil,
		 pingTime = os.time()+60}
local function conSend(cmd,msg,endNull)
	if not con.connected then return false,"Not connected" end
	msg = msg or ""
	if endNull then msg = msg.."\0" end
	if cmd then msg = string.char(cmd)..msg end
	--print("sent "..msg)
	con.socket:send(msg)
end
local function joinChannel(chan)
	conSend(16,chan,true)
	--send some things to new channel
	conSend(34,string.char(L.brushx,L.brushy))
	conSend(37,string.char(math.floor(L.sell/256),L.sell%256))
	conSend(37,string.char(math.floor(64 + L.sela/256),L.sela%256))
	conSend(37,string.char(math.floor(128 + L.selr/256),L.selr%256))
	conSend(65,string.char(math.floor(L.dcolour/16777216),math.floor(L.dcolour/65536)%256,math.floor(L.dcolour/256)%256,L.dcolour%256))
end
local function connectToMniip(ip,port)
	if con.connected then return false,"Already connected" end
	ip = ip or "mniip.com"
	port = port or PORT
	local sock = socket.tcp()
	sock:settimeout(10)
	local s,r = sock:connect(ip,port)
	if not s then return false,r end
	sock:settimeout(0)
	sock:setoption("keepalive",true)
	sock:send(string.char(tpt.version.major)..string.char(tpt.version.minor)..username.."\0")
	local c,r
	while not c do
	c,r = sock:receive(1)
	if not c and r~="timeout" then break end
	end
	if not c and r~="timeout" then return false,r end

	if c~= "\1" then 
	if c=="\0" then
		local err=""
		c,r = sock:receive(1)
		while c~="\0" do
		err = err..c
		c,r = sock:receive(1)
		end
		return false,err
	end
	return false,"Bad Connect"
	end

	con.socket = sock
	con.connected = true
	return true
end
--get up to a null (\0)
local function conGetNull()
	con.socket:settimeout(nil)
	local c,r = con.socket:receive(1)
	local rstring=""
	while c~="\0" do
	rstring = rstring..c
	c,r = con.socket:receive(1)
	end
	con.socket:settimeout(0)
	return rstring
end
--get next char/byte
local function cChar()
	con.socket:settimeout(nil)
	local c,r = con.socket:receive(1)
	con.socket:settimeout(0)
	return c or error(r)
end
local function cByte()
	return cChar():byte()
end
--return table of arguments
local function getArgs(msg)
	if not msg then return {} end
	local args = {}
	for word in msg:gmatch("([^%s%c]+)") do
	table.insert(args,word)
	end
	return args
end

--get different lists for other language keyboards
local keyboardshift = { {before=" qwertyuiopasdfghjklzxcvbnm1234567890-=.,/`|;'[]\\",after=" QWERTYUIOPASDFGHJKLZXCVBNM!@#$%^&*()_+><?~\\:\"{}|",},{before=" qwertyuiopasdfghjklzxcvbnm1234567890+,.-'真真真真真真真<",after=" QWERTYUIOPASDFGHJKLZXCVBNM!\"#真真真�%&/()=?;:_*`^>",}  }
local keyboardaltrg = { {nil},{before=" qwertyuiopasdfghjklzxcvbnm1234567890+,.-'真真真�<",after=" qwertyuiopasdfghjklzxcvbnm1@真真真�$�6{[]}\\,.-'~|",},}

local function shift(s)
	if keyboardshift[KEYBOARD]~=nil then
		return (s:gsub("(.)",function(c)return keyboardshift[KEYBOARD]["after"]:sub(keyboardshift[KEYBOARD]["before"]:find(c,1,true))end))
	else return s end
end
local function altgr(s)
	if keyboardaltgr[KEYBOARD]~=nil then
		return (s:gsub("(.)",function(c)return keyboardaltgr[KEYBOARD]["after"]:sub(keyboardaltgr[KEYBOARD]["before"]:find(c,1,true))end))
	else return s end
end

local ui_base local ui_box local ui_text local ui_button local ui_scrollbar local ui_inputbox local ui_chatbox
ui_base = {
new = function()
	local b={}
	b.drawlist = {}
	function b:drawadd(f)
		table.insert(self.drawlist,f)
	end
	function b:draw(...)
		for _,f in ipairs(self.drawlist) do
			if type(f)=="function" then
				f(self,unpack(arg))
			end
		end
	end
	b.movelist = {}
	function b:moveadd(f)
		table.insert(self.movelist,f)
	end
	function b:onmove(x,y)
		for _,f in ipairs(self.movelist) do
			if type(f)=="function" then
				f(self,x,y)
			end
		end
	end
	return b
end
}
ui_box = {
new = function(x,y,w,h,r,g,b)
	local box=ui_base.new()
	box.x=x box.y=y box.w=w box.h=h box.x2=x+w box.y2=y+h
	box.r=r or 255 box.g=g or 255 box.b=b or 255
	function box:setcolor(r,g,b) self.r=r self.g=g self.b=b end
	function box:setbackground(r,g,b,a) self.br=r self.bg=g self.bb=b self.ba=a end
	box.drawbox=true
	box.drawbackground=false
	box:drawadd(function(self) if self.drawbackground then tpt.fillrect(self.x,self.y,self.w,self.h,self.br,self.bg,self.bb,self.ba) end
								if self.drawbox then tpt.drawrect(self.x,self.y,self.w,self.h,self.r,self.g,self.b) end end)
	box:moveadd(function(self,x,y)
		if x then self.x=self.x+x self.x2=self.x2+x end
		if y then self.y=self.y+y self.y2=self.y2+y end
	end)
	return box
end
}
ui_text = {
new = function(text,x,y,r,g,b)
	local txt = ui_base.new()
	txt.text = text
	txt.x=x or 0 txt.y=y or 0 txt.r=r or 255 txt.g=g or 255 txt.b=b or 255
	function txt:setcolor(r,g,b) self.r=r self.g=g self.b=b end
	txt:drawadd(function(self,x,y) tpt.drawtext(x or self.x,y or self.y,self.text,self.r,self.g,self.b) end)
	txt:moveadd(function(self,x,y) 
		if x then self.x=self.x+x end
		if y then self.y=self.y+y end   
	end)
	function txt:process() return false end
	return txt
end,
--Scrolls while holding mouse over
newscroll = function(text,x,y,vis,force,r,g,b)
	local txt = ui_text.new(text,x,y,r,g,b)
	if not force and tpt.textwidth(text)<vis then return txt end
	txt.visible=vis
	txt.length=string.len(text)
	txt.start=1
	local last=2
	while tpt.textwidth(text:sub(1,last))<vis and last<=txt.length do
		last=last+1
	end
	txt.last=last-1
	txt.minlast=last-1
	txt.ppl=((txt.visible-6)/(txt.length-txt.minlast+1))
	function txt:update(text,pos)
		if text then 
			self.text=text
			self.length=string.len(text)
			local last=2
			while tpt.textwidth(text:sub(1,last))<self.visible and last<=self.length do
				last=last+1
			end
			self.minlast=last-1
			self.ppl=((self.visible-6)/(self.length-self.minlast+1))
			if not pos then self.last=self.minlast end
		end
		if pos then
			if pos>=self.last and pos<=self.length then --more than current visible
				local newlast = pos
				local newstart=1
				while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
				end
				self.start=newstart self.last=newlast
			elseif pos<self.start and pos>0 then --position less than current visible
				local newstart=pos
				local newlast=pos+1
				while tpt.textwidth(self.text:sub(newstart,newlast))<self.visible and newlast<self.length do
						newlast=newlast+1
				end
				self.start=newstart self.last=newlast-1
			end
			--keep strings as long as possible (pulls from left)
			local newlast=self.last
			if newlast<self.minlast then newlast=self.minlast end
			local newstart=1
			while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
			end
			self.start=newstart self.last=newlast
		end
	end
	txt.drawlist={} --reset draw
	txt:drawadd(function(self,x,y) 
		tpt.drawtext(x or self.x,y or self.y, self.text:sub(self.start,self.last) ,self.r,self.g,self.b) 
	end)
	function txt:process(mx,my,button,event,wheel)
		if event==3 then
			local newlast = math.floor((mx-self.x)/self.ppl)+self.minlast
			if newlast<self.minlast then newlast=self.minlast end
			if newlast>0 and newlast~=self.last then
				local newstart=1
				while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
				end
				self.start=newstart self.last=newlast
			end
		end
	end
	return txt
end
}
ui_inputbox = {
new=function(x,y,w,h)
	local intext=ui_box.new(x,y,w,h)
	intext.cursor=0
	intext.focus=false
	intext.t=ui_text.newscroll("",x+2,y+2,w-2,true)
	intext:drawadd(function(self)
		local cursoradjust=tpt.textwidth(self.t.text:sub(self.t.start,self.cursor))+2
		tpt.drawline(self.x+cursoradjust,self.y,self.x+cursoradjust,self.y+10,255,255,255)
		self.t:draw()
	end)
	intext:moveadd(function(self,x,y) self.t:onmove(x,y) end)
	function intext:setfocus(focus)
		self.focus=focus
		if focus then tpt.set_shortcuts(0) self:setcolor(255,255,0)
		else tpt.set_shortcuts(1) self:setcolor(255,255,255) end
	end
	function intext:movecursor(amt)
		self.cursor = self.cursor+amt
		if self.cursor>self.t.length then self.cursor = self.t.length end
		if self.cursor<0 then self.cursor = 0 return end
	end
	function intext:textprocess(key,nkey,modifier,event)
		local modi = (modifier%1024)
		if not self.focus then return false end
		if event~=1 then return end
		if nkey==13 then local text=self.t.text self.cursor=0 self.t.text="" return text end --enter
		local newstr
		if nkey==275 then self:movecursor(1) self.t:update(nil,self.cursor) return end --right
		if nkey==276 then self:movecursor(-1) self.t:update(nil,self.cursor) return end --left
		if nkey==8 then newstr=self.t.text:sub(1,self.cursor-1) .. self.t.text:sub(self.cursor+1) self:movecursor(-1) --back
		elseif nkey==127 then newstr=self.t.text:sub(1,self.cursor) .. self.t.text:sub(self.cursor+2) --delete
		else 
			if nkey<32 or nkey>=127 then return end --normal key
			local addkey = (modi==1 or modi==2) and shift(key) or key
			if (math.floor(modi/512))==1 then addkey=altgr(key) end
			newstr = self.t.text:sub(1,self.cursor) .. addkey .. self.t.text:sub(self.cursor+1)
			self.t:update(newstr,self.cursor+1)
			self:movecursor(1)
			return
		end
		if newstr then
			self.t:update(newstr,self.cursor)
		end
		--some actual text processing, lol
	end
	return intext
end
}
ui_scrollbar = {
new = function(x,y,h,t,m)
	local bar = ui_base.new() --use line object as base?
	bar.x=x bar.y=y bar.h=h
	bar.total=t
	bar.numshown=m
	bar.pos=0
	bar.length=math.floor((1/math.ceil(bar.total-bar.numshown+1))*bar.h)
	bar.soffset=math.floor(bar.pos*((bar.h-bar.length)/(bar.total-bar.numshown)))
	function bar:update(total,shown,pos)
		self.pos=pos or 0
		if self.pos<0 then self.pos=0 end
		self.total=total
		self.numshown=shown
		self.length= math.floor((1/math.ceil(self.total-self.numshown+1))*self.h)
		self.soffset= math.floor(self.pos*((self.h-self.length)/(self.total-self.numshown)))
	end
	function bar:move(wheel)
		self.pos = self.pos-wheel
		if self.pos < 0 then self.pos=0 end
		if self.pos > (self.total-self.numshown) then self.pos=(self.total-self.numshown) end
		self.soffset= math.floor(self.pos*((self.h-self.length)/(self.total-self.numshown)))
	end
	bar:drawadd(function(self)
		if self.total > self.numshown then
			tpt.drawline(self.x,self.y+self.soffset,self.x,self.y+self.soffset+self.length)
		end
	end)
	bar:moveadd(function(self,x,y) 
		if x then self.x=self.x+x end
		if y then self.y=self.y+y end   
	end)
	function bar:process(mx,my,button,event,wheel)
		if wheel~=0 and not hidden_mode then
			if self.total > self.numshown then
				local previous = self.pos
				self:move(wheel)
				if self.pos~=previous then
					return wheel
				end
			end
		end
		--possibly click the bar and drag?
		return false
	end
	return bar
end
}
ui_button = {
new = function(x,y,w,h,f,text)
	local b = ui_box.new(x,y,w,h)
	b.f=f
	b.t=ui_text.new(text,x+2,y+2)
	b.drawbox=false
	b.almostselected=false
	b.invert=true
	b:drawadd(function(self) 
		if self.invert and self.almostselected then
			self.almostselected=false
			tpt.fillrect(self.x,self.y,self.w,self.h)
			local tr=self.t.r local tg=self.t.g local tb=self.t.b
			b.t:setcolor(0,0,0)
			b.t:draw()
			b.t:setcolor(tr,tg,tb)
		else
			b.t:draw() 
		end
	end)
	b:moveadd(function(self,x,y)
		self.t:onmove(x,y) 
	end)
	function b:process(mx,my,button,event,wheel)
		if mx<self.x or mx>self.x2 or my<self.y or my>self.y2 then return false end
		if event==3 then self.almostselected=true end
		if event==2 then self:f() end
		return true
	end
	return b
end
}
ui_chatbox = {
new=function(x,y,w,h)
	local chat=ui_box.new(x,y,w,h)
	chat.moving=false
	chat.lastx=0
	chat.lasty=0
	chat.relx=0
	chat.rely=0
	chat.shown_lines=math.floor(chat.h/10)-2 --one line for top, one for chat
	chat.max_width=chat.w-4
	chat.max_lines=200
	chat.lines = {}
	chat.scrollbar = ui_scrollbar.new(chat.x2-2,chat.y+11,chat.h-22,0,chat.shown_lines)
	chat.inputbox = ui_inputbox.new(x,chat.y2-10,w,10)
	chat:drawadd(function(self)
		tpt.drawtext(self.x+50,self.y+2,"Chat Box")
		tpt.drawline(self.x+1,self.y+10,self.x2-1,self.y+10,120,120,120)
		self.scrollbar:draw()
		local count=0
		for i,line in ipairs(self.lines) do
			if i>self.scrollbar.pos and i<= self.scrollbar.pos+self.shown_lines then
				line:draw(self.x+3,self.y+12+(count*10))
				count = count+1
			end
		end
		self.inputbox:draw()
	end)
	chat:moveadd(function(self,x,y)
		for i,line in ipairs(self.lines) do
			line:onmove(x,y)
		end
		self.scrollbar:onmove(x,y)
		self.inputbox:onmove(x,y)
	end)
	function chat:addline(line,r,g,b)
		if not line or line=="" then return end --No blank lines
		table.insert(self.lines,ui_text.newscroll(line,self.x,0,self.max_width,false,r,g,b))
		if #self.lines>self.max_lines then table.remove(self.lines,1) end
		self.scrollbar:update(#self.lines,self.shown_lines,#self.lines-self.shown_lines)
	end
	function chat:process(mx,my,button,event,wheel)
		if self.moving and event==3 then
			local newx,newy = mx-self.relx,my-self.rely
			local ax,ay = 0,0
			if newx<0 then ax = newx end
			if newy<0 then ay = newy end
			if (newx+self.w)>=612 then ax = newx+self.w-612 end
			if (newy+self.h)>=384 then ay = newy+self.h-384 end
			self:onmove(mx-self.lastx-ax,my-self.lasty-ay)
			self.lastx=mx-ax
			self.lasty=my-ay
			return true
		end
		if self.moving and event==2 then self.moving=false return true end
		if mx<self.x or mx>self.x2 or my<self.y or my>self.y2 then self.inputbox:setfocus(false) return false end
		self.scrollbar:process(mx,my,button,event,wheel)
		local which = math.floor((my-self.y)/10)
		if event==1 and which==0 then self.moving=true self.lastx=mx self.lasty=my self.relx=mx-self.x self.rely=my-self.y return true end
		if which==self.shown_lines+1 then self.inputbox:setfocus(true) return true else self.inputbox:setfocus(false) end --trigger input_box
		if which>0 and which<self.shown_lines+1 and self.lines[which+self.scrollbar.pos] then self.lines[which+self.scrollbar.pos]:process(mx,my,button,event,wheel) end
		return true
	end
	--commands for chat window
	chatcommands = {
	connect = function(self,msg,args)
		if not issocket then self:addline("No luasockets found") return end
		local s,r = connectToMniip(args[1],tonumber(args[2]))
		if not s then self:addline(r) end
	end,
	send = function(self,msg,args)
		if tonumber(args[1]) and args[2] then
		local withNull=false
		if args[2]=="true" then withNull=true end
		rest = rest or ""
		conSend(tonumber(args[1]),rest:sub(#args[1]+#args[2]+2),withNull)
		end
	end,
	quit = function(self,msg,args)
		con.socket:close()
		self:addline("Disconnected")
		con.connected = false
		con.members = {}
	end,
	join = function(self,msg,args)
		if args[1] then joinChannel(args[1]) end

	end,
	}
	function chat:textprocess(key,nkey,modifier,event)
		local text = self.inputbox:textprocess(key,nkey,modifier,event)
		if text then
			local cmd = text:match("^/([^%s]+)")
			if cmd then
				local rest=text:sub(#cmd+3)
				local args = getArgs(rest)
				self:addline("CMD: "..cmd.." "..rest)
				if chatcommands[cmd] then chatcommands[cmd](self,msg,args) end
			else
				--normal chat
				conSend(19,text,true)
				self:addline(username .. ": ".. text) 
			end
		end
		if text==false then return false end
	end
	return chat
end
}

chatwindow = ui_chatbox.new(100,100,150,200)
chatwindow:setbackground(10,10,10,235) chatwindow.drawbackground=true

local eleNameTable = {
["DEFAULT_PT_LIFE_GOL"] = 256,["DEFAULT_PT_LIFE_HLIF"] = 257,["DEFAULT_PT_LIFE_ASIM"] = 258,["DEFAULT_PT_LIFE_2x2"] = 259,["DEFAULT_PT_LIFE_DANI"] = 260,
["DEFAULT_PT_LIFE_AMOE"] = 261,["DEFAULT_PT_LIFE_MOVE"] = 262,["DEFAULT_PT_LIFE_PGOL"] = 263,["DEFAULT_PT_LIFE_DMOE"] = 264,["DEFAULT_PT_LIFE_34"] = 265,
["DEFAULT_PT_LIFE_LLIF"] = 276,["DEFAULT_PT_LIFE_STAN"] = 267,["DEFAULT_PT_LIFE_SEED"] = 268,["DEFAULT_PT_LIFE_MAZE"] = 269,["DEFAULT_PT_LIFE_COAG"] = 270,
["DEFAULT_PT_LIFE_WALL"] = 271,["DEFAULT_PT_LIFE_GNAR"] = 272,["DEFAULT_PT_LIFE_REPL"] = 273,["DEFAULT_PT_LIFE_MYST"] = 274,["DEFAULT_PT_LIFE_LOTE"] = 275,
["DEFAULT_PT_LIFE_FRG2"] = 276,["DEFAULT_PT_LIFE_STAR"] = 277,["DEFAULT_PT_LIFE_FROG"] = 278,["DEFAULT_PT_LIFE_BRAN"] = 279,
["DEFAULT_WL_0"] = 280,["DEFAULT_WL_1"] = 281,["DEFAULT_WL_2"] = 282,["DEFAULT_WL_3"] = 283,["DEFAULT_WL_4"] = 284,
["DEFAULT_WL_5"] = 285,["DEFAULT_WL_6"] = 286,["DEFAULT_WL_7"] = 287,["DEFAULT_WL_8"] = 288,["DEFAULT_WL_9"] = 289,["DEFAULT_WL_10"] = 290,
["DEFAULT_WL_11"] = 291,["DEFAULT_WL_12"] = 292,["DEFAULT_WL_13"] = 293,["DEFAULT_WL_14"] = 294,["DEFAULT_WL_15"] = 295,
["DEFAULT_UI_SAMPLE"] = 296,["DEFAULT_UI_SIGN"] = 297,["DEFAULT_UI_PROPERTY"] = 298,["DEFAULT_UI_WIND"] = 299,
["DEFAULT_TOOL_HEAT"] = 300,["DEFAULT_TOOL_COOL"] = 301,["DEFAULT_TOOL_VAC"] = 302,["DEFAULT_TOOL_AIR"] = 303,["DEFAULT_TOOL_GRAV"] = 304,["DEFAULT_TOOL_NGRV"] = 305,
["DEFAULT_DECOR_SET"] = 306,["DEFAULT_DECOR_ADD"] = 307,["DEFAULT_DECOR_SUB"] = 308,["DEFAULT_DECOR_MUL"] = 309,["DEFAULT_DECOR_DIV"] = 310,["DEFAULT_DECOR_SMDG"] = 311,["DEFAULT_DECOR_CLR"] = 312,
}
local golStart,golEnd=256,279
local wallStart,wallEnd=280,295
local toolStart,toolEnd=300,305
local decoStart,decoEnd=306,312

--Functions that do stuff in powdertoy
local function createBoxAny(x1,y1,x2,y2,c,user)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWallBox(x1,y1,x2,y2,c-wallStart)
		elseif c<=toolEnd then
			if c>=toolStart then sim.toolBox(x1,y1,x2,y2,c-toolStart) end
		elseif c<= decoEnd then
			sim.decoBox(x1,y1,x2,y2,user.dcolour[2],user.dcolour[3],user.dcolour[4],user.dcolour[1],c-decoStart)
		end
		return
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createBox(x1,y1,x2,y2,c)
end
local function createPartsAny(x,y,rx,ry,c,brush,user)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWalls(x,y,rx,ry,c-wallStart,brush)
		elseif c<=toolEnd then
			if c>=toolStart then sim.toolBrush(x,y,rx,ry,c-toolStart,brush) end
		elseif c<= decoEnd then
			sim.decoBrush(x,y,rx,ry,user.dcolour[2],user.dcolour[3],user.dcolour[4],user.dcolour[1],c-decoStart,brush)
		end
		return
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createParts(x,y,rx,ry,c,brush)
end
local function createLineAny(x1,y1,x2,y2,rx,ry,c,brush,user)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWallLine(x1,y1,x2,y2,rx,ry,c-wallStart,brush)
		elseif c<=toolEnd then
			if c>=toolStart then sim.toolLine(x1,y1,x2,y2,rx,ry,c-toolStart,brush) end
		elseif c<= decoEnd then
			sim.decoLine(x1,y1,x2,y2,rx,ry,user.dcolour[2],user.dcolour[3],user.dcolour[4],user.dcolour[1],c-decoStart,brush)
		end
		return
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createLine(x1,y1,x2,y2,rx,ry,c,brush)
end
local function floodAny(x,y,c,cm,bm)
	if c>=wallStart then
		if c<= wallEnd then
			sim.floodWalls(x,y,c-wallStart,cm,bm)
		end
		--other tools shouldn't flood
		return
	elseif c>=golStart then --GoL adjust
		c = 78+(c-golStart)*256
	end
	sim.floodParts(x,y,c,cm,bm)
end

--clicky click
local function playerMouseClick(id,btn,ev)
	local user = con.members[id]
	local createE, checkBut
	
	--MANAGER_PRINT(tostring(btn)..tostring(ev))
	if ev==0 then return end
	if btn==1 then
		user.rbtn,user.abtn = false,false
		createE,checkBut=user.selectedl,user.lbtn
	elseif btn==2 then
		user.rbtn,user.lbtn = false,false
		createE,checkBut=user.selecteda,user.abtn
	elseif btn==4 then
		user.lbtn,user.abtn = false,false
		createE,checkBut=user.selectedr,user.rbtn
	else return end
	
	if user.mousex>=612 or user.mousey>=384 then user.drawtype=false return end
	
	if ev==1 then
		user.pmx,user.pmy = user.mousex,user.mousey
		if not user.drawtype then
			--left box
			if user.ctrl and not user.shift then user.drawtype = 2 return end
			--left line
			if user.shift and not user.ctrl then user.drawtype = 1 return end
			--floodfill
			if user.ctrl and user.shift then floodAny(user.mousex,user.mousey,createE,-1) user.drawtype = 3 return end
			--an alt click
			if user.alt then return end
			user.drawtype=4 --normal hold
		end
		createPartsAny(user.mousex,user.mousey,user.brushx,user.brushy,createE,user.brush,user)
	elseif ev==2 and checkBut and user.drawtype then
		--need to check alt on up!!!
		if user.drawtype==2 then createBoxAny(user.mousex,user.mousey,user.pmx,user.pmy,createE,user)
		else createLineAny(user.mousex,user.mousey,user.pmx,user.pmy,user.brushx,user.brushy,createE,user.brush,user) end
		user.drawtype=false
		user.pmx,user.pmy = user.mousex,user.mousey
	end
end
--To draw continued lines
local function playerMouseMove(id)
	local user = con.members[id]
	local createE, checkBut
	if user.lbtn then
		createE,checkBut=user.selectedl,user.lbtn
	elseif user.rbtn then
		createE,checkBut=user.selectedr,user.rbtn
	elseif user.abtn then
		createE,checkBut=user.selecteda,user.abtn
	end
	if user.drawtype~=4 then if user.drawtype==3 then floodAny(user.mousex,user.mousey,createE,-1) end return end
	if checkBut==3 then
		if user.mousex>=612 then user.mousex=611 end
		if user.mousey>=384 then user.mousey=383 end
		createLineAny(user.mousex,user.mousey,user.pmx,user.pmy,user.brushx,user.brushy,createE,user.brush,user)
		user.pmx,user.pmy = user.mousex,user.mousey
	end
end
local function loadStamp(size,x,y,reset)
	con.socket:settimeout(nil)
	local s = con.socket:receive(size)
	con.socket:settimeout(0)
	local f = io.open(".tmp.stm","wb")
	f:write(s)
	f:close()
	if reset then sim.clearSim() end
	sim.loadStamp(".tmp.stm",x,y)
	os.remove".tmp.stm"
end

local dataCmds = {
	[2] = function() conSend(2,"",false) end,
	[16] = function()
	--room members
		con.members = {}
		local amount = cByte()
		local peeps = {}
		for i=1,amount do
			local id = cByte()
			con.members[id]={name=conGetNull(),mousex=0,mousey=0,brushx=4,brushy=4,brush=0,selectedl=1,selectedr=0,selecteda=296,lbtn=false,abtn=false,rbtn=false,ctrl=false,shift=false,alt=false}
			local name = con.members[id].name
			table.insert(peeps,name)
		end
		chatwindow:addline("Online: "..table.concat(peeps," "))
	end,
	[17]= function()
		local id = cByte()
		con.members[id] ={name=conGetNull(),mousex=0,mousey=0,brushx=4,brushy=4,brush=0,selectedl=1,selectedr=0,selecteda=296,dcolour={0,0,0,0},lbtn=false,abtn=false,rbtn=false,ctrl=false,shift=false,alt=false}
		chatwindow:addline(con.members[id].name.." has joined")
	end,
	[18] = function()
		local id = cByte()
		chatwindow:addline(con.members[id].name.." has left")
		con.members[id]=nil
	end,
	[19] = function()
		chatwindow:addline(con.members[cByte()].name .. ": " .. conGetNull())
	end,
	--Mouse Position
	[32] = function()
		local id = cByte()
		local b1,b2,b3=cByte(),cByte(),cByte()
		con.members[id].mousex,con.members[id].mousey=((b1*16)+math.floor(b2/16)),((b2%16)*256)+b3
		--MANAGER_PRINT("x "..tostring(con.members[id].mousex).." y "..tostring(con.members[id].mousey))
		playerMouseMove(id)
	end,
	--Mouse Click
	[33] = function()
		local id = cByte()
		local d=cByte()
		local btn,ev=math.floor(d/16),d%16
		playerMouseClick(id,btn,ev)
		if ev==0 then return end
		if btn==1 then
			con.members[id].lbtn=ev
		elseif btn==2 then
			con.members[id].abtn=ev
		elseif btn==4 then
			con.members[id].rbtn=ev
		end
	end,
	--Brush size
	[34] = function()
		local id = cByte()
		con.members[id].brushx,con.members[id].brushy=cByte(),cByte()
	end,
	--Brush Shape change, no args
	[35] = function()
		local id = cByte()
		con.members[id].brush=(con.members[id].brush+1)%3
	end,
	--Modifier (mod and state)
	[36] = function()
		local id = cByte()
		local d=cByte()
		local mod,state=math.floor(d/16),d%16~=0
		if mod==0 then
			con.members[id].ctrl=state
		elseif mod==1 then
			con.members[id].shift=state
		elseif mod==2 then
			con.members[id].alt=state
		end
	end,
	--selected elements (2 bits button, 14-element)
	[37] = function()
		local id = cByte()
		local b1,b2=cByte(),cByte()
		local btn,el=math.floor(b1/64),(b1%64)*256+b2
		if btn==0 then
			con.members[id].selectedl=el
		elseif btn==1 then
			con.members[id].selecteda=el
		elseif btn==2 then
			con.members[id].selectedr=el
		end
	end,
	--cmode defaults (1 byte mode)
	[48] = function()
		local id = cByte()
		tpt.display_mode(cByte())
		--Display who set mode?
	end,
	--pause set (1 byte state)
	[49] = function()
		local id = cByte()
		tpt.set_pause(cByte())
		--Display who set pause?
	end,
	--step frame, no args
	[50] = function()
		local id = cByte()
		tpt.set_pause(0)
		L.pauseNextFrame=true
	end,
	
	--deco mode, (1 byte state)
	[51] = function()
		local id = cByte()
		tpt.decorations_enable(cByte())
	end,
	--[[HUD mode, (1 byte state), deprecated
	[52] = function()
		local id = cByte()
		local hstate = cByte()
		tpt.hud(hstate)
	end,
	--]]
	--amb heat mode, (1 byte state)
	[53] = function()
		local id = cByte()
		tpt.ambient_heat(cByte())
	end,
	--newt_grav mode, (1 byte state)
	[54] = function()
		local id = cByte()
		tpt.newtonian_gravity(cByte())
	end,
	
	--[[
	--debug mode (1 byte state?) can't implement
	[55] = function()
		local id = cByte()
		--local dstate = cByte()
		tpt.setdebug()
	end,
	--]]
	--legacy heat mode, (1 byte state)
	[56] = function()
		local id = cByte()
		tpt.heat(cByte())
	end,
	--water equal, can ONLY toggle, could lose sync (no args)
	[57] = function()
		local id = cByte()
		tpt.watertest()
	end,
	--[[
	--grav mode, (1 byte state) can't implement yet
	[58] = function()
		local id = cByte()
		tpt.something_gravmode(cByte())
	end,
	--air mode, (1 byte state) can't implement yet
	[59] = function()
		local id = cByte()
		tpt.something_airmode(cByte())
	end,
	--]]
	
	--Should these three be combined into one number with an arg determining what runs?
	--clear sparks (no args)
	[60] = function()
		local id = cByte()
		tpt.reset_spark()
	end,
	--clear pressure/vel (no args)
	[61] = function()
		local id = cByte()
		tpt.reset_velocity()
		tpt.set_pressure()
	end,
	--invert pressure (no args)
	[62] = function()
		local id = cByte()
		for x=0,152 do
			for y=0,95 do
				sim.pressure(x,y,-sim.pressure(x,y))
			end
		end
	end,
	--Clearsim button (no args)
	[63] = function()
		local id = cByte()
		sim.clearSim()
	end,

	--[[
	--Full graphics view mode (for manual changes in display menu) (3 bytes?)
	[64] = function()
		local id = cByte()
		--do stuff with these
		--ren.displayModes()
		--ren.renderModes()
		--ren.colorMode
	end,
	--]]
	--Selected deco colour (4 bytes)
	[65] = function()
		local id = cByte()
		con.members[id].dcolour = {cByte(),cByte(),cByte(),cByte()}
	end,
	--Recieve a stamp, with location (6 bytes location(3),size(3))
	[66] = function()
		local id = cByte()
		local b1,b2,b3=cByte(),cByte(),cByte()
		local x,y =((b1*16)+math.floor(b2/16)),((b2%16)*256)+b3
		local d = cByte()*65536+cByte()*256+cByte()
		loadStamp(d,x,y,false)
	end,
	--Clear an area, helper for cut (6 bytes, start(3), end(3))
	[67] = function()
		local id = cByte()
		local b1,b2,b3,b4,b5,b6=cByte(),cByte(),cByte(),cByte(),cByte(),cByte()
		local x1,y1 =((b1*16)+math.floor(b2/16)),((b2%16)*256)+b3
		local x2,y2 =((b4*16)+math.floor(b5/16)),((b5%16)*256)+b6
		--clear walls and parts
		createBoxAny(x1,y1,x2,y2,280)
		createBoxAny(x1,y1,x2,y2,0)
	end,
	--A request to send stamp, from server
	[128] = function()
		local id = cByte()
		local n = "stamps/"..sim.saveStamp(0,0,611,383)..".stm"
		local f = assert(io.open(n))
		local s = f:read"*a"
		f:close()
		os.remove(n)
		local d = #s
		conSend(128,string.char(id,math.floor(d/65536),math.floor(d/256)%256,d%256)..s)
	end,
	--Recieve sync stamp
	[129] = function()
		local d = cByte()*65536+cByte()*256+cByte()
		loadStamp(d,0,0,true)
	end,
}

local function connectThink()
	if not con.connected then return end
	if not con.socket then chatwindow:addline("Disconnected") con.connected=false return end
	--check byte for message
	while 1 do --real all per frame now...
		local s,r = con.socket:receive(1)
		if s then
			local cmd = string.byte(s)
			--MANAGER_PRINT("GOT "..tostring(cmd))
			if dataCmds[cmd] then dataCmds[cmd]() end
		else break end
	end

	--ping every minute
	if os.time()>con.pingTime then conSend(2) con.pingTime=os.time()+60 end
end

local function drawStuff()
	if con.members then
		for i,user in pairs(con.members) do
			local x,y = user.mousex,user.mousey
			local brx,bry=user.brushx,user.brushy
			local brush,drawBrush=user.brush,true
			tpt.drawtext(x,y,("%s %dx%d"):format(user.name,brx,bry),0,255,0,192)
			if user.drawtype then
				if user.drawtype==1 then
					tpt.drawline(user.pmx,user.pmy,x,y,0,255,0,128)
				elseif user.drawtype==2 then
					local tpmx,tpmy = user.pmx,user.pmy
					if tpmx>x then tpmx,x=x,tpmx end
					if tpmy>y then tpmy,y=y,tpmy end
					tpt.drawrect(tpmx,tpmy,x-tpmx,y-tpmy,0,255,0,128)
					drawBrush=false
				elseif user.drawtype==3 then
					for cross=1,5 do
						tpt.drawpixel(x+cross,y,0,255,0,128)
						tpt.drawpixel(x-cross,y,0,255,0,128)
						tpt.drawpixel(x,y+cross,0,255,0,128)
						tpt.drawpixel(x,y-cross,0,255,0,128)
					end
					drawBrush=false
				end
			end
			if drawBrush then
				if brush==0 then
					gfx.drawCircle(x,y,brx,bry,0,255,0,128)
				elseif brush==1 then
					gfx.drawRect(x-brx,y-bry,brx*2+1,bry*2+1,0,255,0,128)
				elseif brush==2 then
					gfx.drawLine(x-brx,y+bry,x,y-bry,0,255,0,128)
					gfx.drawLine(x-brx,y+bry,x+brx,y+bry,0,255,0,128)
					gfx.drawLine(x,y-bry,x+brx,y+bry,0,255,0,128)
				end
			end
		end
	end
end

local function sendStuff()
    if not con.connected then return end
    --mouse position every frame, not exactly needed, might be better/more accurate from clicks
    local nmx,nmy = tpt.mousex,tpt.mousey
    if nmx<612 and nmy<384 then nmx,nmy = sim.adjustCoords(nmx,nmy) end
    if L.mousex~= nmx or L.mousey~= nmy then
        L.mousex,L.mousey = nmx,nmy
		local b1,b2,b3 = math.floor(L.mousex/16),((L.mousex%16)*16)+math.floor(L.mousey/256),(L.mousey%256)
		conSend(32,string.char(b1,b2,b3))
    end
	local nbx,nby = tpt.brushx,tpt.brushy
	if L.brushx~=nbx or L.brushy~=nby then
		L.brushx,L.brushy = nbx,nby
		conSend(34,string.char(L.brushx,L.brushy))
	end
    --check selected elements
    local nsell,nsela,nselr = elements[tpt.selectedl] or eleNameTable[tpt.selectedl],elements[tpt.selecteda] or eleNameTable[tpt.selecteda],elements[tpt.selectedr] or eleNameTable[tpt.selectedr]
    if L.sell~=nsell then
		L.sell=nsell
		conSend(37,string.char(math.floor(L.sell/256),L.sell%256))
    elseif L.sela~=nsela then
		L.sela=nsela
		conSend(37,string.char(math.floor(64 + L.sela/256),L.sela%256))
    elseif L.selr~=nselr then
		L.selr=nselr
		conSend(37,string.char(math.floor(128 + L.selr/256),L.selr%256))
    end
    local ncol = sim.decoColour()
    if L.dcolour~=ncol then
		L.dcolour=ncol
		conSend(65,string.char(math.floor(ncol/16777216),math.floor(ncol/65536)%256,math.floor(ncol/256)%256,ncol%256))
    end
	if L.sendScreen then
		local x,y,w,h = 0,0,611,383
		if L.smoved then
			local stm
			if L.copying then stm=L.lastCopy else stm=L.lastStamp end
			if L.rotate then stm.w,stm.h=stm.h,stm.w end
			x,y,w,h = math.floor((L.mousex-stm.w/2)/4)*4,math.floor((L.mousey-stm.h/2)/4)*4,stm.w,stm.h
			L.smoved=false
			L.copying=false
		end
		local n = "stamps/"..sim.saveStamp(x,y,w,h)..".stm"
		local f = assert(io.open(n))
		local s = f:read"*a"
		f:close()
		os.remove(n)
		local d = #s
		local b1,b2,b3 = math.floor(x/16),((x%16)*16)+math.floor(y/256),(y%256)
		conSend(66,string.char(b1,b2,b3,math.floor(d/65536),math.floor(d/256)%256,d%256)..s)
		L.sendScreen=false
	end
end

local function step()
	chatwindow:draw()
	drawStuff()
	sendStuff()
	if L.pauseNextFrame then L.pauseNextFrame=false tpt.set_pause(1) end
	connectThink()
end

--some button locations that emulate tpt, return false will disable button
local tpt_buttons = {
	["clear"] = {x1=470, y1=408, x2=486, y2=422, f=function() conSend(63) end},
	["pause"] = {x1=613, y1=408, x2=627, y2=422, f=function() conSend(49,tpt.set_pause()==0 and "\1" or "\0") end},
	["deco"] = {x1=613, y1=33, x2=627, y2=47, f=function() conSend(51,tpt.decorations_enable()==0 and "\1" or "\0") end},
	["newt"] = {x1=613, y1=49, x2=627, y2=63, f=function() conSend(54,tpt.newtonian_gravity()==0 and "\1" or "\0") end},
	["ambh"] = {x1=613, y1=65, x2=627, y2=79, f=function() conSend(53,tpt.ambient_heat()==0 and "\1" or "\0") end},
	["disp"] = {x1=597, y1=408, x2=611, y2=422, f=function() --[[activate a run once display mode check on next step]] end},
	["open"] = {x1=1, y1=408, x2=17, y2=422, f=function() return not con.connected --[[ No browser while connected (for now), go die]] end},
}
if jacobsmod then
	tpt_buttons["clear"] = {x1=486, y1=404, x2=502, y2=423, f=function() conSend(63) end}
	tpt_buttons["pause"] = {x1=613, y1=404, x2=627, y2=423, f=function() conSend(49,tpt.set_pause()==0 and "\1" or "\0") end}
	tpt_buttons["deco"] = {x1=613, y1=49, x2=627, y2=63, f=function() conSend(51,tpt.decorations_enable()==0 and "\1" or "\0") end}
	tpt_buttons["newt"] = {x1=613, y1=65, x2=627, y2=79, f=function() conSend(54,tpt.newtonian_gravity()==0 and "\1" or "\0") end}
	tpt_buttons["ambh"] = {x1=613, y1=81, x2=627, y2=95, f=function() conSend(53,tpt.ambient_heat()==0 and "\1" or "\0") end}
	tpt_buttons["disp"] = {x1=597, y1=404, x2=611, y2=423, f=function() --[[activate a run once display mode check on next step]] end}
	tpt_buttons["open"] = {x1=0, y1=404, x2=17, y2=423, f=function() return not con.connected --[[ No browser while connected (for now), go die]] end}
end

local function mouseclicky(mousex,mousey,button,event,wheel)
	if chatwindow:process(mousex,mousey,button,event,wheel) then return false end
	if L.skipClick then L.skipClick=false return true end
	if mousex<612 and mousey<384 then mousex,mousey = sim.adjustCoords(mousex,mousey) end

	if L.stamp and button>0 and button~=2 then
		if event==1 and button==1 then
			--initial stamp coords
			L.stampx,L.stampy = mousex,mousey
		elseif event==2 then
			if button==1 then
				--save stamp ourself for data, delete it
				local sx,sy = mousex,mousey
				if sx<L.stampx then L.stampx,sx=sx,L.stampx end
				if sy<L.stampy then L.stampy,sy=sy,L.stampy end
				--cheap cut hook to send a clear
				if L.copying==1 then
					conSend(67,string.char(math.floor(L.stampx/16),((L.stampx%16)*16)+math.floor(L.stampy/256),(L.stampy%256),math.floor(sx/16),((sx%16)*16)+math.floor(sy/256),(sy%256)))
				end
				--Round coords to grid for some reason
				local w,h = sx-L.stampx,sy-L.stampy
				local stm = "stamps/"..sim.saveStamp(L.stampx,L.stampy,w,h)..".stm"
				sx,sy,L.stampx,L.stampy = math.ceil((sx+1)/4)*4,math.ceil((sy+1)/4)*4,math.floor(L.stampx/4)*4,math.floor(L.stampy/4)*4
				w,h = sx-L.stampx, sy-L.stampy
				local f = assert(io.open(stm))
				if L.copying then L.lastCopy = {data=f:read"*a",w=w,h=h} else L.lastStamp = {data=f:read"*a",w=w,h=h} end
				f:close()
				os.remove(stm)
			end
			L.stamp=false
			L.copying=false
		end
		return true
	elseif L.placeStamp and button>0 and button~=2 then
		if event==2 then
			if button==1 then
				local stm
				if L.copying then stm=L.lastCopy else stm=L.lastStamp end
				if stm then
					if not stm.data then
						--unknown stamp, send full screen on next step, how can we read last created stamp, timestamps on files?
						L.sendScreen=true
					else
						--send the stamp
						if L.smoved then
							--moved from arrows or rotate, send area next frame
							L.placeStamp=false
							L.sendScreen=true
							return true
						end
						local sx,sy = mousex-math.floor(stm.w/2),mousey-math.floor((stm.h)/2)
						if sx<0 then sx=0 end
						if sy<0 then sy=0 end
						if sx+stm.w>611 then sx=612-stm.w end
						if sy+stm.h>383 then sy=384-stm.h end
						local b1,b2,b3 = math.floor(sx/16),((sx%16)*16)+math.floor(sy/256),(sy%256)
						local d = #stm.data
						conSend(66,string.char(b1,b2,b3,math.floor(d/65536),math.floor(d/256)%256,d%256)..stm.data)
					end
				end
			end
			L.placeStamp=false
			L.copying=false
		end
		return true
	end

	local obut,oevnt = L.mButt,L.mEvent
	L.mButt,L.mEvent = button,event

	if L.mButt~=obut or L.mEvent~=oevnt then --if different event
		--More accurate mouse from here (because this runs BEFORE step function, it would draw old coords)
		local b1,b2,b3 = math.floor(mousex/16),((mousex%16)*16)+math.floor(mousey/256),(mousey%256)
		conSend(32,string.char(b1,b2,b3))
		L.mousex,L.mousey = mousex,mousey
	    conSend(33,string.char(L.mButt*16+L.mEvent))
	elseif L.mEvent==3 then
		local b1,b2,b3 = math.floor(mousex/16),((mousex%16)*16)+math.floor(mousey/256),(mousey%256)
		conSend(32,string.char(b1,b2,b3))
		L.mousex,L.mousey = mousex,mousey
	end
	--Click inside button first
	if button==1 then
		if event==1 then
			for k,v in pairs(tpt_buttons) do
				if mousex>=v.x1 and mousex<=v.x2 and mousey>=v.y1 and mousey<=v.y2 then
					--down inside!
					L.downInside = k
					break
				end
			end
		--Up inside the button we started with
		elseif event==2 and L.downInside then
			local butt = tpt_buttons[L.downInside]
			if mousex>=butt.x1 and mousex<=butt.x2 and mousey>=butt.y1 and mousey<=butt.y2 then
				--up inside!
				L.downInside = nil
				return butt.f()~=false
			end
		--Mouse hold, we MUST stay inside button or don't trigger on up
		elseif event==3 and L.downInside then
			local butt = tpt_buttons[L.downInside]
			if mousex<butt.x1 or mousex>butt.x2 or mousey<butt.y1 or mousey>butt.y2 then
				--moved out!
				L.downInside = nil
			end
		end
	end
end

local keypressfuncs = {
	--TAB
	[9] = function() conSend(35) end,
	
	--space, pause toggle
	[32] = function() conSend(49,tpt.set_pause()==0 and "\1" or "\0") end,
		
	--View modes 0-9
	[48] = function() conSend(48,"\10") end,
	[49] = function() if L.shift then conSend(48,"\9") tpt.display_mode(9)--[[force local display mode, screw debug check for now]] return false end conSend(48,"\0") end,
	[50] = function() conSend(48,"\1") end,
	[51] = function() conSend(48,"\2") end,
	[52] = function() conSend(48,"\3") end,
	[53] = function() conSend(48,"\4") end,
	[54] = function() conSend(48,"\5") end,
	[55] = function() conSend(48,"\6") end,
	[56] = function() conSend(48,"\7") end,
	[57] = function() conSend(48,"\8") end,
	
	--= key, pressure/spark reset
	[61] = function() if L.ctrl then conSend(60) else conSend(61) end end,

	--b , deco, pauses sim
	[98] = function() if L.ctrl then conSend(51,tpt.decorations_enable()==0 and "\1" or "\0") else conSend(49,"\1") conSend(51,"\1") end end,

	--c , copy
	[99] = function() if L.ctrl then L.stamp=true L.copying=true end end,

	--d key, debug, api broken right now
	--[100] = function() conSend(55) end,
	
	--F , frame step
	[102] = function() conSend(50) end,

	--I , invert pressure
	[105] = function() conSend(62) end,
	
	--K , stamp menu, abort our known stamp, who knows what they picked, send full screen?
	[107] = function() L.lastStamp={data=nil} L.placeStamp=true end,

	--L , last Stamp
	[108] = function () if L.lastStamp then L.placeStamp=true end end,

	--R , for stamp rotate
	[114] = function() if L.placeStamp then L.smoved=true if L.shift then return end L.rotate=not L.rotate end end,

	--S, stamp
	[115] = function() L.stamp=true end,

	--U, ambient heat toggle
	[117] = function() conSend(53,tpt.ambient_heat()==0 and "\1" or "\0") end,

	--V, paste the copystamp
	[118] = function() if L.ctrl and L.lastCopy then L.placeStamp=true L.copying=true end end,

	--X, cut a copystamp and clear
	[120] = function() if L.ctrl then L.stamp=true L.copying=1 end end,

	--W,Y disable (grav mode, air mode)
	[119] = function() return false end,
	[121] = function() return false end,
	--Z
	[122] = function() myZ=true L.skipClick=true end,

	--Arrows for stamp adjust
	[273] = function() if L.placeStamp then L.smoved=true end end,
	[274] = function() if L.placeStamp then L.smoved=true end end,
	[275] = function() if L.placeStamp then L.smoved=true end end,
	[276] = function() if L.placeStamp then L.smoved=true end end,

	--SHIFT,CTRL,ALT
	[304] = function() L.shift=true conSend(36,string.char(17)) end,
	[306] = function() L.ctrl=true conSend(36,string.char(1)) end,
	[308] = function() L.alt=true conSend(36,string.char(33)) end,
}
local keyunpressfuncs = {
	--Z
	[122] = function() myZ=false L.skipClick=false if L.alt then L.skipClick=true end end,
	--SHIFT,CTRL,ALT
	[304] = function() L.shift=false conSend(36,string.char(16)) end,
	[306] = function() L.ctrl=false conSend(36,string.char(0)) end,
	[308] = function() L.alt=false conSend(36,string.char(32)) end,
}
local function keyclicky(key,nkey,modifier,event)
	local check = chatwindow:textprocess(key,nkey,modifier,event)
	if check~=false then return true end
	--MANAGER_PRINT(nkey)
	local ret
	if event==1 then
		if keypressfuncs[nkey] then
			ret = keypressfuncs[nkey]()
		end
	elseif event==2 then
		if keyunpressfuncs[nkey] then
			ret = keyunpressfuncs[nkey]()
		end
	end
	if ret~= nil then return ret end
end

tpt.register_keypress(keyclicky)
tpt.register_mouseclick(mouseclicky)
tpt.register_step(step)

