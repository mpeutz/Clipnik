; Drives Ring.Pick in-process: letters, Esc, Enter, clicks, a flick, paging, until. Needs an idle desktop.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\ring_pick.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
SetWorkingDir A_ScriptDir "\.."
CoordMode "Mouse", "Screen"
SendMode "Event"
SendLevel 1
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\lib\translations.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\RingGeom.ahk
#Include ..\src\ui\native\Ring.ahk
OnError((exc, *) => (FileAppend("FAIL exception: " exc.Message " @ " exc.File ":" exc.Line "`n", "*"), ExitApp(1)))
GetVKList(c) => [Format("{:X}", GetKeyVK(c))]
FileEncoding "UTF-8"
global TXT := Translations_load("languages/english.txt")
Theme.Init("dark")
DllCall("GDI32.DLL\AddFontResourceEx", "Str", A_WorkingDir "\icons\lucide.ttf", "UInt", 0x10, "Int", 0)
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
g := Gui("+AlwaysOnTop", "ring-pick-target"), ed := g.Add("Edit", "w300 h80")
g.Show("x100 y100"), WinWaitActive("ring-pick-target", , 5), ed.Focus()
MouseMove(900, 500, 0), Sleep(200)
items := []
for kv in [["A", "Alpha"], ["B", "Beta"], ["D", "Delta"], ["E", "Echo"], ["G", "Golf"], ["H", "Hotel"], ["I", "India"], ["J", "Juliet"], ["K", "Kilo"], ["L", "Lima"]]
    items.Push({key: kv[1], label: kv[2], desc: "item " kv[2]})
at(i) {
    xy := StrSplit(Ring_WedgePoint(i), ",")
    MouseMove(xy[1], xy[2], 3), Sleep(120)
}
later(ms, fn) => SetTimer(fn, -ms)

later(400, () => SendEvent("b"))
check(Ring.Pick(items, {prefix: ""}) = "B", "a letter picks")
check(Ring_IsOpen() = 0 && !WinExist("Clipjump_Ring ahk_class AutoHotkeyGUI"), "the ring is hidden after a pick")

later(400, () => SendEvent("{Esc}"))
check(Ring.Pick(items, {prefix: ""}) = "", "Esc cancels")

later(400, () => (at(2), SendEvent("{Enter}")))
check(Ring.Pick(items, {prefix: ""}) = "D", "Enter picks the hovered wedge")

later(400, () => (at(1), Click()))
check(Ring.Pick(items, {prefix: ""}) = "B", "a click on wedge 1 picks it")

later(400, () => (MouseMove(200, 150, 3), Sleep(100), Click()))   ; on the test's own window, outside the disc
check(Ring.Pick(items, {prefix: ""}) = "", "a click outside cancels")
MouseMove(900, 500, 0), Sleep(200)

pg := ""
PageFlip() {
    global pg
    at(7), Click(), Sleep(300)
    pg := Ring_LabelAt(0)
    SendEvent("{Esc}")
}
later(400, PageFlip)
Ring.Pick(items, {prefix: ""})
check(pg = "Juliet", "More flips to page 2: " pg)

later(400, () => SendEvent("k"))
check(Ring.Pick(items, {prefix: ""}) = "K", "a letter from page 2 picks while page 1 shows")

SendEvent("{z down}")
later(300, () => (at(3), SendEvent("{z up}")))
check(Ring.Pick(items, {prefix: "", trigger: "z"}) = "E", "a flick picks the wedge under the release")

SendEvent("{z down}")
later(120, () => SendEvent("{z up}"))
later(700, () => SendEvent("{Esc}"))
check(Ring.Pick(items, {prefix: "", trigger: "z"}) = "", "a quick tap leaves the ring open")

t0 := A_TickCount
check(Ring.Pick(items, {prefix: "", until: () => A_TickCount - t0 > 500}) = "", "until closes the ring")

later(400, () => SendEvent("5"))
check(Ring.Pick(items, {prefix: "", extraKeys: ["5"]}) = "5", "an extra key returns itself")

g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
