@echo off
setlocal
cd /d "%~dp0.."
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
if not exist work\native mkdir work\native
cl /nologo /std:c++20 /utf-8 /EHsc /MD /O2 /W4 native\input_test.cpp /Fowork\native\input_test.obj /Fework\native\input_test.exe /link user32.lib
if errorlevel 1 exit /b 1
work\native\input_test.exe
exit /b %errorlevel%
