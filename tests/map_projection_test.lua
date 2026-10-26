package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local P=require('map_projection')
for missing=1,5 do
 local args={0,100,0,10000,2500};args[missing]=nil
 local ok,p,why=pcall(P.plane,table.unpack(args,1,5))
 assert(ok and p==nil and why=='invalid-plane','missing plane input must fail without throwing')
end
local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b))end
near(assert(P.plane(-500,14467.555,-50000,1446755.5,25000)),250)
near(assert(P.plane(-70.12,-34.88,-5000,5000,25000)),35.6)
assert(not P.plane(0,10,5,5,0));assert(not P.plane(0,10,0,5,0/0))
local map=assert(P.new({id='rotated',layer='surface',originX=-50000,originY=80000,ux=0,uy=-800000,vx=400000,vy=0}))
local views={
 {x=0,y=0,width=1000,height=1000,zoom=1,panU=0,panV=0},
 {x=210,y=40,width=1600,height=900,zoom=2,panU=0.1,panV=-0.1},
 {x=120,y=90,width=700,height=500,zoom=3.5,panU=0.05,panV=-0.03},
}
local point={mapId='rotated',layerId='surface',X=150000,Y=-320000}
for _,view in ipairs(views)do
 local s=assert(P.screen(map,view,point));local p=assert(P.pick(map,view,s.x,s.y))
 near(p.X,point.X);near(p.Y,point.Y);assert(p.layerId=='surface')
end
assert(not P.new({id='x',originX=0,originY=0,ux=1,uy=1,vx=2,vy=2}))
assert(not P.pick(map,views[1],-1,200))
assert(not P.pick(map,{x=0,y=0,width=100,height=100,zoom=1,panU=2,panV=0},50,50))
assert(not P.pick(map,views[1],0/0,50))
assert(not P.screen(map,views[1],{mapId='other',layerId='surface',X=0,Y=0}))
assert(not P.screen(map,views[1],{mapId='rotated',layerId='cave',X=0,Y=0}))
assert(not P.pick(map,{x=0,y=0,width=0,height=100,zoom=1,panU=0,panV=0},0,50))
local hub=assert(P.fromBounds('HarkoVillage',{minX=-200,minY=-200,maxX=200,maxY=200},
 {minX=-56750,minY=-56750,maxX=56750,maxY=56750}))
assert(not P.fromBounds('invalid',nil,{}))
assert(not P.fromBounds('invalid',{minX=0,minY=0,maxX=0/0,maxY=1},{minX=0,minY=0,maxX=1,maxY=1}))
local whole={x=0,y=0,width=400,height=400,zoom=1,panU=0,panV=0}
local nativeArrival={mapId='HarkoVillage',layerId='surface',X=-1415,Y=26560}
local hscreen=assert(P.screen(hub,whole,nativeArrival));local hp=assert(P.pick(hub,whole,hscreen.x,hscreen.y))
near(hp.X,-1415);near(hp.Y,26560);assert(hscreen.y>200 and hscreen.y<400)
local padded=assert(P.fromBounds('padded',{minX=-100,minY=-50,maxX=100,maxY=50},
 {minX=-10000,minY=5000,maxX=10000,maxY=15000}))
local edge=P.pick(padded,whole,100,0);near(edge.X,-5000);near(edge.Y,0)
print('PASS map projection: rotated axes, zoom/pan/resolution, boundaries, stale map/layer, nonfinite and singular inputs')
