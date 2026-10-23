@echo off
setlocal
cd /d "%~dp0.."
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
if not exist work\lua mkdir work\lua
type nul >work\lua\sources.rsp
for %%f in (work\sdk\lua-5.4.8\src\*.c) do if /I not "%%~nxf"=="luac.c" echo "%%f">>work\lua\sources.rsp
cl /nologo /O2 /MD /D_CRT_SECURE_NO_WARNINGS /Iwork\sdk\lua-5.4.8\src /Fework\lua\lua.exe /Fowork\lua\ @work\lua\sources.rsp
exit /b %errorlevel%
