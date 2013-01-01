local sched=require'packages.sched'
local pipe=require'packages.sched.pipe'
local fil=require'packages.sched.fil'
PACKAGE_NAME='osi'
local osi=require'init'

Prot={}

Prot.name='parasite'

Prot.new=function(netID,typ,...)
	local self={netID=netID,typ=typ}
	local ptyp=Prot[typ]
	self.task=sched.task('prot:netID='..self.netID,ptyp.f,self,...)
	return self
end

local router={name='router'}
Prot.router=router

router.f=function(self,key)
	local bro=osi.bro
	local freq=self.netID..'111'
	bro.set_key(freq,key or 'key')
	
	local prot_task=sched.me()
	local me=os.getComputerID()
	local function getsid(n)
		return string.rep ('0', 4-tostring(n):len())..tostring(n)
	end
	local s_me=getsid(me)
	
	
	local function time()--must return an integer, and syncronized increasing time over all CC computers; waiting for os.day, this is just for testing and will have problems with midnight
		return os.time()*1000
	end
	local function timestamp()--must return a string, and syncronized increasing time over all CC computers; waiting for os.day, this is just for testing and will have problems with midnight
		local now=os.time()*1000
		return string.rep ('0', 5-tostring(now):len())..tostring(now)
	end
	
	osi.int.register(self,self.netID)
	osi.int.register_rn_int(self,handle_rednet)
	
	
	local routes={}
	local targetorigin_to_route={}
	local route_to_req={}
	local req_timeout=2
	
	local id_to_auth={}
	local auth_objs={}
	
	local auth_timeout=1
	local auth_max_buffer=100
	
	local function auth_handler(auth,em,ev,...)
		if #auth.buffer>auth_max_buffer then
			id_to_auth[auth.id]=false
		else
			id_to_auth[auth.id]=nil
		end
		auth_objs[auth.id]=nil
		sched.me():kill()
	end
	
	local function kill_route(route)
		routes[route]=nil
		targetorigin_to_route[route.id2]=nil
		sched.Obj.kill(route)
	end
	
	local function cleanup_req(route)
		route_to_req[route.id2]=nil
		sched.Obj.kill(route)
	end
	
	local cleanup_timeout=5
	local function kill_req(route)
		route.handle=cleanup_req
		sched.emit'timeout'
		route:setTimeout(cleanup_timeout)
	end
	
	local gc_old
	local gc_now={}
	local gc_handler=function(gc_listener,ev)
		if gc_old then
			for i=1,#gc_old do
				br_ids[gc_old[i]]=nil
			end
		end
		gc_old=gc_now
		gc_now={}
		gc_listener:reset()
		if not next(gc_old) then
			gc_listener:link{[self]={'new_br'}}
		else
			gc_listener:link{timer={os.clock()+gc_timeout}}
		end
	end
	
	local gc_listener=sched.Obj.new(gc_handler):link{[self]={'new_br'}}
	
	local function handle_rednet(id,msg) --for now, handling is done directly on sched.signal call's; maybe in the future it might be better to let the scheduler process state machines and alike, non-coroutine callbacks separately
		local auth_state=id_to_auth[id]
		local packet_type=msg:sub(7,8)
		
		if auth_state==true then
			if packet_type=='Br' then
				local br_id=msg:sub(9,15)
				if not br_ids[br_id] then
					br_ids[br_id]=true
					gc_now[br_id]=true
					sched.signal(self,'new_br')
					rednet.broadcast(msg)
				end
				return true
			end
			local starget,sorigin,stimestamp=msg:sub(9,12),msg:sub(13,16),msg:sub(17,16)
			local target,origin,timestamp=tonumber(starget),tonumber(sorigin),tonumber(stimestamp)
			local route_id=target..origin..timestamp
			local route=routes[route_id]
			if packet_type=='Ms' then
				if route then
					if target==me then
						sched.signal(self,'msg',msg:sub(17))
					else
						rednet.send(route.nodes[target],msg)
					end
					route.resetTimeout()
				end
			elseif packet_type=='Rq' then
				if time()-timestamp<req_timeout then
					local id2=starget..sorigin
					if not route_to_req[id2] then
					
						if targetorigin_to_route[id2] then
							kill_route(targetorigin_to_route[id2])
						end
						
						local route=sched.Obj.new(kill_req):setTimeout(req_timeout)
						
						route.nodes={[origin]=id}
						route.id=route_id
						route.id2=id2
						route_to_req[id2]=route
						
						if target==me then
							routes[route_id]=route
							targetorigin_to_route[id2]=route
							route_to_req[id2]=nil
							route.handle=kill_route
							route:setTimeout(route_timeout)
							rednet.send(route.nodes[origin],'OSI'..self.netID..'Rp'..route_id)
						else
							rednet.broadcast('OSI'..self.netID..'Rq'..route_id)
						end
					end
				end
			elseif packet_type=='Rp' then
				if time()-timestamp<req_timeout then
					local id2=starget..sorigin
					if route_to_req[id2] then
						route=route_to_req[id2]
						route.nodes[target]=id
						routes[route_id]=route
						targetorigin_to_route[id2]=route
						
						route_to_req[id2]=nil
						
						route.handle=kill_route
						route:setTimeout(route_timeout)
						
						if origin~=me then
							rednet.send(route.nodes[origin],'OSI'..self.netID..'Rp'..route_id)
						else
							sched.signal(route,'ready')
						end
					end
				end
			end
		elseif auth_state~=false then
			if auth_state==nil then
				if packet_type=='Au' then
					if bro.check_packet(id,msg:sub(9)) then
						rednet.send(id,'OSI'..prot.netID..'Au'..bro.get_packet(freq))
						id_to_auth[id]=true
					else
						id_to_auth[id]=false
					end
				else
					local auth=sched.Obj.new(auth_handler):setParent(prot_task)
					auth_objs[id]=auth
					auth.buffer={msg}
					auth.id=id
					auth:link{timer={os.clock()+auth_timeout}}
					rednet.send(id,'OSI'..prot.netID..'Au'..bro.get_packet(freq))
					id_to_auth[id]='pending'
				end
			else--if auth_state='pending' then
				if packet_type=='Au' then
					if bro.check_packet(id,msg:sub(9)) then
						id_to_auth[id]=true
						local buffer=auth_objs[id].buffer
						auth_objs[id]:kill()
						auth_objs[id]=nil
						for i=1,#buffer do
							handle_rednet(id,buffer[i])
						end
					else
						id_to_auth[id]=false
					end
				else
					table.insert(auth_objs[id].buffer,msg)
				end
			end
		end
	end
	
	local req_listener
	
	local req_handle=function(req_listener,route,ev)
		if ev=='ready' then
			node=route.id:sub(1,4)
			for i=1,#buffer do
				rednet.send(node,'OSI'..self.netID..'Ms'..route.id..buffer[i])
			end
		end
		req_listener:unlink{[route]={'ready','timeout'}}
	end
	
	req_listener=sched.Obj.new(req_handle)
	
	self.send=function(target,msg)
		if target==me then
			sched.signal(self,'msg',msg)
			return true
		else
			local id2=getsid(target)..s_me
			local route=targetorigin_to_route[id2]
			if route then
				rednet.send(route.nodes[target],'OSI'..self.netID..'Ms'..route.id..msg)
				route.resetTimeout()
			else
				local route=route_to_req[id2]
				if route then
					table.insert(route.buffer,msg)
					return route
				else
					
					local route_id=id2..timestamp()
					
					if targetorigin_to_route[id2] then
						kill_route(targetorigin_to_route[id2])
					end
					
					local route=sched.Obj.new(kill_req):setTimeout(req_timeout)
					req_listener:link{[route]={'ready','timeout'}}
					route.nodes={[me]=id}
					route.id=route_id
					route.id2=id2
					route_to_req[id2]=route
					rednet.broadcast('OSI'..self.netID..'Rq'..route_id)
					route.buffer={msg}
					return route
				end
			end
		end
	end
	
	self.broadcast=function(msg)
		local s=tostring({}):match(':.(.*)')
		local br_id=string.rep ('0', 7-tostring(s):len())..tostring(s)
		rednet.broadcast('OSI'..self.netID..'Br'..br_id..msg)
	end
	
	sched.emit'ready'
	sched.wait('forever','*')	
end

return Prot