-- loadreq.run('packages/sched/test.lua')

sched=require'packages.sched'
log=require'packages.log'

require('packages.osi.rn_rpl',nil,nil,nil,true)
-- log.setlevel('ALL')
sched.task('main',function()
	osi=require('packages.osi',nil,nil,nil,true)
	pint=osi.newProInst(1,'parasite','router')
	pint.send(1,'a')
	sched.wait('platform','terminate')
	sched.stop()
end):run()

sched.loop()