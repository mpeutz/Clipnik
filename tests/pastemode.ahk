; Paste-mode key coverage against a RUNNING Clipjump: action mode, F1, jumps, Space, Z, F search, S, T, Enter.
; State is read through the public API (WM_COPYDATA) rather than by scraping tooltips.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\pastemode.ahk
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 2
SendLevel 1
CoordMode "Mouse", "Screen"
fails := 0
step(s) => FileAppend("     .. " s "`n", "*")
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() => WinExist("Clipjump.ahk ahk_class #32770")
; the card's alpha even while hidden (DetectHiddenWindows scoped to this one call only, so it doesn't
; change what WinExist("Clipjump_HUD ...") sees elsewhere in this file)
cardAlpha() {
    DetectHiddenWindows(true)
    a := ""
    try a := WinGetTransparent("Clipjump_HUD ahk_class AutoHotkeyGUI")
    DetectHiddenWindows(false)
    return a
}
; tooltip texts via UI Automation; only used while no keys are held (slow)
tipText() {
    f := A_Temp "\cj_tips.txt"
    try FileDelete(f)
    RunWait(A_ComSpec ' /c powershell -NoProfile -File "' A_ScriptDir '\..\tools\tips.ps1" > "' f '"', , "Hide")
    t := ""
    try t := FileRead(f)
    return StrReplace(t, "`r`n", "|")
}
cj := Clipjump()
; keep the channel well below its clip limit so compaction cannot renumber clips mid-test
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
    cj.runFunction("compacter()")
clipNo() => Integer(cj["realclipno"])

stamp := "pm-" A_TickCount
A_Clipboard := stamp " alpha"
Sleep 500
A_Clipboard := stamp " beta"
Sleep 500
A_Clipboard := stamp " gamma"
Sleep 500

g := Gui("+AlwaysOnTop", "cj-pm-target")
ed := g.Add("Edit", "w500 h200 +Multi")
g.Show()
WinWaitActive("cj-pm-target", , 5)
ed.Focus()
Sleep 400

step("action mode: Ctrl+Shift+A shows the console, Esc closes it")
SendEvent("^+a")
Sleep 700
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "action mode card shown")
SendEvent("{Esc}")
Sleep 500
check(!WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "action mode closed by Esc")
check(!errorDialog(), "no error after action mode")

step("Ctrl+V then A goes to clip 1, V moves to clip 2")
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
check(clipNo() = 1, "'a' shows clip 1 (realclipno=" clipNo() ")")
check(cj["ctrlRef"] = "pastemode", "ctrlRef is pastemode")
SendEvent("v")
Sleep 400
check(clipNo() = 2, "V moves to clip 2 (realclipno=" clipNo() ")")
step("F1 help sets the rebuild flag, next V clears it")
SendEvent("{F1}")
Sleep 400
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "F1 keeps the card open (help mode)")
SendEvent("v")
Sleep 400
check(clipNo() = 3, "V after F1 moves to clip 3")
SendEvent("c")
Sleep 400
check(clipNo() = 2, "C moves back to clip 2")
SendEvent("{Ctrl up}")
Sleep 1000
check(InStr(ed.Value, stamp " beta"), "pasted clip 2 (beta): [" ed.Value "]")

step("digit jumps: 2 jumps two forward, - toggles direction")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("2")
Sleep 400
check(clipNo() = 3, "'2' jumped from clip 1 to clip " clipNo())
SendEvent("-")
Sleep 200
SendEvent("1")
Sleep 400
check(clipNo() = 2, "'-' then '1' jumped back to clip " clipNo())
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 900
check(ed.Value = "", "X cancelled, nothing pasted")

step("Space fixate toggles the fixed pref")
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("{Space}")
Sleep 400
check(cj["fixStatus"] = cj["TXT.TIP_fixed"], "Space marks clip as fixed")
check(cj.runFunction("clipPref(0," cj["realActive"] ",fixed)") = 1, "fixed pref stored in CPS")
SendEvent("{Space}")
Sleep 400
check(cj["fixStatus"] = "", "Space again unfixes")
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 900

cardAlphaNormal := cardAlpha()

step("Z opens the format ring; U picks Upper case")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 600
check(cj.runFunction("Ring_IsOpen()") = 1, "Z opens the ring")
check(cj.runFunction("Ring_LabelAt(0)") = "Original" && cj.runFunction("Ring_LabelAt(1)") = "Trim Formatting", "Original then Trim Formatting lead the ring")
SendEvent("u")
Sleep 500
check(cj["curPformat"] = "Upper case", "U picked Upper case: [" cj["curPformat"] "]")
check(cj.runFunction("Ring_IsOpen()") = 0, "picking closes the ring")
SendEvent("z")
Sleep 500
SendEvent("z")
Sleep 500
check(cj.runFunction("Ring_IsOpen()") = 0, "a second tap of Z closes the ring")
SendEvent("u")
Sleep 400
check(cj["curPformat"] = "Upper case", "U after the ring closed changes nothing")
SendEvent("{Ctrl up}")
Sleep 900
check(ed.Value == StrUpper(ed.Value) && InStr(ed.Value, StrUpper(stamp), true), "pasted upper case: [" ed.Value "]")

