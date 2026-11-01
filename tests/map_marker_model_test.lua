package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local M=require('map_marker_model');local P=require('map_projection');local C=require('map_canvas')
local map=assert(P.new({id='A',layer='surface',originX=-500,originY=-500,ux=1000,uy=0,vx=0,vy=1000}))
local rows={}
local function row(id,category,x,y,overrides)
 local r={id=id,mapId='A',layerId='surface',category=category,X=x,Y=y,visible=true,discovered=true,label='Место '..id,icon='/Game/NativeIcon',priority=0}
 for k,v in pairs(overrides or{})do r[k]=v end;rows[#rows+1]=r;return r
end
local place=row('place','place',0,0)
place.iconTint={R=.2,G=.3,B=.4,A=1}
row('hidden','place',10,10,{discovered=false});row('unknown','place',10,10,{discovered=nil})
rows[#rows].discovered=nil
row('foreign','quest',0,0,{mapId='B'});row('underground','quest',0,0,{layerId='underground'})
row('nan','quest',0/0,0);row('infinite','base',1/0,0);row('invisible','personal',0,0,{visible=false})
row('base','base',100,-50);row('quest','quest',-100,50);row('personal','personal',50,100);row('player','player',-50,-100,{priority=100})
row('quest','quest',-100,50,{priority=5,label='Обновлённая цель'})
local snapshot=M.snapshot('A','surface',rows);assert(#snapshot.rows==5 and snapshot.rows[1].category=='player')
place.label='Changed';place.X=999
place.iconTint.R=.9
local frozen;for _,r in ipairs(snapshot.rows)do if r.id=='place'then frozen=r end end
assert(frozen and frozen.X==0 and frozen.label=='Место place','Snapshot must not retain mutable input')
assert(frozen.iconTint.R==.2,'Native colours must be copied by value')
local expected={place={X=0,Y=0},base={X=100,Y=-50},quest={X=-100,Y=50},personal={X=50,Y=100},player={X=-50,Y=-100}}
for _,dimensions in ipairs({{900,600},{3440,1440},{1280,1024}})do
 local frame={x=110,y=80,width=dimensions[1],height=dimensions[2]}
 for _,zoom in ipairs({1,2,8})do
  local canvas=C.layout(frame,zoom,.5,.5);local rect=C.rect(canvas)
  local layout=M.layout(snapshot,map,rect,{x=frame.x,y=frame.y,width=canvas.width,height=canvas.height},26)
  for _,entry in ipairs(layout)do
   local picked=assert(P.pick(map,{x=rect.x,y=rect.y,width=rect.width,height=rect.height,zoom=1,panU=0,panV=0},entry.x,entry.y))
   local wanted=expected[entry.marker.id];assert(math.abs(picked.X-wanted.X)<1e-6 and math.abs(picked.Y-wanted.Y)<1e-6)
   assert(entry.size==26,'Icons must not grow with terrain zoom')
  end
 end
end
local overlap=M.snapshot('A','surface',{{id='one',mapId='A',layerId='surface',category='quest',visible=true,X=0,Y=0,priority=1},{id='two',mapId='A',layerId='surface',category='player',visible=true,X=0,Y=0,priority=10}})
local layout=M.layout(overlap,map,{x=0,y=0,width=100,height=100},{x=0,y=0,width=100,height=100})
assert(M.hover(layout,50,50).id=='two');assert(not M.hover(layout,0,0))
assert(#M.layout(snapshot,map,{x=0,y=0,width=100,height=100},{x=200,y=200,width=100,height=100})==0)
assert(#M.layout(M.snapshot('B','surface',rows),map,{x=0,y=0,width=100,height=100},{x=0,y=0,width=100,height=100})==0)
assert(M.snapshot('B','surface',{},'unavailable').status=='unavailable')
print('PASS marker model: all categories, discovery, region/layer isolation, immutable snapshots, deduplication, projection, DPI/zoom, clipping and hover priority')
