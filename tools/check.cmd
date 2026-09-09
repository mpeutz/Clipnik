@echo off
rem Load-gate: parses Clipjump.ahk and exits non-zero on any load error.
"%~dp0..\runtime\AutoHotkey64.exe" /ErrorStdOut /validate "%~dp0..\Clipjump.ahk"
