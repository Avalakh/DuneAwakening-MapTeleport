-- One native travel request, followed by an optional local placement. No engine
-- objects survive a tick; adapter.context resolves the current player afresh.
local Travel={};Travel.__index=Travel
local function clone(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r
end
function Travel.new(a)
    return setmetatable({a=a,sequence=0,job=nil,disabled=false},Travel)
end
function Travel:finish(code,detail)
    local j=self.job;if not j then return end
    self.job=nil
    local ok,err=pcall(self.a.release,j)
    if not ok then self.disabled=true;code='cleanup-failed';detail=tostring(err)end
    self.a.completed(j.id,code,detail,j)
end
function Travel:startLocal(c)
    local j=self.job;j.state='Local';j.localOriginKey=c.key
    local ok,accepted,reason=pcall(self.a.startLocal,c,clone(j.destination.point),j.id)
    if not ok or not accepted then
        return self:finish(j.travelled and'partial'or'local-failed',ok and reason or tostring(accepted))
    end
end
function Travel:request(destination,id)
    if self.disabled then return false,'disabled'end
    if self.job then return false,'busy'end
    local c=self.a.context();if not c then return false,'unavailable'end
    local allowed,why=self.a.eligible(c);if not allowed then return false,why end
    local valid,reason=self.a.validate(c,destination);if not valid then return false,reason end
    local now=self.a.now();self.sequence=self.sequence+1
    local j={id=id or self.sequence,destination=clone(destination),sourceKey=c.key,
        sourceMapId=c.mapId,sourceWorld=c.worldPath,started=now,deadline=now+120,
        state='Request',travelled=false}
    self.job=j
    if c.mapId==destination.mapId then
        if not destination.point then self.job=nil;return false,'no-local-map'end
        self:startLocal(c);return true
    end
    -- Set the state before calling the native API: a synchronous rejection hook
    -- may write the failure record while RequestTravelByDestination is running.
    j.state='AwaitDeparture'
    local ok,accepted,err=pcall(self.a.request,c,j.destination,j.id)
    if not ok or not accepted then self:finish('travel-failed',ok and err or tostring(accepted))end
    return true
end
function Travel:tick()
    local j=self.job;if not j then return end
    local now=self.a.now()
    local failure=self.a.failure(j.id)
    if failure then return self:finish('travel-failed',failure)end
    local c=self.a.context()
    if j.state=='Local'then
        if not c or c.key~=j.localOriginKey then return self:finish('cancelled','world-or-character-changed')end
        local code,detail=self.a.localResult(j.id)
        if code then
            if code=='success'then return self:finish('success')end
            if code=='restore-failed'or code=='cleanup-failed'then self.disabled=true end
            return self:finish(j.travelled and'partial'or code,detail or code)
        end
        return
    end
    if now>=j.deadline then return self:finish('travel-timeout',j.state)end
    if c then
        local allowed,reason=self.a.eligible(c)
        if not allowed then return self:finish('cancelled',reason)end
        if c.mapId==j.destination.mapId and c.key~=j.sourceKey then
            j.travelled=true
            if self.a.arrivalReady(c,j.destination)then
                if j.arrivalKey~=c.key then j.arrivalKey=c.key;j.stableSince=now end
                j.state='VerifyArrival'
                if now-j.stableSince>=3 then
                    if j.destination.point then return self:startLocal(c)end
                    return self:finish('success')
                end
            else j.stableSince=nil;j.arrivalKey=nil;j.state='AwaitArrival'end
        elseif c.key==j.sourceKey and not j.departed then
            -- The engine may keep the old pawn alive while the request queues.
            j.state='AwaitDeparture'
        else
            return self:finish('wrong-destination',c.mapId)
        end
    else
        j.departed=true;j.state='AwaitArrival';j.stableSince=nil;j.arrivalKey=nil
    end
end
return Travel
