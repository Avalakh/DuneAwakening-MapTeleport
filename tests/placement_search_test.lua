package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local S=require('placement_search')
local function job()return{marker={X=400,Y=700},profile={bounds={minX=-1000,maxX=1800,minY=-700,maxY=2100}}}end
local j=job();local calls=0
local d=S.step(j,function(p)calls=calls+1;return{X=p.X,Y=p.Y,Z=100}end)
assert(d.X==400 and d.Y==700 and calls==1 and j.placementOffset==0)
j=job();calls=0
d=S.step(j,function(p)
 calls=calls+1
 if p.X==400 and p.Y==700 then return nil,'occupied'end
 return{X=p.X,Y=p.Y,Z=150}
end)
assert(d and calls==2 and j.placementOffset==100)
j=job();calls=0;local maxDistance=0;local reason
repeat
 local before=calls
 d,reason=S.step(j,function(p)
  calls=calls+1;maxDistance=math.max(maxDistance,math.sqrt((p.X-400)^2+(p.Y-700)^2))
  return nil,'steep-surface'
 end)
 assert(calls-before<=8)
until reason~='not-loaded'
assert(not d and reason=='no-safe-place'and maxDistance<=2000)
j=job();calls=0
for _=1,150 do
 d,reason=S.step(j,function()calls=calls+1;return nil,'not-loaded'end)
 assert(not d and reason=='not-loaded')
end
-- Streaming can become ready after a complete unsuccessful pass.
repeat d=S.step(j,function(p)return{X=p.X,Y=p.Y,Z=100}end)until d
assert(d)
j=job();calls=0
repeat
 d,reason=S.step(j,function(p)calls=calls+1;assert(p.X>=400);return nil,'occupied'end,function(p)return p.X>=400 end)
until reason~='not-loaded'
assert(reason=='no-safe-place'and calls>0)
j=job();d=nil
repeat d=S.step(j,function(p)if p.X>1500 then return{X=p.X,Y=p.Y,Z=100}end;return nil,'occupied'end)until d
assert(j.placementOffset>1000)
print('PASS exact-first, nearby fallback, expansion beyond 10m and bounded batch, streaming retry and map bounds')
