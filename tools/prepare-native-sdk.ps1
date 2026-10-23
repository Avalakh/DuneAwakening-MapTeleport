param([Parameter(Mandatory=$true)][string]$RuntimeDll)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$sdk = Join-Path $root 'work/sdk'
$runtime = (Resolve-Path -LiteralPath $RuntimeDll).Path
if ((Get-FileHash -LiteralPath $runtime).Hash -ne '94C2EBD3CA9F4C4212898D727DF5482937F586771C67502635EBD4367422052A') {
    throw 'Unsupported UE4SS runtime SHA-256; runtime was not modified'
}
$lock = Get-Content (Join-Path $root 'native/sdk-lock.json') -Raw | ConvertFrom-Json
foreach ($header in $lock) {
    if ($header.path -match '(^/|\.\.|:)') {throw 'Invalid SDK header path'}
    $path = Join-Path $sdk ('include/' + $header.path)
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    if (!(Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path).Hash -ne $header.sha256) {
        Invoke-WebRequest -Uri $header.url -OutFile $path
    }
    if ((Get-FileHash -LiteralPath $path).Hash -ne $header.sha256) {throw "Header hash mismatch: $($header.path)"}
}
$compiler = 'C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64'
$exports = & (Join-Path $compiler 'dumpbin.exe') /exports $runtime
if ($LASTEXITCODE) {throw 'dumpbin failed'}
$symbols = $exports | ForEach-Object {
    if ($_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\?\S+)') {$Matches[1]}
}
if (!$symbols) {throw 'No C++ runtime exports found'}
@('LIBRARY UE4SS', 'EXPORTS') + $symbols | Set-Content (Join-Path $sdk 'UE4SS.def')
& (Join-Path $compiler 'lib.exe') /nologo "/def:$sdk/UE4SS.def" /machine:x64 "/out:$sdk/UE4SS.lib"
if ($LASTEXITCODE) {throw 'Import library build failed'}
Write-Output 'Pinned public headers and import library prepared; runtime unchanged.'
