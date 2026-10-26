package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Runtime=require('runtime');local count=0
local function test(n,f)f();count=count+1;print('PASS '..n)end
local function fixture()
 local f={keys={f12=true,shift=true,ctrl=false,focused=true},opens=0,updates=0}
 f.r=Runtime.new({input=function()return f.keys end,open=function()f.opens=f.opens+1;return true end,
 update=function()f.updates=f.updates+1 end,recover=function(e)f.error=e end})
 function f.release()f.keys.f12=false;f.r.tick();f.r.tick();f.keys.f12=true end
 return f
end
test('twelve-second hold opens one window and continues updates',function()
 local f=fixture();f.r.hit();for i=1,240 do f.r.hit();f.r.tick()end
 assert(f.opens==1 and f.updates==240);f.release();f.r.hit();assert(f.opens==2)
end)
test('plain F12 and Ctrl chords cannot become a command on modifier release',function()
 for _,shift in ipairs({false,true})do
  local f=fixture();f.keys.ctrl=true;f.keys.shift=shift;f.r.tick();f.r.hit();assert(f.opens==0)
  f.keys.ctrl=false;f.keys.shift=true;f.r.tick();f.r.hit();assert(f.opens==0)
  f.release();f.r.hit();assert(f.opens==1)
 end
 local f=fixture();f.keys.shift=false;f.r.tick();f.keys.shift=true;f.r.hit();assert(f.opens==0)
end)
test('one absent sample does not release a held key',function()
 local f=fixture();f.r.hit();f.keys.f12=false;f.r.tick();f.keys.f12=true;f.r.tick();f.r.hit();assert(f.opens==1)
end)
test('focus loss and unavailable context discard intent',function()
 local f=fixture();f.keys.focused=false;f.r.hit();assert(f.opens==0)
 f.keys.focused=true;f.r.hit();assert(f.opens==0);f.release();f.r.hit();assert(f.opens==1)
 local g=fixture();local keys=g.keys;g.keys=nil;g.r.hit();g.r.tick();g.r.tick();g.keys=keys
 keys.f12=false;assert(not g.r.hit());assert(g.opens==0)
end)
test('notification after release never executes',function()
 local f=fixture();f.keys.f12=false;f.r.hit();assert(f.opens==0)
end)
print(count..' unified runtime tests passed')
