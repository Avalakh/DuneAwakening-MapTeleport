-- Read-only snapshot of native map/travel data. All retained values are plain
-- Lua values; every engine reference is resolved afresh for each snapshot.
local Catalog={}
local function lib(name)
    local o=StaticFindObject('/Script/'..name);assert(o:IsValid(),'Unavailable '..name);return o
end
local function value(v)return v.get and v:get()or v end
local function column(lib,dt,name)
    local result={}
    for i,v in ipairs(lib:GetDataTableColumnAsString(dt,FName(name)))do result[i]=value(v):ToString()end
    return result
end
local function display(serialized,id)
    local tableId,key=serialized:match('^LOCTABLE%("([^"]+)",%s*"([^"]+)"%)$')
    if tableId then
        local t=lib('Engine.Default__KismetTextLibrary'):TextFromStringTable(FName(tableId),key)
        local text=t:ToString();if text~=''and not text:find('MISSING STRING TABLE ENTRY',1,true)then return text end
    end
    local fallback={ClosedOffTestingStationIsland='Испытательная станция на острове'}
    return fallback[id]or id
end
-- Prefer the normal taxi route over quest-room exits. Choosing a return exit
-- by alphabetical order can select a different set of native requirements.
function Catalog.chooseRoute(routes)
    local ordered={};for _,name in ipairs(routes)do ordered[#ordered+1]=name end
    local function rank(n)
        if n:match('^Travel_To_')then return 1 end
        if n:match('^Overland_to_')then return 2 end
        return 3
    end
    table.sort(ordered,function(a,b)
        local x,y=rank(a),rank(b)
        if x~=y then return x<y end
        if #a~=#b then return #a<#b end
        return a<b
    end)
    return ordered[1]
end
-- Pure filter is also used by offline tests. Unknown access never passes.
function Catalog.filter(rows)
    local seen,result={},{}
    for _,r in ipairs(rows)do
        if type(r.id)=='string'and not seen[r.id]and not r.technical and not r.overview
            and r.progressAllowed==true and(r.current or r.routeAllowed==true)then
            seen[r.id]=true;result[#result+1]=r
        end
    end
    table.sort(result,function(a,b)
        if a.current~=b.current then return a.current==true end
        return a.name==b.name and a.id<b.id or a.name<b.name
    end)
    return result
end
function Catalog.snapshot(c)
    assert(c and c.pc and c.pawn,'Player context unavailable')
    local maps=lib('DuneSandbox.Default__DuneMapUtilities')
    local sys=lib('Engine.Default__KismetSystemLibrary')
    local tags=lib('GameplayTags.Default__BlueprintGameplayTagLibrary')
    local journey=lib('DuneSandbox.Default__JourneyUtils')
    local tables=lib('Engine.Default__DataTableFunctionLibrary')
    local dt=StaticFindObject('/Game/Dune/Maps/CDT_MapsInfo.CDT_MapsInfo');assert(dt:IsValid(),'Map table unavailable')
    local current=maps:GetDuneMapIdFromWorld(c.pc).Name:ToString()
    local rows={};tables:GetDataTableRowNames(dt,rows)
    local paths,names=column(tables,dt,'m_Map'),column(tables,dt,'m_DisplayName')
    local settings=FindFirstOf('CartographyMapSettings');assert(settings:IsValid(),'Cartography settings unavailable')
    local mnemonic=c.pc.PlayerState:GetMnemonicRecallActorComponent()
    assert(mnemonic:IsValid()and mnemonic:GetIsJourneyStateInitialized(),'Journey not initialized')
    local perMap={}
    settings.m_PerMapSettings:ForEach(function(k,v)
        local id=k:get().Name:ToString();local d=v:get();local required=d.m_MapRevealConditions
        local layer=d.m_MapLayerSettings
        local actor=sys:Conv_SoftClassReferenceToString(layer.m_MapLayerActor):ToString()
        local prerequisite=required.RequiredJourneyNodeName:ToString()
        local allowed=true
        if prerequisite~=''then
            local node=journey:GetJourneyNodeByName(c.pc,prerequisite)
            if node:IsValid()then
                local count=node:GetCompletionCount(mnemonic)
                allowed=count.TotalCount>0 and count.CompletedCount>=count.TotalCount
            else allowed=false end
        end
        allowed=allowed and(tags:IsTagQueryEmpty(required.RequiredPlayerFlagsQuery)
            or tags:DoesContainerMatchTagQuery(c.pawn.m_PlayerFlags,required.RequiredPlayerFlagsQuery))
        local localMapState='unknown'
        if actor~=''then localMapState=actor:find('/Arrakis/BP_MapLayer_Global',1,true)and'absent'or'present'end
        perMap[id]={progressAllowed=allowed,prerequisite=prerequisite,layerActor=actor,localMapState=localMapState,
            layerScale=layer.m_MapLayerScale,layerPosition={X=layer.m_MapLayerPosition.X,Y=layer.m_MapLayerPosition.Y,Z=layer.m_MapLayerPosition.Z}}
    end)
    local routes,arrivals={},{};local seen,targets={},{};local api=lib('DuneSandbox.Default__DuneTravelApi')
    local cache=FindFirstOf('DuneGlobalDataCacheSubsystem');assert(cache:IsValid(),'Travel cache unavailable')
    cache:GetCache().Data.PerMapData:ForEach(function(mapRef,r)
        local worldPath=sys:Conv_SoftObjectReferenceToString(mapRef:get()):ToString()
        r:get().Global.TravelDestinations.content:ForEach(function(_,v)
            local name=v:get().Name:ToString()
            -- Third-party injected taxi destinations are not our integration.
            if not name:match('^NBS_')then
                if not seen[name]then
                    seen[name]=true;local target={}
                    if api:CanTravelToDestination(c.pawn,FName(name),target)and target.Name then
                        local id=target.Name:ToString();targets[name]=id
                        routes[id]=routes[id]or{};routes[id][#routes[id]+1]=name
                    end
                end
                local id=targets[name]
                if id then
                    local p=v:get().Transform.Translation
                    if type(p.X)=='number'and type(p.Y)=='number'and p.X==p.X and p.Y==p.Y and math.abs(p.X)<math.huge and math.abs(p.Y)<math.huge then
                        arrivals[name]=arrivals[name]or{}
                        arrivals[name][worldPath]={mapId=id,layerId='surface',X=p.X,Y=p.Y}
                    end
                end
            end
        end)
    end)
    local raw={}
    for i,ref in ipairs(rows)do
        local id=value(ref):ToString();local d=perMap[id]
        local row={id=id,mapId=id,worldPath=paths[i],name=display(names[i]or'',id),current=id==current,
            technical=id=='MainMenu'or id:match('^CombatGym')~=nil,overview=id=='Overland',
            progressAllowed=d and d.progressAllowed==true or false,
            routeAllowed=routes[id]~=nil,routes=routes[id]or{},localMapState=d and d.localMapState or'unknown',
            layerActor=d and d.layerActor,prerequisite=d and d.prerequisite,
            layerScale=d and d.layerScale,layerPosition=d and d.layerPosition}
        table.sort(row.routes);row.destinationName=Catalog.chooseRoute(row.routes)
        local points=arrivals[row.destinationName]
        row.defaultPoint=points and points[row.worldPath];raw[#raw+1]=row
    end
    return Catalog.filter(raw),raw
end
return Catalog
