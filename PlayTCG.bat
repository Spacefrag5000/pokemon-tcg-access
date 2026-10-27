@echo off
rem Pokemon Trading Card Game blind accessibility mod by Spacefrag5000.
rem Starts BizHawk (one folder up) with the game file in this folder and the mod.
cd /d "%~dp0"
set "ROM="
for %%f in (*.gbc) do if not defined ROM set "ROM=%%~ff"
if not defined ROM (
  echo No game file found. Put your Pokemon Trading Card Game file, ending in .gbc, in this folder.
  pause
  exit /b
)
if not exist "..\EmuHawk.exe" (
  echo BizHawk not found. Put this folder inside your BizHawk folder, next to EmuHawk.exe.
  pause
  exit /b
)
start "" /d ".." "..\EmuHawk.exe" "%ROM%" --lua="%~dp0tcg_access.lua"
