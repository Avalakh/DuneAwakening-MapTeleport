-- Owns the navigation contract. Engine/UI adapters expose values, never widgets
-- or UObject references in the selection that survives a callback.
local Selection={};Selection.__index=Selection
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function defaultPoint(r)
    local p=r.defaultPoint
    if r.localMapState=='present'and p and p.mapId==r.mapId and p.layerId=='surface'and finite(p.X)and finite(p.Y)then
        return{mapId=p.mapId,layerId=p.layerId,X=p.X,Y=p.Y}
    end
end
local function copy(r)
    return {id=r.id,name=r.name,mapId=r.mapId,worldPath=r.worldPath,
        current=r.current==true,localMapState=r.localMapState,destinationName=r.destinationName,defaultPoint=defaultPoint(r)}
end
function Selection.new(a)
    return setmetatable({a=a,state='Idle',revision=0,sequence=0},Selection)
end
function Selection:message(code,detail)if self.a.message then self.a.message(code,detail)end end
function Selection:close()
    local ok,err=pcall(self.a.close)
    self.regions=nil;self.region=nil;self.point=nil;self.contextKey=nil
    self.revision=self.revision+1;self.state='Idle'
    if not ok then self:message('ui-cleanup-failed',tostring(err));return false end
    return true
end
function Selection:present()
    self.revision=self.revision+1
    local rows={};for i,r in ipairs(self.regions or{})do rows[i]=copy(r)end
    local point=self.point and {X=self.point.X,Y=self.point.Y,mapId=self.point.mapId,layerId=self.point.layerId}
    local view={state=self.state,revision=self.revision,regions=rows,region=self.region and copy(self.region),point=point}
    local ok,result=pcall(self.a.present,view)
    if not ok or result==false then self:close();self:message('ui-error',ok and'presentation-rejected'or tostring(result));return false end
    return true
end
function Selection:open(context)
    if self.state~='Idle'then self:message('busy');return false end
    local allowed,reason=self.a.eligible(context)
    if not allowed then self:message(reason);return false end
    local ok,rows=pcall(self.a.catalog,context)
    if not ok then self:message('catalog-unavailable',tostring(rows));return false end
    self.regions={};self.point=nil;self.region=nil;self.contextKey=context.key
    for _,r in ipairs(rows or{})do
        self.regions[#self.regions+1]=copy(r)
        if r.current then self.region=copy(r);self.point=defaultPoint(r)end
    end
    self.state='SelectRegion';return self:present()
end
function Selection:event(event,context)
    if self.state=='Idle'or self.state=='Executing'then return false end
    if not context or context.key~=self.contextKey then self:close();return false end
    local allowed,reason=self.a.eligible(context)
    if not allowed then self:close();self:message(reason);return false end
    if type(event)~='table'or event.revision~=self.revision then return false end
    if event.action=='cancel'then return self:close()end
    if event.action=='select'and self.state=='SelectRegion'then
        for _,r in ipairs(self.regions)do if r.id==event.id then self.region=copy(r);self.point=defaultPoint(r);return self:present()end end
        return false
    end
    if event.action=='point'and self.state=='SelectRegion'and self.region and self.region.localMapState=='present'then
        local p=event.point
        if not p or p.mapId~=self.region.mapId or not finite(p.X)or not finite(p.Y)then return false end
        local ok,valid,why=pcall(self.a.validatePoint,self.region,p)
        if not ok or not valid then self:message('invalid-point',ok and why or tostring(valid));return false end
        self.point={mapId=p.mapId,layerId=p.layerId,X=p.X,Y=p.Y};return self:present()
    end
    if event.action~='teleport'or not self.region then return false end
    -- Availability is refreshed for every navigation/confirmation step. The
    -- adapter must not interpret an unknown prerequisite as an unlock.
    local refreshed,region,why=pcall(self.a.refreshRegion,context,self.region.id)
    if not refreshed or not region then
        self:message('destination-unavailable',refreshed and why or tostring(region));return false
    end
    if region.mapId~=self.region.mapId or region.worldPath~=self.region.worldPath then
        self.point=nil;self:message('map-changed');return false
    end
    self.region=copy(region)
    if region.localMapState=='present'then
        if not self.point then return false end
        local valid,reason=self.a.validatePoint(self.region,self.point)
        if not valid then self:message('invalid-point',reason);return false end
    elseif region.localMapState=='absent'then
        self.point=nil
        if region.current then self:message('no-local-map');return false end
    else self:message('map-unavailable');return false end
    local destination=copy(self.region)
    if self.point then destination.point={mapId=self.point.mapId,layerId=self.point.layerId,X=self.point.X,Y=self.point.Y}end
    -- Release the UI before starting the operation's independent input owner.
    if not self:close()then return false end
    self.sequence=self.sequence+1;self.state='Executing';self.operationId=self.sequence
    local ok,accepted,reason=pcall(self.a.execute,destination,self.operationId)
    if not ok or not accepted then self.state='Idle';self:message('request-failed',ok and reason or tostring(accepted));return false end
    return true
end
function Selection:completed(operationId)
    if self.state~='Executing'or self.operationId~=operationId then return false end
    self.state='Idle';return true
end
function Selection:update(context)
    if self.state=='Idle'or self.state=='Executing'then return end
    if not context or context.key~=self.contextKey then return self:close()end
    local allowed=self.a.eligible(context);if not allowed then return self:close()end
end
return Selection
