-- Copy only scalar values from the native camera; never retain engine structs.
local M={}
M.fields={'AutoExposureMethod','AutoExposureBias','AmbientOcclusionIntensity','AmbientOcclusionRadius',
 'AmbientOcclusionFadeDistance','AmbientOcclusionFadeRadius','ReflectionMethod','SmartReflectionQuality',
 'LumenReflectionQuality','DynamicGlobalIlluminationMethod'}
function M.snapshot(capture)
 local p=capture.PostProcessSettings
 local result={fov=capture.FOVAngle,source=capture.CaptureSource,post={}}
 assert(type(result.fov)=='number'and result.fov>0 and result.fov<180,'Invalid native map FoV')
 for _,key in ipairs(M.fields)do
  local value=p[key];assert(type(value)=='number'and value==value,'Invalid native map postprocess: '..key)
  result.post[key]={enabled=p['bOverride_'..key]==true,value=value}
 end
 return result
end
function M.apply(capture,settings)
 capture.CaptureSource=settings.source
 for _,key in ipairs(M.fields)do
  local row=assert(settings.post[key]);capture.PostProcessSettings['bOverride_'..key]=row.enabled
  capture.PostProcessSettings[key]=row.value
 end
end
function M.geometry(width,fov,fraction)
 assert(width>0 and fov>0 and fov<180 and fraction>0,'Invalid map camera geometry')
 return width*fraction/(2*math.tan(fov*math.pi/360)),fov
end
return M
