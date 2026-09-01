$ErrorActionPreference = "Continue"
$godotExe = "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
$projDir  = "C:/Users/felixfu007/Documents/Claude-Code-Game-Studios/prototypes/adr0005-engine-probes-2026-09-01"
$logFile  = "$projDir/logs/probe10_windowed.txt"
$errFile  = "$projDir/logs/probe10_windowed.err.txt"

$godotProc = Start-Process -FilePath $godotExe -ArgumentList @("--path", $projDir, "scenes/Probe10FocusTiming.tscn") -RedirectStandardOutput $logFile -RedirectStandardError $errFile -PassThru

Start-Sleep -Seconds 3

$npProc = Start-Process notepad.exe -PassThru
Start-Sleep -Seconds 2

$wshell = New-Object -ComObject WScript.Shell
$activated1 = $wshell.AppActivate($npProc.Id)
Start-Sleep -Seconds 3

$backOk1 = $wshell.AppActivate("AdrProbe10Window")
Start-Sleep -Seconds 3

$activated2 = $wshell.AppActivate($npProc.Id)
Start-Sleep -Seconds 3

$backOk2 = $wshell.AppActivate("AdrProbe10Window")
Start-Sleep -Seconds 3

if ($npProc -and -not $npProc.HasExited) { Stop-Process -Id $npProc.Id -Force -ErrorAction SilentlyContinue }

Write-Output "activated1(byPID)=$activated1 backOk1=$backOk1 activated2(byPID)=$activated2 backOk2=$backOk2"

$exited = $godotProc.WaitForExit(30000)
if (-not $exited) {
    Write-Output "GODOT DID NOT EXIT IN TIME — killing"
    Stop-Process -Id $godotProc.Id -Force -ErrorAction SilentlyContinue
} else {
    Write-Output "GODOT EXITED with code $($godotProc.ExitCode)"
}
