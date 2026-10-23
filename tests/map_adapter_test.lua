package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local Adapter=require('map_adapter')
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
local function fixture()
 local f={time=0,objects={},updates={},ignore=2}
 local invalid={IsValid=function()return false end}
 local function object(name,kind)
  local o={name=name,IsValid=function()return true end}
  function o:GetFullName()return(kind or'UObject')..' '..self.name end
  f.objects[name]=o;return o
 end
 local function level(name,asset,loadedName)
  local l=object(name,'LevelStreamingDynamic');l.loaded=true;l.visible=true;l.LevelLODIndex=-1
  l.PackageNameToLoad={ToString=function()return'/Game/'..asset end}
  l.LODPackageNames={ForEach=function(_,cb)cb(1,{})end}
  l.level=object(loadedName,'Level')
  function l:IsLevelLoaded()return self.loaded end
  function l:IsLevelVisible()return self.visible end
  function l:GetLoadedLevel()return self.level end
  function l:SetShouldBeLoaded(v)self.requestLoad=v end
  function l:SetShouldBeVisible(v)self.requestVisible=v end
  function l:SetIsRequestingUnloadAndRemoval(v)self.removal=v end
  return l
 end
 f.source=level('/World:Source','Floor','/Temp/Original.Floor:PersistentLevel')
 f.clone=level('/World:Clone','Floor','/Temp/Clone.Floor:PersistentLevel')
 f.cloneComp=object('/Temp/Clone.Floor:PersistentLevel.Ground.Collision','LandscapeHeightfieldCollisionComponent')
 f.original=object('/Temp/Original.Floor:PersistentLevel.Ground.Collision','LandscapeHeightfieldCollisionComponent')
 function f.original:GetCollisionEnabled()return 3 end
 function f.original:SetCollisionEnabled(value)f.updates[#f.updates+1]=value end
 local statics=object('/Script/Engine.Default__GameplayStatics')
 function statics:GetRealTimeSeconds()return f.time end
 _G.StaticFindObject=function(name)return f.objects[name]or invalid end
 _G.FindAllOf=function(kind)if kind=='LandscapeHeightfieldCollisionComponent'then return{f.cloneComp,f.original}end;return{}end
 local pc={SetIgnoreMoveInput=function(_,value)f.ignore=f.ignore+(value and 1 or-1)end}
 object('/Script/Engine.InputComponent','Class')
 function pc:K2_GetComponentsByClass()
  local components={{get=function()return{GetFullName=function()return'EnhancedInputComponent pc.Existing'end}end}}
  if f.lock and not f.inputDestroyed then components[#components+1]={get=function()return f.lock end}end
  return components
 end
 function pc:IsValid()return true end
 function pc:GetFullName()return'PlayerController pc'end
 function pc:GetOuter()return{GetOuter=function()return{GetAddress=function()return'world'end}end}end
 function pc:CreateNewInputComponent()error('Plain input component must not be used')end
 object('/Script/Engine.Actor','Class');object('/Script/EnhancedInput.EnhancedInputComponent','Class')
 function statics:BeginDeferredActorSpawnFromClass(_,_,_,_,owner)
  assert(owner==pc)
  local actor=object('/World:InputOwner','Actor');actor.valid=true;f.inputActor=actor
  function actor:IsValid()return self.valid end
  function actor:IsActorBeingDestroyed()return f.actorDestroyed or false end
  function actor:GetOwner()return f.actorDestroyed and invalid or pc end
  function actor:EnableInput(controller)assert(controller==pc);f.inputEnabled=true end
  function actor:DisableInput(controller)assert(controller==pc);f.inputEnabled=false end
  function actor:K2_DestroyActor()f.actorDestroyed=true;self.valid=false end
  function actor:K2_GetComponentsByClass()if f.lock and not f.inputDestroyed then return{{get=function()return f.lock end}}end;return{}end
  function actor:CreateInputComponent(class)
  assert(class==f.objects['/Script/EnhancedInput.EnhancedInputComponent'])
  local lock=object('/World:InputLock','InputComponent');lock.valid=true
  function lock:IsValid()return self.valid end
  function lock:IsA(name)return name=='/Script/EnhancedInput.EnhancedInputComponent'end
  function lock:GetOwner()return actor end
  function lock:K2_DestroyComponent(owner)assert(owner==actor);f.inputDestroyed=true end
  -- Live UE4SS keeps the UObject resolvable after component removal.
  function lock:IsBeingDestroyed()return false end
  f.lock=lock
  actor.InputComponent=lock
  end
  return actor
 end
 function statics:FinishSpawningActor(actor)return actor end
 function statics:GetAllActorsWithTag(_,_,result)if f.inputActor and not f.actorDestroyed then result[#result+1]=f.inputActor end end
 _G.FName=function(value)return value end
 local pawn={CharacterMovement={StopMovementImmediately=function()end},K2_GetActorLocation=function()return{X=0,Y=0,Z=200}end}
 function pawn:IsDead()return false end
 function pawn:IsInDownedState()return false end
 f.c={world='world',worldPath='worldPath',key='world/player',pcId='pc',pc=pc,pawn=pawn}
 f.job={world='world',key=f.c.key,origin={position={X=0,Y=0,Z=100},halfHeight=92},destination={X=0,Y=0,Z=200},marker={X=0,Y=0},resources={owned={{kind='collision',name=f.clone.name,source=f.source.name,target=true,targetSupport=true}}}}
 f.a=Adapter.new();f.a.context=function()return f.c end
 return f
end
test('requested full LOD is insufficient while the old LOD world is still loaded',function()
 local f=fixture();assert(f.a.canHandoff(f.c,f.job,false))
 f.source.level.name='/Temp/Original_LOD1.Floor_LOD1:PersistentLevel'
 assert(not f.a.canHandoff(f.c,f.job,false))
end)

test('unloaded overlapping packages do not block handoff unless they support the character',function()
 local f=fixture();f.source.loaded=false;f.job.resources.owned[1].targetSupport=false
 assert(f.a.canHandoff(f.c,f.job,false))
 f.job.resources.owned[1].originSupport=true
 assert(not f.a.canHandoff(f.c,f.job,true))
end)
test('original physics refresh waits for actual duplicate unload and deferred destruction',function()
 local f=fixture();f.a.handoff(f.c,f.job,false)
 assert(f.clone.removal and not f.clone.requestLoad and#f.updates==0)
 assert(not f.a.handoffReady(f.c,f.job))
 f.clone.loaded=false;f.clone.visible=false;f.time=1
 assert(not f.a.handoffReady(f.c,f.job)and#f.updates==0)
 f.time=1.05;assert(not f.a.handoffReady(f.c,f.job))
 f.time=1.11;assert(f.a.handoffReady(f.c,f.job))
 assert(#f.updates==2 and f.updates[1]==0 and f.updates[2]==3)
 assert(f.c.pawn.CharacterMovement.bForceNextFloorCheck)
end)
test('partial preparation destroys its own input component without changing shared ignore counters',function()
 local f=fixture();f.job.resources={}
 local ok=pcall(f.a.prepare,f.c,f.job)
 assert(not ok and f.ignore==2 and f.job.resources.inputLockPc=='pc')
 assert(f.inputActor.bBlockInput and f.inputActor.InputPriority==2147483647 and f.inputEnabled)
 assert(f.a.release(f.job)and f.ignore==2 and f.inputDestroyed and not f.job.resources.inputLockName)
 assert(f.actorDestroyed and not f.inputEnabled and not f.job.resources.inputOwnerName)
 assert(f.a.release(f.job)and f.ignore==2)
end)
test('another character is never moved during cleanup of the previous request',function()
 local f=fixture();f.c.key='world/new-player';f.a.handoff(f.c,f.job,false)
 f.clone.loaded=false;f.clone.visible=false;f.time=1;f.a.handoffReady(f.c,f.job)
 f.time=1.2;assert(f.a.handoffReady(f.c,f.job))
 assert(not f.c.pawn.CharacterMovement.bForceNextFloorCheck)
end)
test('a retained destroyed UObject does not falsely disable cleanup',function()
 local f=fixture();f.job.resources={};pcall(f.a.prepare,f.c,f.job)
 assert(f.a.release(f.job)and f.lock:IsValid()and not f.lock:IsBeingDestroyed())
 assert(not f.job.resources.inputLockName and f.inputDestroyed)
end)

test('a partially created input actor is released even before its component exists',function()
 local f=fixture();f.job.resources={}
 f.objects['/Script/EnhancedInput.EnhancedInputComponent']=nil
 local ok=pcall(f.a.prepare,f.c,f.job)
 assert(not ok and f.job.resources.inputOwnerName and not f.job.resources.inputLockName)
 assert(f.a.release(f.job)and f.actorDestroyed and not f.job.resources.inputOwnerName)
end)

test('world membership verifies removal when destroyed actor wrappers remain valid',function()
 local f=fixture();f.job.resources={};pcall(f.a.prepare,f.c,f.job)
 f.inputActor.IsValid=function()return true end
 f.inputActor.IsActorBeingDestroyed=function()return false end
 assert(f.a.release(f.job)and f.actorDestroyed and not f.inputEnabled)
 assert(not f.job.resources.inputOwnerName and not f.job.resources.inputLockName)
end)
test('marker selection ignores POIs and takes an independent finite coordinate snapshot',function()
 local f=fixture();local personal={X=123,Y=456,Z=789}
 f.c.pc.m_PlayerMapMarkerComponent={m_MapMarkers={m_ClientDynamicItemCache={ForEach=function(_,cb)
  cb(1,{get=function()return{m_MarkerType={Name={ToString=function()return'Objective'end}},m_WorldPosition={X=1,Y=2,Z=3}}end})
  cb(2,{get=function()return{m_MarkerType={Name={ToString=function()return'PersonalMarker'end}},m_WorldPosition=personal}end})
 end}}}
 local point=assert(f.a.marker(f.c));personal.X=999
 assert(point.X==123 and point.Y==456)
end)
test('missing ambiguous or nonfinite personal markers are rejected',function()
 local f=fixture();local points={}
 f.c.pc.m_PlayerMapMarkerComponent={m_MapMarkers={m_ClientDynamicItemCache={ForEach=function(_,cb)
  for i,p in ipairs(points)do cb(i,{get=function()return{m_MarkerType={Name={ToString=function()return'PersonalMarker'end}},m_WorldPosition=p}end})end
 end}}}
 local p,reason=f.a.marker(f.c);assert(not p and reason=='no-marker')
 points={{X=0/0,Y=2,Z=3}};p,reason=f.a.marker(f.c);assert(not p and reason=='invalid-marker')
 points={{X=1,Y=2,Z=3},{X=4,Y=5,Z=6}};p,reason=f.a.marker(f.c);assert(not p and reason=='invalid-marker')
end)
test('vehicle possession resolves the seated character and rejects before preparation',function()
 local f=fixture();local valid,character=true,true
 local world={GetAddress=function()return'world'end,GetFullName=function()return'World /Game/Dune/Maps/Arrakis/SOC_1/Survival_1.Survival_1'end}
 local pawn=f.c.pawn
 pawn.IsValid=function()return valid end
 pawn.IsA=function(_,name)assert(name=='/Script/DuneSandbox.DunePlayerCharacter');return character end
 pawn.GetFullName=function()return'BP_DunePlayerCharacter_C world.Player'end
 pawn.GetOuter=function()return{GetOuter=function()return world end}end
 pawn.GetHealth=function()return 100 end
 local pc=f.c.pc
 pc.IsLocalController=function()return true end
 pc.GetDunePlayerCharacter=function()return pawn end
 pc.K2_GetPawn=function()error('Possessed vehicle is not the player character')end
 pc.HasAuthority=function()return true end
 _G.FindAllOf=function(kind)assert(kind=='BP_DunePlayerController_C');return{pc}end
 f.objects['/Script/DuneSandbox.Default__GUIBlueprintLibrary']={IsValid=function()return true end,IsSoloPlay=function()return true end}
 f.objects['/Script/UE4Dreamworld.Default__PersistenceIdBlueprintFunctionLibrary']={IsValid=function()return true end,IsValid_PersistenceActorId=function()return true end}
 local a=Adapter.new();local c=assert(a.context());assert(c.pawn==pawn and c.key=='world/world.Player')
 local allowed,why=a.eligible(c);assert(not allowed and why=='vehicle'and not f.inputEnabled)
 valid=false;assert(a.context()==nil)
 valid=true;character=false;assert(a.context()==nil)
end)

test('unsupported worlds reject before querying character or session APIs',function()
 local f=fixture();local allowed,why=f.a.eligible(f.c)
 assert(not allowed and why=='unsupported-map')
end)
test('session authority solo vehicle and death restrictions are read-only',function()
 local f=fixture();f.c.worldPath='/Game/Dune/Maps/Arrakis/SOC_1/Survival_1.Survival_1'
 local authority,solo,vehicle,dead=true,true,false,false
 f.c.pc.HasAuthority=function()return authority end
 f.c.pawn.IsDead=function()return dead end
 f.c.pawn.GetHealth=function()return 100 end
 f.objects['/Script/DuneSandbox.Default__GUIBlueprintLibrary']={IsValid=function()return true end,IsSoloPlay=function()return solo end}
 f.objects['/Script/UE4Dreamworld.Default__PersistenceIdBlueprintFunctionLibrary']={IsValid=function()return true end,IsValid_PersistenceActorId=function()return vehicle end}
 assert(f.a.eligible(f.c))
 authority=false;local ok,why=f.a.eligible(f.c);assert(not ok and why=='solo-only')
 authority=true;solo=false;ok,why=f.a.eligible(f.c);assert(not ok and why=='solo-only')
 solo=true;vehicle=true;ok,why=f.a.eligible(f.c);assert(not ok and why=='vehicle')
 vehicle=false;dead=true;ok,why=f.a.eligible(f.c);assert(not ok and why=='dead')
 assert(not f.inputDestroyed and#f.updates==0 and f.ignore==2)
end)
test('preparation reads streaming levels incrementally from the current world',function()
 local f=fixture();local streaming,proxies={},{}
 for i=0,1 do
  local asset='/Game/Tiles/SOS-MinorErg_x'..i..'_y0'
  streaming[#streaming+1]={IsValid=function()return true end,IsA=function()return true end,
   PackageNameToLoad={ToString=function()return asset end},
   GetFullName=function()return'LevelStreamingDynamic world.Tile'..i end,
   bDisableDistanceStreaming=false,LevelLODIndex=0}
  proxies[#proxies+1]={GetFullName=function()return'LandscapeStreamingProxy '..asset..'.Tile:Proxy'end,
   GetActorBounds=function(_,_,o,e)o.X=i*1000;o.Y=0;o.Z=0;e.X=500;e.Y=500;e.Z=100 end}
 end
 local visits=0
 local world={StreamingLevels={StreamingLevels={ForEach=function(_,cb)
  for i,l in ipairs(streaming)do visits=visits+1;cb(i,{get=function()return l end})end
 end}}}
 f.c.pawn.GetOuter=function()return{GetOuter=function()return world end}end
 _G.FindAllOf=function(kind)assert(kind=='LandscapeStreamingProxy','Bulk streaming discovery is forbidden');return proxies end
 _G.FindFirstOf=function(kind)assert(kind=='TerrainBlocksSubsystem');return{IsValid=function()return true end,m_SpawnedInstances={ForEach=function()end}}end
 f.job.resources={};f.a.prepare(f.c,f.job)
 assert(visits==2 and#f.job.resources.plan==1 and f.job.resources.plan[1].kind=='landscape')
 assert(f.a.release(f.job)and f.inputDestroyed)
end)
test('destination requires a walkable blocking floor and a free full capsule',function()
 local f=fixture();local found,blocked,normal,response=true,false,1,2;local capsuleCalls=0
 f.job.origin.radius=36;f.job.origin.halfHeight=92
 f.c.pawn.CharacterMovement.K2_GetWalkableFloorZ=function()return 0.64 end
 f.c.pawn.CapsuleComponent={GetCollisionObjectType=function()return 2 end}
 f.original.GetCollisionResponseToChannel=function(_,channel)assert(channel==2);return response end
 f.objects['/Script/Engine.Default__KismetSystemLibrary']={IsValid=function()return true end,
  LineTraceSingle=function(_,_,_,_,_,_,_,_,hit)
   hit.ImpactPoint={X=0,Y=0,Z=10};hit.ImpactNormal={X=0,Y=0,Z=normal}
   hit.Component={Get=function()return f.original end};return found
  end,
  CapsuleTraceSingle=function(_,_,start,finish,radius,half)
   assert(radius==36 and half==92 and start.Z==152 and finish.Z==153)
   capsuleCalls=capsuleCalls+1;return blocked
  end}
 local d=assert(f.a.destination(f.c,f.job));assert(d.Z==152 and f.job.resources.owned[1].targetSupport)
 response=0;local p,why=f.a.destination(f.c,f.job);assert(not p and why=='non-blocking-surface'and capsuleCalls==1);response=2
 blocked=true;local p,why=f.a.destination(f.c,f.job);assert(not p and why=='occupied')
 normal=0.2;p,why=f.a.destination(f.c,f.job);assert(not p and why=='steep-surface'and capsuleCalls==2)
 found=false;p,why=f.a.destination(f.c,f.job);assert(not p and why=='not-loaded')
end)
print(count..' adapter tests passed')
