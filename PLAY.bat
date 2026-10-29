@echo off
setlocal

rem ===========================================================
rem  Blind in the Faint Light -- vertical slice launcher
rem
rem  Double-click to play. Starts at the TITLE SCREEN (full campaign:
rem  5 missions, support conversations, settings). Opens at 1440x810 (3x the 480x270
rem  native resolution) because at 1x the window is postage-
rem  stamp sized on a modern display. Integer scaling is on,
rem  so pixel edges stay hard at 3x.
rem
rem  ASCII only, on purpose: cmd.exe mis-parses non-ASCII batch
rem  files depending on the machine's console code page, and
rem  this file is meant to be handed to other people. Chinese
rem  on-screen guidance lives in the game itself.
rem
rem  Before launching it runs a one-off headless --import, so scripts
rem  added since the last run are registered (without it a fresh or
rem  outdated checkout can fail with "Identifier not declared").
rem  2026-10-28: changed from launching BattleScreen.tscn directly
rem  (which skipped title, campaign and support conversations).
rem
rem  Finding Godot (2026-10-29: used to check only two places, so an
rem  engine installed anywhere else made double-click fail). First hit wins:
rem    0. environment variable GODOT_BIN, if set and the file exists
rem    1. the Downloads folder of the current user (exact path)
rem    2. C:\Godot (searched including subfolders)
rem    3. LOCALAPPDATA\Programs\Godot (searched including subfolders)
rem    4. ProgramFiles\Godot (searched including subfolders)
rem    5. system PATH: Godot_v4.7.1-stable_win64.exe, then godot.exe
rem  Folders 2-4 are searched only for the exact name
rem  Godot_v4.7.1-stable_win64.exe. The whole C: drive is never searched.
rem  A godot.exe found on PATH is accepted without checking its version.
rem  The non-console build is used on purpose: the _console build opens
rem  a second black window next to the game.
rem
rem  Requires Godot 4.7.1 AND a full checkout of this project.
rem  To hand the game to someone without Godot, an exported
rem  standalone build is needed instead (export templates must
rem  be installed first).
rem ===========================================================

set "PROJ=%~dp0"
set "RES=1440x810"
set "GODOT_NAME=Godot_v4.7.1-stable_win64.exe"

rem ---- DETECT-BEGIN: find the engine. No labels, no goto, no blocks, so this range can be run on its own. ----
set "GODOT="
if defined GODOT_BIN if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"
if not defined GODOT if exist "%USERPROFILE%\Downloads\%GODOT_NAME%\%GODOT_NAME%" set "GODOT=%USERPROFILE%\Downloads\%GODOT_NAME%\%GODOT_NAME%"
if not defined GODOT for /r "C:\Godot" %%F in (%GODOT_NAME%) do if not defined GODOT if exist "%%F" set "GODOT=%%F"
if not defined GODOT for /r "%LOCALAPPDATA%\Programs\Godot" %%F in (%GODOT_NAME%) do if not defined GODOT if exist "%%F" set "GODOT=%%F"
if not defined GODOT for /r "%ProgramFiles%\Godot" %%F in (%GODOT_NAME%) do if not defined GODOT if exist "%%F" set "GODOT=%%F"
if not defined GODOT for %%G in (%GODOT_NAME% godot.exe) do if not defined GODOT if not "%%~$PATH:G"=="" set "GODOT=%%~$PATH:G"
rem ---- DETECT-END ----

if not defined GODOT goto :no_godot
if not exist "%PROJ%project.godot" goto :no_project

echo.
echo   Blind in the Faint Light
echo.
echo   Engine: %GODOT%
echo.
echo   Importing project files ^(first time may take a minute^) ...
"%GODOT%" --headless --path "%PROJ%." --import
if errorlevel 1 (
    echo.
    echo   [Import failed] See the messages above. Please report them.
    echo.
    pause
    exit /b 1
)
echo.
echo   Window %RES%  ^(480x270 native, 3x integer scale^)
echo.
echo   Keyboard: Arrows = cursor   Enter/Space = confirm   Esc = cancel
echo             C = hand   M = menu ^(end turn is in here^)   Q = end unit turn
echo             Tab / Shift+Tab = next / prev target
echo             X = guess marker ^(enable it in Settings first^)   R = relation map
echo   Gamepad : D-pad = cursor   A = confirm   B = cancel   X = hand
echo             Start = menu   Back = end unit turn   RB / LB = next / prev target
echo             Y = guess marker   Right stick click = relation map
echo   Mouse   : move = cursor   Left click = confirm
echo.
echo   Close the game window to quit.
echo.

"%GODOT%" --path "%PROJ%." --resolution %RES%
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
echo   Searched, in this order:
if defined GODOT_BIN echo     0. GODOT_BIN=%GODOT_BIN%  ^(file does not exist^)
if not defined GODOT_BIN echo     0. GODOT_BIN environment variable  ^(not set^)
echo     1. %USERPROFILE%\Downloads\%GODOT_NAME%\
echo     2. C:\Godot\  ^(including subfolders^)
echo     3. %LOCALAPPDATA%\Programs\Godot\  ^(including subfolders^)
echo     4. %ProgramFiles%\Godot\  ^(including subfolders^)
echo     5. system PATH: %GODOT_NAME% or godot.exe
echo.
echo   Godot 4.7.1 is required. Portable build:
echo     https://godotengine.org/download/windows/
echo   Then do ONE of these and run this file again:
echo     - unzip %GODOT_NAME% into any folder listed above
echo     - add it to PATH
echo     - set environment variable GODOT_BIN to its full path
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
