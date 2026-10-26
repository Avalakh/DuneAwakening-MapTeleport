local application=require('application').new()
local runtime=require('runtime').new(application)
local pending=false
local cancelPending=false
local navigationPending={}
RegisterKeyBind(Key.F12,{ModifierKey.SHIFT},function()pending=true end)
RegisterKeyBind(Key.ESCAPE,function()cancelPending=true end)
local function queueNavigation(direction)
 if #navigationPending<16 then navigationPending[#navigationPending+1]=direction end
end
RegisterKeyBind(Key.TAB,function()queueNavigation('next')end)
RegisterKeyBind(Key.TAB,{ModifierKey.SHIFT},function()queueNavigation('previous')end)
assert(type(LoopInGameThreadWithDelay)=='function','Required game-thread timer unavailable')
LoopInGameThreadWithDelay(50,function()
 if cancelPending then
  cancelPending=false;pending=false;navigationPending={}
  local ok,err=pcall(application.cancel)
  if not ok then pcall(runtime.recover,err)end
 end
 local navigation=table.remove(navigationPending,1)
 if navigation then
  local ok,err=pcall(application.navigate,navigation)
  if not ok then pcall(runtime.recover,err)end
 end
 if pending then
  pending=false
  local ok,err=pcall(runtime.hit)
  if not ok then pcall(runtime.recover,err)end
 end
 local ok,err=pcall(runtime.tick)
 if not ok then
  print('[MapTeleport] update error: '..tostring(err)..'\n')
  local recovered,why=pcall(runtime.recover,err)
  if not recovered then
   application.runner.disabled=true;application.travel.disabled=true
   pcall(application.window.close)
   print('[MapTeleport] recovery error: '..tostring(why)..'\n')
  end
 end
end)
print('[MapTeleport] unified region window: Shift+F12; persistent game-thread timer\n')
