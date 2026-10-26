local G=require('geometry')
local Search=require('placement_search')
local Profiles=require('map_profiles')
local Adapter={}
local WORLD='/Game/Dune/Maps/Arrakis/SOC_1/Survival_1.Survival_1'
local function path(o) return o:GetFullName():match('^%S+ (.+)$') end
local function object(name) local o=StaticFindObject(name);assert(o:IsValid(),'Object unavailable: '..name);return o end
local function library(name) return object('/Script/'..name) end
local function fullLevel(l)
    if not l:IsLevelLoaded() or not l:IsLevelVisible() then return false end
    local n=0;l.LODPackageNames:ForEach(function()n=n+1 end)
    local actual=path(l:GetLoadedLevel()):match('%.([^%.:]+):PersistentLevel$')
    local expected=l.PackageNameToLoad:ToString():match('/([^/]+)$')
    -- The requested index changes before asynchronous replacement finishes;
    -- terrain-block LOD packages do not necessarily contain a /LOD/ directory.
    return actual==expected and(n==0 or l.LevelLODIndex==-1)
end

function Adapter.new(options)
 options=options or{}
 local a={}
 function a.context()
    for _,pc in ipairs(FindAllOf('BP_DunePlayerController_C')or{})do
        -- Possession switches to the vehicle while driving. Keep the actual
        -- player character so eligibility can read its current vehicle ID.
        local pawn=pc:IsLocalController()and pc:GetDunePlayerCharacter()
        if pawn and pawn:IsValid()and pawn:IsA('/Script/DuneSandbox.DunePlayerCharacter')then
            local w=pawn:GetOuter():GetOuter()
            local world=tostring(w:GetAddress())
            return {pc=pc,pawn=pawn,world=world,worldPath=path(w),pcId=path(pc),key=world..'/'..path(pawn)}
        end
    end
    return nil,'unavailable'
 end
 function a.eligible(c)
    if options.profile then
        if not options.profile(c)then return false,'unsupported-map'end
    elseif c.worldPath~=WORLD then return false,'unsupported-map'end
    if not c.pc:HasAuthority() or not library('DuneSandbox.Default__GUIBlueprintLibrary'):IsSoloPlay(c.pc)then return false,'solo-only' end
    if c.pawn:IsDead() or c.pawn:IsInDownedState() or c.pawn:GetHealth()<=0 then return false,'dead' end
    if library('UE4Dreamworld.Default__PersistenceIdBlueprintFunctionLibrary'):IsValid_PersistenceActorId(c.pawn.m_CurrentVehicleId)then return false,'vehicle' end
    return true
 end
 function a.now(c) return library('Engine.Default__GameplayStatics'):GetRealTimeSeconds(c.pc) end
 function a.point(c,p)
    if not options.profile or not options.validatePoint then return nil,'profile-unavailable'end
    local profile=options.profile(c)
    local valid,why=options.validatePoint(profile,p);if not valid then return nil,why end
    return {X=p.X,Y=p.Y,Z=0,mapId=p.mapId,layerId=p.layerId}
 end
 function a.marker(c)
    local result,count=nil,0
    c.pc.m_PlayerMapMarkerComponent.m_MapMarkers.m_ClientDynamicItemCache:ForEach(function(_,ref)
        local m=ref:get()
        if m.m_MarkerType.Name:ToString()=='PersonalMarker' then
            count=count+1;local v=m.m_WorldPosition
            if G.vector(v) then result=G.copy(v) end
        end
    end)
    if count==0 then return nil,'no-marker' end
    if count~=1 or not result then return nil,'invalid-marker' end
    return result
 end
 local function trace(c,x,y,top,bottom)
    local hit={}
    local ok=library('Engine.Default__KismetSystemLibrary'):LineTraceSingle(c.pc,{X=x,Y=y,Z=top},{X=x,Y=y,Z=bottom},0,false,{c.pawn},0,hit,true,{},{},0)
    return ok,hit
 end
 local function support(c,position,halfHeight)
    local ok,h=trace(c,position.X,position.Y,position.Z-halfHeight+30,position.Z-halfHeight-150)
    if not ok or not G.surfaceHit(h)or h.ImpactNormal.Z<c.pawn.CharacterMovement:K2_GetWalkableFloorZ()then return false end
    local component=h.Component:Get()
    local blocks=component:IsValid()and component:GetCollisionResponseToChannel(c.pawn.CapsuleComponent:GetCollisionObjectType())==2
    return blocks,blocks and path(component)or nil
 end
 function a.snapshot(c)
    local p=G.copy(c.pawn:K2_GetActorLocation());local r=c.pawn:K2_GetActorRotation()
    local cap=c.pawn.CapsuleComponent
    local radius,half=cap:GetScaledCapsuleRadius(),cap:GetScaledCapsuleHalfHeight()
    if not G.vector(p)then return nil,'unsafe-origin'end
    local supported,component=support(c,p,half)
    if not supported then return nil,'unsafe-origin'end
    return {position=p,rotation={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll},radius=radius,halfHeight=half,health=c.pawn:GetHealth(),supportComponent=component}
 end
 local function desertLandscapes(c,job)
    local entries,loaded={},{}
    c.pawn:GetOuter():GetOuter().StreamingLevels.StreamingLevels:ForEach(function(_,ref)
        local l=ref:get()
        if l:IsValid()and l:IsA('/Script/Engine.LevelStreamingDynamic')then
            local asset=l.PackageNameToLoad:ToString()
            local x,y=asset:match('/heightmap/[^/]+_x(%d+)_y(%d+)$')
            if x then
                -- Deep Desert repeats one biome asset at many transforms.
                -- The streaming instance, not PackageNameToLoad, is its key.
                local t=l.LevelTransform;local q=t.Rotation;local s=t.Scale3D
                assert(math.abs(q.X)<1e-6 and math.abs(q.Y)<1e-6 and s.X>0 and s.Y>0 and s.Z>0,'Unsupported desert landscape transform')
                local e={level=l,x=tonumber(x),y=tonumber(y),transform={Rotation={X=q.X,Y=q.Y,Z=q.Z,W=q.W},
                    Translation=G.copy(t.Translation),Scale3D=G.copy(s)}}
                entries[#entries+1]=e
                if l:IsLevelLoaded()then loaded[path(l:GetLoadedLevel())]=e end
            end
        end
    end)
    local proxies={};library('Engine.Default__GameplayStatics'):GetAllActorsOfClass(c.pc,object('/Script/Landscape.LandscapeStreamingProxy'),proxies)
    local basis,count=nil,0
    for _,ref in ipairs(proxies)do
        local p=ref.get and ref:get()or ref;local e=loaded[path(p:GetOuter())]
        if e then
            local o,extent={},{};p:GetActorBounds(false,o,extent,false)
            local loX,loY,hiX,hiY=math.huge,math.huge,-math.huge,-math.huge
            for _,x in ipairs({o.X-extent.X,o.X+extent.X})do for _,y in ipairs({o.Y-extent.Y,o.Y+extent.Y})do
                local v=G.inverseTransform(e.transform,{X=x,Y=y,Z=o.Z})
                loX=math.min(loX,v.X);loY=math.min(loY,v.Y);hiX=math.max(hiX,v.X);hiY=math.max(hiY,v.Y)
            end end
            local b={dx=hiX-loX,dy=hiY-loY};b.x=loX-e.x*b.dx;b.y=loY-e.y*b.dy
            assert(G.finite(b.dx)and G.finite(b.dy)and b.dx>0 and b.dy>0,'Invalid desert landscape bounds')
            if basis then assert(math.abs(b.dx-basis.dx)<1 and math.abs(b.dy-basis.dy)<1 and math.abs(b.x-basis.x)<1 and math.abs(b.y-basis.y)<1,'Inconsistent desert landscape grid')
            else basis=b end
            count=count+1
        end
    end
    assert(basis and count>=2,'Desert landscape grid unavailable')
    local plan={};local originFound,targetFound=false,false
    for _,e in ipairs(entries)do
        local x,y=basis.x+e.x*basis.dx,basis.y+e.y*basis.dy
        local bounds=G.bounds2(e.transform,{Min={X=x,Y=y,Z=0},Max={X=x+basis.dx,Y=y+basis.dy,Z=0}})
        local origin,target=G.contains(bounds,job.origin.position,100),G.contains(bounds,job.marker,100)
        if origin or target then
            assert(not e.level.bDisableDistanceStreaming or e.level.LevelLODIndex==-1,'Desert landscape owned by another streaming override')
            plan[#plan+1]={kind='landscape',name=path(e.level),bounds=bounds,origin=origin,target=target,verifyBounds=true}
            originFound=originFound or origin;targetFound=targetFound or target
        end
    end
    assert(originFound and targetFound,'Point outside supported desert landscape')
    return plan
 end
 local function selectSources(c,job)
    local profile=options.profile and options.profile(c)
    local plan
    if profile and profile.kind=='desert-streamed'then plan=desertLandscapes(c,job)
    else
    local levels={}
    -- Enumerate this world's array incrementally. FindAllOf constructed over
    -- 7,600 Lua wrappers at once and crashed inside UE4SS while building them.
    c.pawn:GetOuter():GetOuter().StreamingLevels.StreamingLevels:ForEach(function(_,reference)
        local l=reference:get()
        if l:IsValid()and l:IsA('/Script/Engine.LevelStreamingDynamic')then
            local s=l.PackageNameToLoad:ToString()
            local profile=options.profile and options.profile(c)
            local pattern=profile and profile.kind=='desert-streamed'and'/Tiles/[^/]+_x%d+_y%d+$'or'/Tiles/SOS%-MinorErg_x%d+_y%d+$'
            if s:find(pattern) then levels[s]=l end
        end
    end)
    local basis,count=nil,0
    for _,p in ipairs(FindAllOf('LandscapeStreamingProxy')or{})do
        local source=p:GetFullName():match('^%S+ (.-)%.')
        if levels[source] then
            local prefix,x,y=source:match('^(.-)_x(%d+)_y(%d+)$')
            local o,e={},{};p:GetActorBounds(false,o,e,false)
            if G.vector(o) and G.vector(e) and e.X>0 and e.Y>0 then
                local b={prefix=prefix,dx=2*e.X,dy=2*e.Y,x=o.X-e.X-tonumber(x)*2*e.X,y=o.Y-e.Y-tonumber(y)*2*e.Y}
                if basis then
                    assert(b.prefix==basis.prefix and math.abs(b.dx-basis.dx)<1 and math.abs(b.dy-basis.dy)<1 and math.abs(b.x-basis.x)<1 and math.abs(b.y-basis.y)<1,'Inconsistent landscape grid')
                else basis=b end
                count=count+1
            end
        end
    end
    assert(basis and count>=2,'Landscape grid unavailable')
    plan={}
    local originFound,targetFound=false,false
    for s,l in pairs(levels)do
        local _,x,y=s:match('^(.-)_x(%d+)_y(%d+)$')
        local b={minX=basis.x+tonumber(x)*basis.dx,minY=basis.y+tonumber(y)*basis.dy,maxX=basis.x+(tonumber(x)+1)*basis.dx,maxY=basis.y+(tonumber(y)+1)*basis.dy}
        local origin,target=G.contains(b,job.origin.position,100),G.contains(b,job.marker,100)
        if origin or target then
            originFound=originFound or origin;targetFound=targetFound or target
            assert(not l.bDisableDistanceStreaming or l.LevelLODIndex==-1,'Landscape owned by another streaming override')
            plan[#plan+1]={kind='landscape',name=path(l),bounds=b,origin=origin,target=target}
        end
    end
    assert(originFound and targetFound,'Point outside supported landscape')
    end
    local sub=library('Engine.Default__SubsystemBlueprintLibrary'):GetWorldSubsystem(c.pc,object('/Script/DuneSandbox.TerrainBlocksSubsystem'))
    assert(sub:IsValid(),'Terrain subsystem unavailable in current world')
    sub.m_SpawnedInstances:ForEach(function(_,ref)
        ref:get().SubLevels:ForEach(function(_,r)
            local entry=r:get();local l=entry.StreamingLevel
            local asset=l:IsValid()and l:GetWorldAssetPackageFName():ToString()or''
            -- Some walkable rocks live in Art, while ArtCollision contains only
            -- part of a terrain block. Loading the latter alone exposes lower floors.
            if l:IsValid() and (asset:find('_ArtCollision',1,true)or asset:match('_Art$'))then
                local b=G.bounds2(l.LevelTransform,entry.StreamingLevelBounds)
                local origin,target=G.contains(b,job.origin.position,100),G.contains(b,job.marker,100)
                if origin or target then plan[#plan+1]={kind='collision',name=path(l),origin=origin,target=target} end
            end
        end)
    end)
    assert(#plan<=24,'Too many collision packages for bounded preload')
    return plan
 end
 function a.prepare(c,job)
    -- Enhanced Input skips a plain InputComponent. Its blocker must also be
    -- pushed onto the controller's input stack, not merely registered.
    local statics=library('Engine.Default__GameplayStatics')
    local transform={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
    local actor=statics:BeginDeferredActorSpawnFromClass(c.pc,object('/Script/Engine.Actor'),transform,1,c.pc,0)
    assert(actor:IsValid(),'Input blocker owner creation failed')
    job.resources.inputOwnerName=path(actor);job.resources.inputLockPc=c.pcId
    actor.Tags={FName('MapTeleportInputOwner')}
    actor.bBlockInput=true;actor.InputPriority=2147483647
    statics:FinishSpawningActor(actor,transform,0)
    actor:CreateInputComponent(object('/Script/EnhancedInput.EnhancedInputComponent'))
    local lock=actor.InputComponent
    assert(lock:IsValid()and lock:IsA('/Script/EnhancedInput.EnhancedInputComponent'),'Enhanced input blocker creation failed')
    job.resources.inputLockName=path(lock)
    actor:EnableInput(c.pc)
    c.pawn.CharacterMovement:StopMovementImmediately()
    local profile=options.profile and options.profile(c)
    job.profile=profile
    job.resources.plan=profile and profile.kind=='compact'and{}or selectSources(c,job)
    job.resources.next=1;job.resources.owned={}
 end
 function a.ready(c,job)
    local r=job.resources;local item=r.plan[r.next]
    if item then
        local source=object(item.name)
        if item.kind=='landscape' then
            local owned={kind='landscape',name=item.name,lod=source.LevelLODIndex,distance=source.bDisableDistanceStreaming,load=source:ShouldBeLoaded(),visible=source.bShouldBeVisible,bounds=item.bounds,origin=item.origin,target=item.target,verifyBounds=item.verifyBounds}
            r.owned[#r.owned+1]=owned
            source.bDisableDistanceStreaming=true;source:SetLevelLODIndex(-1);source:SetShouldBeLoaded(true);source:SetShouldBeVisible(true)
        else
            local clone=source:CreateInstance('MapTeleport_'..math.floor(job.started*1000)..'_'..job.id..'_'..r.next)
            assert(clone:IsValid(),'Collision instance creation failed')
            local prefix=source:IsLevelLoaded()and path(source:GetLoadedLevel())
            local originSupport=prefix and job.origin.supportComponent and job.origin.supportComponent:sub(1,#prefix+1)==prefix..'.'or false
            r.owned[#r.owned+1]={kind='collision',name=path(clone),source=item.name,origin=item.origin,target=item.target,originSupport=originSupport}
            clone.PackageNameToLoad=source.PackageNameToLoad;clone.LevelTransform=source.LevelTransform
            clone.bShouldBlockOnLoad=false;clone.bDisableDistanceStreaming=true;clone:SetLevelLODIndex(-1);clone:SetShouldBeLoaded(true);clone:SetShouldBeVisible(true)
        end
        r.next=r.next+1
        return false
    end
    for _,owned in ipairs(r.owned)do if not fullLevel(object(owned.name))then return false end end
    local verification
    for _,owned in ipairs(r.owned)do if owned.verifyBounds and not owned.boundsVerified then
        if not verification then verification={};library('Engine.Default__GameplayStatics'):GetAllActorsOfClass(c.pc,object('/Script/Landscape.LandscapeStreamingProxy'),verification)end
        local expected=path(object(owned.name):GetLoadedLevel());local found=false
        for _,ref in ipairs(verification)do
            local p=ref.get and ref:get()or ref
            if path(p:GetOuter())==expected then
                local o,e={},{};p:GetActorBounds(false,o,e,false);local b=owned.bounds
                assert(math.abs(o.X-e.X-b.minX)<1 and math.abs(o.X+e.X-b.maxX)<1 and math.abs(o.Y-e.Y-b.minY)<1 and math.abs(o.Y+e.Y-b.maxY)<1,'Loaded desert landscape bounds differ from plan')
                found=true
            end
        end
        if not found then return false end
        owned.boundsVerified=true
    end end
    return true
 end
 local function candidate(c,job,point)
    local profile=job.profile
    local top,reason=Profiles.traceTop(profile,point,job.origin.halfHeight)
    if not top then return nil,reason end
    local ok,h=trace(c,point.X,point.Y,top,profile and profile.bottom or -300000)
    if not ok then return nil,'not-loaded' end
    local observedComponent=h.Component:Get()
    job.surface={point={X=h.ImpactPoint.X,Y=h.ImpactPoint.Y,Z=h.ImpactPoint.Z},normalZ=h.ImpactNormal.Z,
        minNormalZ=c.pawn.CharacterMovement:K2_GetWalkableFloorZ(),component=observedComponent:IsValid()and path(observedComponent)or'invalid',
        profile=profile and profile.id or'HaggaBasin',collisionReady=true,traceTime=h.Time,traceDistance=h.Distance}
    if a.log then pcall(a.log,job,'Surface')end
    local valid,hitReason=G.surfaceHit(h);if not valid then return nil,hitReason end
    local d,why=G.destination(h.ImpactPoint,h.ImpactNormal,job.origin.radius,job.origin.halfHeight,c.pawn.CharacterMovement:K2_GetWalkableFloorZ())
    if not d then return nil,why end
    local component=h.Component:Get()
    if not component:IsValid()or component:GetCollisionResponseToChannel(c.pawn.CapsuleComponent:GetCollisionObjectType())~=2 then return nil,'non-blocking-surface'end
    local cap={}
    local blocked=library('Engine.Default__KismetSystemLibrary'):CapsuleTraceSingle(c.pc,d,{X=d.X,Y=d.Y,Z=d.Z+1},job.origin.radius,job.origin.halfHeight,0,false,{c.pawn},0,cap,true,{},{},0)
    if blocked then return nil,'occupied' end
    local componentName=path(component);job.destinationSupportComponent=componentName
    for _,owned in ipairs(job.resources.owned or{})do
        if owned.kind=='collision'then
            owned.targetSupport=false
            for _,name in ipairs({owned.name,owned.source})do
                local level=object(name)
                if level:IsLevelLoaded()then
                    local prefix=path(level:GetLoadedLevel())
                    if componentName:sub(1,#prefix+1)==prefix..'.'then owned.targetSupport=true end
                end
            end
        end
    end
    return d
 end
 function a.destination(c,job)
    return Search.step(job,function(point)return candidate(c,job,point)end,function(point)
        return not job.profile or G.contains(job.profile.bounds,point)
    end)
 end
 -- The game's terrain manager can change a source LOD after initial readiness.
 -- Keep every still-owned source pinned, including the retained return point.
 function a.maintain(c,job)
    for _,owned in ipairs(job.resources.owned or {})do
        if not owned.released then
            local l=object(owned.name)
            l.bDisableDistanceStreaming=true;l:SetLevelLODIndex(-1)
            l:SetShouldBeLoaded(true);l:SetShouldBeVisible(true)
        end
    end
 end
 function a.restoreReady(c,job)
    for _,owned in ipairs(job.resources.owned or {})do
        if owned.origin and not fullLevel(object(owned.released and (owned.source or owned.name)or owned.name))then return false end
    end
    -- Check the original floor elevation, rather than accepting any lower floor.
    return support(c,job.origin.position,job.origin.halfHeight)
 end
 local function move(c,position,rotation)
    c.pawn.CharacterMovement:StopMovementImmediately()
    return library('DuneSandbox.Default__DuneBlueprintFunctionLibrary'):TeleportTo(c.pawn,position,rotation,false,false,{})
 end
 function a.move(c,job) return move(c,job.destination,job.origin.rotation) end
 function a.restore(c,job) return move(c,job.origin.position,job.origin.rotation) end
 function a.verify(c,job,restoring)
    local p=G.copy(c.pawn:K2_GetActorLocation());local intended=restoring and job.origin.position or job.destination
    if G.distance2(p,intended)>500^2 or math.abs(p.Z-intended.Z)>150 then return false,'position-rejected' end
    if c.pawn:GetHealth()<job.origin.health-0.1 then return false,'health-lost' end
    if not support(c,p,job.origin.halfHeight) then return false,'no-support' end
    return true
 end
 function a.canHandoff(c,job,restoring)
    for _,owned in ipairs(job.resources.owned or{})do
        -- Bounds can also contain unloaded, irrelevant cave/ship packages.
        -- Wait for the actual supporting level, then verify the normal floor
        -- for three seconds after all temporary levels leave the world.
        if owned.kind=='collision'and(restoring and owned.originSupport or not restoring and owned.targetSupport)and not fullLevel(object(owned.source))then return false end
    end
    return true
 end
 local function unload(owned)
    local l=StaticFindObject(owned.name)
    if l:IsValid()then l:SetShouldBeVisible(false);l:SetShouldBeLoaded(false);l:SetIsRequestingUnloadAndRemoval(true)end
    owned.released=true
 end
 local function restoreLandscape(c,owned)
    local l=object(owned.name)
    -- Once the character is here the normal streamer needs full detail. Do not
    -- briefly force the old distant LOD underneath their feet during handoff.
    local here=c.pawn and c.pawn:IsValid()and G.contains(owned.bounds,G.copy(c.pawn:K2_GetActorLocation()),100)
    if not here then l:SetLevelLODIndex(owned.lod);l:SetShouldBeLoaded(owned.load);l:SetShouldBeVisible(owned.visible) end
    l.bDisableDistanceStreaming=owned.distance
    owned.released=true
 end
 local function beginRelease(c,job,mode)
    local stage=job.resources.releaseStage or{unloading={},refresh={}};stage.mode=mode;local seen={}
    for _,name in ipairs(stage.refresh)do seen[name]=true end
    local components
    for _,owned in ipairs(job.resources.owned or{})do
        local selected=mode=='all'or(mode=='origin'and owned.origin)or(mode=='target'and owned.target)
        if selected and not owned.released and owned.kind=='collision'then
            local clone=object(owned.name);local source=object(owned.source)
            if clone:IsLevelLoaded()and fullLevel(source)then
                components=components or FindAllOf('LandscapeHeightfieldCollisionComponent')or{}
                local prefix=path(clone:GetLoadedLevel());local original=path(source:GetLoadedLevel())
                for _,component in ipairs(components)do
                    local name=path(component)
                    if name:sub(1,#prefix+1)==prefix..'.'then
                        local counterpart=original..name:sub(#prefix+1)
                        if not seen[counterpart]then seen[counterpart]=true;stage.refresh[#stage.refresh+1]=counterpart end
                    end
                end
            end
            stage.unloading[#stage.unloading+1]=owned.name
            unload(owned)
        elseif selected and not owned.released and owned.kind=='landscape'and(mode=='all'or not owned.origin)then
            restoreLandscape(c,owned)
        end
    end
    job.resources.releaseStage=stage
    job.resources.lastRelease={mode=mode,unloading=#stage.unloading,refresh=#stage.refresh}
 end
 function a.handoff(c,job,restoring)
    beginRelease(c,job,restoring and'origin'or'target')
 end
 local function releaseInput(job)
    local r=job.resources
    if r.inputOwnerName then
        local actor=StaticFindObject(r.inputOwnerName)
        if actor:IsValid()and not actor:IsActorBeingDestroyed()then
            local pc=actor:GetOwner()
            assert(pc:IsValid()and path(pc)==r.inputLockPc,'Input blocker owner changed; preserved')
            assert(tostring(pc:GetOuter():GetOuter():GetAddress())==job.world,'Input blocker world changed; preserved')
            actor:DisableInput(pc)
            if r.inputLockName then
                local lock=StaticFindObject(r.inputLockName)
                if lock:IsValid()and not lock:IsBeingDestroyed()then
                    assert(path(lock:GetOwner())==r.inputOwnerName,'Enhanced input component owner changed; preserved')
                    lock:K2_DestroyComponent(actor)
                end
                for _,reference in ipairs(actor:K2_GetComponentsByClass(object('/Script/Engine.InputComponent')))do
                    local component=reference.get and reference:get()or reference
                    assert(path(component)~=r.inputLockName,'Enhanced input blocker destruction rejected')
                end
            end
            actor:K2_DestroyActor()
            -- A destroyed actor can remain resolvable until GC with the
            -- transient destruction flag cleared. Check world membership.
            local remaining={}
            library('Engine.Default__GameplayStatics'):GetAllActorsWithTag(pc,FName('MapTeleportInputOwner'),remaining)
            for _,reference in ipairs(remaining)do
                local other=reference.get and reference:get()or reference
                assert(path(other)~=r.inputOwnerName,'Input blocker actor destruction rejected')
            end
            assert(not actor:IsValid()or not actor:GetOwner():IsValid(),'Input blocker owner was not released')
        end
        r.inputOwnerName=nil;r.inputLockName=nil;r.inputLockPc=nil
        return
    end
    if not r.inputLockName then return end
    local lock=StaticFindObject(r.inputLockName)
    if lock:IsValid()and not lock:IsBeingDestroyed()then
        local owner=lock:GetOwner()
        assert(owner:IsValid()and path(owner)==r.inputLockPc,'Input blocker owner changed; preserved')
        assert(tostring(owner:GetOuter():GetOuter():GetAddress())==job.world,'Input blocker world changed; preserved')
        lock:K2_DestroyComponent(owner)
        -- UE4SS may still resolve a destroyed UObject until GC, while the
        -- transient IsBeingDestroyed flag has already returned to false.
        -- Verify removal from the actor's actual component collection.
        for _,reference in ipairs(owner:K2_GetComponentsByClass(object('/Script/Engine.InputComponent')))do
            local component=reference.get and reference:get()or reference
            assert(path(component)~=r.inputLockName,'Input blocker destruction rejected')
        end
    end
    r.inputLockName=nil;r.inputLockPc=nil
 end
 a.releaseRestrictions=releaseInput
 function a.handoffReady(c,job)
    local stage=job.resources.releaseStage
    if not stage then return true end
    for _,name in ipairs(stage.unloading)do
        local l=StaticFindObject(name)
        if l:IsValid()and(l:IsLevelLoaded()or l:IsLevelVisible())then return false end
    end
    if #stage.unloading>0 then
        stage.unloadedAt=stage.unloadedAt or a.now(c)
        -- Deferred physics destruction can outlive IsLevelLoaded=false.
        if a.now(c)-stage.unloadedAt<0.1 then return false end
    end
    -- Landscape instances share cooked heightfields. Refresh the original
    -- collision only after the duplicate has actually left the physics scene.
    for _,name in ipairs(stage.refresh)do
        local component=StaticFindObject(name)
        if component:IsValid()then
            local enabled=component:GetCollisionEnabled()
            if enabled~=0 then component:SetCollisionEnabled(0);component:SetCollisionEnabled(enabled)end
        end
    end
    local sameCharacter=c.pawn and c.key==job.key and not c.pawn:IsDead()and not c.pawn:IsInDownedState()
    if sameCharacter then c.pawn.CharacterMovement.bForceNextFloorCheck=true end
    local intended=(stage.mode=='origin'or(stage.mode=='all'and(job.restoring or not job.moved)))and job.origin.position or job.destination
    local current=sameCharacter and G.copy(c.pawn:K2_GetActorLocation())
    local probe=intended and{X=intended.X,Y=intended.Y,Z=intended.Z-((job.restoring or not job.moved)and 0 or 50)}
    if sameCharacter and intended and current.Z<intended.Z-70 and support(c,probe,job.origin.halfHeight)then
        assert(move(c,{X=intended.X,Y=intended.Y,Z=intended.Z+50},job.origin.rotation),'Handoff floor recovery failed')
    end
    job.resources.releaseStage=nil
    if stage.mode=='all'then releaseInput(job)end
    return true
 end
 a.releaseReady=a.handoffReady
 function a.release(job)
    local c=a.context()
    if not c then
        local pc=StaticFindObject(job.pcId or job.resources.inputLockPc or'')
        if pc:IsValid()and tostring(pc:GetOuter():GetOuter():GetAddress())==job.world then
            c={pc=pc,pcId=path(pc),world=job.world}
        end
    end
    if not c or c.world~=job.world then releaseInput(job);return end
    if not job.resources.releaseStage or job.resources.releaseStage.mode~='all'then beginRelease(c,job,'all')end
    return a.handoffReady(c,job)
 end
 local messages={preparing='Подготовка места назначения…',success='Перенос завершён',busy='Перенос уже выполняется',['no-marker']='Поставьте личную метку на карте M',restored='Перенос отменён, исходная позиция восстановлена',timeout='Место назначения не загрузилось',['restore-failed']='Ошибка восстановления: переносы отключены',disabled='Переносы отключены после ошибки',dead='Перенос недоступен: персонаж не готов',vehicle='Сначала покиньте транспорт',['solo-only']='Требуется одиночная игра',['unsupported-map']='Эта карта не поддерживается'}
 local reasons={['no-safe-place']='Не найдено безопасное место для появления',['steep-surface']='Слишком крутая поверхность',['occupied']='Недостаточно места для персонажа',['initial-overlap']='Точка внутри препятствия',['invalid-trace-hit']='Поверхность не подтверждена',['non-blocking-surface']='Нет надёжной опоры',['playable-height-unavailable']='Не определён игровой уровень поверхности',['no-support']='Не подтверждена опора',['unsafe-origin']='Не подтверждена исходная опора',['wrong-map-or-layer']='Точка принадлежит другой карте или слою',['outside-map']='Точка за границами карты'}
 function a.describeReason(code)return reasons[code]or messages[code]or tostring(code)end
 function a.message(code,detail)
    local text=code=='partial'and tostring(detail)or messages[code]or reasons[detail]or('Перенос отменён: '..tostring(detail or code))
    print('[MapTeleport] '..code..' '..tostring(detail or '')..'\n')
    local c=a.context()
    if c then
        local data=StaticConstructObject(object('/Script/DuneSandbox.ToastData'),c.pc)
        local texts=library('Engine.Default__KismetTextLibrary')
        data.TitleText=texts:Conv_StringToText('Телепортация');data.ContentText=texts:Conv_StringToText(text)
        data.TitleTextTint={R=1,G=0.8,B=0.3,A=1};data.ContentTextTint={R=1,G=1,B=1,A=1};data.TimeToShowInSeconds=3
        local notification=StaticConstructObject(object('/Script/DuneSandbox.ToastNotificationData'),c.pc)
        notification.m_WorldContext=c.pc;notification.m_ToastData=data
        notification.m_ToastNotificationSettingsData=object('/Game/Dune/GUI/Data/ToastNotificationData/ToastNotificationsDataSettings.ToastNotificationsDataSettings')
        c.pc:ClientHUDShowNotificationToast(notification)
    end
 end
 function a.log(job,phase)
    local observed='';local c=a.context()
    if c and c.key==job.key then
        local p=c.pawn:K2_GetActorLocation()
        observed=string.format(' current=(%.3f,%.3f,%.3f) health=%.3f',p.X,p.Y,p.Z,c.pawn:GetHealth())
    end
    print(string.format('[MapTeleport] request=%s world=%s state=%s marker=(%.3f,%.3f) origin=(%.3f,%.3f,%.3f)%s\n',job.id,job.world,phase,job.marker.X,job.marker.Y,job.origin.position.X,job.origin.position.Y,job.origin.position.Z,observed))
    if job.destination then
        local d=job.destination
        print(string.format('[MapTeleport] placement requested=(%.3f,%.3f) actual=(%.3f,%.3f,%.3f) offsetMeters=%.3f\n',job.marker.X,job.marker.Y,d.X,d.Y,d.Z,(job.placementOffset or 0)/100))
    end
    if job.surface then
        local s=job.surface
        print(string.format('[MapTeleport] operation=%s map=%s layer=%s profile=%s normalZ=%.6f minNormalZ=%.6f support=%s impact=(%.3f,%.3f,%.3f) collisionReady=%s traceTime=%s traceDistance=%s\n',
            tostring(job.operationId or job.id),tostring(job.marker.mapId or'HaggaBasin'),tostring(job.marker.layerId or'surface'),s.profile,s.normalZ,s.minNormalZ,s.component,s.point.X,s.point.Y,s.point.Z,tostring(s.collisionReady),tostring(s.traceTime),tostring(s.traceDistance)))
    end
 end
 return a
end
return Adapter
