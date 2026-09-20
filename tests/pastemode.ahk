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

step("action mode: Ctrl+Shift+A shows the ring, Esc closes it, H opens History")
SendEvent("^+a")
Sleep 700
check(cj.runFunction("Ring_IsOpen()") = 1, "action ring shown")
SendEvent("{Esc}")
Sleep 500
check(cj.runFunction("Ring_IsOpen()") = 0, "action ring closed by Esc")
SendEvent("^+a")
Sleep 700
SendEvent("h")
hist := cj["TXT.HST__name"] " ahk_class AutoHotkeyGUI"
check(WinWait(hist, , 5) != 0, "H opened Clipboard History")
Sleep 2500		; let History's WebView2 finish initializing before closing it (matches history_flow.ahk's settle time)
try WinClose(hist)
check(WinWaitClose(hist, , 5), "History closed")
WinActivate("cj-pm-target")
ed.Focus()
Sleep 300
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

step("F1 in paste mode shows the card, not the help window")
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("{F1}")
Sleep 600
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI") != 0, "F1 shows the paste-mode card")
check(!WinExist("Clipjump Help ahk_class AutoHotkeyGUI"), "F1 in paste mode does not open the help window")
SendEvent("{Ctrl up}")
Sleep 600

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

step("B walks the Vault instead of the clip stack")
vaultBefore := Integer(cj.runFunction("vaultCount()"))
v1 := cj.runFunction("vaultAdd(vault-alpha-" stamp ",0)")
v2 := cj.runFunction("vaultAdd(vault-beta-" stamp ",0)")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 500
check(cj.runFunction("Vault_IsActive()") = "0", "the walker starts on the clip stack")
SendEvent("b")
Sleep 800
check(InStr(cj.runFunction("Vault_IsActive()"), "1 1/"), "B entered the Vault: " cj.runFunction("Vault_IsActive()"))
cur := cj["CURSAVE"]
SendEvent("v")
Sleep 600
check(InStr(cj.runFunction("Vault_IsActive()"), "1 2/"), "V stepped to the second entry")
SendEvent("{Space}")
Sleep 300
SendEvent("t")
Sleep 300
check(cj["CURSAVE"] = cur, "fix and tag did nothing while the Vault was showing")
SendEvent("b")
Sleep 700
check(cj.runFunction("Vault_IsActive()") = "0", "B returned to the clip stack")
SendEvent("{Ctrl up}")
Sleep 900
cj.runFunction("vaultDelete(" v1 ")")
cj.runFunction("vaultDelete(" v2 ")")
check(Integer(cj.runFunction("vaultCount()")) = vaultBefore, "the seeded entries were cleaned up")


; ---------------------------------------------------------------- L locks the card open
; a token no earlier run can have produced: searching for "alpha" would also match clips this
; suite left in the channel on previous runs, which made the assertion depend on stale state
token := "lockfind" A_TickCount
A_Clipboard := token
Sleep 600
; Every block here must leave the lock closed: a leaked InputHook swallows the keyboard and makes
; every later step in this file fail for reasons that look nothing like the real cause.
lockOpen() {
    SendEvent("{Ctrl down}v")
    Sleep 450
    SendEvent("l")
    Sleep 500
    SendEvent("{Ctrl up}")
    Sleep 700
}
locked() => cj.runFunction("PasteLock_IsActive()")

step("L keeps the card open after Ctrl is released")
ed.Value := ""
lockOpen()
check(locked() = 1, "still locked after Ctrl came up")
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "the card is still on screen")
check(cj["ctrlRef"] = "pastemode", "the release mode is untouched: [" cj["ctrlRef"] "]")
check(ed.Value = "", "nothing was pasted by locking: [" ed.Value "]")

step("unmodified keys drive the card and none of them reach the document")
SendEvent("a")
Sleep 500
check(clipNo() = 1, "A went to clip 1: " clipNo())
SendEvent("v")
Sleep 500
check(clipNo() = 2, "V stepped to clip 2: " clipNo())
SendEvent("c")
Sleep 500
check(clipNo() = 1, "C stepped back to clip 1: " clipNo())
check(ed.Value = "", "the keys the lock claims never reach the target: [" ed.Value "]")
; a key the lock does NOT claim is deliberately left alone: binding the bare letters is what keeps
; every Ctrl combination alive (Ctrl+C, Ctrl+X, Ctrl+Shift+A), and the price is that stray typing
; lands in the document. Pinned here so the trade-off cannot change silently.
SendEvent("p")
Sleep 400
check(ed.Value = "p", "an unclaimed key still reaches the application: [" ed.Value "]")
ed.Value := ""
check(!errorDialog(), "no error while the lock routed keys")

step("Enter pastes and ends the lock")
SendEvent("{Enter}")
Sleep 1400
check(locked() = 0, "Enter cleared the lock")
check(cj["ctrlRef"] = "", "paste mode ended")
check(InStr(ed.Value, token), "Enter pasted clip 1: [" ed.Value "] active=" WinGetTitle("A"))

step("Esc cancels the lock and puts the clipboard back")
before := A_Clipboard
ed.Value := ""
lockOpen()
check(locked() = 1, "locked again")
SendEvent("{Esc}")
Sleep 1200
check(locked() = 0, "Esc cleared the lock")
check(ed.Value = "", "Esc pasted nothing: [" ed.Value "]")
check(A_Clipboard = before, "Esc restored the clipboard")

