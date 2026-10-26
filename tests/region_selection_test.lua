package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local S=require('region_selection');local count=0
local function test(name,f)f();count=count+1;print('PASS '..name)end
local function fixture(kind,current)
 local f={moves=0,closes=0,allowed=true,c={key='world/player'},row={id='A',name='A',mapId='mapA',worldPath='/A',current=current~=false,localMapState=kind or'present'}}
 f.a={eligible=function()return f.allowed,'dead'end,catalog=function()return{f.row}end,
  present=function(v)f.view=v;if f.renderError then error('render')end end,
  close=function()f.closes=f.closes+1 end,message=function(code)f.message=code end,
  refreshRegion=function()if f.locked then return nil,'locked'end;return f.row end,
  validatePoint=function(r,p)return p.layerId=='surface'and p.X>=0 and p.X<=100,'bounds'end,
  execute=function(d,id)f.moves=f.moves+1;f.destination=d;f.operation=id;return not f.executeError end}
 f.s=S.new(f.a);assert(f.s:open(f.c))
 function f.event(action,extra)local e=extra or{};e.action=action;e.revision=f.s.revision;return f.s:event(e,f.c)end
 function f.localMap()assert(f.s.state=='SelectRegion'and f.moves==0)end
 return f
end
test('Region selection previews immediately; one confirmation moves once',function()
 local f=fixture();f.localMap();assert(not f.event('teleport'))
 assert(f.event('point',{point={mapId='mapA',layerId='surface',X=50,Y=70}}))
 local oldRevision=f.s.revision;assert(f.event('teleport'));assert(f.moves==1 and f.destination.point.X==50)
 assert(not f.s:event({action='teleport',revision=oldRevision},f.c));assert(f.moves==1)
 assert(not f.s:open(f.c));assert(f.s:completed(f.operation));assert(f.s:open(f.c))
end)
test('No map travels directly; unknown/error never travel',function()
 for _,kind in ipairs({'absent','unknown','error'})do
  local f=fixture(kind,false);assert(f.event('select',{id='A'}));f.event('teleport')
  assert(f.moves==(kind=='absent'and 1 or 0))
 end
 local f=fixture('absent');assert(not f.event('teleport'));assert(f.moves==0)
end)
test('Cancel discards preview and selected point without movement',function()
 for _,localMap in ipairs({false,true})do local f=fixture();if localMap then f.localMap()end
  assert(f.event('cancel'));assert(f.s.state=='Idle'and not f.s.point and f.moves==0 and f.closes==1)
 end
end)
test('Stale events, world change and death cannot move or retain UI',function()
 local f=fixture();local rev=f.s.revision;f.event('select',{id='A'});assert(not f.s:event({action='teleport',revision=rev},f.c))
 f.s:update({key='other'});assert(f.s.state=='Idle'and f.moves==0)
 f=fixture();f.allowed=false;f.s:update(f.c);assert(f.s.state=='Idle'and f.moves==0)
end)
test('Availability rechecked and point cannot cross map, layer or bounds',function()
 local f=fixture();f.localMap()
 assert(not f.event('point',{point={mapId='other',layerId='surface',X=50,Y=30}}))
 assert(not f.event('point',{point={mapId='mapA',layerId='cave',X=50,Y=30}}))
 assert(not f.event('point',{point={mapId='mapA',layerId='surface',X=101,Y=30}}))
 f.event('point',{point={mapId='mapA',layerId='surface',X=50,Y=30}});f.locked=true
 assert(not f.event('teleport'));assert(f.moves==0)
end)
test('Region changes discard points; UI/execute failures recover',function()
 local f=fixture();f.localMap();f.event('point',{point={mapId='mapA',layerId='surface',X=50,Y=30}})
 assert(f.event('select',{id='A'}));assert(not f.s.point and f.moves==0)
 f.renderError=true;f.event('select',{id='A'});assert(f.s.state=='Idle'and f.moves==0)
 f=fixture('absent',false);f.event('select',{id='A'});f.executeError=true
 assert(not f.event('teleport'));assert(f.s.state=='Idle')
 f.executeError=false;assert(f.s:open(f.c));assert(f.s.state=='SelectRegion')
end)

test('UI values and later edits cannot mutate a confirmed operation or unlock it with stale completion',function()
 local f=fixture();f.localMap();f.event('point',{point={mapId='mapA',layerId='surface',X=50,Y=70}})
 f.view.point.X=95;assert(f.s.point.X==50)
 f.event('teleport');f.row.mapId='changed';assert(f.destination.mapId=='mapA'and f.destination.point.X==50)
 assert(not f.s:completed(f.operation+1));assert(not f.s:open(f.c));assert(f.moves==1)
 assert(f.s:completed(f.operation));assert(f.s:open(f.c))
end)
test('Native arrival point is the default, editable, copied and reset per region',function()
 local f=fixture();f.s:close()
 f.row.defaultPoint={mapId='mapA',layerId='surface',X=20,Y=30}
 assert(f.s:open(f.c));assert(f.s.point.X==20)
 f.view.point.X=99;assert(f.s.point.X==20)
 assert(f.event('point',{point={mapId='mapA',layerId='surface',X=50,Y=70}}));assert(f.s.point.X==50)
 assert(f.event('select',{id='A'}));assert(f.s.point.X==20 and f.moves==0)
 assert(f.event('teleport'));assert(f.moves==1 and f.destination.point.X==20)
 f.row.defaultPoint.X=80;assert(f.destination.point.X==20)
end)
print(count..' selection tests passed')
