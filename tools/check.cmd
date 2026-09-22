@echo off
rem Load-gate: parses Clipnik.ahk and exits non-zero on any load error.
"%~dp0..\runtime\AutoHotkey64.exe" /ErrorStdOut /validate "%~dp0..\Clipnik.ahk"
