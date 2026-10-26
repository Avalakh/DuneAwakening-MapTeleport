local count=0
local function test(n,f)f();count=count+1;print('PASS '..n)end
local function fixture()
 local f={thread='startup',hits=0,ticks=0,timers=0,recoveries=0}
 local app={runner={},travel={},window={close=function()f.closed=true end},cancel=function()assert(f.thread=='game');f.cancels=(f.cancels or 0)+1 end,
 navigate=function(direction)assert(f.thread=='game');f.navigation=f.navigation or{};f.navigation[#f.navigation+1]=direction end}
 local runtime={hit=function()assert(f.thread=='game');f.hits=f.hits+1;if f.hitError then error('input')end end,
 tick=function()assert(f.thread=='game');f.ticks=f.ticks+1;if f.tickError then error('update')end end,
 recover=function()assert(f.thread=='game');f.recoveries=f.recoveries+1;if f.recoveryError then error('recovery')end end}
 local env=setmetatable({require=function(name)if name=='application'then return{new=function()return app end}end;assert(name=='runtime');return{new=function(a)assert(a==app);return runtime end}end,
 Key={F12=123,ESCAPE=27,TAB=9},ModifierKey={SHIFT=16},RegisterKeyBind=function(key,mods,cb)
  if key==27 then assert(type(mods)=='function'and cb==nil);f.escape=mods
  elseif key==9 then if cb then assert(#mods==1 and mods[1]==16);f.previous=cb else f.next=mods end
  else assert(key==123 and#mods==1 and mods[1]==16);f.key=cb end end,
 LoopInGameThreadWithDelay=function(delay,cb)assert(f.thread=='startup'and delay==50);f.timers=f.timers+1;f.timer=cb end,
 ExecuteInGameThread=function()error('Per-event callback forbidden')end,LoopAsync=function()error('Async handoff forbidden')end,print=function()end},{__index=_G})
 assert(loadfile('mods/MapTeleport/Scripts/main.lua','t',env))()
 function f.press()f.thread='input';f.key()end
 function f.cancel()f.thread='input';f.escape()end
 function f.step()f.thread='game';f.timer()end
 f.app=app;return f
end
test('one timer owns queued input and all engine updates',function()
 local f=fixture();f.press();f.press();assert(f.hits==0);f.step();assert(f.hits==1 and f.ticks==1)
 for i=1,240 do f.step()end;assert(f.timers==1 and f.hits==1 and f.ticks==241)
end)

test('short Escape is queued once and cancels a competing open before game-thread update',function()
 local f=fixture();f.press();f.cancel();f.cancel();assert(not f.cancels);f.step()
 assert(f.cancels==1 and f.hits==0 and f.ticks==1);f.step();assert(f.cancels==1)
end)

test('Tab navigation is ordered on the game thread and Escape discards pending navigation',function()
 local f=fixture();f.thread='input';f.next();f.previous();assert(not f.navigation)
 f.step();assert(#f.navigation==1 and f.navigation[1]=='next');f.step();assert(f.navigation[2]=='previous')
 f.thread='input';f.next();f.cancel();f.step();assert(#f.navigation==2 and f.cancels==1)
end)
test('input and update failures recover and later updates continue',function()
 local f=fixture();f.hitError=true;f.press();f.step();assert(f.recoveries==1 and f.ticks==1)
 f.tickError=true;f.step();assert(f.recoveries==2);f.tickError=false;f.step();assert(f.ticks==3)
end)
test('recovery failure disables movement and attempts own UI cleanup',function()
 local f=fixture();f.tickError=true;f.recoveryError=true;f.step()
 assert(f.app.runner.disabled and f.app.travel.disabled and f.closed)
end)
print(count..' unified entrypoint tests passed')
