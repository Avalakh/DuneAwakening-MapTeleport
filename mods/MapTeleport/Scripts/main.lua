local adapter=require('map_adapter').new()
local runtime=require('runtime').new(adapter)
local pending=false
RegisterKeyBind(Key.F12,{ModifierKey.SHIFT},function()
    -- The input thread only writes a boolean. It must not create registry refs
    -- while the game thread is running another callback in this Lua state.
    pending=true
end)
-- One persistent callback, registered once. No LoopAsync -> ExecuteInGameThread
-- handoff and no per-key callback scheduling on the shared Lua registry.
assert(type(LoopInGameThreadWithDelay)=='function','Required game-thread timer unavailable')
LoopInGameThreadWithDelay(50,function()
    if pending then
        pending=false
        local ok,err=pcall(runtime.hit)
        if not ok then print('[MapTeleport] input error: '..tostring(err)..'\n')end
    end
    local ok,err=pcall(runtime.tick)
    if not ok then
        print('[MapTeleport] update error: '..tostring(err)..'\n')
        local recovered,recoveryError=pcall(function()
            local job=runtime.runner.job
            if not job then return end
            local c=adapter.context()
            if not c or c.key~=job.key then
                runtime.runner:finish('cancelled','world-or-character-changed')
            elseif job.moved then
                runtime.runner:restore(tostring(err),adapter.now(c),c)
            else runtime.runner:finish('cancelled',tostring(err))end
        end)
        if not recovered then
            print('[MapTeleport] recovery error: '..tostring(recoveryError)..'\n')
            runtime.runner.disabled=true
            pcall(runtime.runner.finish,runtime.runner,'restore-failed',tostring(recoveryError))
        end
    end
end)
print('[MapTeleport] 0.1.3: личная метка на карте M, затем Shift+F12; persistent game-thread timer\n')
