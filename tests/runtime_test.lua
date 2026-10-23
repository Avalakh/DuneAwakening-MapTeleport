package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Runtime=require('runtime')
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function fixture()
 local f={down=true,present=true,requests=0,ticks=0}
 local pc={IsInputKeyDown=function()return f.down end}
 local r=Runtime.new({context=function()if f.present then return{pc=pc}end end})
 r.runner.request=function()f.requests=f.requests+1 end
 r.runner.tick=function()f.ticks=f.ticks+1 end
 f.r=r;return f
end
_G.FName=function(v)return v end
test('twelve-second hold accepts one request despite repeated key notifications',function()
 local f=fixture();f.r.hit()
 for i=1,240 do f.r.hit();f.r.tick()end
 assert(f.requests==1 and f.ticks==240)
end)
test('a released key allows the next distinct press',function()
 local f=fixture();f.r.hit();f.down=false;f.r.tick();f.r.tick()
 f.down=true;f.r.hit();assert(f.requests==2)
end)
test('one missing down sample while held does not start another request',function()
 local f=fixture();f.r.hit();f.down=false;f.r.tick();f.down=true;f.r.tick();f.r.hit()
 assert(f.requests==1)
end)
test('losing the character never creates a request and permits a fresh press after return',function()
 local f=fixture();f.r.hit();f.present=false
 for i=1,20 do f.r.tick()end
 assert(f.requests==1)
 f.present=true;f.r.hit();assert(f.requests==2)
end)
print(count..' runtime tests passed')
