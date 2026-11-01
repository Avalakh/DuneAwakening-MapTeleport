local Model=require('map_marker_model')
local Array=require('unreal_array')
local M={}
local function object(n)local o=StaticFindObject(n);assert(o:IsValid(),'Marker resource unavailable: '..n);return o end
local function category(kind,tag)
 if kind=='PersonalMarker'then return'personal'end
 if kind=='HomeBase'or kind=='HomeBaseRespawn'or tag:find('Placeable',1,true)or tag:find('BaseBackup',1,true)then return'base'end
 if kind=='Objective'or tag:find('Objective',1,true)or tag:find('Contract',1,true)or tag:find('Journey',1,true)then return'quest'end
 return'place'
end
M.category=category
function M.new(context)
 local a={};local presentation={};local presentationKey
 local function tint(slate)
  local c=slate.SpecifiedColor
  return{R=c.R,G=c.G,B=c.B,A=c.A}
 end
 function a.snapshot(mapId)
  local c=context();if not c then return Model.snapshot(mapId,'surface',{},'unavailable')end
  local current=object('/Script/DuneSandbox.Default__DuneMapUtilities'):GetDuneMapIdFromWorld(c.pc).Name:ToString()
  -- SPS coordinates belong to the current world. A remote catalog alone does
  -- not prove player discovery and must never be displayed as an explored map.
  if current~=mapId then return Model.snapshot(mapId,'surface',{},'remote-unavailable')end
  local sys=object('/Script/Engine.Default__KismetSystemLibrary')
  local tables=FindFirstOf('DataTablesSubsystem');assert(tables:IsValid(),'Marker table subsystem unavailable')
  local dt=sys:LoadAsset_Blocking(tables.m_MapMarkerTypesDataTable);assert(dt:IsValid(),'Marker styles unavailable')
  local rows={};local styles={}
  -- Discovery payloads are not reflected in SPS. Read the game's own resolved
  -- presentation instead of treating every replicated location as discovered.
  local key=current..'/'..tostring(c.key or c.pc:GetFullName())
  if presentationKey~=key then presentation={};presentationKey=key end
  local native=FindFirstOf('W_FullscreenMap_C')
  if native and native:IsValid() and native:GetOwningPlayer():GetFullName()==c.pc:GetFullName() then
   native.m_MarkersOverlay.m_MarkerWidgets:ForEach(function(_,value)
    local w=value:get();local level=w.m_DiscoveryLevel
    local p={level=level,visible=w:GetVisibility()~=1 and w:GetVisibility()~=2}
    local icon=w.m_MarkerIconPreset
    if level>=2 and icon:IsValid() then
     p.icon=sys:Conv_SoftObjectReferenceToString(icon.m_IconTexture):ToString()
     p.preset=icon.m_IconPresetWidgetName.Name:ToString()
     p.iconTint=tint(icon.m_Icon.Brush.TintColor)
     p.backgroundTint=tint(icon.m_Background.Brush.TintColor)
     local a,b=icon.ColorAndOpacity,w.ColorAndOpacity
     p.tint={R=a.R*b.R,G=a.G*b.G,B=a.B*b.B,A=a.A*b.A}
    end
    presentation[tostring(w:GetMarkerId().m_UniqueId)]=p
   end)
  end
  local incomplete=false;local present={}
  local function style(kind)
   if styles[kind]~=nil then return styles[kind]or nil end
   local r=dt:FindRow(kind);if not r then styles[kind]=false;return end
   local result={label=r.m_MarkerDisplayName:ToString(),icon=sys:Conv_SoftObjectReferenceToString(r.m_IconTexture):ToString(),
    preset=r.m_IconAppearance.Name:ToString(),tag=r.m_MarkerFilterTag.TagName:ToString(),disabled=r.m_bDisableOnFullscreenMap}
   styles[kind]=result;return result
  end
  local function append(m)
   present[tostring(m.m_MarkerId.m_UniqueId)]=true
   local kind=m.m_MarkerType.Name:ToString();local s=style(kind)
   if not s or s.disabled or s.icon=='' or s.preset=='None' or kind=='Player'or kind=='PlayerViewMarker'or kind=='PlayerStart'then return end
   local p=m.m_WorldPosition;local group=category(kind,s.tag)
   local icon,preset,label=s.icon,s.preset,s.label
   local iconTint,backgroundTint,widgetTint
   if group=='place' then
    local known=presentation[tostring(m.m_MarkerId.m_UniqueId)]
    if not known then incomplete=true;return end
    if not known.visible or known.level<2 then return end
    if not known.icon then incomplete=true;return end
    icon,preset=known.icon,known.preset
    iconTint,backgroundTint=known.iconTint,known.backgroundTint
    widgetTint=known.tint
    if known.level==2 then label='Неизвестное место' end
   end
   -- Entries originate in the player's replicated, authorized SPS, not the
   -- complete static POI catalog. Use the already-known type label; do not
   -- reveal undiscovered unique names from the global cache.
   rows[#rows+1]={id=tostring(m.m_MarkerId.m_UniqueId),mapId=current,layerId='surface',X=p.X,Y=p.Y,
    category=group,visible=true,discovered=true,label=label,icon=icon,preset=preset,iconTint=iconTint,backgroundTint=backgroundTint,tint=widgetTint,
    rotation=m.m_RotationRadians,priority=group=='personal'and 80 or(group=='quest'and 70 or(group=='base'and 60 or 10))}
  end
  local component=c.pc.m_PlayerMapMarkerComponent;assert(component:IsValid(),'Player markers unavailable')
  local s=component.m_MapMarkers
  s.m_MarkerMap:ForEach(function(_,value)append(value:get())end)
  Array.each(s.m_ClientDynamicItemCache,function(_,m)append(m)end)
  for id in pairs(presentation)do if not present[id]then presentation[id]=nil end end
  local p=c.pawn:K2_GetActorLocation();local player=style('Player')
  if player then rows[#rows+1]={id='local-player',mapId=current,layerId='surface',category='player',visible=true,
   X=p.X,Y=p.Y,label='Вы',icon=player.icon,preset=player.preset,rotation=c.pawn:K2_GetActorRotation().Yaw*math.pi/180,priority=100}end
  return Model.snapshot(mapId,'surface',rows,incomplete and 'partial' or 'available')
 end
 return a
end
return M