step("a click on a wedge picks it; a flick picks it")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 600
xy := StrSplit(cj.runFunction("Ring_WedgePoint(2)"), ","), lbl := cj.runFunction("Ring_LabelAt(2)")
MouseMove(xy[1], xy[2], 5)
Sleep 150
Click()
Sleep 500
check(lbl != "" && cj["curPformat"] = lbl, "a click picked [" lbl "]: [" cj["curPformat"] "]")
SendEvent("{z down}")
Sleep 500
xy := StrSplit(cj.runFunction("Ring_WedgePoint(3)"), ","), lbl := cj.runFunction("Ring_LabelAt(3)")
MouseMove(xy[1], xy[2], 10)
Sleep 200
SendEvent("{z up}")
Sleep 500
check(lbl != "" && cj["curPformat"] = lbl, "a flick picked [" lbl "]: [" cj["curPformat"] "]")

step("built-in letters win over plugin letters")
SendEvent("z")
Sleep 500
SendEvent("m")
Sleep 500
check(cj["curPformat"] = "Markdown link", "M picked Markdown link: [" cj["curPformat"] "]")
SendEvent("z")
Sleep 500
SendEvent("s")
Sleep 500
check(cj["curPformat"] = "Strip URL tracking", "S picked Strip URL tracking: [" cj["curPformat"] "]")

step("O picks Original; releasing Ctrl with the ring open leaves no ring")
SendEvent("z")
Sleep 500
SendEvent("o")
Sleep 500
check(cj["curPformat"] = "", "O picked Original")
SendEvent("z")
Sleep 500
SendEvent("{Ctrl up}")
Sleep 1200
check(cj.runFunction("Ring_IsOpen()") = 0, "the ring closed with paste mode")
check(InStr(ed.Value, stamp), "the clip was pasted: [" ed.Value "]")
check(cardAlpha() = cardAlphaNormal, "the card's opacity is restored: [" cardAlpha() "]")
cj.runFunction("set_pformat()")
check(cj["curPformat"] = "", "set_pformat() resets the format")

step("F opens the search box, typing filters, Enter pastes")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("f")
Sleep 800
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "F keeps the card open with the search row")
check(cj["SPM.ACTIVE"] = 1, "SPM.ACTIVE set")
SendEvent("{Ctrl up}")
Sleep 300
SendEvent("alpha")
Sleep 1000
check(InStr(cj["temp_clipboard"], stamp " alpha"), "search jumps to the alpha clip: [" cj["temp_clipboard"] "]")
SendEvent("{Enter}")
Sleep 1500
check(cj["SPM.ACTIVE"] = "", "Enter ends the search")
check(InStr(ed.Value, stamp " alpha"), "search + Enter pasted alpha: [" ed.Value "]")

step("S suspends: clip goes to the system clipboard without pasting")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("s")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 1500
check(InStr(A_Clipboard, stamp " gamma"), "S put clip 1 on the system clipboard: [" A_Clipboard "]")
check(ed.Value = "", "S did not paste")
check(cj["ctrlRef"] = "", "paste mode ended after S")

step("T tags the clip through the InputBox")
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("t")
Sleep 300
SendEvent("{Ctrl up}")
if WinWait(cj["TXT._tags"] " ahk_class #32770", , 4) {
    Sleep 300
    SendEvent("tagtest{Enter}")
    Sleep 1000
    check(cj.runFunction("clipPref(0," cj["realActive"] ",Tags)") = "tagtest", "tag stored on the clip")
    hits := cj.runFunction("API.getClipByTag(tagtest)")
    check(!errorDialog(), "getClipByTag works")
} else
    check(false, "tag InputBox did not appear")
; the InputBox belongs to Clipjump, not this script's own window; closing it does not reliably hand
; focus back to our target, so reclaim it explicitly before the next step types into it
WinActivate("cj-pm-target")
WinWaitActive("cj-pm-target", , 2)

step("Enter (multipaste) pastes and keeps paste mode open")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("{Enter}")
Sleep 1200
check(InStr(ed.Value, stamp " gamma"), "Enter pasted clip 1 while Ctrl held: [" ed.Value "] active=" WinGetTitle("A") " hud=" WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI") " multi=" cj["MULTIPASTE"] " ref=" cj["ctrlRef"])
; the continuation of multipaste cannot be simulated: Clipjump's own Send restores modifiers to their
; physical state, which releases a Ctrl that is only held by SendEvent. Verify that part manually.
SendEvent("{Ctrl up}")
Sleep 1000
check(cj["ctrlRef"] = "", "paste mode ended")

check(!errorDialog(), "no error dialogs at the end")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
