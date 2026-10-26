package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Window=require('teleport_window')
local view={region={localMapState='present'},point={mapId='A',layerId='surface',X=0,Y=0}}
local descriptor={profile={mapId='A',layerId='surface',bounds={minX=-10,minY=-10,maxX=10,maxY=10}}}
assert(Window.canTeleport(view,descriptor));assert(not Window.canTeleport(view,nil))
view.point.X=11;assert(not Window.canTeleport(view,descriptor))
view.point.X=0;view.point.layerId='underground';assert(not Window.canTeleport(view,descriptor))
view.point=nil;assert(not Window.canTeleport(view,descriptor))
view.region.localMapState='unknown';assert(not Window.canTeleport(view,descriptor))
view.region.localMapState='absent';assert(Window.canTeleport(view,nil))
view.region.current=true;assert(not Window.canTeleport(view,nil))
local function fixture(failure)
 local f={removed=0,released=0,restored=0,mapClosed=0,hooks={}}
 RegisterHook=function(name,callback)f.hooks[name]=callback;return 10,11 end
 FName=function(x)return x end
 local widget={IsValid=function()return true end,RemoveFromParent=function()f.removed=f.removed+1;if failure=='widget'then error('remove')end end,IsInViewport=function()return false end}
 local lib={IsValid=function()return true end,SetInputMode_GameOnly=function()f.restored=f.restored+1 end,GetMousePositionOnViewport=function()return f.mouse or{X=50,Y=50}end}
 StaticFindObject=function(name)if name=='owned'then return widget else return lib end end
 local c={key='player',pc={SetShowDuneMouseCursor=function()end}}
 f.ui=Window.new({context=function()return c end,
  releaseInput=function()f.released=f.released+1;if failure=='input'then error('input')end end,
  map={close=function()f.mapClosed=f.mapClosed+1 end}})
 f.ui.widget='owned';f.ui.contextKey='player';f.ui.oldCursor=false;f.ui.inputOwner='own input'
 return f
end
for _,failure in ipairs({'widget','input'})do
 local f=fixture(failure);assert(not pcall(f.ui.close));assert(f.ui.failed)
 assert(f.removed==1 and f.released==1 and f.restored==1 and f.mapClosed==1)
 if failure=='input'then assert(f.ui.inputOwner=='own input')end
