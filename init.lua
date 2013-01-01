---main OSI thread
local sched=require'packages.sched'
local pipe=require'packages.sched.pipe'
local barrier=require'packages.sched.barrier'

local fil=require'packages.sched.fil'

PACKAGE_NAME='osi'

local osi={}



local init_b
osi.task=sched.task('osi',function(prots)
	--load pro inst from config?
	sched.emit'ready'
	sched.wait('forever','*')
end,prots)

osi.prots={}

osi.newProInst= function (netID,name,...)
	local prot=require('packages.osi.protocols.'..name)
	local instance=prot.new(netID,...)
	instance.task:setParent(osi.task):run()
	sched.wait(instance.task,'ready')
	sched.on(function() 
		if osi.prots[netID]==instance then
			osi.prots[netID]=nil
		end
		sched.me():kill()
	end, instance.task,'dead')
	osi.prots[netID]=instance
	return instance
end

local renv=setmetatable({osi=osi},{__index=_G})
osi.int=require('int',nil,nil,renv,true)
osi.bro=require('bro',nil,nil,renv,true)

osi.start=function()
	osi.task:setParent(sched.me()):run()
	sched.wait(osi.task,'ready')
end
return osi