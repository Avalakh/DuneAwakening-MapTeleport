package.path='mods/MapTeleport/Scripts/?.lua;'..package.path
local M=require('map_marker_adapter')
local function name(s)return{ToString=function()return s end}end
local function row(label,tag,disabled)return{m_MarkerDisplayName=name(label),m_MarkerFilterTag={TagName=name(tag)},m_IconTexture='icon/'..label,m_IconAppearance={Name=name('native')},m_bDisableOnFullscreenMap=disabled}end
local styles={HomeBase=row('База','MapMarkers.Player.Placeable.Dynamic.HomeBase'),Objective=row('Задание','MapMarkers.Player.Objective'),PersonalMarker=row('Метка','MapMarkers.Player.PersonalMarker'),Shipwreck=row('Крушение','MapMarkers.Location.Static'),Hidden=row('Скрыто','',true),Player=row('Игрок','')}
styles.NoIcon=row('XX_NoIcon','');styles.NoIcon.m_IconTexture=''
local function item(kind,id,x,y)return{m_MarkerType={Name=name(kind)},m_MarkerId={m_UniqueId=id},m_WorldPosition={X=x,Y=y},m_RotationRadians=0}end
local live={item('HomeBase',1,1,2),item('Objective',2,3,4),item('Shipwreck',3,5,6),item('Hidden',4,7,8),item('Missing',5,9,10)}
live[#live+1]=item('NoIcon',7,20,30)
local dynamic={item('PersonalMarker',6,11,12),item('HomeBase',1,1,2)};dynamic.GetArrayNum=function()return #dynamic end
local markerMap={ForEach=function(_,f)for _,v in ipairs(live)do f(nil,{get=function()return v end})end end}
local component={IsValid=function()return true end,m_MapMarkers={m_MarkerMap=markerMap,m_ClientDynamicItemCache=dynamic}}
local c={key='world-1/pawn-1',pc={m_PlayerMapMarkerComponent=component},pawn={K2_GetActorLocation=function()return{X=13,Y=14}end,K2_GetActorRotation=function()return{Yaw=90}end}}
local current='A';local reads=0
local pc=c.pc;pc.GetFullName=function()return 'local-player-controller'end
local discovery=3
local color={SpecifiedColor={R=.2,G=.3,B=.4,A=1}}
local resolvedIcon={IsValid=function()return true end,ColorAndOpacity={R=.5,G=.5,B=.5,A=1},m_IconTexture='icon/resolved',m_IconPresetWidgetName={Name=name('native')},GetIconBrushTintColor=function()return color end,GetBackgroundBrushTintColor=function()return color end}
resolvedIcon.m_Icon={Brush={TintColor=color}};resolvedIcon.m_Background={Brush={TintColor=color}}
local native={IsValid=function()return true end,GetOwningPlayer=function()return pc end,
 m_MarkersOverlay={m_MarkerWidgets={ForEach=function(_,f)f(nil,{get=function()return{
  m_DiscoveryLevel=discovery,ColorAndOpacity={R=.4,G=.4,B=.4,A=1},GetVisibility=function()return 0 end,GetMarkerId=function()return{m_UniqueId=3}end,
  m_MarkerIconPreset=resolvedIcon
 }end})end}}}
local dt={IsValid=function()return true end,FindRow=function(_,k)reads=reads+1;return styles[k]end}
local sys={IsValid=function()return true end,LoadAsset_Blocking=function()return dt end,Conv_SoftObjectReferenceToString=function(_,v)return name(v)end}
StaticFindObject=function(path)if path:find('DuneMapUtilities',1,true)then return{IsValid=function()return true end,GetDuneMapIdFromWorld=function()return{Name=name(current)}end}else return sys end end
FindFirstOf=function(kind)if kind=='W_FullscreenMap_C'then return native end;return{IsValid=function()return true end,m_MapMarkerTypesDataTable='table'}end
local adapter=M.new(function()return c end);local s=adapter.snapshot('A');assert(s.status=='available'and #s.rows==5)
local groups={};for _,r in ipairs(s.rows)do groups[r.category]=true;assert(r.label~=''and r.icon~=''and r.preset=='native')end
for _,group in ipairs({'place','base','quest','personal','player'})do assert(groups[group])end
discovery=2
for _,r in ipairs(adapter.snapshot('A').rows)do if r.category=='place'then assert(r.label=='Неизвестное место' and r.icon=='icon/resolved'and r.preset=='native'and r.iconTint.R==.2 and r.tint.R==.2)end end
discovery=1;assert(#adapter.snapshot('A').rows==4)
discovery=3;adapter.snapshot('A')
local saved=native;native=nil;assert(#adapter.snapshot('A').rows==5,'Previously observed plain discovery survives native widget culling')
c.key='world-2/pawn-1';local partial=adapter.snapshot('A');assert(partial.status=='partial'and #partial.rows==4);native=saved;discovery=3
local before=reads;assert(adapter.snapshot('B').status=='remote-unavailable'and reads==before)
current='B';assert(#adapter.snapshot('A').rows==0)
assert(M.new(function()end).snapshot('A').status=='unavailable')
assert(M.category('Custom','MapMarkers.Contract')=='quest');assert(M.category('Custom','MapMarkers.Player.Placeable.Dynamic')=='base')
print('PASS marker adapter: replicated sources, native labels/icons, five categories, native-disabled/missing styles, deduplication and remote isolation')
