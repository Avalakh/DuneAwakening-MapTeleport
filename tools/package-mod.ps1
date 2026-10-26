param([string]$OutputDirectory = "$PSScriptRoot/../dist")
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$sourceRoot = Join-Path $projectRoot 'mods/MapTeleport'
$manifest = Get-Content -LiteralPath (Join-Path $sourceRoot 'mod.json') -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 2 -or $manifest.id -ne 'MapTeleport' -or $manifest.type -ne 'lua') { throw 'Invalid manifest' }
if ($manifest.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version' }
if (@($manifest.requires | Where-Object id -eq 'ue4ss')[0].version -ne '3.0.1-1140-gf58e8f84') { throw 'Unqualified UE4SS dependency' }
if (@($manifest.requires | Where-Object { $_.id -notin @('wps-launcher','ue4ss') }).Count) { throw 'Unexpected dependency' }
$files = @(
    'mod.json','README.md','Scripts/geometry.lua','Scripts/main.lua',
    'Scripts/map_adapter.lua','Scripts/runtime.lua','Scripts/teleport.lua','Scripts/placement_search.lua',
    'Scripts/application.lua','Scripts/input_owner.lua','Scripts/map_profiles.lua',
    'Scripts/map_projection.lua','Scripts/map_canvas.lua','Scripts/map_view_adapter.lua','Scripts/teleport_window.lua',
    'Scripts/region_catalog.lua','Scripts/region_selection.lua','Scripts/region_travel.lua','Scripts/travel_adapter.lua'
) | Sort-Object
foreach ($relative in $files) { if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $relative) -PathType Leaf)) { throw "Missing $relative" } }
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$zipPath = Join-Path $outputRoot ("MapTeleport-{0}.zip" -f $manifest.version)
$stream = [IO.File]::Open($zipPath,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite)
$archive = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try {
    foreach ($relative in $files) {
        $entry = $archive.CreateEntry("MapTeleport/$relative",[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [datetimeoffset]'2000-01-01T00:00:00Z'
        $output = $entry.Open()
        $input = [IO.File]::OpenRead((Join-Path $sourceRoot $relative))
        try { $input.CopyTo($output) } finally { $input.Dispose(); $output.Dispose() }
    }
} finally { $archive.Dispose() }
$check = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $expected = @($files | ForEach-Object { "MapTeleport/$_" })
    $actual = @($check.Entries | ForEach-Object FullName)
    if (@(Compare-Object $expected $actual).Count) { throw 'Archive layout mismatch' }
} finally { $check.Dispose() }
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText("$zipPath.sha256", "$hash  $([IO.Path]::GetFileName($zipPath))`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{ path=$zipPath; sha256=$hash; files=$files.Count; version=$manifest.version } | ConvertTo-Json
