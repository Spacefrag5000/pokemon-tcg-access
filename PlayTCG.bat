@echo off
rem Pokemon Trading Card Game blind accessibility mod by Spacefrag5000.
rem Starts BizHawk with your game file and the mod running.
rem Any problem is shown in a message box, so your screen reader reads it.
setlocal
cd /d "%~dp0"
set "MOD=%~dp0"

rem Find BizHawk: one folder up (the readme's layout), or this same folder.
set "BH="
if exist "%MOD%..\EmuHawk.exe" for %%d in ("%MOD%..") do set "BH=%%~fd\"
if exist "%MOD%EmuHawk.exe" set "BH=%MOD%"
if not defined BH goto nobizhawk
if not exist "%BH%dll\prism.dll" goto nospeech

rem Find the game file: in this folder first, then in the BizHawk folder.
set "ROM="
for %%f in ("%MOD%*.gbc") do if not defined ROM set "ROM=%%~ff"
if not defined ROM for %%f in ("%BH%*.gbc") do if not defined ROM set "ROM=%%~ff"
if not defined ROM goto nogame

start "" /d "%BH%" "%BH%EmuHawk.exe" "%ROM%" --lua="%MOD%tcg_access.lua"
exit /b

:nobizhawk
set "TCG_MSG=BizHawk was not found. Put the poketcg-access folder inside your BizHawk folder, so that EmuHawk.exe is one folder up from PlayTCG.bat. Or put the mod's files straight into your BizHawk folder, next to EmuHawk.exe."
goto tell

:nospeech
set "TCG_MSG=This BizHawk has no speech support: there is no prism.dll in its dll folder. Use Amethyst's accessible BizHawk. The readme says where to download it."
goto tell

:nogame
set "TCG_MSG=No game file found. Put your Pokemon Trading Card Game file, ending in .gbc, in this folder: %MOD% If the game file is still inside a zip file, unzip it first."
goto tell

:tell
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($env:TCG_MSG, 'Pokemon TCG accessibility mod', 'OK', 'Warning')"
if errorlevel 1 set TCG_MSG
if errorlevel 1 pause
exit /b
