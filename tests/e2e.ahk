; End-to-end smoke test against a RUNNING Clipjump (v2): copy capture, paste-mode cycling in Notepad.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\e2e.ahk
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 2
SendLevel 1   ; hook hotkeys in the target script ignore level-0 simulated input
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
cj := Clipjump()
; keep the channel well below its clip limit so compaction cannot renumber clips mid-test
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
    cj.runFunction("compacter()")
before := Integer(cj.runFunction("API.getChStrength(0)"))
stamp := "e2e-" A_TickCount
A_Clipboard := stamp " first"
Sleep 600
A_Clipboard := stamp " second"
Sleep 600
after := Integer(cj.runFunction("API.getChStrength(0)"))
check(after != before, "clipboard writes were captured (strength " before " -> " after ")")
check(cj.getClipAt(0, 1) = stamp " second", "clip 1 is the newest: " cj.getClipAt(0, 1))
check(cj.getClipAt(0, 2) = stamp " first", "clip 2 is the older one")

; paste mode into our own Edit control
g := Gui("+AlwaysOnTop", "cj-e2e-target")
ed := g.Add("Edit", "w500 h200 +Multi")
g.Show()
WinWaitActive("cj-e2e-target", , 5)
ed.Focus()
Sleep 500
; Ctrl+V once = paste clip 1
SendEvent("{Ctrl down}v{Ctrl up}")
Sleep 1000
; Ctrl held, V twice = clip 2
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("v")
Sleep 400
SendEvent("{Ctrl up}")
Sleep 1000
text := ed.Value
check(InStr(text, stamp " second"), "single Ctrl+V pasted clip 1")
check(InStr(text, stamp " first"), "Ctrl+V,V pasted clip 2")
FileAppend("target text: [" StrReplace(text, "`r`n", "|") "]`n", "*")
; Ctrl+V then C (move back) should return to clip 1
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("v")
Sleep 400
SendEvent("c")
Sleep 400
SendEvent("{Ctrl up}")
Sleep 1000
; with ini_PreserveClipPos the session starts at the last pasted clip (clip 2), so V,C lands back on clip 2
expected := cj["ini_PreserveClipPos"] ? stamp " first" : stamp " second"
check(InStr(ed.Value, expected), "Ctrl+V,V,C moved back (PreserveClipPos=" cj["ini_PreserveClipPos"] "): [" ed.Value "]")
; X = cancel mode: nothing pasted
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("x")
Sleep 400
SendEvent("{Ctrl up}")
Sleep 1000
check(ed.Value = "", "Ctrl+V,X cancels paste: [" ed.Value "]")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
