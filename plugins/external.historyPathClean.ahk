;@Plugin-Name History file paths cleaner
;@Plugin-Description Cleans History tool of copied file paths and folder paths.
;@Plugin-Author Avi
;@Plugin-version 0.1
;@Plugin-Tags history cleaning
#Requires AutoHotkey v2.0

historypath := A_ScriptDir "\..\cache\history\"
SetWorkingDir(historypath)
z := 0

loop files "*.txt"
{
	var := FileRead(A_LoopFileName)
	match := 1
	loop parse var, "`n", "`r"
		if !RegExMatch(A_LoopField, 'i)^[A-Z]:\[^\*\?"\|]*$')
			match := 0
	if match {
		FileDelete(A_LoopFileName)
		z++
	}
}

MsgBox("Cleaned " z " Items from the History.")
