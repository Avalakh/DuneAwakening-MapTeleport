local Projection=require('map_projection')
local Profiles=require('map_profiles')
local Canvas=require('map_canvas')
local View={}
local function obj(n)local o=StaticFindObject(n);assert(o:IsValid(),'Map object unavailable: '..n);return o end
local function lib(n)return obj('/Script/'..n)end
local function path(o)return o:GetFullName():match('^%S+ (.+)$')end
-- Keep our copies outside the native camera's scene; never alter that camera.
local previewZ=10000000
function View.new(context,catalog)
    local v={zoomValue=1,panU=0,panV=0,owned={}}
    function v.close()
        local errors,remaining={},{}
        for i=#v.owned,1,-1 do
            local name=v.owned[i]
            local ok,why=pcall(function()
                local o=StaticFindObject(name)
                if o:IsValid()and o:IsA('/Script/Engine.Actor')and not o:IsActorBeingDestroyed()then
                    assert(o:ActorHasTag(FName('MapTeleportPreview')),'Preview ownership changed')
                    local ownerWorld=o:GetOuter():GetOuter()
                    o:K2_DestroyActor()
                    if ownerWorld:IsValid()then
                        local actors={};lib('Engine.Default__GameplayStatics'):GetAllActorsWithTag(ownerWorld,FName('MapTeleportPreview'),actors)
                        for _,r in ipairs(actors)do local actor=r.get and r:get()or r;assert(path(actor)~=name,'Preview destruction rejected')end
                    else assert(o:IsActorBeingDestroyed()or not o:IsValid(),'Preview destruction not confirmed')end
                end
            end)
            if not ok then remaining[#remaining+1]=name;errors[#errors+1]=tostring(why)end
        end
        v.owned=remaining
        if #errors>0 then error(table.concat(errors,'; '))end
        v.map=nil;v.texture=nil;v.camera=nil;v.currentId=nil;v.profile=nil;v.previewWorld=nil;v.windowView=nil
    end
    local function spawn(c,class,t)
        local stats=lib('Engine.Default__GameplayStatics')
        local a=stats:BeginDeferredActorSpawnFromClass(obj(v.previewWorld),class,t,1,nil,0)
        assert(a:IsValid(),'Map preview creation failed')
        v.owned[#v.owned+1]=path(a);a.Tags={FName('MapTeleportPreview')};a:SetActorEnableCollision(false)
        stats:FinishSpawningActor(a,t,0);return a
    end
    local function cameraPosition()
        if v.windowView then
            return{X=v.centerX+(v.windowView.u-.5)*v.width,Y=v.centerY+(v.windowView.v-.5)*v.width,Z=previewZ+v.planeZ+v.cameraHeight}
        end
        return {X=v.centerX+v.panU*v.width,Y=v.centerY+v.panV*v.width,Z=previewZ+v.planeZ+v.cameraHeight}
    end
    local function capture()
        local camera=obj(v.camera)
        camera:K2_SetActorLocation(cameraPosition(),false,{},true)
        local fraction=v.windowView and v.windowView.fraction or 1/v.zoomValue
        camera.CaptureComponent2D.FOVAngle=2*math.atan(v.width*fraction/(2*v.cameraHeight))*180/math.pi
        camera.CaptureComponent2D:CaptureScene()
    end
    local function prepare(c,id)
        v.close();v.zoomValue=1;v.panU=0;v.panV=0
        local row
        local _,raw=catalog.snapshot(c)
        for _,r in ipairs(raw)do if r.id==id then row=r;break end end
        assert(row,'Map missing from native catalog')
        local settings=FindFirstOf('CartographyMapSettings');local class
        local subsystem=lib('Engine.Default__SubsystemBlueprintLibrary'):GetWorldSubsystem(c.pc,obj('/Script/DuneSandbox.CartographyMapSubsystem'))
        assert(subsystem:IsValid(),'Cartography subsystem unavailable in current world')
        local nativeLayer=subsystem:GetCurrentMapLayerActor()
        assert(nativeLayer:IsValid(),'Native cartography showroom not ready')
        v.previewWorld=path(nativeLayer:GetOuter():GetOuter())
        settings.m_PerMapSettings:ForEach(function(k,r)
            if k:get().Name:ToString()==id then class=lib('Engine.Default__KismetSystemLibrary'):LoadClassAsset_Blocking(r:get().m_MapLayerSettings.m_MapLayerActor)end
        end)
        assert(class and class:IsValid(),'Native map layer unavailable')
        local t={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=previewZ},Scale3D={X=1,Y=1,Z=1}}
        local actor=spawn(c,class,t)
        actor:OnIsCurrentMapLayerChanged(true)
        local children={};actor:GetAllChildActors(children,true)
        for _,r in ipairs(children)do local child=r.get and r:get()or r;child:SetActorEnableCollision(false)end
        local copies={actor};for _,r in ipairs(children)do copies[#copies+1]=r.get and r:get()or r end
        for _,copy in ipairs(copies)do
            for _,r in ipairs(copy:K2_GetComponentsByClass(obj('/Script/Engine.PrimitiveComponent')))do
                local component=r.get and r:get()or r;component:SetVisibleInSceneCaptureOnly(true)
            end
        end
        -- Fog planes depend on the live world's exploration render target.
        -- Hide only the copies owned by this preview, never native map actors.
        for _,r in ipairs(actor:K2_GetComponentsByClass(obj('/Script/Engine.PrimitiveComponent')))do
            local component=r.get and r:get()or r
            if component:GetFName():ToString():match('^FogLayer')then component:SetVisibility(false,false)end
        end
        local b=actor.m_MapLayerComponent.m_MapLayerMapBounds
        assert(b.Max.X>b.Min.X and b.Max.Y>b.Min.Y,'Native map bounds invalid')
        v.width=math.max(b.Max.X-b.Min.X,b.Max.Y-b.Min.Y)
        v.centerX=(b.Min.X+b.Max.X)/2;v.centerY=(b.Min.Y+b.Max.Y)/2
        local fov
        actor.m_MapLayerComponent.m_ZoomSteps:ForEach(function(_,r)
            local step=r:get();if not fov and step.VerticalFoV>0 and step.VerticalFoV<180 then fov=step.VerticalFoV end
        end)
        assert(fov and fov>0 and fov<180,'Native map camera settings unavailable')
        v.planeZ=0
        if id~='Overland'then
            local metadata,why=Profiles.metadata(row);assert(metadata,why)
            local sys=lib('Engine.Default__KismetSystemLibrary')
            local widgetClass=sys:LoadClassAsset_Blocking(sys:Conv_SoftClassPathToSoftClassRef(sys:MakeSoftClassPath('/Game/Dune/GUI/Widgets/Menus/Gameplay/PlayerMenu/FullscreenMap/W_FullscreenMap.W_FullscreenMap_C')))
            assert(widgetClass:IsValid(),'Native map cursor plane unavailable')
            local height=widgetClass:GetCDO().m_CursorProjectionPlaneHeight
            v.planeZ=assert(Projection.plane(b.Min.Z,b.Max.Z,metadata.min,metadata.max,height))
            v.map=assert(Projection.fromBounds(id,{minX=b.Min.X,minY=b.Min.Y,maxX=b.Max.X,maxY=b.Max.Y},metadata.bounds))
            v.profile=assert(Profiles.new(row,metadata.bounds,metadata))
            Profiles.register(v.profile)
        else
            -- Overview is display-only; it never supplies a placement target.
            v.map=nil
        end
        v.cameraHeight=math.max(v.width/(2*math.tan(fov*math.pi/360)),b.Max.Z-v.planeZ+100)
        fov=2*math.atan(v.width/(2*v.cameraHeight))*180/math.pi
        local nativeTarget=obj('/Game/Dune/GUI/3D/RT_MenuMap.RT_MenuMap')
        local rt=lib('Engine.Default__KismetRenderingLibrary'):CreateRenderTarget2D(c.pc,1536,1536,nativeTarget.RenderTargetFormat,{r=.015,G=.02,B=.03,A=1},false,false,0,false)
        assert(rt:IsValid(),'Map render target creation failed');v.texture=path(rt)
        rt.TargetGamma=nativeTarget.TargetGamma
        local rot=lib('Engine.Default__KismetMathLibrary'):Conv_RotatorToQuaternion({Pitch=-90,Yaw=-90,Roll=0})
        local cam=spawn(c,obj('/Script/Engine.SceneCapture2D'),{Rotation=rot,Translation=cameraPosition(),Scale3D={X=1,Y=1,Z=1}})
        v.camera=path(cam);local capture=cam.CaptureComponent2D
        capture.ProjectionType=0;capture.FOVAngle=fov;capture.TextureTarget=rt;capture.CaptureSource=10
        capture.bAlwaysPersistRenderingState=true
        capture.PostProcessSettings.bOverride_AutoExposureMethod=true;capture.PostProcessSettings.AutoExposureMethod=0
        capture.PostProcessSettings.bOverride_AutoExposureBias=true;capture.PostProcessSettings.AutoExposureBias=1
        capture.PrimitiveRenderMode=2;capture.bCaptureEveryFrame=false;capture.bCaptureOnMovement=false
        capture:ShowOnlyActorComponents(actor,true);capture:CaptureScene()
        v.currentId=id;v.pendingCapture=true;v.captureUntil=nil;v.nextCapture=nil
    end
    function v.show(view,rect)
        local id=view.region and view.region.localMapState=='present'and view.region.mapId or'Overland'
        local c=context();assert(c,'Map player unavailable')
        if v.currentId~=id then
            local ok,why=pcall(prepare,c,id)
            if not ok then v.close();return nil,'Не удалось открыть карту: '..tostring(why)end
        end
        return {texture=v.texture,map=v.map,profile=v.profile}
    end
    local function viewport(rect)
        return{x=rect.x,y=rect.y,width=rect.width,height=rect.height,zoom=v.zoomValue,panU=v.panU,panV=v.panV}
    end
    function v.pick(rect,x,y)
        if not v.profile then return end
        local p=Projection.pick(v.map,viewport(rect),x,y)
        if p and Profiles.validate(v.profile,p)then return p end
    end
    function v.screen(point,rect)
        local p=Projection.screen(v.map,viewport(rect),point);if p then return p.x,p.y end
    end
    function v.viewport(viewport,rect)
        local next=Canvas.capture(viewport,rect);local old=v.windowView
        if old and old.width==next.width and old.height==next.height and math.abs(old.u-next.u)<1e-8 and math.abs(old.v-next.v)<1e-8 and math.abs(old.fraction-next.fraction)<1e-8 then return end
        if not old or old.width~=next.width or old.height~=next.height then
            lib('Engine.Default__KismetRenderingLibrary'):ResizeRenderTarget2D(obj(v.texture),next.width,next.height)
        end
        v.windowView=next;capture()
    end
    function v.zoom(factor)v.zoomValue=math.max(1,math.min(16,v.zoomValue*factor));capture()end
    function v.pan(u,w)
        local limit=.5-.5/v.zoomValue
        v.panU=math.max(-limit,math.min(limit,v.panU+u));v.panV=math.max(-limit,math.min(limit,v.panV+w));capture()
    end
    function v.tick()
        if v.pendingCapture and v.camera then
            local time={};lib('Engine.Default__GameplayStatics'):GetAccurateRealTime(time,{})
            local now=time.Seconds+time.PartialSeconds
            v.captureUntil=v.captureUntil or(now+3)
            if not v.nextCapture or now>=v.nextCapture then capture();v.nextCapture=now+.25 end
            if now>=v.captureUntil then v.pendingCapture=false end
        end
    end
    return v
end
return View

