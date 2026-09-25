; The tray icon sits on the taskbar, not on an app surface, so its tint has to clear the taskbar
; background - whatever the app's own theme and accent are. Standalone.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\traytint.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\src\ui\native\Theme.ahk
SetWorkingDir A_ScriptDir "\.."
global STORE := CJMap(), CJGUI := Map(), ACTIONS := CJMap()

; a missing function must print and exit, not raise a modal dialog that blocks an automated run
OnError(fatal)
fatal(e, mode) {
	FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*")
	ExitApp 1
}

fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

; AHK variable names are case-insensitive, so these must not collide with the loop's "onDark"
tbDark := 0x202020, tbLight := 0xF3F3F3
target := 4.5

; a known-good reference: pure black on pure white is 21:1
check(Round(Theme.ContrastRatio(0x000000, 0xFFFFFF), 1) = 21.0, "ContrastRatio black on white is 21:1")
check(Round(Theme.ContrastRatio(0xFFFFFF, 0xFFFFFF), 1) = 1.0, "ContrastRatio white on white is 1:1")
check(Theme.ContrastRatio(0x4270C4, tbDark) < target, "the reported accent really does fail on a dark taskbar")

; the point of the feature: whatever the accent, the tray tint is legible on the taskbar it lands on
accents := [0x4270C4, 0x000000, 0xFFFFFF, 0xFF0000, 0x00A000, 0x0078D4, 0x8440FF]
for a in accents {
	for onDark in [true, false] {
		tint := Theme.TrayTint(a, onDark)
		bg := onDark ? tbDark : tbLight
		r := Theme.ContrastRatio(tint, bg)
		check(r >= target, Format("#{:06X} on a {} taskbar -> #{:06X} at {:.2f}:1", a, onDark ? "dark" : "light", tint, r))
	}
}

; an accent that already clears the bar is left alone - no pointless drift from the user's color
check(Theme.TrayTint(0xFFFFFF, true) = 0xFFFFFF, "an accent that already passes is returned unchanged")
check(Theme.TrayTint(0x000000, false) = 0x000000, "a black accent on a light taskbar is returned unchanged")

; the tint follows the TASKBAR theme, not the app theme: the same accent differs between the two
check(Theme.TrayTint(0x4270C4, true) != Theme.TrayTint(0x4270C4, false), "the two taskbar themes get different tints")

; Detect() records the taskbar theme separately from the app theme
Theme.Init("light", "4270C4")
check(Theme.HasProp("SystemIsDark"), "Detect records the taskbar theme as SystemIsDark")
check(Theme.IsDark = false, "the app theme still follows the app's own setting")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
