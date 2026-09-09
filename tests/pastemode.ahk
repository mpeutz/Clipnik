; Paste-mode key coverage against a RUNNING Clipjump: action mode, F1, jumps, Space, Z, F search, S, T, Enter.
; State is read through the public API (WM_COPYDATA) rather than by scraping tooltips.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\pastemode.ahk
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 2
SendLevel 1
fails := 0
step(s) => FileAppend("     .. " s "`n", "*")
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
errorDialog() => WinExist("Clipjump.ahk ahk_class #32770")
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
check(InStr(tipText(), cj["TXT.ACT__name"]), "action mode console shown")
SendEvent("{Esc}")
Sleep 500
check(!InStr(tipText(), cj["TXT.ACT__name"]), "action mode closed by Esc")
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
check(cj["STORE.pstTipRebuild"] = 1, "F1 marks the tip for rebuild")
SendEvent("v")
Sleep 400
check(cj["STORE.pstTipRebuild"] = 0 && clipNo() = 3, "V after F1 rebuilds and moves to clip 3")
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

step("Z cycles paste formats")
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 500
fmt1 := cj["curPformat"]
check(fmt1 != "", "Z selects a paste format: " fmt1)
SendEvent("z")
Sleep 500
check(cj["curPformat"] != fmt1, "Z again changes format (" fmt1 " -> " cj["curPformat"] ")")
SendEvent("x")
Sleep 300
SendEvent("{Ctrl up}")
Sleep 900
cj.runFunction("set_pformat()")
check(cj["curPformat"] = "", "set_pformat() resets the format")

step("F opens the search box, typing filters, Enter pastes")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("f")
Sleep 800
check(WinExist("Clipjump_SPM ahk_class AutoHotkeyGUI"), "F opens the search window")
check(cj["SPM.ACTIVE"] = 1, "SPM.ACTIVE set")
SendEvent("{Ctrl up}")
Sleep 300
SendEvent("alpha")
Sleep 1000
check(InStr(cj["temp_clipboard"], stamp " alpha"), "search jumps to the alpha clip: [" cj["temp_clipboard"] "]")
SendEvent("{Enter}")
Sleep 1500
check(!WinExist("Clipjump_SPM ahk_class AutoHotkeyGUI"), "Enter closes the search window")
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

step("Enter (multipaste) pastes and keeps paste mode open")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
SendEvent("{Enter}")
Sleep 1200
check(InStr(ed.Value, stamp " gamma"), "Enter pasted clip 1 while Ctrl held: [" ed.Value "]")
; the continuation of multipaste cannot be simulated: Clipjump's own Send restores modifiers to their
; physical state, which releases a Ctrl that is only held by SendEvent. Verify that part manually.
SendEvent("{Ctrl up}")
Sleep 1000
check(cj["ctrlRef"] = "", "paste mode ended")

check(!errorDialog(), "no error dialogs at the end")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
