local me=os.getComputerID()
local rednet=rednet
local new={}
graph=require'packages.graph.Graph'
g=graph.new()
adj={
{2},--1
{3},--2
{4},--3
{5},--4
{},--5
}
for i,n in pairs(adj) do
	g:addvertex(i)
end
for i,n in pairs(adj) do
	g:addedge (i, i,true)
	for _,v in pairs(n) do
		g:addedge (i, v,true)
	end
end

nb=assert(g.vset[me],'Neigborhood not defined for '..me)

new.send=function(id,msg)
	if nb[id] then
		rednet.send(id,msg)
	end
	return rednet.send(1000,'')
end

new.broadcast=function(msg)
	for id in pairs(nb) do
		rednet.send(id,msg)
	end
	return rednet.send(1000,'')
end

return new