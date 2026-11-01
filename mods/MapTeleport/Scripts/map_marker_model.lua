-- Value-only marker snapshots and projection. No engine calls or marker writes.
local Projection=require('map_projection')
local M={}
local categories={place=true,base=true,quest=true,personal=true,player=true}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function text(s)return type(s)=='string'and s or''end
local function tint(c)
 if type(c)~='table'then return end
 for _,k in ipairs({'R','G','B','A'})do if not finite(c[k])then return end end
 return{R=c.R,G=c.G,B=c.B,A=c.A}
end
function M.snapshot(mapId,layer,records,status)
 local result={mapId=mapId,layerId=layer,rows={},status=status or'available'};local ids={}
 for _,r in ipairs(records or{})do
  if r.mapId==mapId and r.layerId==layer and categories[r.category]and r.visible==true
    and finite(r.X)and finite(r.Y)and(r.category~='place'or r.discovered==true)then
   local id=text(r.id)
   if id==''then id=table.concat({r.category,string.format('%.6f',r.X),string.format('%.6f',r.Y),text(r.label)},'|')end
   local old=ids[id]
   local row={id=id,mapId=mapId,layerId=layer,X=r.X,Y=r.Y,category=r.category,
    label=text(r.label),icon=text(r.icon),preset=text(r.preset),iconTint=tint(r.iconTint),backgroundTint=tint(r.backgroundTint),tint=tint(r.tint),rotation=finite(r.rotation)and r.rotation or 0,
    priority=finite(r.priority)and r.priority or 0}
   if not old then result.rows[#result.rows+1]=row;ids[id]=#result.rows
   elseif row.priority>result.rows[old].priority then result.rows[old]=row end
  end
 end
 table.sort(result.rows,function(a,b)if a.priority~=b.priority then return a.priority>b.priority end;return a.id<b.id end)
 return result
end
function M.layout(snapshot,map,rect,viewport,size)
 local result={};size=size or 26
 if not map or snapshot.mapId~=map.id or snapshot.layerId~=map.layer then return result end
 local view={x=rect.x,y=rect.y,width=rect.width,height=rect.height,zoom=1,panU=0,panV=0}
 for _,row in ipairs(snapshot.rows)do
  local p=Projection.screen(map,view,row)
  if p and p.x+size/2>=viewport.x and p.y+size/2>=viewport.y
    and p.x-size/2<=viewport.x+viewport.width and p.y-size/2<=viewport.y+viewport.height then
   result[#result+1]={marker=row,x=p.x,y=p.y,size=size}
  end
 end
 return result
end
function M.hover(layout,x,y)
 local found,best
 for _,entry in ipairs(layout)do
  local distance=(entry.x-x)^2+(entry.y-y)^2
  if distance<=(entry.size/2)^2 and(not found or entry.marker.priority>found.priority
    or(entry.marker.priority==found.priority and distance<best))then found=entry.marker;best=distance end
 end
 return found
end
return M
