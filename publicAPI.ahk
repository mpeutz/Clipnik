; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
/*

This function file helps any AHK v2 script to use Clipnik API functions from its side.
Just include this file in your script.

Note that API.text2binary() is not supported currently.
The ClipnikCommunicator.ahk file is already included in this file.

v 15.5.17 (AutoHotkey v2 port)

*/

/*
EXAMPLES

cnk := Clipnik()

cnk.IncognitoMode(1)
cnk.pasteText("some text")
MsgBox cnk.getClipLoc(1, 5)
cnk.Paste("","")
cnk["CALLER"] := 0
cnk["STORE.somevar"] := "abc value"
MsgBox cnk.getVar("version")
MsgBox cnk.version

*/

;cnk := Clipnik()
;cnk.runFunction("set_pformat(NO-FORMATTING)")
;cnk.getClipAt(0, 7)
;MsgBox cnk.author_page

class Clipnik
{
	__New() {
	}

	; any unknown method call is forwarded to Clipnik's API class over WM_COPYDATA
	__Call(funcname, parameters) {
		cbF := A_Temp "\cjcb.txt"
		rFuncs := "|getClipAt|getClipLoc|getVar|runFunction|"

		resChar := "`r"
		ps := ""
		for val in parameters
		{
			val := StrReplace(val, "`r`n", "`n")
			val := StrReplace(val, "`r", "`n")
			ps .= resChar val
		}
		try FileDelete(cbF)
		returned := CjControl("API:" funcname ps)
		if (returned > 0) && InStr(rFuncs, "|" funcname "|")
		{
			Clipnik_wait4file()
			out := FileRead(cbF)
			try FileDelete(cbF)
			return out
		}
		else
			return ""
	}

	/*
	Use -
		cnk := Clipnik()
		MsgBox cnk.version
	*/
	__Get(var, params) {
		return this.getVar(var)
	}

	/*
	Use -
		cnk := Clipnik()
		cnk["pastemodekey.z"] := "y"
		cnk.MYVAR := "value"
	*/
	__Set(var, params, value) {
		this.setVar(var, value)
	}

	; cnk["STORE.somevar"] := "abc" / x := cnk["version"]
	__Item[var] {
		get => this.getVar(var)
		set => this.setVar(var, value)
	}

	;-----------------------------------------------------------------------------------------
	;------------------------------------------- END -----------------------------------------
	;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
}

; the class's name before the rename, so scripts that call Clipjump() keep working
class Clipjump extends Clipnik {
}

Clipnik_wait4file() {
	while !FileExist(A_Temp "\cjcb.txt")
		Sleep 15
}


;---------------------- Clipnik Communicator.ahk ---------------------------------------------

CjControl(Code)
{
	if !(IsExe := CjControl_check())
		return -1       ;Clipnik doesn't exist

	TargetScriptTitle := "Clipnik" (IsExe == 1 ? ".ahk ahk_class AutoHotkey" : ".exe ahk_class AutoHotkey")

	CopyDataStruct := Buffer(3 * A_PtrSize, 0)
	SizeInBytes := (StrLen(Code) + 1) * 2
	NumPut("UPtr", SizeInBytes, CopyDataStruct, A_PtrSize)
	NumPut("Ptr", StrPtr(Code), CopyDataStruct, 2 * A_PtrSize)
	Prev_DetectHiddenWindows := A_DetectHiddenWindows
	Prev_TitleMatchMode := A_TitleMatchMode
	DetectHiddenWindows true
	SetTitleMatchMode 2
	Z := 0

	while !Z
	{
		try Z := SendMessage(0x4a, 0, CopyDataStruct, , TargetScriptTitle)
		catch
			Z := 0
		if A_Index > 100
			return -1 ;Timeout..
	}

	DetectHiddenWindows Prev_DetectHiddenWindows
	SetTitleMatchMode Prev_TitleMatchMode

	while !FileExist(A_Temp "\clipnikcom.txt")
	{
		if (A_Index > 40)		;2 secs total
			if !CjControl_check()
				return -1
		Sleep 50
	}
	try FileDelete(A_Temp "\clipnikcom.txt")

	return 1        ;True
}

CjControl_check() {
	HW := A_DetectHiddenWindows, TM := A_TitleMatchMode
	DetectHiddenWindows true
	SetTitleMatchMode 2
	A := WinExist("\Clipnik.ahk - ahk_class AutoHotkey")
	E := WinExist("\Clipnik.exe - ahk_class AutoHotkey")
	DetectHiddenWindows HW
	SetTitleMatchMode TM

	return A ? 1 : (E ? 2 : 0)
}
