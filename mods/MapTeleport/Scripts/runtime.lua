-- Notifications are consumed in the game thread against current key state.
local Runtime={}
function Runtime.new(app)
 local r={app=app,runner=app.runner,latched=false,upFrames=0}
 function r.hit()
  if r.latched then return false end
  r.latched=true;r.upFrames=0
  local k=app.input()
  if not k or not k.focused or not k.f12 or not k.shift or k.ctrl then return false end
  return app.open()
 end
 function r.tick()
  local k=app.input()
  if k and k.f12 then
   r.upFrames=0
   if k.ctrl or not k.shift or not k.focused then r.latched=true end
  else r.upFrames=r.upFrames+1;if r.upFrames>=2 then r.latched=false end end
  app.update()
 end
 function r.recover(err)return app.recover(err)end
 return r
end
return Runtime
