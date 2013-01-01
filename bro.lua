---safe broadcast
saved=require'APIS.saved'

PACKAGE_NAME='osi'
local err_prefix='layer2'


sha1=require'sha1'

local freq_len=6
local me=os.getComputerID()

freq_keys={}
cache={}
saves=saved.new(loadreq.getDir(FILE_PATH)..'/'..'vars')

local function get_sha1(freq,id)
	local c=cache[freq]
	if not c then
		c={}
		cache[freq]=c
	end
	if not c[id] then
		c[id]=sha1(id..freq_keys[freq])
		--save to disk
	end
	return c[id]
end

set_key=function(freq,key)
	if not tostring(freq):len()==freq_len then error(err_prefix..'freq should have lenght='..freq_len) end
	freq_keys[freq]=key
end

get_packet = function (freq)
	return freq..get_sha1(freq,me)
end

check_packet = function (id,pck)
	local freq=string.sub(pck,1,freq_len)
	local enc=string.sub(pck,freq_len+1)
	return enc==get_sha1(freq,id)
end
