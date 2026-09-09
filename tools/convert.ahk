; Headless wrapper around the mmikeww AHK v1 -> v2 converter.
; Usage: runtime\AutoHotkey64.exe /ErrorStdOut tools\convert.ahk <input.ahk> <output.ahk>
; Output is a first draft only. Every converted file is hand-merged before use.
#Requires AutoHotkey >=2.0-<2.1
#SingleInstance Off
SetWorkingDir A_ScriptDir "\converter"
global dbg := 0
global gFilePath := ""
#Include converter\ConvertFuncs.ahk

if A_Args.Length < 2 {
    FileAppend "usage: convert.ahk <input> <output>`n", "*"
    ExitApp 1
}
src := FileRead(A_Args[1])
src := RegExReplace(src, "(?m)(?<!\r)\n", "`r`n")
out := Convert(src)
f := FileOpen(A_Args[2], "w", "utf-8-raw")
f.Write(out)
f.Close()
ExitApp 0
