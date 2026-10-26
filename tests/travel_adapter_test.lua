package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Adapter=require('travel_adapter')
local f={calls=0,hooks={},clock=40,mapId='A',records={{id='B',mapId='B',worldPath='/B',destinationName='TaxiB'}}}
local function valid(t)t.IsValid=function()return true end;return t end
local pc=valid({GetFullName=function()return'Controller pc'end})
local pawn=valid({})
_G.FName=function(x)return x end
local objects={}
objects['/Script/Engine.Default__GameplayStatics']=valid({GetAccurateRealTime=function(_,out,unused)out.Seconds=f.clock;out.PartialSeconds=.25;assert(next(unused)==nil)end})
objects['/Script/DuneSandbox.Default__DuneTravelApi']=valid({
 CanTravelToDestination=function(_,p,n,out)assert(p==pawn and n=='TaxiB');out.Name={ToString=function()return f.target or'B'end};return not f.routeBlocked end,
 RequestTravelByDestination=function(_,p,n,queued,result,why,dialog,dimension)
  assert(p==pc and n=='TaxiB'and queued==nil and result==nil and dialog==2 and dimension==-1)
  f.calls=f.calls+1
 end})
_G.StaticFindObject=function(n)return assert(objects[n],n)end
local nextHook=0
_G.RegisterHook=function(n,cb)nextHook=nextHook+1;f.hooks[n]=cb;return nextHook,nextHook+100 end
_G.UnregisterHook=function(n,pre,post)assert(pre and post==pre+100);f.hooks[n]=nil end
local a=Adapter.new({context=function()return{pc=pc,pawn=pawn}end},
 {snapshot=function()return f.records end},{request=function(_,point,id)f.localId=id;return point.mapId=='B'end},function()end)
local d={id='B',mapId='B',worldPath='/B',destinationName='TaxiB'}
assert(a.now()==40.25)
assert(a.validate({pc=pc,pawn=pawn},d));f.records[1].destinationName='different';assert(not a.validate({pc=pc,pawn=pawn},d));f.records[1].destinationName='TaxiB'
f.target='C';assert(not a.request({pc=pc,pawn=pawn},d,3)and f.calls==0);f.target=nil
assert(a.request({pc=pc,pawn=pawn},d,3));assert(f.calls==1)
a.nativeFailure('foreign','B','unrelated');assert(not a.failure(3))
a.nativeFailure('pc','C','wrong-map');assert(not a.failure(3))
a.nativeFailure('pc','B','native requirements');assert(a.failure(3)=='native requirements'and not a.failure(4))
a.release({id=4});assert(a.failure(3)=='native requirements');a.release({id=3});assert(not a.failure(3))
assert(a.startLocal({}, {mapId='B'},7));assert(f.localId==7)
a.onLocalComplete(7,'restored','steep-surface');assert(a.localResult(7)=='restored'and not a.localResult(8))
a.release({id=7});assert(not a.localResult(7))
a.installHooks();assert(f.hooks['/Script/DuneSandbox.DunePlayerControllerBase:ClientShowTravelRequirementsFailedDialog'])
a.installHooks();assert(nextHook==2,'duplicate hooks on repeated install')
assert(a.request({pc=pc,pawn=pawn},d,9));assert(not pcall(a.shutdown),'active operation must retain failure hooks')
a.release({id=9});a.shutdown();assert(next(f.hooks)==nil);a.shutdown()
print('PASS native adapter: monotonic out parameters, route recheck, NoDialog/nil delegates, scoped rejection and local completion')
