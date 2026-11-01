package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Array=require('unreal_array')
local reads,visits=0,0
local weak=setmetatable({},{__mode='v'})
local function temporary()
 local object=setmetatable({GetArrayNum=function()return 12000 end,ForEach=function()error('Unsafe native callback')end},{__index=function(_,i)
  assert(i>=1 and i<=12000);reads=reads+1;return i
 end});weak[1]=object;return object
end
Array.each(temporary(),function(i,value)
 assert(value==i);visits=visits+1
 if i%100==0 then collectgarbage('collect');assert(weak[1],'Array must remain rooted during callbacks')end
end)
assert(reads==12000 and visits==12000);collectgarbage('collect');assert(not weak[1],'No array retained afterward')
local size=2;local outOfRange=false
local changing=setmetatable({GetArrayNum=function()return size end},{__index=function(_,i)if i>size then outOfRange=true end;return i end})
assert(not pcall(Array.each,changing,function()size=0 end));assert(not outOfRange,'Read must not grow an engine array after shrink')
local called=0;Array.each({GetArrayNum=function()return 0 end},function()called=called+1 end);assert(called==0)
assert(not pcall(Array.each,{GetArrayNum=function()return -1 end},function()end))
assert(not pcall(Array.each,temporary(),function()error('Callback error')end));collectgarbage('collect');assert(not weak[1])
print('PASS native arrays: 12000 elements, forced GC, temporary lifetime, no native ForEach, size changes, empty and callback failure')