end
local f=fixture();f.ui.close();f.ui.close()
assert(not f.ui.failed and not f.ui.widget and f.removed==1 and f.released==1 and f.restored==1)
local f=fixture();local C=require('map_canvas');local u=f.ui
u.wheelScroll='wheel';u.canvasLayout=C.layout({x=0,y=0,width=100,height=100});u.descriptor={};u.view={revision=7}
local hook=f.hooks['/Script/UMG.ScrollBox:SetScrollOffset'];assert(hook)
local value=1064;local param={get=function()return value end,set=function(_,v)value=v end}
local function context(name)return{get=function()return{GetFullName=function()return'ScrollBox '..name end}end}end
hook(context('foreign'),param);assert(value==1064 and #u.events==0)
hook(context('wheel'),param);assert(value==1000 and #u.events==1 and u.events[1].revision==7 and u.events[1].delta<0)
hook(context('wheel'),param);assert(#u.events==1,'programmatic reset must not zoom again')
f.mouse={X=150,Y=50};value=968;hook(context('wheel'),param);assert(value==1000 and #u.events==1,'outside canvas must not zoom')
print('PASS window cleanup continues after widget/input failure and preserves failed ownership; close is idempotent')
print('PASS native wheel bridge scopes ownership, resets once, queues revision and preserves foreign/list scrolling')
do
 local C=require('map_canvas');local objects={};local captures=0
 local hooks={};RegisterHook=function(name,callback)hooks[name]=callback;return 1,2 end
 local pc={IsInputKeyDown=function()return false end}
 local mouse={X=1150,Y=500}
 local lib={IsValid=function()return true end,GetViewportSize=function()return{X=1920,Y=1080}end,GetViewportScale=function()return 1 end,GetMousePositionOnViewport=function()return mouse end}
 local function bar()
  return{IsValid=function()return true end,offset=0,SetScrollBarVisibility=function()end,
   GetScrollOffset=function(self)return self.offset end,SetScrollOffset=function(self,x)self.offset=x end}
 end
 objects.x=bar();objects.y=bar()
 objects.ex={IsValid=function()return true end,SetWidthOverride=function(self,x)self.width=x end}
 objects.ey={IsValid=function()return true end,SetHeightOverride=function(self,x)self.height=x end}
 objects.owned={IsValid=function()return true end,ForceLayoutPrepass=function()end}
 StaticFindObject=function(n)return objects[n]or lib end
 local picks=0
 local u=Window.new({context=function()return{key='player',pc=pc}end,map={viewport=function()captures=captures+1 end,pick=function()picks=picks+1;return{X=1,Y=2}end}})
 u.widget='owned';u.contextKey='player';u.width=1920;u.height=1080;u.view={revision=7}
 u.canvasMapId='A';u.canvasLayout=C.layout({x=450,y=160,width=1430,height=770},1)
 u.mapBars={x='x',y='y'};u.mapExtents={x='ex',y='ey'}
 u.present=function()error('Zoom must not rebuild the window')end
 u.events={{action='wheel',delta=1,x=1150,y=500,revision=7},{action='wheel',delta=1,x=1150,y=500,revision=7}}
 u.poll();assert(#u.events==1 and u.canvasLayout.zoom==1.25)
 u.poll();assert(#u.events==0 and u.canvasLayout.zoom==1.5625)
 local x,y=objects.x.offset,objects.y.offset
 for _=1,50 do u.poll()end
 assert(u.canvasLayout.zoom==1.5625 and objects.x.offset==x and objects.y.offset==y)
 assert(u.widget=='owned'and u.view.revision==7 and u.canvasMapId=='A'and captures>0)
 print('PASS queued wheel steps retain native widgets, scale and offsets across idle updates without rebuilding')
 local pressed=true
 objects.surface={IsValid=function()return true end,IsPressed=function()return pressed end}
 u.mapButton='surface';u.bindings.surface={event={action='map'},revision=7};u.view.region={localMapState='present'}
 local function eventContext(name)return{get=function()return{GetFullName=function()return'Button '..name end}end}end
 local press=hooks['/Script/UMG.Widget:ForceLayoutPrepass']
 local click=hooks['/Script/UMG.Widget:InvalidateLayoutAndVolatility']
 press(eventContext('foreign'));assert(not u.mapDrag)
 press(eventContext('surface'));local oldX,oldY=objects.x.offset,objects.y.offset
 mouse.X=mouse.X+100;mouse.Y=mouse.Y+50;u.poll()
 assert(u.mapDrag.moved and objects.x.offset==math.max(0,oldX-100)and objects.y.offset==math.max(0,oldY-50))
 pressed=false;click(eventContext('surface'));assert(picks==0 and #u.events==0 and not u.mapDrag,'drag release must not select a point')
 pressed=true;press(eventContext('surface'));mouse.X=mouse.X+2;mouse.Y=mouse.Y+2
 pressed=false;click(eventContext('surface'));assert(picks==1 and #u.events==1 and u.events[1].action=='point','small movement remains a click')
 u.events={};pressed=true;press(eventContext('surface'));pressed=false;u.poll();assert(not u.mapDrag,'capture loss must cancel the gesture')
 pressed=true;press(eventContext('surface'));u.view.revision=8;assert(not u.dragMap(mouse.X+20,mouse.Y));assert(not u.mapDrag,'stale gesture cannot pan a new view')
 print('PASS native drag start, two-axis pan, no point on drag release, click tolerance and capture/revision cancellation')
 local focused='first'
 for _,name in ipairs({'first','disabled','second'})do objects[name]={IsValid=function()return true end,
  HasKeyboardFocus=function()return focused==name end,SetUserFocus=function(_,owner)assert(owner==pc)end,
  SetKeyboardFocus=function()focused=name end}end
 u.buttons={{path='first',event={action='select',id='A'},enabled=true},
  {path='disabled',event={action='teleport'},enabled=false},{path='surface',event={action='map'},enabled=true},
  {path='second',event={action='cancel'},enabled=true}}
 assert(u.navigate('next')and focused=='second');assert(u.navigate('next')and focused=='first')
 assert(u.navigate('previous')and focused=='second')
 u.widget=nil;assert(not u.navigate('next')and focused=='second')
 print('PASS modal keyboard navigation skips disabled/map controls, wraps and ignores a closed window')
end
