o=require'packages.osi.layer2'
o.set_key('freq','key')
p=o.get_packet('freq',1)
print(p)
print(o.check_packet(1,p))