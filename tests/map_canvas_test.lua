package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local C=require('map_canvas');local P=require('map_projection')
local function close(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' != '..tostring(b))end
for _,screen in ipairs({{1280,720},{1920,1080},{2580,1080},{1080,1920}})do
 local f=C.frame(screen[1],screen[2],math.min(430,screen[1]*.27))
 assert(f.x+f.width==screen[1]-40 and f.y+f.height==screen[2]-150)
 local l=C.layout(f,1,.4,.7);assert(l.width>0 and l.height>0)
 local r=C.rect(l);assert(r.width==r.height)
 local fit=C.layout(f,.001);close(fit.zoom,fit.minZoom);assert(fit.maxX==0 and fit.maxY==0)
 local huge=C.layout(f,100);assert(huge.zoom==16 and huge.maxX>0 and huge.maxY>0)
 local x,y=f.x+l.width*.6,f.y+l.height*.4
 local before=C.rect(l,l.x,l.y);local next=C.zoom(l,l.x,l.y,1.25,x,y);local after=C.rect(next)
 close((x-before.x)/before.width,(x-after.x)/after.width)
 close((y-before.y)/before.height,(y-after.y)/after.height)
 local m=assert(P.new({id='A',layer='surface',originX=-10000,originY=-10000,ux=20000,uy=0,vx=0,vy=20000}))
 local function view(rect)return{x=rect.x,y=rect.y,width=rect.width,height=rect.height,zoom=1,panU=0,panV=0}end
 local p=assert(P.pick(m,view(before),x,y));local q=assert(P.pick(m,view(after),x,y));close(p.X,q.X);close(p.Y,q.Y)
 local edge=C.rect(huge,math.huge,-math.huge);close(edge.x,f.x+huge.mapX-huge.maxX);close(edge.y,f.y+huge.mapY)
 local viewport={x=f.x,y=f.y,width=l.width,height=l.height};local capture=C.capture(viewport,after)
 close(capture.u,(x-after.x)/after.width+(viewport.x+viewport.width/2-x)/after.width)
 close(capture.fraction,viewport.width/after.width)
 assert(math.max(capture.width,capture.height)<=1536 and math.max(capture.width,capture.height)>768)
 assert(capture.width%2==0 and capture.height%2==0)
 assert(math.abs((capture.width/capture.height)/(viewport.width/viewport.height)-1)<.0002)
end
do
 local viewport={x=0,y=0,width=1414,height=754};local r={x=0,y=0,width=1414,height=1414}
 local capture=C.capture(viewport,r)
 assert(capture.width==1414 and capture.height==754,'exact even viewport ratio must not become 1536x819')
end
do
 local l=C.layout({x=100,y=100,width=800,height=500},2)
 local start={x=300,y=300,scrollX=400,scrollY=500}
 assert(not C.drag(l,start,303,304),'small pointer jitter is a click')
 local pan=assert(C.drag(l,start,320,280));close(pan.x,380);close(pan.y,520)
 start.moved=true;pan=assert(C.drag(l,start,300,300));close(pan.x,400);close(pan.y,500)
 pan=assert(C.drag(l,start,10000,-10000));close(pan.x,0);close(pan.y,l.maxY)
 local fit=C.layout(l.frame,.001);pan=assert(C.drag(fit,start,320,280));close(pan.x,0);close(pan.y,0)
end
print('PASS responsive map canvas: aspect ratios, fit/fill, scroll bounds, pointer-anchored zoom and world-coordinate invariance')
print('PASS drag threshold, both axes, return-to-origin gesture and map bounds')
local viewport={x=0,y=0,width=2200,height=800}
local rect={x=0,y=0,width=3000,height=3000}
local small=C.capture(viewport,rect);local native=C.capture(viewport,rect,2400,1100)
assert(native.width<=2400 and native.height<=1100 and native.width>small.width)
assert(native.width%2==0 and native.height%2==0 and math.abs(native.width/native.height-2200/800)<1e-8)
assert(C.capture(viewport,rect).width==small.width,'Native limits must not contaminate the default capture cache')
print('PASS viewport capture preserves native RT limits, aspect and independent cache keys')
