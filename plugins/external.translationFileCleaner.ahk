; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;@Plugin-Name Translation File Cleaner
;@Plugin-Description Finds extra and duplicate keys in translation files and shows them
;@Plugin-Author Avi
;@Plugin-version 0.1
;@Plugin-Tags translation maintenance

;@Plugin-param1 The language file name to look in (without the .txt)
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\publicAPI.ahk


projectDir := A_WorkingDir

fstr := FileRead("Clipjump.ahk")

loop files "lib\*.ahk"
	fstr .= "`n" FileRead(A_LoopFileFullPath)

; MANAGING ARGUMENT
F := A_Args.Length ? A_Args[1] : ""
if (F == "") ; if no argument passed
	ExitApp

F := "languages\" F ".txt"
if !FileExist(F) {
	MsgBox("Translation file not found.")
	ExitApp
}

kobj := Map()
err := "", dup := ""

loop read F
{
	m := Trim(A_LoopReadLine)
	if ((InStr(m, ";") == 1) || (InStr(m, "=") == 1) || !m)
		continue
	k := Trim(SubStr(m, 1, InStr(m, "=") - 1))
	if !InStr(fstr, k)
		err .= k "`n"
	if !kobj.Has(k)
		kobj[k] := 0
	else
		dup .= k "`n"
}

cj := Clipjump()
str := '"INVALIDS`n`n' err '`n`nDUPLICATES`n`n' dup '"'
fstr := 'guiMsgBox("Translation File Cleaner Results",' str ")"
cj.runFunction(fstr)
