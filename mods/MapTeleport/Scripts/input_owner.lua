-- Independent Enhanced Input stack entry. Never resets the game's global
-- ignore counters or removes another menu/mod's input component.
local Owner={}
local function path(o)return o:GetFullName():match('^%S+ (.+)$')end
local function obj(n)local o=StaticFindObject(n);assert(o:IsValid(),n);return o end
function Owner.acquire(c)
    local record={world=c.world,pcId=c.pcId}
    local ok,why=pcall(function()
        local stats=obj('/Script/Engine.Default__GameplayStatics')
        local t={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
        local actor=stats:BeginDeferredActorSpawnFromClass(c.pc,obj('/Script/Engine.Actor'),t,1,c.pc,0)
        assert(actor:IsValid(),'Input owner creation failed');record.actor=path(actor)
        actor.Tags={FName('MapTeleportWindowInputOwner')};actor.bBlockInput=true;actor.InputPriority=2147483647
        stats:FinishSpawningActor(actor,t,0)
        actor:CreateInputComponent(obj('/Script/EnhancedInput.EnhancedInputComponent'))
        record.component=path(actor.InputComponent);actor:EnableInput(c.pc)
        c.pawn.CharacterMovement:StopMovementImmediately()
    end)
    if not ok then pcall(Owner.release,nil,record);error(why)end
    return record
end
function Owner.release(_,record)
    if not record or not record.actor then return end
    local actor=StaticFindObject(record.actor)
    if actor:IsValid()and not actor:IsActorBeingDestroyed()then
        assert(actor:ActorHasTag(FName('MapTeleportWindowInputOwner')),'Input owner tag changed')
        local pc=actor:GetOwner()
        if pc:IsValid()then
            assert(path(pc)==record.pcId and tostring(pc:GetOuter():GetOuter():GetAddress())==record.world,'Input owner identity changed')
            actor:DisableInput(pc)
            if record.component then
                local component=StaticFindObject(record.component)
                if component:IsValid()and not component:IsBeingDestroyed()then
                    assert(path(component:GetOwner())==record.actor,'Input component ownership changed')
                    component:K2_DestroyComponent(actor)
                end
            end
        end
        actor:K2_DestroyActor()
        if pc:IsValid()then
            local out={};obj('/Script/Engine.Default__GameplayStatics'):GetAllActorsWithTag(pc,FName('MapTeleportWindowInputOwner'),out)
            for _,r in ipairs(out)do local a=r.get and r:get()or r;assert(path(a)~=record.actor,'Input owner still present')end
        end
    end
    record.actor=nil;record.component=nil
end
return Owner
