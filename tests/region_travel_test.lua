package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Travel=require('region_travel')
local count=0
local function test(n,f)f();count=count+1;print('PASS '..n)end
local function fixture()
 local f={now=0,c={key='old',mapId='A',worldPath='A'},ready=true,requests=0,locals=0,releases=0}
 local a={context=function()return f.c end,now=function()return f.now end,
 eligible=function()return not f.dead,'dead'end,validate=function()return not f.locked,'locked'end,
 request=function(_,d,id)f.requests=f.requests+1;f.requestId=id;return not f.rejected,'requirements'end,
 failure=function()return f.failure end,arrivalReady=function()return f.ready end,
 startLocal=function(c,p,id)f.locals=f.locals+1;f.localKey=c.key;f.point=p;return true end,
 localResult=function()return f.result,f.detail end,release=function()f.releases=f.releases+1 end,
 completed=function(id,code,detail,j)f.done={id=id,code=code,detail=detail,job=j}end}
 f.t=Travel.new(a)
 function f.arrive()f.c={key='new',mapId='B',worldPath='B'};f.t:tick()end
 function f.step(n)f.now=f.now+n;f.t:tick()end
 return f
end
test('current map bypasses travel and freezes point',function()
 local f=fixture();local d={mapId='A',point={X=1,Y=2}};assert(f.t:request(d,4));d.point.X=99
 assert(f.requests==0 and f.locals==1 and f.point.X==1)
 assert(not f.t:request(d,5));f.result='success';f.step(1);assert(f.done.code=='success'and f.releases==1)
end)
test('native request once, arrival stable three seconds, automatic local stage',function()
 local f=fixture();assert(f.t:request({mapId='B',point={X=5,Y=7}},8))
 for i=1,10 do f.step(1)end;assert(f.requests==1 and f.locals==0)
 f.c=nil;f.step(1);f.arrive();f.step(2);assert(f.locals==0);f.step(1)
 assert(f.locals==1 and f.localKey=='new');f.result='success';f.step(1)
 assert(f.done.code=='success'and f.done.job.travelled)
end)
test('no local map completes at verified native arrival',function()
 local f=fixture();f.t:request({mapId='B'},1);f.arrive();f.step(3)
 assert(f.done.code=='success'and f.locals==0)
end)
test('arrival readiness and character changes restart stability window',function()
 local f=fixture();f.t:request({mapId='B'},1);f.arrive();f.step(2)
 f.ready=false;f.step(1);f.ready=true;f.step(1);f.step(2);assert(not f.done)
 f.c.key='new-pawn';f.step(1);f.step(2);assert(not f.done);f.step(1);assert(f.done.code=='success')
end)
test('requirements rejection is terminal and a fresh request is allowed',function()
 local f=fixture();f.rejected=true;f.t:request({mapId='B'},1)
 assert(f.done.code=='travel-failed'and f.locals==0);f.rejected=false;assert(f.t:request({mapId='B'},2))
 f.failure='native reason';f.step(1);assert(f.done.detail=='native reason'and f.requests==2)
end)
test('deadline covers departure and arrival independently of world clock',function()
 local f=fixture();f.t:request({mapId='B'},1);f.c=nil;f.step(120)
 assert(f.done.code=='travel-timeout');f.arrive();assert(f.locals==0 and f.releases==1)
end)
test('unexpected world, death, and stale old pawn cannot start local placement',function()
 local f=fixture();f.t:request({mapId='B',point={}},1);f.c={key='other',mapId='C'};f.step(1)
 assert(f.done.code=='wrong-destination'and f.locals==0)
 local g=fixture();g.t:request({mapId='B'},1);g.dead=true;g.step(1);assert(g.done.code=='cancelled')
 local h=fixture();h.t:request({mapId='B'},1);h.c=nil;h.step(1);h.c={key='old',mapId='A'};h.step(1)
 assert(h.done.code=='wrong-destination')
end)
test('local failure after travel reports partial and retains arrival-world origin',function()
 local f=fixture();f.t:request({mapId='B',point={}},1);f.arrive();f.step(3)
 f.result='restored';f.detail='steep-surface';f.step(1)
 assert(f.done.code=='partial'and f.done.detail=='steep-surface'and f.localKey=='new')
 assert(f.t:request({mapId='B',point={}},2));assert(f.requests==1)
end)
test('failed cleanup or restoration disables further operations',function()
 local f=fixture();f.t:request({mapId='A',point={}},1);f.result='restore-failed';f.step(1)
 assert(f.t.disabled and not f.t:request({mapId='A',point={}},2))
end)
print(count..' region travel tests passed')
