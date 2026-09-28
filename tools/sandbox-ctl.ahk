; sandbox-ctl.ahk - the steps of tools/test-sandbox.sh that need AutoHotkey. One command per run:
;   running             prints "<exe>|<script>" for every running Clipnik.ahk
;   stop <where> [force]  asks the Clipnik running from <where> (its folder or its Clipnik.ahk) to exit, its
;                       OnExit saving as usual, and waits; with force, one that will not exit is ended
;   ready <folder>      waits until the only Clipnik running is the one from <folder>, finished starting up
;   dialogs <folder>    prints the message boxes the AutoHotkey in <folder>\runtime shows; exit 1 when there are any
;   clip-save <file>    writes the whole clipboard to <file>
;   clip-restore <file> puts <file> back on the clipboard
; Exit code 0 on success, 1 with a reason on stdout otherwise.
#Requires AutoHotkey v2.0
#NoTrayIcon
#Include %A_LineFile%\..\..\tests\lib\sandbox_guard_fns.ahk
#Include %A_LineFile%\..\..\publicAPI.ahk

cmd := A_Args.Length ? A_Args[1] : ""
arg := A_Args.Length > 1 ? A_Args[2] : ""
switch cmd {
	case "running": ExitApp Running()
	case "stop": ExitApp Stop(arg, A_Args.Length > 2 && A_Args[3] = "force")
	case "ready": ExitApp Ready(arg)
	case "dialogs": ExitApp Dialogs(arg)
	case "clip-save": ExitApp ClipSave(arg)
	case "clip-restore": ExitApp ClipRestore(arg)
}
Fail("unknown command: " cmd)

Fail(msg) {
	FileAppend(msg "`n", "*")
	ExitApp 1
}

; hwnd -> script path of every running Clipnik.ahk
Clipniks() {
	found := Map()
	dhw := A_DetectHiddenWindows, tmm := A_TitleMatchMode
	DetectHiddenWindows true
	SetTitleMatchMode 2
	for hw in WinGetList("Clipnik.ahk ahk_class AutoHotkey")
		if RegExMatch(WinGetTitle(hw), "i)^(.*\\Clipnik\.ahk) - AutoHotkey", &m)
			found[hw] := m[1]
	DetectHiddenWindows dhw
	SetTitleMatchMode tmm
	return found
}

Running() {
	for hw, script in Clipniks()
		FileAppend(WinGetProcessPath(hw) "|" script "`n", "*")
	return 0
}

; the Clipnik.ahk path when given one, else the folder itself
FolderOf(where) {
	SplitPath(where, &name, &dir)
	return SandboxGuard_Long(name = "Clipnik.ahk" ? dir : where)
}

; hwnd of the Clipnik running from folder, 0 when there is none
ClipnikIn(folder) {
	for hw, script in Clipniks() {
		SplitPath(script, , &dir)
		if (SandboxGuard_Long(dir) = folder)
			return hw
	}
	return 0
}

Stop(where, force) {
	folder := FolderOf(where)
	if !(hw := ClipnikIn(folder))
		return 0   ; not running: nothing to stop
	pid := WinGetPID(hw), t := A_TickCount
	PostMessage(0x111, 65405, 0, , hw)   ; the tray menu's Exit command
	if !ProcessWaitClose(pid, 60) {   ; 0 once it is gone, its PID on a timeout
		FileAppend("Clipnik in " folder " exited in " Round((A_TickCount - t) / 1000, 1) " s`n", "*")
		return 0
	}
	if !force
		Fail("Clipnik in " folder " did not exit within 60 s")
	ProcessClose(pid)
	FileAppend("Clipnik in " folder " did not exit within 60 s and was ended`n", "*")
	return 0
}

; the other Clipnik may still be closing and this one still opening, so only the right one, alone, will do
Ready(folder) {
	folder := FolderOf(folder)
	loop 60 {
		if (Clipniks().Count = 1 && ClipnikIn(folder)) {
			try if (Clipnik()["startUpComplete"] = 1)
				return 0
		}
		Sleep 500
	}
	Fail("the Clipnik in " folder " was not the only one running and started within 30 s (" Clipniks().Count " running)")
}

Dialogs(folder) {
	exe := SandboxGuard_Long(FolderOf(folder) "\runtime\AutoHotkey64.exe"), n := 0
	for hw in WinGetList("ahk_class #32770") {
		try path := SandboxGuard_Long(WinGetProcessPath(hw))
		catch
			continue
		if (path = exe)
			FileAppend(WinGetTitle(hw) ": " StrReplace(WinGetText(hw), "`r`n", " ") "`n", "*"), n++
	}
	return n ? 1 : 0
}

; an empty clipboard saves as an empty file
ClipSave(file) {
	data := ClipboardAll()
	f := FileOpen(file, "w")
	if data.Size
		f.RawWrite(data)
	f.Close()
	return 0
}

ClipRestore(file) {
	if !FileExist(file)
		Fail("no saved clipboard at " file)
	A_Clipboard := FileGetSize(file) ? ClipboardAll(FileRead(file, "RAW")) : ""
	return 0
}
