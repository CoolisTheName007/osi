---helper for protocols
env=getfenv()

local class=require'30log'


packet={}

function packet.getProtID(p) --4 chars
	return string.sub(1,4)
end

function packet.getNetID(p) --4 chars
	return string.sub(5,8)
end



function encode(str,key)

end

function decode(str,key)

end

Rout=class()

function Rout:__init()
	self.gat={}
	self.ids={}
end

function Rout:_addGat(rout)
	for _,gat in ipairs(rout.gat) do
		for __,id in 
end
return env