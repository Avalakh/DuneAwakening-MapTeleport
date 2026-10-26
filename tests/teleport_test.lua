local root='mods/MapTeleport/Scripts/'
local T=assert(loadfile(root..'teleport.lua'))()
local G=assert(loadfile(root..'geometry.lua'))()
local count=0
local function test(name,f) f();count=count+1;print('PASS '..name) end
local function fixture()
    local f={time=0, key='world/player', markerPos={X=100,Y=200,Z=0},
        readyValue=true, stable=true, moves=0, restores=0, releases=0, messages={}}
    local a={}
    function a.context() if f.absent then return nil,'unavailable' end;return {key=f.key,world='world',pcId='pc'} end
    function a.eligible() return not f.ineligible, f.ineligible end
    function a.marker() if not f.markerPos then return nil,'no-marker' end; return G.copy(f.markerPos) end
    function a.snapshot() return {position={X=0,Y=0,Z=92}} end
    function a.now() return f.time end
    function a.prepare(_,job) job.resources[1]='owned';if f.prepareError then error('prepare failed') end end
    function a.ready() return f.readyValue end
    function a.destination(_,job) if f.invalid then return nil,'steep-surface' end;return {X=job.marker.X,Y=job.marker.Y,Z=142} end
    function a.move() f.moves=f.moves+1;if f.moveError then error('partial move') end;return true end
    function a.restore() f.restores=f.restores+1;return not f.restoreFailure end
    function a.verify(_,_,restoring) if restoring then return not f.restoreUnstable,'restore-unstable' end;return f.stable,'no-support' end
    function a.release(job) assert(job.resources[1]=='owned');f.releases=f.releases+1;if f.releaseError then error('release failed') end end
    function a.message(code) f.messages[#f.messages+1]=code end
    f.t=T.new(a)
    function f.tick(delta) f.time=f.time+delta;f.t:tick() end
    return f
end

test('marker snapshot remains fixed and second request stays busy',function()
    local f=fixture();f.t:request();f.markerPos.X=999;f.t:request();f.tick(0.1)
    assert(f.t.job.destination.X==100 and f.moves==1 and f.t.sequence==1)
    f.tick(2.99);assert(f.t.job);f.tick(0.02)
    assert(not f.t.job and f.releases==1 and f.messages[#f.messages]=='success')
end)
test('missing marker never prepares or moves',function()
    local f=fixture();f.markerPos=nil;f.t:request();assert(not f.t.job and f.moves==0 and f.releases==0)
end)
test('timeout releases resources without moving',function()
    local f=fixture();f.readyValue=false;f.t:request();f.tick(14.99);assert(f.t.job);f.tick(0.01)
    assert(not f.t.job and f.moves==0 and f.releases==1 and f.messages[#f.messages]=='timeout')
end)
test('new world cancels before touching stale adapter objects',function()
    local f=fixture();f.t:request();f.key='new-world/new-player';f.tick(1)
    assert(not f.t.job and f.moves==0 and f.restores==0 and f.releases==1)
end)
test('death cancels without moving a dead character',function()
    local f=fixture();f.t:request();f.ineligible='dead';f.tick(1);assert(f.moves==0 and f.restores==0 and f.releases==1)
end)
test('a different character cancels once and late ticks never touch the expired job',function()
 local f=fixture();f.t:request();f.key='world/new-player';f.tick(0.1)
 assert(not f.t.job and f.moves==0 and f.restores==0 and f.releases==1)
 f.t.a.context=function()error('Expired callback touched engine objects')end
 for i=1,20 do f.tick(0.1)end
 assert(f.releases==1)
end)
test('prepare exception releases partially acquired resources',function()
    local f=fixture();f.prepareError=true;f.t:request();assert(not f.t.job and f.releases==1)
end)
test('bad surface cancels before move',function()
    local f=fixture();f.invalid=true;f.t:request();f.tick(0.1);assert(f.moves==0 and f.releases==1)
end)
test('a rejected surface releases its request and a fresh safe request succeeds',function()
 local f=fixture();f.invalid=true;f.t:request();f.tick(.1)
 assert(not f.t.job and not f.t.disabled and f.moves==0 and f.releases==1)
 f.invalid=false;f.markerPos={X=300,Y=400,Z=0};assert(f.t:request());f.tick(.1);f.tick(3.1)
 assert(not f.t.job and not f.t.disabled and f.moves==1 and f.releases==2 and f.t.sequence==2 and f.messages[#f.messages]=='success')
end)
test('lost support restores once and checks restoration for three seconds',function()
    local f=fixture();f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1)
    assert(f.restores==1 and f.t.job.state=='Restore');f.tick(2.99);assert(f.t.job);f.tick(0.02)
    assert(not f.t.job and f.releases==1 and f.messages[#f.messages]=='restored')
end)
test('partial move exception also restores',function()
    local f=fixture();f.moveError=true;f.t:request();f.tick(0.1);assert(f.moves==1 and f.restores==1)
end)
test('failed restoration disables further requests',function()
    local f=fixture();f.restoreFailure=true;f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1)
    assert(not f.t.job and f.t.disabled and f.releases==1);f.t:request();assert(f.moves==1)
end)
test('unstable restored position is an unresolved defect',function()
    local f=fixture();f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1);f.restoreUnstable=true;f.tick(0.1)
    assert(f.t.disabled and f.messages[#f.messages]=='restore-failed')
end)
test('cleanup failure disables further requests',function()
    local f=fixture();f.releaseError=true;f.t:request();f.tick(0.1);f.tick(3.1)
    assert(f.t.disabled and f.messages[#f.messages]=='cleanup-failed')
end)

test('handoff keeps origin resources until three seconds after temporary target support is released',function()
    local f=fixture();local handed=0
    f.t.a.handoff=function() handed=handed+1 end
    f.t:request();f.tick(0.1);f.tick(3.01)
    assert(handed==1 and f.t.job.state=='VerifyReleased' and f.releases==0)
    f.tick(2.99);assert(f.t.job);f.tick(0.02)
    assert(not f.t.job and f.releases==1 and f.messages[#f.messages]=='success')
end)

test('lost normal support after handoff restores the retained origin',function()
    local f=fixture();f.t.a.handoff=function()end
    f.t:request();f.tick(0.1);f.tick(3.01);f.stable=false;f.tick(0.1)
    assert(f.restores==1 and f.t.job.state=='Restore' and f.releases==0)
end)

test('partial handoff exception restores before releasing origin resources',function()
    local f=fixture();f.t.a.handoff=function()error('handoff failed')end
    f.t:request();f.tick(0.1);f.tick(3.01)
    assert(f.restores==1 and f.t.job.state=='Restore' and f.releases==0)
end)

test('rollback waits for the original floor instead of accepting a lower underground hit',function()
    local f=fixture();local ready=false;local maintained=0
    f.t.a.restoreReady=function()return ready end
    f.t.a.maintain=function()maintained=maintained+1 end
    f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1)
    assert(f.t.job.state=='RestorePrepare' and f.restores==0 and f.releases==0)
    f.tick(2);assert(f.restores==0 and maintained>0)
    ready=true;f.tick(0.1);assert(f.restores==1 and f.t.job.state=='Restore')
    f.tick(3.01);assert(f.messages[#f.messages]=='restored')
end)

test('unavailable original floor times out without a blind rollback',function()
    local f=fixture();f.t.a.restoreReady=function()return false end
    f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1);f.tick(15)
    assert(f.restores==0 and f.t.disabled and not f.t.job)
end)

test('handoff waits for actual unload and then observes normal support for three seconds',function()
    local f=fixture();local unloaded=false
    f.t.a.handoff=function()end;f.t.a.handoffReady=function()return unloaded end
    f.t:request();f.tick(0.1);f.tick(3.1);assert(f.t.job.state=='Handoff')
    f.tick(1);assert(f.t.job.state=='Handoff'and f.releases==0)
    unloaded=true;f.tick(0.1);assert(f.t.job.state=='VerifyReleased')
    f.tick(3.1);assert(not f.t.job and f.messages[#f.messages]=='success')
end)

test('rollback also checks normal support after releasing its temporary floor',function()
    local f=fixture();f.t.a.handoff=function()end;f.t.a.handoffReady=function()return true end
    f.t:request();f.tick(0.1);f.stable=false;f.tick(0.1);f.tick(3.1)
    assert(f.t.job.state=='RestoreHandoff'and f.releases==0)
    f.tick(0.1);assert(f.t.job.state=='RestoreReleased')
    f.tick(3.1);assert(not f.t.job and f.messages[#f.messages]=='restored')
end)

test('cancelled preparation remains busy until asynchronous cleanup finishes',function()
    local f=fixture();local unloaded=false
    f.t.a.release=function()f.releases=f.releases+1;return false end
    f.t.a.releaseReady=function()return unloaded end
    f.invalid=true;f.t:request();f.tick(0.1);assert(f.t.job.state=='Cleanup')
    f.t:request();assert(f.messages[#f.messages]=='busy')
    f.tick(1);assert(f.t.job)
    unloaded=true;f.tick(0.1);assert(not f.t.job and f.messages[#f.messages]=='cancelled'and f.releases==1)
end)
test('resolution exceptions never acquire resources or move the character',function()
 for _,stage in ipairs({'eligible','marker','snapshot','now'})do
  local f=fixture();f.t.a[stage]=function()error(stage..' failure')end
  f.t:request();assert(not f.t.job and f.moves==0 and f.releases==0 and f.messages[#f.messages]=='unavailable')
 end
end)

test('preparation query exceptions release resources before any move',function()
 for _,stage in ipairs({'ready','destination'})do
  local f=fixture();f.t.a[stage]=function()error(stage..' failure')end
  f.t:request();f.tick(0.1)
  assert(not f.t.job and f.moves==0 and f.releases==1)
 end
end)

test('a restoration maintenance exception cannot escape and runs cleanup',function()
 local f=fixture()
 f.t:request();f.tick(0.1)
 f.t.a.maintain=function()error('maintenance failed')end
 f.tick(0.1)
 assert(not f.t.job and f.t.disabled and f.restores==0 and f.releases==1)
end)

test('cleanup timeout removes the input restriction even when unloading never completes',function()
 local f=fixture();local unlocked=0
 f.t.a.release=function()return false end
 f.t.a.releaseReady=function()return false end
 f.t.a.releaseRestrictions=function()unlocked=unlocked+1 end
 f.t:request();f.tick(0.1);f.tick(3.1);f.tick(15.1)
 assert(not f.t.job and f.t.disabled and unlocked==1 and f.messages[#f.messages]=='cleanup-failed')
end)

test('cleanup exceptions still attempt to remove their own input restriction',function()
 local f=fixture();local unlocked=0;f.releaseError=true
 f.t.a.releaseRestrictions=function()unlocked=unlocked+1 end
 f.t:request();f.tick(0.1);f.tick(3.1)
 assert(not f.t.job and f.t.disabled and unlocked==1)
end)

test('surface and capsule validation use centimetres',function()
    local p=assert(G.destination({X=10,Y=20,Z=100},{X=0,Y=0,Z=1},36,92,0.64))
    assert(p.Z==242);assert(not G.destination({X=0,Y=0,Z=0},{X=0,Y=1,Z=0.3},36,92,0.64))
    assert(not G.destination({X=0/0,Y=0,Z=0},{X=0,Y=0,Z=1},36,92,0.64))
    assert(not G.destination({X=0,Y=0,Z=0},{X=0,Y=0,Z=1},100,92,0.64))
end)
test('surface hits reject an initial overlap even with an upward normal and zero penetration depth',function()
 local h={Time=.5,Distance=100,PenetrationDepth=0,ImpactPoint={X=0,Y=0,Z=10},ImpactNormal={X=0,Y=0,Z=1},bStartPenetrating=true}
 assert(G.surfaceHit(h),'packed bitfield alone must not reject a measured floor')
 h.Time=0;h.Distance=0;local ok,why=G.surfaceHit(h);assert(not ok and why=='initial-overlap')
 h.Time=.5;h.Distance=100;h.PenetrationDepth=1;assert(not G.surfaceHit(h))
 h.PenetrationDepth=0;h.Distance=0/0;assert(not G.surfaceHit(h))
 h.Distance=nil;assert(not G.surfaceHit(h))
end)
test('streaming bounds account for rotation translation and scale',function()
    local s=math.sqrt(0.5)
    local t={Translation={X=100,Y=200,Z=300},Rotation={X=0,Y=0,Z=s,W=s},Scale3D={X=2,Y=3,Z=1}}
    local b=G.bounds2(t,{Min={X=-1,Y=-2,Z=-3},Max={X=1,Y=2,Z=3}})
    local original={X=1,Y=2,Z=3};local restored=G.inverseTransform(t,G.transform(t,original))
    assert(math.abs(restored.X-original.X)<1e-9 and math.abs(restored.Y-original.Y)<1e-9 and math.abs(restored.Z-original.Z)<1e-9)
    assert(math.abs(b.minX-94)<1e-9 and math.abs(b.maxY-202)<1e-9)
    assert(G.contains(b,{X=100,Y=200}) and not G.contains(b,{X=110,Y=200}))
end)
print(count..' tests passed')
