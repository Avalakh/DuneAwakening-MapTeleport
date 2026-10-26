-- Native API boundary. Hook callbacks only record rejection values for the
-- current operation; the single game-thread timer decides what happens next.
local Adapter={}
local function object(n)local o=StaticFindObject('/Script/'..n);assert(o:IsValid(),n..' unavailable');return o end
local function path(o)return o:GetFullName():match('^%S+ (.+)$')end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function Adapter.new(base,catalog,localRunner,completed)
    local a={};local pending=nil;local result=nil;local hooks={}
    function a.now()
        local out,unused={},{}
        object('Engine.Default__GameplayStatics'):GetAccurateRealTime(out,unused)
        assert(finite(out.Seconds)and finite(out.PartialSeconds),'Monotonic clock unavailable')
        return out.Seconds+out.PartialSeconds
    end
    function a.context()
        local c=base.context();if not c then return nil end
        c.mapId=object('DuneSandbox.Default__DuneMapUtilities'):GetDuneMapIdFromWorld(c.pc).Name:ToString()
        return c
    end
    function a.eligible(c)
        if not c.pc:HasAuthority()or not object('DuneSandbox.Default__GUIBlueprintLibrary'):IsSoloPlay(c.pc)then return false,'solo-only'end
        if c.pawn:IsDead()or c.pawn:IsInDownedState()or c.pawn:GetHealth()<=0 then return false,'dead'end
        if object('UE4Dreamworld.Default__PersistenceIdBlueprintFunctionLibrary'):IsValid_PersistenceActorId(c.pawn.m_CurrentVehicleId)then return false,'vehicle'end
        return true
    end
    function a.validate(c,d)
        if type(d)~='table'or type(d.mapId)~='string'or type(d.worldPath)~='string'then return false,'invalid-destination'end
        local found
        for _,r in ipairs(catalog.snapshot(c))do if r.id==d.id then found=r;break end end
        if not found or found.mapId~=d.mapId or found.worldPath~=d.worldPath then return false,'destination-unavailable'end
        if not found.current and found.destinationName~=d.destinationName then return false,'route-changed'end
        if d.point and(not finite(d.point.X)or not finite(d.point.Y)or d.point.mapId~=d.mapId)then return false,'invalid-point'end
        return true
    end
    function a.request(c,d,id)
        local target={};local api=object('DuneSandbox.Default__DuneTravelApi')
        if not api:CanTravelToDestination(c.pawn,FName(d.destinationName),target)
            or not target.Name or target.Name:ToString()~=d.mapId then return false,'route-unavailable'end
        pending={id=id,controller=path(c.pc),mapId=d.mapId};result=nil
        print(string.format('[MapTeleport] operation=%s region=%s world=%s state=Request route=%s\n',tostring(id),d.mapId,c.worldPath,d.destinationName))
        -- NoDialog skips only the redundant confirmation. The engine still
        -- evaluates travel requirements; native failure dialogs are preserved.
        api:RequestTravelByDestination(c.pc,FName(d.destinationName),nil,nil,'MapTeleport confirmed destination',2,-1)
        return true
    end
    function a.failure(id)if pending and pending.id==id then return pending.failure end end
    function a.arrivalReady(c,d)
        if c.mapId~=d.mapId or c.worldPath~=d.worldPath then return false end
        if not c.pc:IsLocalController()or c.pc:K2_GetPawn():GetAddress()~=c.pawn:GetAddress()then return false end
        return base.snapshot(c)~=nil
    end
    function a.startLocal(c,point,id)
        result=nil
        return localRunner:request(point,id)
    end
    function a.localResult(id)
        if result and result.id==id then return result.code,result.detail end
    end
    function a.onLocalComplete(id,code,detail)result={id=id,code=code,detail=detail}end
    function a.release(j)
        if pending and pending.id==j.id then pending=nil end
        result=nil
    end
    function a.completed(id,code,detail,j)completed(id,code,detail,j)end
    function a.nativeFailure(controller,mapId,reason)
        if not pending or controller~=pending.controller then return end
        if mapId and mapId~=pending.mapId then return end
        pending.failure=reason
    end
    function a.installHooks()
        if #hooks>0 then return end
        local function hook(name,callback)
            local pre,post=RegisterHook(name,callback)
            hooks[#hooks+1]={name=name,pre=pre,post=post}
        end
        hook('/Script/DuneSandbox.DunePlayerControllerBase:ClientShowTravelRequirementsFailedDialog',function(context,mapId,reason)
            local ok,err=pcall(function()
                a.nativeFailure(path(context:get()),mapId:get().Name:ToString(),reason:get():ToString())
            end)
            if not ok then print('[MapTeleport] native failure capture: '..tostring(err)..'\n')end
        end)
        hook('/Script/DuneSandbox.DunePlayerControllerBase:ClientShowTravelFailedDialog',function(context,reason)
            local ok,err=pcall(function()a.nativeFailure(path(context:get()),nil,'travel-failed: '..tostring(reason:get()))end)
            if not ok then print('[MapTeleport] native failure capture: '..tostring(err)..'\n')end
        end)
    end
    function a.shutdown()
        assert(not pending,'Travel operation still active')
        local remaining,errors={},{}
        for _,h in ipairs(hooks)do
            local ok,why=pcall(UnregisterHook,h.name,h.pre,h.post)
            if not ok then remaining[#remaining+1]=h;errors[#errors+1]=tostring(why)end
        end
        hooks=remaining
        if #errors>0 then error(table.concat(errors,'; '))end
    end
    return a
end
return Adapter
