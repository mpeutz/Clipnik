; X mode ring (delete, copy), customizer bindings, incognito/disable toggles, against a RUNNING Clipjump.
; Only clips created by this test are deleted.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\modes.ahk
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
cj := Clipjump()
; keep the channel well below its clip limit so compaction cannot renumber clips mid-test
if (Integer(cj.runFunction("API.getChStrength(0)")) >= Integer(cj["TOTALCLIPS"]) - 6)
    cj.runFunction("compacter()")
strength() => Integer(cj.runFunction("API.getChStrength(0)"))
stamp := "md-" A_TickCount
A_Clipboard := stamp " one"
Sleep 500
A_Clipboard := stamp " two"
Sleep 500
g := Gui("+AlwaysOnTop", "cj-md-target")
ed := g.Add("Edit", "w500 h200 +Multi")
g.Show()
WinWaitActive("cj-md-target", , 5)
ed.Focus()
Sleep 400

step("X,X = delete mode removes the shown clip")
before := strength()
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
check(cj.getClipAt(0, 1) = stamp " two", "clip 1 is our newest test clip")
SendEvent("x")
Sleep 300
check(cj["ctrlRef"] = "cancel", "first X = cancel mode")
SendEvent("x")
Sleep 300
check(cj["ctrlRef"] = "delete", "second X = delete mode")
SendEvent("{Ctrl up}")
Sleep 1200
check(strength() = before - 1, "clip deleted (strength " before " -> " strength() ")")
check(cj.getClipAt(0, 1) = stamp " one", "clip 1 is now the older test clip")
check(ed.Value = "", "nothing pasted in delete mode")

step("X,X,X,X = copy mode duplicates the clip into the chosen channel (0)")
before := strength()
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("a")
Sleep 400
loop 4 {
    SendEvent("x")
    Sleep 250
}
check(cj["ctrlRef"] = "copy", "fourth X = copy mode")
SendEvent("{Ctrl up}")
if WinWait(cj["TXT.CHC_name"] " ahk_class AutoHotkeyGUI", , 4) {
    Sleep 400
    SendEvent("{Home}{Enter}")   ; choose channel 0 (first entry) via the default OK button
    Sleep 1200
    check(strength() = before + 1, "copy created a clip (strength " before " -> " strength() ")")
    check(cj.getClipAt(0, 1) = stamp " one" && cj.getClipAt(0, 2) = stamp " one", "clip 1 and 2 are both the copied clip")
} else
    check(false, "channel chooser did not appear")
check(!errorDialog(), "no error after mode ring")

step("customizer: a [section] with bind/run/tip works after Reload customizations")
ini := A_ScriptDir "\..\ClipjumpCustom.ini"
FileCopy(ini, ini ".testbak", 1)
FileAppend("`n[cjtest]`nbind = Ctrl+Alt+F9`ntip = customizer says hi`nrun = API.pasteText(" stamp " custom)`n", ini)
reloadCustom()
ed.Value := ""
ed.Focus()
Sleep 300
SendEvent("^!{F9}")
Sleep 3500
check(InStr(ed.Value, stamp " custom"), "bound hotkey ran API.pasteText: [" ed.Value "] active=" WinGetTitle("A") " clip=[" A_Clipboard "]")
check(cj["CUSTOMS._cjtest.bind"] = "$^!F9", "section stored in CUSTOMS with parsed bind: " cj["CUSTOMS._cjtest.bind"])
FileMove(ini ".testbak", ini, 1)
reloadCustom()
Sleep 300
check(!errorDialog(), "no error after customizer round trip")

step("incognito and disable toggles")
cj.runLabel("incognito")
Sleep 300
check(cj["NOINCOGNITO"] = 0, "incognito on")
cj.runLabel("incognito")
Sleep 300
check(cj["NOINCOGNITO"] = 1, "incognito off")
cj.runLabel("disable_clipjump")
Sleep 500
check(cj["CLIPJUMP_STATUS"] = 0, "disabled")
ed.Value := ""
A_Clipboard := stamp " while disabled"
Sleep 600
SendEvent("{Ctrl down}v{Ctrl up}")
Sleep 800
check(InStr(ed.Value, stamp " while disabled"), "Ctrl+V is a plain paste while disabled: [" ed.Value "] active=" WinGetTitle("A") " clip=[" A_Clipboard "]")
check(cj["ctrlRef"] = "", "paste mode not entered while disabled (ctrlRef=" cj["ctrlRef"] ")")
cj.runLabel("disable_clipjump")
Sleep 500
check(cj["CLIPJUMP_STATUS"] = 1, "re-enabled")
check(!errorDialog(), "no error dialogs at the end")
g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails

; "Reload customizations" ends with a MsgBox that would block the synchronous API call, so the two
; functions behind it are called directly.
reloadCustom() {
    global cj
    cj.runFunction("resetCustomizations()")
    cj.runFunction("loadCustomizations()")
    Sleep 300
}
