local T=require('teleport')
local Runtime={}
function Runtime.new(adapter)
    local r={adapter=adapter,runner=T.new(adapter),latched=false,upFrames=0}
    function r.hit()
        if r.latched then return end
        r.latched=true;r.upFrames=0
        r.runner:request()
    end
    function r.tick()
        local c=adapter.context()
        if r.latched then
            if not c or not c.pc:IsInputKeyDown({KeyName=FName('F12')})then
                r.upFrames=r.upFrames+1
                if r.upFrames>=2 then r.latched=false end
            else r.upFrames=0 end
        end
        r.runner:tick()
    end
    return r
end
return Runtime
