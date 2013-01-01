local osi=osi

local sched=require'packages.sched'
local fil=require'packages.sched.fil'
local int={}
local err_prefix='osi.int|path='..FILE_PATH..':'
local prots={}
int.register=function(prot,netID)
	if prots[netID] and prots[netID]~=prot then
		error(err_prefix..'Attempt to register a protocol to the already registered netID:'..tostring(netID),2)
	else
		prots[netID]=prot
		sched.on(int.unregister,prot,'dead'):setParent(osi.task)
	end
	prot.netID=netID
	prot.interfaces={}
end

int.unregister=function(prot)
	for interface in pairs(prot.interfaces) do
		interface.handle[prot.netID]=nil
		if not next(interface.handle) then
			interface:kill()
		end
	end
	prots[prot.netID]=nil
end

local int_killer=sched.on(function()
	while next(prots) do
		int.unregister(prots[next(prots)])
	end
end,osi.task,'dying'):setParent(osi.task)

local rn_handler=function(obj,em,ev,id,msg,...)
	if msg:sub(1,3)=='OSI' then
		local netID=msg:sub(4,6)
		if netID and obj.handle[netID] then
			obj.handle[netID](id,msg,...)
		end
	end
end

int.ev_interfaces=fil.new()

local kill_ev_interface=function(obj)
	sched.signal(obj,'killedby',sched.me())
	sched.signal(obj,'dying') --warns subs
	obj:finalize()
	int.ev_interfaces:uniset(obj.em,obj.ev)
	sched.signal(obj,'dead')
end

int.register_ev_int=function(prot,handle,em,ev)
	local interface
	if int.ev_interfaces:get(em,ev) then
		interface=int.ev_interfaces:get(em,ev)
	else
		interface=sched.Obj.new(rn_handler,'osi-int-'..tostring(em)..'.'..tostring(ev)):link{[em]={ev}}:setParent(int_killer)
		interface.handle={}
		interface.em,interface.ev=em,ev
		interface.kill=kill_ev_interface
		int.ev_interfaces:uniset(em,ev,interface)
	end
	prot.interfaces[interface]=true
	interface.handle[prot.netID]=handle
end

int.unregister_ev_int=function(prot,em,ev)
	local interface = int.ev_interfaces:get(em,ev)
	prot.interfaces[interface]=nil
	interface.handle[prot.netID]=nil
	if not next(interface.handle) then
		interface:kill()
	end
end

int.register_rn_int=function(prot,handle)
	return int.register_ev_int(prot,handle,'platform','rednet')
end

int.unregister_rn_int=function(prot,handle)
	return int.unregister_ev_int(prot,handle,'platform','rednet')
end

return int