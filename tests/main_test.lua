local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function fixture()
 local f={thread='startup',ticks=0,hits=0,timers=0,contextCalls=0,messages={}}
 local adapter={context=function()assert(f.thread=='game');f.contextCalls=f.contextCalls+1;return f.context end,now=function()return 1 end}
 local runner={finish=function(_,code)f.finished=code end,restore=function()f.restored=true end}
 local runtime={runner=runner,hit=function()assert(f.thread=='game');f.hits=f.hits+1;if f.hitError then error('hit failed')end end,tick=function()assert(f.thread=='game');f.ticks=f.ticks+1;if f.tickError then error('tick failed')end end}
 local env=setmetatable({
  require=function(name)if name=='map_adapter'then return{new=function()return adapter end}end;assert(name=='runtime');return{new=function()return runtime end}end,
  Key={F12=123},ModifierKey={SHIFT=16},
  RegisterKeyBind=function(key,mods,callback)assert(key==123 and #mods==1 and mods[1]==16);f.key=callback end,
  LoopInGameThreadWithDelay=function(delay,callback)assert(f.thread=='startup'and delay==50);f.timers=f.timers+1;f.timer=callback;return 1 end,
  LoopAsync=function()error('Async registry handoff forbidden')end,
  ExecuteInGameThread=function()error('Per-event registry scheduling forbidden')end,
  print=function(text)f.messages[#f.messages+1]=text end,
 },{__index=_G})
 assert(loadfile('mods/MapTeleport/Scripts/main.lua','t',env))()
 function f.press()f.thread='input';f.key()end
 function f.step()f.thread='game';f.timer()end
 f.runner=runner;return f
end
test('hotkey only queues intent; one persistent timer owns all engine work',function()
 local f=fixture();assert(f.timers==1)
 f.press();f.press();assert(f.hits==0 and f.contextCalls==0)
 f.step();assert(f.hits==1 and f.ticks==1)
 for i=1,240 do f.step()end
 assert(f.timers==1 and f.ticks==241 and f.hits==1)
 f.press();f.step();assert(f.hits==2)
end)
test('input failure cannot stop later timer updates',function()
 local f=fixture();f.hitError=true;f.press();f.step();assert(f.ticks==1)
 f.hitError=false;f.press();f.step();assert(f.hits==2 and f.ticks==2)
end)
test('tick failure before movement cancels instead of blindly restoring',function()
 local f=fixture();f.runner.job={key='current',moved=false};f.context={key='current'};f.tickError=true
 f.step();assert(f.finished=='cancelled'and not f.restored)
 f.tickError=false;f.step();assert(f.ticks==2)
end)
test('tick failure after movement restores only the matching character',function()
 local f=fixture();f.runner.job={key='old',moved=true};f.context={key='new'};f.tickError=true
 f.step();assert(f.finished=='cancelled'and not f.restored)
 local same=fixture();same.runner.job={key='current',moved=true};same.context={key='current'};same.tickError=true
 same.step();assert(same.restored)
end)
print(count..' entrypoint tests passed')
