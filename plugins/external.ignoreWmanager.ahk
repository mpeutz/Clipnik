;@Plugin-Name Ignored Window Manager
;@Plugin-Description Manages the windows that will be ignored by Clipjump Clipboard monitoring and paste mode.
;@Plugin-Author fump2000
;@Plugin-Version 0.1
;@Plugin-Tags system
; AutoHotkey v2 port. The per-row LV_Colors tinting of the v1 version is replaced by the ListView's own
; background color; the window is rebuilt as a native Clipjump window in a later phase.
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\publicAPI.ahk

global cj := Clipjump()
global PROGNAME := cj.PROGNAME
global TXT := Map()

TXT["IGN_delete"] := cj["TXT.IGN_delete"], TXT["IGN_add"] := cj["TXT.IGN_add"]
TXT["IGN__name"] := cj["TXT.IGN__name"], TXT["IGN_RestartMsg"] := cj["TXT.IGN_RestartMsg"]
TXT["IGN_tip"] := cj["TXT.IGN_tip"]

ClassManager()

;============================================================================
; Class-Manager for ClipJump
;============================================================================
ClassManager() {
	global cj, PROGNAME, TXT
	ClassChange := 0
	g := Gui("-MaximizeBox", PROGNAME " " TXT["IGN__name"])
	g.BackColor := "FFFFFF"
	lv := g.Add("ListView", "x0 y0 w320 h260 +BackgroundD9E7FB NoSortHdr -Multi vClipClass", ["Classes"])
	g.Add("Button", "x0 y260 w320 h30", TXT["IGN_delete"]).OnEvent("Click", ClassDelete)
	g.Add("Button", "x0 y290 w320 h30", TXT["IGN_add"]).OnEvent("Click", AddClass)
	g.OnEvent("Close", ClipClassGuiClose)
	g.Show("w320 h325")
	FillClassList()
	return

	FillClassList() {
		lv.Opt("-Redraw")
		lv.Delete()
		lv.ModifyCol()
		lv.ModifyCol(1, 315)
		OutVar := IniRead(A_WorkingDir "\settings.ini", "Advanced", "ignoreWindows", "")
		loop parse OutVar, "|"
		{
			if (A_LoopField = "")
				break
			lv.Add("", A_LoopField)
		}
		lv.Opt("+Redraw")
	}

	ClassDelete(*) {
		row := lv.GetNext(0)
		if row
			lv.Delete(row)
		SaveClasses()
		ClassChange := 1
	}

	ClipClassGuiClose(*) {
		if ClassChange
		{
			answer := MsgBox(TXT["IGN_RestartMsg"], PROGNAME, 67)
			if (answer = "Yes")
				cj.runLabel("reload")
			else if (answer = "Cancel")
				return      ; dont Exitapp
		}
		g.Destroy()
		ExitApp
	}

	AddClass(*) {
		classtool_cl := classget_Tool()
		try WinActivate(PROGNAME " " TXT["IGN__name"])
		if (classtool_cl = "")
			return
		lv.Add("", classtool_cl)
		SaveClasses()
		ClassChange := 1
	}

	SaveClasses() {
		ClipClasses := ""
		loop lv.GetCount()
			ClipClasses .= lv.GetText(A_Index) "|"
		IniWrite(ClipClasses, A_WorkingDir "\settings.ini", "Advanced", "ignoreWindows")
	}
}


; Lets the user pick a window: shows the class of the active window until Space (accept) or Esc (cancel).
classget_Tool() {
	global TXT
	classtool_cl := ""
	classTool_active := 1

	SetTimer(classget, 200)
	Hotkey("Esc", classTool_end, "On")
	Hotkey("Space", classTool_copy, "On")

	while classTool_active
		Sleep 20

	SetTimer(classget, 0)
	ToolTip(, , , 6)
	Hotkey("Esc", classTool_end, "Off")
	Hotkey("Space", classTool_copy, "Off")
	return classtool_cl

	classget() {
		try classtool_cl := WinGetClass("A")
		ToolTip(classtool_cl "`n`n" TXT["IGN_tip"], , , 6)
	}

	classTool_copy(*) {
		classTool_active := 0
	}

	classTool_end(*) {
		classtool_cl := ""
		classTool_active := 0
	}
}
