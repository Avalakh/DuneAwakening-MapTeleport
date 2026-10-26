package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local C=require('region_catalog')
local function row(id,extra)
 local r={id=id,name=id,current=false,progressAllowed=true,routeAllowed=true}
 for k,v in pairs(extra or{})do r[k]=v end;return r
end
local data={row('locked',{progressAllowed=false}),row('unknown',{progressAllowed=nil}),
 row('technical',{technical=true}),row('overview',{overview=true}),row('blocked',{routeAllowed=false}),
 row('beta'),row('alpha'),row('here',{current=true,routeAllowed=false}),row('beta')}
-- nil removes the key explicitly (pairs cannot contain a nil override).
data[2].progressAllowed=nil
local r=C.filter(data);assert(#r==3 and r[1].id=='here'and r[2].id=='alpha'and r[3].id=='beta')
data[1].progressAllowed=true;r=C.filter(data);assert(#r==4)
data[1].progressAllowed=false;assert(#C.filter(data)==3)
assert(#C.filter({})==0)
assert(C.chooseRoute({'ApartmentMurder_to_Arrakeen','Overland_to_Arrakeen','Travel_To_Arrakeen'})=='Travel_To_Arrakeen')
assert(C.chooseRoute({'Travel_To_Harko_InterrogationExit','Travel_To_Harko'})=='Travel_To_Harko')
assert(C.chooseRoute({'Story_DangerousAllies_CaveExit','Overland_to_DeepDesert1_S1'})=='Overland_to_DeepDesert1_S1')
assert(C.chooseRoute({})==nil)
print('PASS catalog: current, deduplication, progress refresh, unknown, routes, technical/overview and empty list')