step("Ctrl+V while locked steps a clip and leaves the lock alone")
ed.Value := ""
lockOpen()
n := clipNo()
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("{Ctrl up}")
Sleep 700
check(clipNo() = n + 1, "Ctrl+V stepped from " n " to " clipNo())
check(locked() = 1, "the lock survived a second Ctrl+V")
SendEvent("{Esc}")
Sleep 900

step("the format ring works with bare letters while locked")
cj.runFunction("set_pformat()")
ed.Value := ""
lockOpen()
SendEvent("z")
Sleep 800
check(cj.runFunction("Ring_IsOpen()") = 1, "Z opened the ring with no Ctrl held")
SendEvent("u")
Sleep 700
check(cj.runFunction("Ring_IsOpen()") = 0, "picking closed the ring")
check(cj["curPformat"] = "Upper case", "U picked Upper case: [" cj["curPformat"] "]")
check(locked() = 1, "the lock survived the ring")
SendEvent("{Enter}")
Sleep 1400
check(ed.Value != "" && ed.Value = StrUpper(ed.Value), "the locked paste applied the format: [" ed.Value "]")
cj.runFunction("set_pformat()")

step("F hands the keyboard to search and search still commits")
ed.Value := ""
lockOpen()
SendEvent("f")
Sleep 800
check(cj["SPM.ACTIVE"] = 1, "F opened search from the locked card")
SendEvent(token)
Sleep 1100
check(InStr(cj["temp_clipboard"], token), "search filtered to the unique clip: [" cj["temp_clipboard"] "]")
SendEvent("{Enter}")
Sleep 1500
check(cj["SPM.ACTIVE"] = "", "Enter ended the search")
check(locked() = 0, "the lock was released with the search")
check(InStr(ed.Value, token), "search + Enter pasted the match: [" ed.Value "]")

step("X cycles the release mode and Enter commits it")
ed.Value := ""
lockOpen()
SendEvent("x")
Sleep 400
check(cj["ctrlRef"] = "cancel", "X went to cancel: [" cj["ctrlRef"] "]")
SendEvent("x")
Sleep 400
check(cj["ctrlRef"] = "delete", "X went to delete: [" cj["ctrlRef"] "]")
loop 4 {
    SendEvent("x")
    Sleep 350
}
check(cj["ctrlRef"] = "pastemode", "the locked cycle wraps back to pastemode: [" cj["ctrlRef"] "]")
SendEvent("{Enter}")
Sleep 1400
check(locked() = 0, "Enter ended the lock after the cycle")
check(ed.Value != "", "Enter pasted once the mode was back to pastemode: [" ed.Value "]")

step("multipaste refuses to start while locked")
ed.Value := ""
lockOpen()
SendEvent("{Ctrl down}{Enter}")
Sleep 500
SendEvent("{Ctrl up}")
Sleep 900
check(cj["MULTIPASTE"] = 0, "MULTIPASTE stayed off: [" cj["MULTIPASTE"] "]")
check(locked() = 1, "the lock is still held")
check(ed.Value = "", "no paste loop ran: [" ed.Value "]")
SendEvent("{Esc}")
Sleep 900
check(locked() = 0, "Esc cleaned up")

step("Ctrl combinations still work while the card is locked")
; an InputHook that suppressed these letters also killed Ctrl+C, Ctrl+X and Ctrl+Shift+A, which is
; exactly why the lock binds bare hotkeys instead
ed.Value := ""
lockOpen()
; the clipboard is useless as a witness here - paste mode owns it and loads each browsed clip onto
; it - so watch the Edit instead. "a" is bound bare while locked, so Ctrl+A still selecting proves
; a modified combination on a claimed letter reaches the application.
ed.Value := "lock-copy-" stamp
ed.Focus()
Sleep 300
SendEvent("^a")
Sleep 500
sel := EditGetSelectedText(ed)
check(InStr(sel, "lock-copy-" stamp), "Ctrl+A reached the application while locked: [" sel "]")
SendEvent("{Esc}")
Sleep 900
check(locked() = 0, "Esc cleaned up after the Ctrl+C check")
ed.Value := ""

step("Action Mode still answers its bare keys while the card is locked")
; regression guard: the lock's InputHook suppresses the paste-mode letters, and a bare hotkey loses to
; a suppressing hook - so the ring has to be opened with the lock hook suspended or Esc does nothing
ed.Value := ""
lockOpen()
SendEvent("^+a")
Sleep 900
check(cj.runFunction("Ring_IsOpen()") = 1, "the action ring opened over the locked card")
SendEvent("{Esc}")
Sleep 700
check(cj.runFunction("Ring_IsOpen()") = 0, "Esc reached the ring and closed it")
check(locked() = 1, "the lock came back after the ring")
check(ed.Value = "", "the ring leaked nothing into the target: [" ed.Value "]")
SendEvent("{Esc}")
Sleep 900
check(locked() = 0, "Esc cleaned up the lock")

step("moving to another window cancels the lock")
ed.Value := ""
lockOpen()
check(locked() = 1, "locked before the focus change")
g2 := Gui("+AlwaysOnTop", "cj-lock-other")
g2.Add("Edit", "w200 h60")
g2.Show()
WinWaitActive("cj-lock-other", , 5)
Sleep 900
check(locked() = 0, "the lock released when focus left the target")
check(cj["ctrlRef"] = "", "paste mode ended with it")
g2.Destroy()
WinActivate("cj-pm-target")
ed.Focus()
Sleep 400
check(!errorDialog(), "no error after the lock tests")
check(!errorDialog(), "no error dialogs at the end")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
