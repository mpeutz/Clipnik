# Launches Clipnik on the v2 runtime, waits, then reports process state, stdout/stderr and any dialog text.
param([int]$wait = 8)
$p = Start-Process -FilePath ".\runtime\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut","Clipnik.ahk" -WorkingDirectory (Get-Location) -PassThru -RedirectStandardOutput "$env:TMP\cj\run.out" -RedirectStandardError "$env:TMP\cj\run.err"
Start-Sleep $wait
"running=" + (-not $p.HasExited) + " exit=" + $p.ExitCode
Get-Content "$env:TMP\cj\run.out" -ErrorAction SilentlyContinue
Get-Content "$env:TMP\cj\run.err" -ErrorAction SilentlyContinue
powershell -NoProfile -File tools\dialogs.ps1
