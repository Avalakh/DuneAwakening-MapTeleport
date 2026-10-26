package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local P=require('map_profiles')
local b={minX=-100,minY=-200,maxX=300,maxY=400}
for _,key in ipairs({'minX','minY','maxX','maxY'})do
 local incomplete={};for k,v in pairs(b)do if k~=key then incomplete[k]=v end end
 local ok,profile,why=pcall(P.new,{id='HarkoVillage'},incomplete,{min=0,max=100})
 assert(ok and profile==nil and why=='invalid-bounds','incomplete bounds must fail without throwing')
end
local function row(id)return{id=id,mapId=id,worldPath='/'..id}end
for _,id in ipairs({'HaggaBasin','DeepDesert','Arrakeen','HarkoVillage'})do
 local p=assert(P.new(row(id),b,{min=49000,max=58000}));assert(p.top==58500 and p.bottom==48500)
 assert(P.validate(p,{mapId=id,layerId='surface',X=-100,Y=400}))
 assert(not P.validate(p,{mapId=id,layerId='underground',X=0,Y=0}))
 assert(not P.validate(p,{mapId='other',layerId='surface',X=0,Y=0}))
 assert(not P.validate(p,{mapId=id,layerId='surface',X=0/0,Y=0}))
 assert(not P.validate(p,{mapId=id,layerId='surface',X=301,Y=0}))
end
assert(not P.new(row('unknown'),b,{min=0,max=10}))
assert(not P.new(row('HaggaBasin'),b,{min=10,max=0}))
local queries=0
local actors={
 {IsValid=function()return true end,IsActorBeingDestroyed=function()return false end,
  GetActorBounds=function(_,_,o,e)o.Z=15000;e.Z=3000 end},
 {IsValid=function()return true end,IsActorBeingDestroyed=function()return false end,
  GetActorBounds=function(_,_,o,e)o.Z=20000;e.Z=7000 end},
}
_G.StaticFindObject=function(n)
 if n=='/Script/Engine.LevelBounds'then return 'level-class'end
 if n=='/Script/DuneSandbox.DuneWorldSettings'then return 'settings-class'end
 assert(n=='/Script/Engine.Default__GameplayStatics')
 return{GetAllActorsOfClass=function(_,pc,class,out)
  if class=='settings-class'then
   out[1]={IsValid=function()return true end,m_UnstuckLocations={ForEach=function(_,cb)
    cb(1,{get=function()return{Translation={X=0,Y=0,Z=14717.2}}end})
    cb(2,{get=function()return{Translation={X=1000,Y=0,Z=13899}}end})
   end}};return
  end
  assert(pc=='current-controller'and class=='level-class');queries=queries+1
  for i,a in ipairs(actors)do out[i]=a end
 end}
end
local p=assert(P.new(row('HarkoVillage'),b,{min=-5000,max=5000}))
local c={pc='current-controller',key='world/player',worldPath='/HarkoVillage'}
assert(not P.activate(p,{worldPath='/other'}))
local active=assert(P.activate(p,c));assert(active.top==27500 and active.bottom==11500)
assert(p.top==5500,'projection metadata must remain independent of collision bounds')
assert(P.activate(active,c)==active and queries==1,'reuse only within the same live context')
assert(P.traceTop(active,{X=0,Y=0},92)==14859.2,'do not start above the invisible ceiling at Z=16014')
assert(P.traceTop(active,{X=1000,Y=0},92)==14041,'choose the nearest native playable elevation')
assert(not P.traceTop({kind='compact',top=100000,floorAnchors={}},{X=0,Y=0},92))
actors={};assert(not P.activate(active,{pc=c.pc,key='new-world/player',worldPath=c.worldPath}))
print('PASS profiles: explicit map/layer/bounds, finite points, distinct heights and preparation strategies')
