-- Fullscreen UMG composition. All controls are owned by this UserWidget; the
-- game's map, personal marker, menus and input mappings remain independent.
local Window={}
local Profiles=require('map_profiles')
local Canvas=require('map_canvas')
local MarkerModel=require('map_marker_model')
function Window.canTeleport(view,descriptor)
    local region=view and view.region
    if not region then return false end
    if region.localMapState=='absent'then return not region.current end
    if region.localMapState~='present'or not descriptor or not descriptor.profile then return false end
    return Profiles.validate(descriptor.profile,view.point)
end
local function obj(n)local o=StaticFindObject(n);assert(o:IsValid(),'UI resource unavailable: '..n);return o end
local function path(o)return o:GetFullName():match('^%S+ (.+)$')end
local gold={r=.83,G=.65,B=.32,A=1}
local white={r=.94,G=.91,B=.83,A=1}
local background={r=.025,G=.031,B=.05,A=1}
-- UE4SS table marshalling uses the reflected field name: lowercase r.
local function nativeColor(c)return{r=c.R,G=c.G,B=c.B,A=c.A}end
function Window.new(a)
    local ui={buttons={},serial=0,bindings={},events={}}
    local bridge='/Script/UMG.Widget:InvalidateLayoutAndVolatility'
    -- A no-argument native UFunction is a legal target of UButton.OnClicked.
    -- One hook routes only our own button instances to the game-thread queue.
    -- The original function still performs its harmless layout invalidation.
    local pre,post=RegisterHook(bridge,function(context)
        local b=context:get();local binding=ui.bindings[path(b)]
        if not binding then return end
        local e={};for k,v in pairs(binding.event)do e[k]=v end;e.revision=binding.revision
        if e.action=='map'then
            if not ui.view or not ui.view.region or ui.view.region.localMapState~='present'then return end
            local c=a.context();if not c or c.key~=ui.contextKey then return end
            local p=obj('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(c.pc)
            local dragged=ui.dragMap and ui.dragMap(p.X,p.Y)
            ui.mapDrag=nil
            if dragged then return end
            if ui.syncMap then ui.syncMap()end
            e.action='point';e.point=a.map.pick(ui.mapRect,p.X,p.Y)
            if not e.point then return end
        end
        if #ui.events<16 then ui.events[#ui.events+1]=e end
    end)
    -- Native OnPressed records the exact gesture origin even if a short press
    -- falls between timer ticks. Its no-argument signature matches this target.
    local pressBridge='/Script/UMG.Widget:ForceLayoutPrepass'
    local pressPre,pressPost=RegisterHook(pressBridge,function(context)
        if not ui.mapButton or path(context:get())~=ui.mapButton then return end
        local c=a.context();if not c or c.key~=ui.contextKey or not ui.canvasLayout then return end
        local p=obj('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(c.pc)
        if not Canvas.contains(ui.canvasLayout,p.X,p.Y)then return end
        local x,y=ui.syncMap()
        ui.mapDrag={x=p.X,y=p.Y,scrollX=x,scrollY=y,revision=ui.view.revision}
    end)
    -- A plain native UserWidget has no Blueprint wheel implementation. A
    -- private ScrollBox receives Slate wheel events and delegates its offset
    -- through a matching native float function. Resetting that parameter keeps
    -- this catcher fixed; the queued event zooms our independent map viewport.
    local wheelBridge='/Script/UMG.ScrollBox:SetScrollOffset'
    local wheelPre,wheelPost=RegisterHook(wheelBridge,function(context,offset)
        if not ui.widget or path(context:get())~=ui.wheelScroll then return end
        local delta=(1000-offset:get())/48
        offset:set(1000)
        if delta==0 or not ui.canvasLayout or not ui.descriptor then return end
        local c=a.context();if not c or c.key~=ui.contextKey then return end
        local p=obj('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(c.pc)
        if not Canvas.contains(ui.canvasLayout,p.X,p.Y)then return end
        if delta~=0 and #ui.events<16 then
            ui.events[#ui.events+1]={action='wheel',delta=math.max(-4,math.min(4,delta)),x=p.X,y=p.Y,revision=ui.view.revision}
        end
    end)
    local function unbind()
        if ui.mapButton then
            local b=StaticFindObject(ui.mapButton)
            if b:IsValid()then b.OnPressed:Remove(b,FName('ForceLayoutPrepass'))end
            ui.mapButton=nil
        end
        ui.mapDrag=nil
        if ui.wheelScroll then
            local wheel=StaticFindObject(ui.wheelScroll)
            if wheel:IsValid()then wheel.OnUserScrolled:Remove(wheel,FName('SetScrollOffset'))end
            ui.wheelScroll=nil
        end
        for name in pairs(ui.bindings)do
            local b=StaticFindObject(name)
            if b:IsValid()then b.OnClicked:Remove(b,FName('InvalidateLayoutAndVolatility'))end
        end
        ui.bindings={};ui.events={}
    end
    local function create(kind,name)
        ui.serial=ui.serial+1
        return StaticConstructObject(obj('/Script/UMG.'..kind),obj(ui.widget).WidgetTree,FName(name..'_'..ui.serial))
    end
    local function place(root,w,x,y,width,height,z)
        local s=root:AddChildToCanvas(w);s:SetPosition({X=x,Y=y});s:SetSize({X=width,Y=height});s:SetZOrder(z or 0);return s
    end
    local function text(label,size,color)
        ui.serial=ui.serial+1
        local t=create('TextBlock','MapTeleportText'..ui.serial)
        t:SetText(FText(label));t:SetColorAndOpacity({SpecifiedColor=color or white,ColorUseRule=0})
        t:SetFont({FontObject=obj('/Game/Dune/Fonts/Raleway-Regular_Font.Raleway-Regular_Font'),Size=size,TypefaceFontName=FName('Regular')})
        t:SetVisibility(4);return t
    end
    local function panel(root,x,y,w,h,color,z)
        ui.serial=ui.serial+1
        local p=create('Border','MapTeleportPanel'..ui.serial);p:SetBrushColor(color);place(root,p,x,y,w,h,z);return p
    end
    local function markerIcon(row)
        local pc=a.context().pc
        local sys=obj('/Script/Engine.Default__KismetSystemLibrary')
        local class=sys:LoadClassAsset_Blocking(sys:Conv_SoftClassPathToSoftClassRef(sys:MakeSoftClassPath('/Game/Dune/GUI/Widgets/Components/Item/W_DuneIconPreset.W_DuneIconPreset_C')))
        assert(class:IsValid(),'Native marker icon widget unavailable')
        local w=obj('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc,class,pc)
        w:SetPresetSettings({Name=FName(row.preset)})
        if row.icon~=''then w:SetIcon(sys:Conv_SoftObjPathToSoftObjRef(sys:MakeSoftObjectPath(row.icon)))end
        if row.iconTint then w.m_Icon:SetBrushTintColor({SpecifiedColor=nativeColor(row.iconTint),ColorUseRule=0})end
        if row.backgroundTint then w.m_Background:SetBrushTintColor({SpecifiedColor=nativeColor(row.backgroundTint),ColorUseRule=0})end
        if row.tint then w:SetColorAndOpacity(nativeColor(row.tint))end
        w:SetVisibility(3);return w
    end
    function ui.refreshMarkers()
        if not ui.markerClip or not ui.descriptor or not ui.descriptor.map then return end
        local ok,snapshot=pcall(a.map.markers)
        if not ok or not snapshot then
            ui.markerSnapshot={mapId=ui.descriptor.map.id,layerId='surface',rows={},status='unavailable'}
            if not ok and ui.markerError~=tostring(snapshot)then print('[MapTeleport] markers: '..tostring(snapshot)..'\n');ui.markerError=tostring(snapshot)end
        else ui.markerSnapshot=snapshot;ui.markerError=nil end
    end
    function ui.layoutMarkers()
        local snapshot=ui.markerSnapshot;local l=ui.canvasLayout
        if not snapshot or not l or not ui.markerClip then return end
        local layout=MarkerModel.layout(snapshot,ui.descriptor.map,ui.mapRect,{x=l.frame.x,y=l.frame.y,width=l.width,height=l.height},30)
        ui.markerLayout=layout;local wanted={};ui.markerEntries=ui.markerEntries or{}
        for _,entry in ipairs(layout)do
            local r=entry.marker;local key=r.id..'|'..r.icon..'|'..r.preset
            for _,color in ipairs({r.iconTint or{},r.backgroundTint or{},r.tint or{}})do
                for _,channel in ipairs({'R','G','B','A'})do key=key..'|'..tostring(color[channel]or'')end
            end
            wanted[key]=true
            local widget=ui.markerEntries[key]
            if not widget then
                local icon=markerIcon(r);local slot=place(obj(ui.markerClip),icon,0,0,30,30,10+r.priority)
                widget={path=path(icon),slot=slot};ui.markerEntries[key]=widget
            end
            -- Native async icon loading may restore its default preset colours.
            -- Reapply the resolved native presentation on each data refresh.
            if widget.styleTime~=ui.markerTime then
                local icon=obj(widget.path)
                if r.iconTint then icon.m_Icon:SetBrushTintColor({SpecifiedColor=nativeColor(r.iconTint),ColorUseRule=0})end
                if r.backgroundTint then icon.m_Background:SetBrushTintColor({SpecifiedColor=nativeColor(r.backgroundTint),ColorUseRule=0})end
                if r.tint then icon:SetColorAndOpacity(nativeColor(r.tint))end
                widget.styleTime=ui.markerTime
            end
            widget.slot:SetPosition({X=entry.x-l.frame.x-15,Y=entry.y-l.frame.y-15+1000})
            if r.category=='player'then obj(widget.path):SetRenderTransformAngle(r.rotation*180/math.pi)end
        end
        for key,w in pairs(ui.markerEntries)do if not wanted[key]then obj(w.path):RemoveFromParent();ui.markerEntries[key]=nil end end
        if ui.markerLegend then
            local label='Места · Базы · Задания · Личные метки · Игрок'
            if snapshot.status=='remote-unavailable'then label=label..'\nОбозначения региона не загружены игрой'
            elseif snapshot.status=='partial'then label=label..'\nЧасть обозначений не предоставлена игрой'
            elseif snapshot.status~='available'then label=label..'\nОбозначения временно недоступны'end
            obj(ui.markerLegend):SetText(FText(label))
        end
        if ui.markerTooltip then
            local c=a.context();local p=obj('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(c.pc)
            local hovered=Canvas.contains(l,p.X,p.Y)and MarkerModel.hover(layout,p.X,p.Y)
            obj(ui.markerTooltip):SetVisibility(hovered and 4 or 1)
            if hovered then obj(ui.markerTooltipText):SetText(FText(hovered.label))end
        end
    end
    local function button(root,label,x,y,w,h,event,enabled,selected)
        ui.serial=ui.serial+1
        local b=create('Button','MapTeleportButton'..ui.serial)
        local style=b.WidgetStyle
        style.Normal.TintColor.SpecifiedColor=selected and{r=.2,G=.09,B=.26,A=1}or{r=.06,G=.045,B=.085,A=1}
        style.Hovered.TintColor.SpecifiedColor={r=.32,G=.2,B=.12,A=1}
        style.Pressed.TintColor.SpecifiedColor={r=.38,G=.19,B=.4,A=1}
        -- Configure before the Slate control is built. Passing WidgetStyle's
        -- own property wrapper back into SetStyle aliases nested native data
        -- on UE4SS 1140 and can terminate the process during parameter cleanup.
        b:SetIsEnabled(enabled~=false)
        b.IsFocusable=event.action~='map'
        local caption=text(label,17,gold);caption:SetJustification(1);b:AddChild(caption)
        caption:SetAutoWrapText(true)
        place(root,b,x,y,w,h,3)
        ui.buttons[#ui.buttons+1]={path=path(b),event=event,enabled=enabled~=false}
        ui.bindings[path(b)]={event=event,revision=ui.view.revision}
        if event.action~='map'and enabled~=false then
            local f=ui.focusEvent
            if f and f.action==event.action and f.id==event.id then ui.focusTarget=path(b);ui.focusMatched=true
            elseif not ui.focusMatched and(not ui.focusTarget or selected)then ui.focusTarget=path(b)end
        end
        b.OnClicked:Add(b,FName('InvalidateLayoutAndVolatility'))
        return b
    end
    local function controller()
        local c=a.context();assert(c and c.key==ui.contextKey,'UI player changed');return c.pc,c
    end
    function ui.close()
        local errors={}
        local function attempt(f)
            local ok,why=pcall(f);if not ok then errors[#errors+1]=tostring(why)end
        end
        attempt(unbind)
        if ui.widget then
            attempt(function()
                local w=StaticFindObject(ui.widget)
                if w:IsValid()then w:RemoveFromParent();assert(not w:IsInViewport(),'Window removal rejected')end
            end)
            local c
            attempt(function()c=a.context()end)
            attempt(function()
                if c and c.key==ui.contextKey then c.pc:SetShowDuneMouseCursor(ui.oldCursor)end
            end)
            attempt(function()if ui.inputOwner then a.releaseInput(c and c.key==ui.contextKey and c or nil,ui.inputOwner);ui.inputOwner=nil end end)
            attempt(function()
                if c and c.key==ui.contextKey then
                    local lib=obj('/Script/UMG.Default__WidgetBlueprintLibrary')
                    local previous=ui.previousWindow and StaticFindObject(ui.previousWindow)
                    if previous and previous:IsValid()then lib:SetInputMode_GameAndUIEx(c.pc,previous,0,false,false)
                    elseif ui.oldCursor then lib:SetInputMode_GameAndUIEx(c.pc,nil,0,false,false)
                    else lib:SetInputMode_GameOnly(c.pc,false)end
                end
            end)
        end
        attempt(a.map.close)
        if #errors>0 then ui.failed=true;error(table.concat(errors,'; '))end
        ui.widget=nil;ui.buttons={};ui.view=nil;ui.inputOwner=nil;ui.contextKey=nil;ui.previousWindow=nil;ui.scroll=nil
        ui.canvasLayout=nil;ui.canvasMapId=nil;ui.mapBars=nil;ui.mapExtents=nil;ui.mapSlot=nil;ui.crossSlots=nil;ui.scrollPending=nil;ui.focusTarget=nil;ui.focusEvent=nil
        ui.markerClip=nil;ui.markerEntries=nil;ui.markerSnapshot=nil;ui.markerLayout=nil;ui.markerLegend=nil;ui.markerTooltip=nil;ui.markerTooltipText=nil;ui.markerTime=nil
    end
    function ui.syncMap()
        local l=ui.canvasLayout;if not l or not ui.mapBars then return end
        local x=obj(ui.mapBars.x):GetScrollOffset();local y=obj(ui.mapBars.y):GetScrollOffset()
        local r=Canvas.rect(l,x,y);ui.mapRect=r
        a.map.viewport({x=l.frame.x,y=l.frame.y,width=l.width,height=l.height},r)
        if ui.crossSlots and ui.view.point then
            local px,py=a.map.screen(ui.view.point,r)
            if px then for _,s in ipairs(ui.crossSlots)do s.slot:SetPosition({X=px-l.frame.x+s.x,Y=py-l.frame.y+s.y+1000})end end
        end
        ui.layoutMarkers()
        return x,y
    end
    function ui.applyCanvas(l)
        -- Zoom changes the capture and native scroll extents in place. Rebuilding
        -- the widget here drops queued wheel events and resets Slate scroll state.
        ui.canvasLayout=l
        local horizontal,vertical=obj(ui.mapExtents.x),obj(ui.mapExtents.y)
        horizontal:SetWidthOverride(l.contentWidth);vertical:SetHeightOverride(l.contentHeight)
        obj(ui.mapBars.x):SetScrollBarVisibility(l.maxX>0 and 0 or 1)
        obj(ui.mapBars.y):SetScrollBarVisibility(l.maxY>0 and 0 or 1)
        obj(ui.widget):ForceLayoutPrepass()
        obj(ui.mapBars.x):SetScrollOffset(l.x);obj(ui.mapBars.y):SetScrollOffset(l.y)
        ui.syncMap()
    end
    function ui.dragMap(x,y)
        local start=ui.mapDrag
        if not start or start.revision~=ui.view.revision then ui.mapDrag=nil;return false end
        local pan=Canvas.drag(ui.canvasLayout,start,x,y)
        if not pan then return false end
        start.moved=true
        obj(ui.mapBars.x):SetScrollOffset(pan.x);obj(ui.mapBars.y):SetScrollOffset(pan.y)
        ui.syncMap()
        return true
    end
    function ui.navigate(direction)
        if not ui.widget then return false end
        local pc=controller();local controls={};local current
        for _,b in ipairs(ui.buttons)do
            if b.enabled and b.event.action~='map'then
                controls[#controls+1]=b
                if obj(b.path):HasKeyboardFocus()then current=#controls end
            end
        end
        if #controls==0 then return false end
        local index=current and((current-1+(direction=='previous'and-1 or 1))%#controls+1)or 1
        local b=controls[index];local focus=obj(b.path)
        focus:SetUserFocus(pc);focus:SetKeyboardFocus();ui.focusTarget=b.path;ui.focusEvent=b.event
        if b.event.action=='select'and ui.scroll then obj(ui.scroll):ScrollWidgetIntoView(focus,false,0,8)end
        return true
    end
    function ui.present(view)
        local c=a.context();assert(c,'Local player unavailable')
        if not ui.widget then
            ui.contextKey=c.key;ui.oldCursor=c.pc:IsDuneMouseCursorVisible()
            local previous=c.pc:GetHUD():GetActiveWindow()
            ui.previousWindow=previous:IsValid()and path(previous)or nil
            local w=obj('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(c.pc,obj('/Script/UMG.UserWidget'),c.pc)
            ui.widget=path(w);ui.inputOwner=a.acquireInput(c)
            c.pc:SetShowDuneMouseCursor(true)
        end
        local pc=controller();local w=obj(ui.widget)
        for _,b in ipairs(ui.buttons)do
            local previous=StaticFindObject(b.path)
            if previous:IsValid()and previous:HasKeyboardFocus()then ui.focusEvent=b.event;break end
        end
        ui.focusTarget=nil;ui.focusMatched=false
        local zoom,u,v
        if ui.canvasLayout then
            local x,y=ui.syncMap();zoom=ui.canvasLayout.zoom;u,v=Canvas.center(ui.canvasLayout,x,y)
        end
        local scrollOffset=0
        if ui.scroll then
            local previousScroll=StaticFindObject(ui.scroll)
            if previousScroll:IsValid()then scrollOffset=previousScroll:GetScrollOffset()end
        end
        ui.scroll=nil
        unbind()
        if w:IsInViewport()then w:RemoveFromParent()end
        local old=w.WidgetTree.RootWidget
        if old:IsValid()then old:RemoveFromParent()end
        local root=create('CanvasPanel','MapTeleportCanvas'..view.revision);w.WidgetTree.RootWidget=root
        ui.markerClip=nil;ui.markerEntries={};ui.markerSnapshot=nil;ui.markerTooltip=nil;ui.markerLegend=nil
        local layout=obj('/Script/UMG.Default__WidgetLayoutLibrary')
        local physical=layout:GetViewportSize(pc);local dpi=layout:GetViewportScale(pc)
        assert(physical.X>0 and physical.Y>0 and dpi>0,'Viewport is not ready')
        local width,height=physical.X/dpi,physical.Y/dpi
        ui.view=view;ui.buttons={};ui.width=width;ui.height=height
        panel(root,0,0,width,height,background)
        panel(root,0,0,width,90,{r=.012,G=.012,B=.02,A=1})
        panel(root,0,89,width,1,gold)
        place(root,text('ТЕЛЕПОРТАЦИЯ',30,gold),40,25,width-80,44,2)
        local region=view.region
        local title=region and region.name or'ВЫБОР РЕГИОНА'
        place(root,text(title,24,gold),40,112,width-80,40,2)
        local left=view.state=='SelectRegion'and math.min(430,width*.27)or 40
        local frame=Canvas.frame(width,height,left)
        local mapX,mapY,mapSize=frame.x,frame.y,frame.height
        ui.mapRect=frame
        ui.mapBars=nil;ui.mapExtents=nil;ui.mapSlot=nil;ui.crossSlots=nil
        if view.state=='SelectRegion'then
            local scroll=create('ScrollBox','MapTeleportRegions'..view.revision)
            ui.scroll=path(scroll)
            place(root,scroll,40,165,left-60,height-285,2)
            for _,r in ipairs(view.regions)do
                local row=create('CanvasPanel','MapTeleportRegion'..r.id)
                local size=create('SizeBox','MapTeleportRegionSize'..r.id);size:SetHeightOverride(96);size:AddChild(row);scroll:AddChild(size)
                button(row,r.name..(r.current and' •'or''),0,0,left-80,90,{action='select',id=r.id},true,region and region.id==r.id)
            end
            scroll:SetScrollOffset(scrollOffset)
        end
        local descriptor,reason=a.map.show(view,ui.mapRect)
        ui.descriptor=descriptor
        if descriptor then
            -- Scroll geometry supplies both picking and the camera's visible
            -- region, so zoom reveals detail without a huge render target.
            if a.map.zoomValue~=1 then a.map.zoom(1/a.map.zoomValue)end
            if a.map.panU~=0 or a.map.panV~=0 then a.map.pan(-a.map.panU,-a.map.panV)end
            local mapId=region and region.id or'overview'
            if ui.canvasMapId~=mapId then
                zoom=descriptor.profile and 1 or .001;u,v=.5,.5
                if view.point then local p=a.map.map;u=(view.point.X-p.originX)/p.ux;v=(view.point.Y-p.originY)/p.vy end
                if descriptor.initialView then zoom=descriptor.initialView.zoom;u,v=descriptor.initialView.u,descriptor.initialView.v end
            end
            local l=Canvas.layout(frame,zoom,u,v);ui.canvasLayout=l;ui.canvasMapId=mapId
            local wheel=create('ScrollBox','MapTeleportMapWheel'..view.revision)
            wheel:SetOrientation(1);wheel:SetConsumeMouseWheel(1);wheel:SetAllowOverscroll(false);wheel:SetScrollBarVisibility(1);wheel:SetClipping(1)
            place(root,wheel,frame.x,frame.y,l.width,l.height,2)
            local extent=create('SizeBox','MapTeleportWheelExtent'..view.revision)
            extent:SetWidthOverride(l.width);extent:SetHeightOverride(l.height+2000)
            local clip=create('CanvasPanel','MapTeleportMapViewport'..view.revision)
            ui.markerClip=path(clip)
            extent:AddChild(clip);wheel:AddChild(extent)
            ui.wheelScroll=path(wheel);wheel.OnUserScrolled:Add(wheel,FName('SetScrollOffset'))
            ui.mapExtents={}
            local function scrollbar(axis,horizontal)
                local bar=create('ScrollBox','MapTeleportMapScroll'..axis..view.revision)
                bar:SetOrientation(horizontal and 0 or 1);bar:SetConsumeMouseWheel(0);bar:SetAllowOverscroll(false)
                bar.ScrollbarThickness={X=14,Y=14};bar.ScrollbarPadding={Left=0,Top=0,Right=0,Bottom=0}
                bar:SetScrollBarVisibility((horizontal and l.maxX or l.maxY)>0 and 0 or 1)
                local filler=create('SizeBox','MapTeleportScrollExtent'..axis..view.revision)
                ui.mapExtents[horizontal and 'x' or 'y']=path(filler)
                filler:SetWidthOverride(horizontal and l.contentWidth or 1);filler:SetHeightOverride(horizontal and 1 or l.contentHeight)
                bar:AddChild(filler)
                place(root,bar,frame.x+(horizontal and 0 or l.width),frame.y+(horizontal and l.height or 0),horizontal and l.width or 16,horizontal and 16 or l.height,3)
                return path(bar)
            end
            ui.mapBars={x=scrollbar('X',true),y=scrollbar('Y',false)};ui.scrollPending={x=l.x,y=l.y}
            ui.mapRect=Canvas.rect(l)
            local image=create('Image','MapTeleportMap'..view.revision)
            -- A render target is UTexture, not UTexture2D. Use the resource API
            -- rather than passing it to SetBrushFromTexture's narrower type.
            image:SetBrushResourceObject(obj(descriptor.texture));image:SetVisibility(4)
            local surface=button(clip,'',0,1000,l.width,l.height,{action='map'},true)
            ui.mapButton=path(surface);surface.OnPressed:Add(surface,FName('ForceLayoutPrepass'))
            ui.mapSlot=surface.Slot
            surface:ClearChildren()
            local slot=surface:AddChild(image)
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            if view.point then
                local x,y=a.map.screen(view.point,ui.mapRect)
                if x then
                    ui.crossSlots={}
                    for _,d in ipairs({{-13,-3,26,6,{r=0,G=0,B=0,A=1}},{-3,-13,6,26,{r=0,G=0,B=0,A=1}},{-10,-1,20,2,gold},{-1,-10,2,20,gold}})do
                        local line=panel(clip,x-frame.x+d[1],y-frame.y+d[2]+1000,d[3],d[4],d[5],200);line:SetVisibility(4)
                        ui.crossSlots[#ui.crossSlots+1]={slot=line.Slot,x=d[1],y=d[2]}
                    end
                end
            end
            if descriptor.map then
                local legend=text('',14,gold);place(root,legend,frame.x,119,math.max(100,frame.width-280),36,4);ui.markerLegend=path(legend)
                local tooltip=panel(root,frame.x+12,frame.y+12,430,40,{R=.015,G=.012,B=.02,A=.95},8)
                local caption=text('',16,gold);tooltip:AddChild(caption);tooltip:SetVisibility(1)
                ui.markerTooltip=path(tooltip);ui.markerTooltipText=path(caption)
                ui.refreshMarkers();ui.layoutMarkers();ui.markerTime=os.time()
            end
        else ui.canvasLayout=nil;place(root,text(reason or'Карта загружается…',20,white),mapX,mapY+mapSize/2,frame.width,60,2)end
        local bottom=height-88
        panel(root,0,height-110,width,1,gold)
        local hasMap=region and region.localMapState=='present'
        local enabled=Window.canTeleport(view,descriptor)
        button(root,'Телепортироваться',width/2-320,bottom,390,54,{action='teleport'},enabled==true)
        button(root,'Отменить',width/2+90,bottom,230,54,{action='cancel'})
        if hasMap and descriptor then
            button(root,'−',width-252,110,44,38,{action='zoom-out'})
            button(root,'+',width-200,110,44,38,{action='zoom-in'})
            button(root,'Вписать',width-148,110,108,38,{action='fit'})
            place(root,text(enabled and'Клик — точка, зажать ЛКМ — двигать карту, колесо — масштаб.'or'Выберите допустимую точку на карте',16,white),mapX,frame.y+frame.height+8,frame.width,30,2)
        elseif region then
            local hint=region.localMapState=='absent'and(region.current and'Вы уже в этом регионе. Местной карты нет.'or'Прибытие в штатное место региона')or'Местная карта недоступна'
            place(root,text(hint,18,white),mapX,frame.y+frame.height+8,frame.width,40,2)
        end
        w:AddToViewport(1000)
        w.bIsFocusable=true
        local navigation,regions={},{}
        for _,b in ipairs(ui.buttons)do if b.enabled and b.event.action~='map'then
            navigation[#navigation+1]=b.path
            if b.event.action=='select'then regions[#regions+1]=b.path end
        end end
        -- EUINavigation values read from this build: Up=2, Down=3,
        -- Next=4, Previous=5. Keep navigation inside our own controls.
        for i,name in ipairs(navigation)do
            obj(name):SetNavigationRuleExplicit(4,obj(navigation[i%#navigation+1]))
            obj(name):SetNavigationRuleExplicit(5,obj(navigation[(i-2)%#navigation+1]))
        end
        for i,name in ipairs(regions)do
            obj(name):SetNavigationRuleExplicit(2,obj(regions[(i-2)%#regions+1]))
            obj(name):SetNavigationRuleExplicit(3,obj(regions[i%#regions+1]))
        end
        obj('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_UIOnlyEx(pc,ui.focusTarget and obj(ui.focusTarget)or w,0,false)
        ui.focusPending=true
        return true
    end
    function ui.poll()
        if not ui.widget then return end
        local pc=controller()
        if ui.focusPending then
            local focus=ui.focusTarget and obj(ui.focusTarget)or obj(ui.widget)
            obj('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_UIOnlyEx(pc,focus,0,false)
            focus:SetUserFocus(pc)
            focus:SetKeyboardFocus()
            ui.focusPending=false
        end
        if ui.scrollPending and ui.mapBars then
            obj(ui.mapBars.x):SetScrollOffset(ui.scrollPending.x);obj(ui.mapBars.y):SetScrollOffset(ui.scrollPending.y);ui.scrollPending=nil
            obj(ui.wheelScroll):SetScrollOffset(1000)
        end
        ui.syncMap()
        if ui.markerTime~=os.time()then ui.markerTime=os.time();ui.refreshMarkers();ui.layoutMarkers()end
        if ui.mapDrag then
            if obj(ui.mapButton):IsPressed()then
                local p=obj('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(pc)
                ui.dragMap(p.X,p.Y)
            else ui.mapDrag=nil end
        end
        local layout=obj('/Script/UMG.Default__WidgetLayoutLibrary')
        local viewport=layout:GetViewportSize(pc);local dpi=layout:GetViewportScale(pc)
        if viewport.X<=0 or viewport.Y<=0 or dpi<=0 then return end
        if math.abs(viewport.X/dpi-ui.width)>.5 or math.abs(viewport.Y/dpi-ui.height)>.5 then ui.present(ui.view);return end
        local escape=pc:IsInputKeyDown({KeyName=FName('Escape')})
        if escape and not ui.escape then ui.escape=escape;return {action='cancel',revision=ui.view.revision}end
        ui.escape=escape
        local e=table.remove(ui.events,1)
        if e and e.revision==ui.view.revision then
            if e.action=='zoom-in'or e.action=='zoom-out'or e.action=='wheel'or e.action=='fit'then
                if ui.canvasLayout then
                    ui.mapDrag=nil
                    local x,y=ui.syncMap();local l=ui.canvasLayout
                    local factor=e.action=='wheel'and 1.25^e.delta or(e.action=='zoom-in'and 1.25 or .8)
                    if e.action=='fit'then factor=l.minZoom/l.zoom end
                    local next=Canvas.zoom(l,x,y,factor,e.x,e.y)
                    ui.applyCanvas(next)
                end
                return
            end
            return e
        end
    end
    function ui.shutdown()
        ui.close();UnregisterHook(bridge,pre,post);UnregisterHook(wheelBridge,wheelPre,wheelPost);UnregisterHook(pressBridge,pressPre,pressPost)
    end
    return ui
end
return Window

