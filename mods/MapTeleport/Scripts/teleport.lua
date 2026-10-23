-- Pure request lifecycle. The adapter alone touches the engine.
local Teleport = {}
Teleport.__index = Teleport

function Teleport.new(adapter)
    return setmetatable({a=adapter, sequence=0, job=nil, disabled=false},Teleport)
end

function Teleport:message(code, detail)
    local ok,err=pcall(self.a.message,code,detail)
    if not ok then print('[MapTeleport] message failed: '..tostring(err)..'\n') end
end

function Teleport:finish(code, detail)
    local job=self.job
    if job then
        local ok,result=pcall(self.a.release,job)
        if not ok then
            self.disabled=true;code='cleanup-failed';detail=tostring(result)
            if self.a.releaseRestrictions then
                local released,err=pcall(self.a.releaseRestrictions,job)
                if not released then detail=detail..'; input: '..tostring(err)end
            end
        elseif result==false then
            job.state='Cleanup';job.finalCode=code;job.finalDetail=detail
            job.cleanupDeadline=job.cleanupDeadline or((job.lastTime or job.started)+15)
            return
        end
    end
    self.job=nil
    self:message(code,detail)
end

function Teleport:restore(reason, now, context)
    local job=self.job
    if job.restoring then
        self.disabled=true
        return self:finish('restore-failed',reason)
    end
    job.restoring=true;job.state='RestorePrepare'; job.reason=reason; job.stageTime=now;job.restoreDeadline=now+15
    return self:tryRestore(now,context)
end

function Teleport:tryRestore(now,context)
    local job=self.job
    if self.a.maintain then self.a.maintain(context,job)end
    if self.a.restoreReady and not self.a.restoreReady(context,job)then
        -- Stay at the checked destination while the original floor reloads.
        if now>=job.restoreDeadline then
            self.disabled=true
            return self:finish('restore-failed','origin-not-ready')
        end
        return
    end
    job.state='Restore';job.stageTime=now
    local ok,result=pcall(self.a.restore,context,job)
    if not ok or result==false then
        self.disabled=true
        self:finish('restore-failed',ok and job.reason or tostring(result))
    end
end

function Teleport:request()
    if self.disabled then return self:message('disabled') end
    if self.job then return self:message('busy') end
    local ok,context,reason=pcall(self.a.context)
    if not ok then return self:message('unavailable',context) end
    if not context then return self:message(reason or 'unavailable') end
    local resolved,marker,origin,now,reason=pcall(function()
        local allowed,why=self.a.eligible(context)
        if not allowed then return nil,nil,nil,why end
        local point,markerReason=self.a.marker(context)
        if not point then return nil,nil,nil,markerReason or'no-marker'end
        local snapshot,originReason=self.a.snapshot(context)
        if not snapshot then return nil,nil,nil,originReason or'unsafe-origin'end
        return point,snapshot,self.a.now(context)
    end)
    if not resolved then return self:message('unavailable',marker)end
    if not marker then return self:message(reason)end
    self.sequence=self.sequence+1
    local job={id=self.sequence, key=context.key, world=context.world,
        pcId=context.pcId, marker=marker, origin=origin, resources={},
        state='Prepare', started=now, stageTime=now, deadline=now+15, moved=false}
    self.job=job
    if self.a.log then pcall(self.a.log,job,'Prepare')end
    self:message('preparing')
    local begun,err=pcall(self.a.prepare,context,job)
    if not begun then self:finish('cancelled',tostring(err)) end
end

function Teleport:tick()
    local job=self.job
    if not job then return end
    local ok,context=pcall(self.a.context)
    if not ok or not context or context.key~=job.key then
        return self:finish('cancelled','world-or-character-changed')
    end
    local now=job.lastTime or job.started
    local previous=job.state
    local success,err=pcall(function()
        local allowed,why=self.a.eligible(context)
        if not allowed then return self:finish('cancelled',why)end
        now=self.a.now(context);job.lastTime=now
        if self.a.maintain then self.a.maintain(context,job)end
        if job.state=='Cleanup'then
            if self.a.releaseReady(context,job)then
                self.job=nil;self:message(job.finalCode,job.finalDetail)
            elseif now>=job.cleanupDeadline then
                self.disabled=true
                local released,err=true,nil
                if self.a.releaseRestrictions then released,err=pcall(self.a.releaseRestrictions,job)end
                self.job=nil;self:message('cleanup-failed',released and'unload-timeout'or tostring(err))
            end
        elseif job.state=='Handoff'or job.state=='RestoreHandoff'then
            if self.a.handoffReady(context,job)then
                job.state=job.restoring and'RestoreReleased'or'VerifyReleased';job.stageTime=now
            elseif now-job.stageTime>=15 then self:restore('handoff-timeout',now,context)end
        elseif job.state=='Prepare' then
            if now>=job.deadline then return self:finish('timeout') end
            if not self.a.ready(context,job) then return end
            local destination,reason=self.a.destination(context,job)
            if not destination then
                if reason=='not-loaded' then return end
                return self:finish('cancelled',reason)
            end
            job.destination=destination; job.moved=true
            local accepted=self.a.move(context,job)
            if accepted==false then return self:restore('move-rejected',now,context) end
            job.state='Verify'; job.stageTime=now
        elseif job.state=='Verify' or job.state=='VerifyReleased' then
            local stable,reason=self.a.verify(context,job,false)
            if not stable then return self:restore(reason,now,context) end
            if now-job.stageTime>=3 then
                if job.state=='Verify' and self.a.handoff then
                    if self.a.canHandoff and not self.a.canHandoff(context,job,false)then
                        if now-job.stageTime>=15 then self:restore('normal-streaming-timeout',now,context)end
                        return
                    end
                    self.a.handoff(context,job)
                    job.state=self.a.handoffReady and'Handoff'or'VerifyReleased';job.stageTime=now
                else self:finish('success')end
            end
        elseif job.state=='RestorePrepare' then
            self:tryRestore(now,context)
        elseif job.state=='Restore'or job.state=='RestoreReleased'then
            local stable,reason=self.a.verify(context,job,true)
            if not stable then
                self.disabled=true
                return self:finish('restore-failed',reason)
            end
            if now-job.stageTime>=3 then
                if job.state=='Restore'and self.a.handoff then
                    if self.a.canHandoff and not self.a.canHandoff(context,job,true)then
                        if now-job.stageTime>=15 then self.disabled=true;self:finish('restore-failed','normal-streaming-timeout')end
                        return
                    end
                    self.a.handoff(context,job,true)
                    job.state=self.a.handoffReady and'RestoreHandoff'or'RestoreReleased';job.stageTime=now
                else self:finish('restored',job.reason)end
            end
        end
    end)
    if not success and self.job then
        if job.state=='Cleanup'then self:finish('cleanup-failed',tostring(err));self.disabled=true
        elseif job.moved then
            local restored,restoreError=pcall(self.restore,self,tostring(err),now,context)
            if not restored then self.disabled=true;self:finish('restore-failed',tostring(restoreError))end
        else self:finish('cancelled',tostring(err)) end
    end
    if self.job==job and previous~=job.state and self.a.log then pcall(self.a.log,job,job.state)end
end

function Teleport:shutdown()
    if self.job then self:finish('cancelled','shutdown') end
end
return Teleport
