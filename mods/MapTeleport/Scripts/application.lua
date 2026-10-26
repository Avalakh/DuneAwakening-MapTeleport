local Catalog=require('region_catalog')
local Profiles=require('map_profiles')
local Selection=require('region_selection')
local Travel=require('region_travel')
local Input=require('input_owner')
local App={}
function App.new()
    local base
    local function profile(c)
        local id=StaticFindObject('/Script/DuneSandbox.Default__DuneMapUtilities'):GetDuneMapIdFromWorld(c.pc).Name:ToString()
        local p=Profiles.get(id,c.worldPath)
        return Profiles.activate(p,c)
    end
    base=require('map_adapter').new({profile=profile,validatePoint=Profiles.validate})
    local notify=base.message
    local app={runner=require('teleport').new(base)}
    local selection,travel
    local ta=require('travel_adapter').new(base,Catalog,app.runner,function(id,code,detail,j)
        if selection then selection:completed(id)end
        if code=='partial'then notify('partial','Регион достигнут; перенос к точке отменён: '..base.describeReason(detail))
        else notify(code,detail)end
        print('[MapTeleport] operation='..id..' result='..code..' map='..j.destination.mapId..' detail='..tostring(detail)..'\n')
    end)
    travel=Travel.new(ta);app.travel=travel
    base.completed=ta.onLocalComplete
    base.message=function(code,detail)
        if code=='preparing'then notify(code,detail)
        else print('[MapTeleport] local result='..tostring(code)..' '..tostring(detail)..'\n')end
    end
    local map=require('map_view_adapter').new(ta.context,Catalog)
    local window=require('teleport_window').new({context=ta.context,map=map,acquireInput=Input.acquire,releaseInput=Input.release})
    selection=Selection.new({
        context=ta.context,eligible=ta.eligible,catalog=function(c)return Catalog.snapshot(c)end,
        present=window.present,close=window.close,message=notify,
        refreshRegion=function(c,id)
            for _,r in ipairs(Catalog.snapshot(c))do if r.id==id then return r end end
            return nil,'Регион недоступен по текущим условиям игры'
        end,
        validatePoint=function(row,p)return Profiles.validate(Profiles.get(row.mapId,row.worldPath),p)end,
        execute=function(d,id)return travel:request(d,id)end,
    })
    app.selection=selection;app.window=window;app.map=map;app.adapter=base
    function app.context()return ta.context()end
    function app.input()
        local c=ta.context();if not c then return nil end
        local function down(key)return c.pc:IsInputKeyDown({KeyName=FName(key)})end
        return {focused=c.pc:IsLocalController(),f12=down('F12'),
            shift=down('LeftShift')or down('RightShift'),ctrl=down('LeftControl')or down('RightControl')}
    end
    function app.open()
        if app.runner.disabled or travel.disabled or window.failed then notify('disabled');return false end
        if travel.job or app.runner.job then notify('busy');return false end
        local c=ta.context();if not c then return false end
        return selection:open(c)
    end
    function app.cancel()
        if selection.state=='Idle'or selection.state=='Executing'then return false end
        return selection:close()
    end
    function app.navigate(direction)
        if selection.state=='Idle'or selection.state=='Executing'then return false end
        return window.navigate(direction)
    end
    function app.update()
        app.runner:tick()
        local previous=travel.job and travel.job.state
        travel:tick()
        if travel.job and travel.job.state~=previous then
            local j=travel.job;local current=ta.context()
            print(string.format('[MapTeleport] operation=%s region=%s world=%s state=%s\n',tostring(j.id),j.destination.mapId,current and current.worldPath or'unavailable',j.state))
        end
        local c=ta.context();selection:update(c)
        if selection.state~='Idle'and selection.state~='Executing'then
            map.tick();local e=window.poll();if e then selection:event(e,c)end
        end
    end
    function app.shutdown()
        assert(not travel.job and not app.runner.job,'Teleport operation still active')
        local errors={}
        for _,cleanup in ipairs({window.shutdown,ta.shutdown})do
            local ok,why=pcall(cleanup)
            if not ok then errors[#errors+1]=tostring(why)end
        end
        if #errors>0 then error(table.concat(errors,'; '))end
    end
    function app.recover(err)
        print('[MapTeleport] recovery: '..tostring(err)..'\n')
        if selection.state~='Executing'then selection:close()end
        local job=app.runner.job
        if job then
            local c=base.context()
            if not c or c.key~=job.key then app.runner:finish('cancelled','world-or-character-changed')
            elseif job.moved then app.runner:restore(tostring(err),base.now(c),c)
            else app.runner:finish('cancelled',tostring(err))end
        elseif travel.job then travel:finish('travel-failed',tostring(err))end
    end
    ta.installHooks()
    return app
end
return App
