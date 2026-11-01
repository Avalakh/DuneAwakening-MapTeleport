package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local M=require('map_capture_settings')
local native={FOVAngle=100,CaptureSource=10,PostProcessSettings={}}
for i,k in ipairs(M.fields)do native.PostProcessSettings[k]=i;native.PostProcessSettings['bOverride_'..k]=i%2==0 end
local settings=M.snapshot(native);local own={PostProcessSettings={}}
M.apply(own,settings)
for _,k in ipairs(M.fields)do assert(own.PostProcessSettings[k]==native.PostProcessSettings[k]);assert(own.PostProcessSettings['bOverride_'..k]==native.PostProcessSettings['bOverride_'..k])end
own.PostProcessSettings.AutoExposureBias=99;assert(native.PostProcessSettings.AutoExposureBias~=99)
native.PostProcessSettings.AutoExposureBias=42;assert(settings.post.AutoExposureBias.value~=42)
for _,fraction in ipairs({1,.5,.1,.025})do local h,f=M.geometry(24384,100,fraction);assert(math.abs(2*h*math.tan(f*math.pi/360)-24384*fraction)<1e-7)end
assert(not pcall(M.geometry,100,0,1));assert(not pcall(M.geometry,100,90,0))
print('PASS native capture settings: scalar snapshot, isolated application, fixed FoV and zoom height footprint')
