@echo off
setlocal

rem ===========================================================
rem  Blind in the Faint Light -- vertical slice launcher
rem
rem  Double-click to play. Opens at 1440x810 (3x the 480x270
rem  native resolution) because at 1x the window is postage-
rem  stamp sized on a modern display. Integer scaling is on,
rem  so pixel edges stay hard at 3x.
rem
rem  ASCII only, on purpose: cmd.exe mis-parses non-ASCII batch
rem  files depending on the machine's console code page, and
rem  this file is meant to be handed to other people. Chinese
rem  on-screen guidance lives in the game itself.
rem
rem  Requires Godot 4.7.1 AND a full checkout of this project.
rem  To hand the game to someone without Godot, an exported
rem  standalone build is needed instead (export templates must
rem  be installed first).
rem ===========================================================

set "PROJ=%~dp0"
set "SCENE=res://src/ui/battle/BattleScreen.tscn"
set "RES=1440x810"

set "GODOT="
if exist "%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not defined GODOT for %%G in (godot.exe) do if not "%%~$PATH:G"=="" set "GODOT=%%~$PATH:G"

if not defined GODOT goto :no_godot
if not exist "%PROJ%project.godot" goto :no_project

echo.
echo   Blind in the Faint Light -- vertical slice
echo   Window %RES%  ^(480x270 native, 3x integer scale^)
echo.
echo   Keyboard : Arrows = cursor,  Enter/Space = confirm,  Esc = end turn
echo   Gamepad  : D-pad  = cursor,  A = confirm,            B   = end turn
echo   Mouse    : move   = cursor,  Left click = confirm
echo.
echo   Close the game window to quit.
echo.

"%GODOT%" --path "%PROJ%." --resolution %RES% "%SCENE%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo   Game exited with code %RC%. If you did not close it yourself,
    echo   please report this together with the messages above.
    echo.
    pause
)
goto :eof

:no_godot
echo.
echo   [Godot not found]
echo.
echo   Looked in:
echo     1. %USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\
echo     2. godot.exe on the system PATH
echo.
echo   Godot 4.7.1 is required. Portable build:
echo     https://godotengine.org/download/windows/
echo   Unzip to path 1 above, or add it to PATH, then run this again.
echo.
pause
exit /b 1

:no_project
echo.
echo   [Project not found] This file must sit next to project.godot.
echo   Current location: %PROJ%
echo.
pause
exit /b 1
