-- Profiles use native projection metadata; physical collision bounds are
-- resolved separately from the destination world's loaded geometry.
-- A local map without an unambiguous profile cannot supply a movement target.
local Profiles={}
local registered={}
function Profiles.register(profile)registered[profile.mapId]=profile end
function Profiles.get(mapId,worldPath)
    local p=registered[mapId]
    if p and p.worldPath==worldPath then return p end
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function Profiles.new(row,bounds,height)
    if not row or not bounds or not height then return nil,'profile-unavailable'end
    local b={minX=bounds.minX,minY=bounds.minY,maxX=bounds.maxX,maxY=bounds.maxY}
    for _,k in ipairs({'minX','minY','maxX','maxY'})do if not finite(b[k])then return nil,'invalid-bounds'end end
    if not(b.minX<b.maxX and b.minY<b.maxY)or not finite(height.min)or not finite(height.max)or height.min>=height.max then return nil,'invalid-profile'end
    local kind
    if row.id=='HaggaBasin'then kind='hagga-streamed'
    elseif row.id=='DeepDesert'then kind='desert-streamed'
    elseif row.id=='Arrakeen'or row.id=='HarkoVillage'then kind='compact'
    else return nil,'profile-unqualified'end
    return {id=row.id,mapId=row.mapId,worldPath=row.worldPath,layerId='surface',kind=kind,bounds=b,
        top=height.max+500,bottom=height.min-500}
end
function Profiles.validate(profile,point)
    if not profile or not point or point.mapId~=profile.mapId or point.layerId~=profile.layerId then return false,'wrong-map-or-layer'end
    if not finite(point.X)or not finite(point.Y)then return false,'invalid-coordinate'end
    local b=profile.bounds
    if point.X<b.minX or point.X>b.maxX or point.Y<b.minY or point.Y>b.maxY then return false,'outside-map'end
    return true
end
-- Map artwork height is a projection range, not a physical collision range.
-- Compact hubs can have walkable floors above that range (Harko is one).
-- Resolve collision bounds only after arrival, from this world's LevelBounds;
-- never load destination levels or retain their UObject references for this.
function Profiles.activate(profile,c)
    if not profile or not c or profile.worldPath~=c.worldPath then return nil,'wrong-world'end
    if profile.kind~='compact'then return profile end
    if profile.collisionWorldKey==c.key then return profile end
    local stats=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local class=StaticFindObject('/Script/Engine.LevelBounds')
    local actors={};stats:GetAllActorsOfClass(c.pc,class,actors)
    local low,high
    for _,r in ipairs(actors)do
        local actor=r.get and r:get()or r
        if actor:IsValid()and not actor:IsActorBeingDestroyed()then
            local origin,extent={},{};actor:GetActorBounds(false,origin,extent,false)
            if finite(origin.Z)and finite(extent.Z)and extent.Z>0 then
                low=math.min(low or math.huge,origin.Z-extent.Z)
                high=math.max(high or -math.huge,origin.Z+extent.Z)
            end
        end
    end
    if not low or not high or high<=low then return nil,'collision-bounds-unavailable'end
    local copy={};for k,v in pairs(profile)do copy[k]=v end
    copy.top=high+500;copy.bottom=low-500;copy.collisionWorldKey=c.key
    -- A hub's uppermost blocking surface can be an invisible ceiling volume
    -- inside the artwork. Use the game's authored recovery locations to select
    -- the playable elevation, rather than treating every roof as a floor.
    local settings={};stats:GetAllActorsOfClass(c.pc,StaticFindObject('/Script/DuneSandbox.DuneWorldSettings'),settings)
    copy.floorAnchors={}
    for _,r in ipairs(settings)do
        local actor=r.get and r:get()or r
        if actor:IsValid()then actor.m_UnstuckLocations:ForEach(function(_,ref)
            local p=ref:get().Translation
            if finite(p.X)and finite(p.Y)and finite(p.Z)then
                copy.floorAnchors[#copy.floorAnchors+1]={X=p.X,Y=p.Y,Z=p.Z}
            end
        end)end
    end
    if #copy.floorAnchors==0 then return nil,'playable-height-unavailable'end
    Profiles.register(copy)
    return copy
end
function Profiles.traceTop(profile,point,halfHeight)
    if not profile or profile.kind~='compact'then return profile and profile.top or 1000000 end
    local nearest,distance
    for _,p in ipairs(profile.floorAnchors or{})do
        local d=(p.X-point.X)^2+(p.Y-point.Y)^2
        if not distance or d<distance then nearest=p;distance=d end
    end
    if not nearest then return nil,'playable-height-unavailable'end
    return math.min(profile.top,nearest.Z+halfHeight+50)
end
local assetPaths
function Profiles.metadata(row)
    local sys=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
    if not assetPaths then
        local registry=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAssetRegistry()
        local out={};assert(registry:GetAssetsByClass({PackageName=FName('/Script/DuneSandbox'),AssetName=FName('FullscreenMapDataAsset')},out,true),'Map metadata unavailable')
        assetPaths={}
        for _,r in ipairs(out)do local d=r.get and r:get()or r;assetPaths[#assetPaths+1]=d.PackageName:ToString()..'.'..d.AssetName:ToString()end
    end
    local prefix=row.worldPath:match('^(.*/)[^/]+$');local selected
    for _,name in ipairs(assetPaths)do
        if name:sub(1,#prefix)==prefix then if selected then return nil,'ambiguous-map-metadata'end;selected=name end
    end
    if not selected then return nil,'map-height-unavailable'end
    local soft=sys:Conv_SoftObjPathToSoftObjRef(sys:MakeSoftObjectPath(selected))
    local data=sys:LoadAsset_Blocking(soft);assert(data:IsValid(),'Map metadata failed to load')
    local d=data.m_MapWorldLevelData
    local e,center,h=d.Extents,d.Center,d.Height
    local bounds={minX=e.X+center.X,minY=e.X+center.Y,maxX=e.Y+center.X,maxY=e.Y+center.Y}
    if not(finite(e.X)and finite(e.Y)and finite(center.X)and finite(center.Y)and e.X<e.Y)then return nil,'invalid-world-map-bounds'end
    return {min=h.X,max=h.Y,source=selected,bounds=bounds}
end
Profiles.height=Profiles.metadata
return Profiles
