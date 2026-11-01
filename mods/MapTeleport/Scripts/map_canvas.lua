-- Viewport and scroll geometry in logical UMG units. The texture remains square;
-- the surrounding viewport can have any aspect ratio without distorting clicks.
local C={}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function C.frame(width,height,left)
 return{x=left+20,y=160,width=math.max(100,width-left-60),height=math.max(100,height-310)}
end
function C.layout(frame,zoom,u,v)
 local w,h=math.max(1,frame.width-16),math.max(1,frame.height-16)
 local base=math.max(w,h);local minimum=math.min(w,h)/base
 zoom=clamp(zoom or 1,minimum,16)
 local size=base*zoom;local cw,ch=math.max(w,size),math.max(h,size)
 local mx,my=(cw-size)/2,(ch-size)/2
 local sx=clamp(mx+(u or .5)*size-w/2,0,cw-w)
 local sy=clamp(my+(v or .5)*size-h/2,0,ch-h)
 return{frame=frame,width=w,height=h,size=size,zoom=zoom,minZoom=minimum,
  contentWidth=cw,contentHeight=ch,mapX=mx,mapY=my,maxX=cw-w,maxY=ch-h,x=sx,y=sy}
end
function C.rect(l,x,y)
 x=clamp(x or l.x,0,l.maxX);y=clamp(y or l.y,0,l.maxY)
 return{x=l.frame.x+l.mapX-x,y=l.frame.y+l.mapY-y,width=l.size,height=l.size}
end
function C.center(l,x,y)
 return clamp(((x or l.x)+l.width/2-l.mapX)/l.size,0,1),
  clamp(((y or l.y)+l.height/2-l.mapY)/l.size,0,1)
end
function C.contains(l,x,y)
 return x>=l.frame.x and x<=l.frame.x+l.width and y>=l.frame.y and y<=l.frame.y+l.height
end
function C.drag(l,start,x,y)
 local dx,dy=x-start.x,y-start.y
 if not start.moved and dx*dx+dy*dy<36 then return end
 return{x=clamp(start.scrollX-dx,0,l.maxX),y=clamp(start.scrollY-dy,0,l.maxY)}
end
function C.zoom(l,x,y,factor,px,py)
 local old=C.rect(l,x,y)
 local u,v=C.center(l,x,y)
 local next=C.layout(l.frame,l.zoom*factor,u,v)
 if px and py and C.contains(l,px,py)then
  local pu,pv=(px-old.x)/old.width,(py-old.y)/old.height
  next.x=clamp(next.mapX+pu*next.size-(px-l.frame.x),0,next.maxX)
  next.y=clamp(next.mapY+pv*next.size-(py-l.frame.y),0,next.maxY)
 end
 return next
end
local cachedSize
local function captureSize(width,height,maxWidth,maxHeight)
 maxWidth=maxWidth or 1536;maxHeight=maxHeight or 1536
 if cachedSize and cachedSize.width==width and cachedSize.height==height and cachedSize.maxWidth==maxWidth and cachedSize.maxHeight==maxHeight then return cachedSize end
 local aspect=width/height;local best=math.huge;local rw,rh=2,2
 -- Even dimensions keep centre UV aligned with the native integer-pixel ray.
 -- Match the viewport ratio before maximising resolution: rounding one side
 -- at a fixed 1536 width moves clicks by metres on large world maps.
 for w=2,maxWidth,2 do
  local h=2*math.floor(w/aspect/2+.5)
  if h>=2 and h<=maxHeight then
   local error=math.abs((w/h)/aspect-1)
   if error<best-1e-12 or(math.abs(error-best)<=1e-12 and w*h>rw*rh)then best=error;rw=w;rh=h end
  end
 end
 cachedSize={width=width,height=height,maxWidth=maxWidth,maxHeight=maxHeight,rtWidth=rw,rtHeight=rh};return cachedSize
end
function C.capture(viewport,rect,maxWidth,maxHeight)
 local size=captureSize(viewport.width,viewport.height,maxWidth,maxHeight)
 return{u=(viewport.x+viewport.width/2-rect.x)/rect.width,
  v=(viewport.y+viewport.height/2-rect.y)/rect.height,
  fraction=viewport.width/rect.width,
  width=size.rtWidth,height=size.rtHeight}
end
return C
