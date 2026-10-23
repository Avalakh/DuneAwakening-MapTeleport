@echo off
setlocal
cd /d "%~dp0.."
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
if not exist work\native mkdir work\native
set "BRIDGE_OUTPUT=mapteleport_native"
if not "%~1"=="" set "BRIDGE_OUTPUT=%~1"
cl /nologo /std:c++20 /utf-8 /EHsc /MD /O2 /W4 /LD /Iwork\sdk\include native\bridge.cpp /Fowork\native\bridge.obj /Fework\native\%BRIDGE_OUTPUT%.dll /link work\sdk\UE4SS.lib bcrypt.lib user32.lib /INCREMENTAL:NO
exit /b %errorlevel%
