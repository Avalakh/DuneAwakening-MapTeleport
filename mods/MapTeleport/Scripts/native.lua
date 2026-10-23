-- All calls that touch UObjects must run on the game thread.
local Native = {}

function Native.load(dll_path)
    local entry, err = package.loadlib(dll_path, 'luaopen_mapteleport_native')
    if not entry then return nil, err end
    entry()
    if type(MapTeleportNativeGeometry) ~= 'function' then
        return nil, 'Installed UE4SS DLL is not qualified for this bridge'
    end
    return Native
end

function Native.geometry(widget)
    if not widget or not widget:IsValid() then return nil, 'Invalid map widget' end
    local get_geometry = StaticFindObject('/Script/UMG.Widget:GetCachedGeometry')
    local slate = StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary')
    local get_size = StaticFindObject('/Script/UMG.SlateBlueprintLibrary:GetLocalSize')
    local to_absolute = StaticFindObject('/Script/UMG.SlateBlueprintLibrary:LocalToAbsolute')
    for _, object in ipairs({get_geometry, slate, get_size, to_absolute}) do
        if not object:IsValid() then return nil, 'Slate interface unavailable' end
    end
    local ok, x0, y0, x1, y1, width, height = MapTeleportNativeGeometry(
        widget:GetAddress(), get_geometry:GetAddress(), slate:GetAddress(),
        get_size:GetAddress(), to_absolute:GetAddress())
    if not ok then return nil, x0 end
    return {left=x0, top=y0, right=x1, bottom=y1, width=width, height=height}
end

-- Caller must establish map visibility, foreground hit target and current world
-- before arming; a stale view expires natively after 250 ms.
function Native.arm(rect, generation)
    return MapTeleportNativeArm(MapTeleportNativeGameWindow(), generation,
        rect.left, rect.top, rect.right, rect.bottom)
end

function Native.disarm() MapTeleportNativeDisarm() end
function Native.poll() return MapTeleportNativePoll() end
function Native.shutdown() return MapTeleportNativeShutdown() end

return Native
