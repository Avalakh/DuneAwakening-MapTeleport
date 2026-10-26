-- Pure affine map projection. The engine adapter supplies the map's measured
-- basis; nothing here assumes Hagga's scale, axes, or a loaded destination world.
local P={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function P.plane(sceneMin,sceneMax,worldMin,worldMax,worldHeight)
    local values={sceneMin,sceneMax,worldMin,worldMax,worldHeight}
    for i=1,5 do
        if not finite(values[i])then return nil,'invalid-plane'end
    end
    if worldMax<=worldMin or sceneMax<sceneMin then return nil,'invalid-plane'end
    return sceneMin+(worldHeight-worldMin)/(worldMax-worldMin)*(sceneMax-sceneMin)
end
-- Cartography maps a physical world box to a scene box. The preview camera
-- faces -Z with the native -90 degree yaw: right is +X, down is +Y.
-- Preserve square capture
-- padding instead of stretching either box or assuming a universal 1:100.
function P.fromBounds(id,scene,world)
    if type(scene)~='table'or type(world)~='table'then return nil,'invalid-bounds'end
    for _,b in ipairs({scene,world})do
        for _,k in ipairs({'minX','minY','maxX','maxY'})do if not finite(b[k])then return nil,'invalid-bounds'end end
    end
    local sx,sy=scene.maxX-scene.minX,scene.maxY-scene.minY
    local wx,wy=world.maxX-world.minX,world.maxY-world.minY
    if sx<=0 or sy<=0 or wx<=0 or wy<=0 then return nil,'invalid-bounds'end
    local width=math.max(sx,sy)
    local cx,cy=(scene.minX+scene.maxX)/2,(scene.minY+scene.maxY)/2
    return P.new({id=id,layer='surface',
        originX=world.minX+(cx-width/2-scene.minX)*wx/sx,
        originY=world.minY+(cy-width/2-scene.minY)*wy/sy,
        ux=width*wx/sx,uy=0,vx=0,vy=width*wy/sy})
end
function P.new(map)
    if type(map)~='table'or type(map.id)~='string'or map.id==''then return nil,'invalid-map'end
    for _,k in ipairs({'originX','originY','ux','uy','vx','vy'})do
        if not finite(map[k])then return nil,'invalid-transform'end
    end
    local det=map.ux*map.vy-map.uy*map.vx
    if math.abs(det)<1e-9 then return nil,'singular-transform'end
    return {id=map.id,layer=map.layer,originX=map.originX,originY=map.originY,
        ux=map.ux,uy=map.uy,vx=map.vx,vy=map.vy,det=det}
end
local function validView(v)
    if type(v)~='table'then return false end
    for _,k in ipairs({'x','y','width','height','zoom','panU','panV'})do if not finite(v[k])then return false end end
    return v.width>0 and v.height>0 and v.zoom>0
end
function P.pick(map,view,x,y)
    if not validView(view)or not finite(x)or not finite(y)then return nil,'invalid-view'end
    if x<view.x or x>view.x+view.width or y<view.y or y>view.y+view.height then return nil,'outside-viewport'end
    local u=((x-view.x)/view.width-0.5)/view.zoom+0.5+view.panU
    local v=((y-view.y)/view.height-0.5)/view.zoom+0.5+view.panV
    if u<0 or u>1 or v<0 or v>1 then return nil,'outside-map'end
    local wx,wy=map.originX+map.ux*u+map.vx*v,map.originY+map.uy*u+map.vy*v
    if not finite(wx)or not finite(wy)then return nil,'invalid-coordinate'end
    return {mapId=map.id,layerId=map.layer,X=wx,Y=wy}
end
function P.screen(map,view,point)
    if not validView(view)or type(point)~='table'or not finite(point.X)or not finite(point.Y)then return nil,'invalid-view'end
    if point.mapId~=map.id or point.layerId~=map.layer then return nil,'wrong-map'end
    local dx,dy=point.X-map.originX,point.Y-map.originY
    local u=(dx*map.vy-dy*map.vx)/map.det
    local v=(dy*map.ux-dx*map.uy)/map.det
    return {x=view.x+view.width*((u-0.5-view.panU)*view.zoom+0.5),
        y=view.y+view.height*((v-0.5-view.panV)*view.zoom+0.5)}
end
return P
