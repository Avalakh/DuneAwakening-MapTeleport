-- Centimetres. Exact point first, then expanding rings within the map.
-- Engine references never survive a tick; every candidate uses identical checks.
local Search={}
local function initial(job)
 local b=job.profile and job.profile.bounds or{minX=-457200,minY=-457200,maxX=355600,maxY=355600}
 local maxRadius=0
 for _,x in ipairs({b.minX,b.maxX})do for _,y in ipairs({b.minY,b.maxY})do
  maxRadius=math.max(maxRadius,math.sqrt((x-job.marker.X)^2+(y-job.marker.Y)^2))
 end end
 return{exact=true,radius=100,index=0,missing=false,maxRadius=maxRadius}
end
function Search.step(job,probe,allowed,budget)
 local s=job.placementSearch or initial(job);job.placementSearch=s
 for _=1,budget or 8 do
  if not s.exact and s.radius>s.maxRadius then
   if s.missing then job.placementSearch=nil;return nil,'not-loaded'end
   return nil,'no-safe-place'
  end
  local x,y=0,0
  if s.exact then s.exact=false
  else
   local count=math.min(64,math.ceil(2*math.pi*s.radius/100))
   local angle=2*math.pi*s.index/count
   x,y=s.radius*math.cos(angle),s.radius*math.sin(angle)
   s.index=s.index+1
   if s.index>=count then
    s.index=0;s.radius=s.radius<1000 and s.radius+100 or s.radius*1.5
   end
  end
  local point={X=job.marker.X+x,Y=job.marker.Y+y}
  if not allowed or allowed(point)then
   local destination,reason=probe(point)
   if destination then
    job.placementSearch=nil;job.placementOffset=math.sqrt(x*x+y*y)
    return destination
   end
   s.lastReason=reason
   if reason=='not-loaded'then s.missing=true end
  end
 end
 return nil,'not-loaded'
end
return Search
