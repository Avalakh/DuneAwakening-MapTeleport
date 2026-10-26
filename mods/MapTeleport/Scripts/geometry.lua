local G = {}
function G.finite(n) return type(n) == 'number' and n == n and math.abs(n) < math.huge end
function G.vector(v) return v and G.finite(v.X) and G.finite(v.Y) and G.finite(v.Z) end
function G.copy(v) return {X=v.X, Y=v.Y, Z=v.Z} end
function G.surfaceHit(hit)
    if not hit or not G.finite(hit.Time)or not G.finite(hit.Distance)or not G.finite(hit.PenetrationDepth)then
        return false,'invalid-trace-hit'
    end
    -- UE4SS 1140 exposes packed FHitResult flags ambiguously. A start-overlap
    -- can report an upward normal and zero depth; it is not a measured floor.
    if hit.Time<=0 or hit.Distance<=0 or hit.PenetrationDepth>0 then return false,'initial-overlap'end
    if hit.Time>1 or not G.vector(hit.ImpactPoint)or not G.vector(hit.ImpactNormal)then return false,'invalid-trace-hit'end
    return true
end
function G.distance2(a,b) return (a.X-b.X)^2 + (a.Y-b.Y)^2 end

function G.transform(t, v)
    local q, s, p = t.Rotation, t.Scale3D, t.Translation
    local x,y,z = v.X*s.X, v.Y*s.Y, v.Z*s.Z
    local cx,cy,cz = q.Y*z-q.Z*y, q.Z*x-q.X*z, q.X*y-q.Y*x
    local dx,dy,dz = q.Y*cz-q.Z*cy, q.Z*cx-q.X*cz, q.X*cy-q.Y*cx
    return {X=p.X+x+2*(q.W*cx+dx), Y=p.Y+y+2*(q.W*cy+dy), Z=p.Z+z+2*(q.W*cz+dz)}
end
function G.inverseTransform(t,v)
    local q=t.Rotation
    local rotated=G.transform({Rotation={X=-q.X,Y=-q.Y,Z=-q.Z,W=q.W},
        Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}},
        {X=v.X-t.Translation.X,Y=v.Y-t.Translation.Y,Z=v.Z-t.Translation.Z})
    return {X=rotated.X/t.Scale3D.X,Y=rotated.Y/t.Scale3D.Y,Z=rotated.Z/t.Scale3D.Z}
end

function G.bounds2(t, box)
    local result = {minX=math.huge, minY=math.huge, maxX=-math.huge, maxY=-math.huge}
    for _,x in ipairs({box.Min.X,box.Max.X}) do
        for _,y in ipairs({box.Min.Y,box.Max.Y}) do
            for _,z in ipairs({box.Min.Z,box.Max.Z}) do
                local v=G.transform(t,{X=x,Y=y,Z=z})
                result.minX=math.min(result.minX,v.X); result.maxX=math.max(result.maxX,v.X)
                result.minY=math.min(result.minY,v.Y); result.maxY=math.max(result.maxY,v.Y)
            end
        end
    end
    return result
end

function G.contains(b, p, padding)
    padding=padding or 0
    return p.X >= b.minX-padding and p.X <= b.maxX+padding and
        p.Y >= b.minY-padding and p.Y <= b.maxY+padding
end

function G.destination(point, normal, radius, halfHeight, minNormalZ)
    if not G.vector(point) or not G.vector(normal) then return nil, 'invalid-surface' end
    if not G.finite(radius) or not G.finite(halfHeight) or radius <= 0 or halfHeight < radius then
        return nil, 'invalid-capsule'
    end
    if normal.Z < minNormalZ then return nil, 'steep-surface' end
    -- Game units are centimetres. Feet start 50 cm above the confirmed support.
    return {X=point.X, Y=point.Y, Z=point.Z+halfHeight+50}
end
return G
