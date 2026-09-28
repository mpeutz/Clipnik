; WebHost.Create() waits on WebView2 twice, and each wait lets other threads run. A second Show or a Prewarm
; arriving then (the startup prewarm timer, a second hotkey press) must not start a second browser on the same
; window, and a close arriving then must leave the window closed. Standalone: its own window, no Clipnik.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\webhost_reentry.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\WebView2\WebView2.ahk
#Include ..\lib\vendor\JSON.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\web\WebHost.ahk
SetWorkingDir A_ScriptDir "\.."
global CJGUI := Map(), PROGNAME := "Clipnik", TXT := CJMap()
BrowserRun(u) => Run(u)
Theme.Init("dark")
OnError((e, *) => (FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*"), ExitApp(1)))
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}
if !WebHost.Available() {
	FileAppend("WebView2 runtime missing: nothing to test`nALL PASSED`n", "*")
	ExitApp 0
}

; a Prewarm and a second Show while the first Show is still creating the browser
h := WebHost("webhost reentry", "demo/index.html")
; Show marks the window visible before it creates the browser, so "visible, no browser yet" = inside Create();
; a fast timer acts at its first tick there, while Create() waits
creating() => h.Visible && h.ctrl = ""
seen := [], midCreate := false
again() {
	global midCreate
	if !creating()
		return
	SetTimer(again, 0), midCreate := true
	h.Prewarm(), seen.Push(h.ctrl)
	h.Show("w400 h200"), seen.Push(h.ctrl)
}
SetTimer(again, 10)
check(h.Show("w400 h200"), "the first Show succeeds")
SetTimer(again, 0)
Sleep 300
check(midCreate, "the re-entrant calls ran while the browser was being created")
for c in seen
	check(c = "" || c = h.ctrl, "re-entrant call " A_Index " did not create a second browser")
check(h.ctrl && h.ctrl.IsVisible, "the browser is shown")
h.Hide(), h.g.Destroy()

; a close while the browser is being created
h := WebHost("webhost reentry close", "demo/index.html")
midClose := false
closeNow() {
	global midClose
	if !creating()
		return
	SetTimer(closeNow, 0), midClose := true
	h.OnCloseEvent()
}
SetTimer(closeNow, 10)
h.Show("w400 h200")
SetTimer(closeNow, 0)
Sleep 300
check(midClose, "the close arrived while the browser was being created")
check(!h.Visible && !DllCall("IsWindowVisible", "Ptr", h.g.Hwnd), "the window stays closed")
check(h.ctrl && !h.ctrl.IsVisible, "the browser stays hidden")
check(h.Show("w400 h200") && h.ctrl.IsVisible, "it opens normally afterwards")
h.Hide(), h.g.Destroy()

; a Focus while the browser is being created (a caller whose Show returned before the browser existed) lands
; once the browser is there
focusedClass(g) {
	try return ControlGetClassNN(ControlGetFocus(g.Hwnd))
	return ""
}
h := WebHost("webhost reentry focus", "demo/index.html")
midFocus := false
focusNow() {
	global midFocus
	if !creating()
		return
	SetTimer(focusNow, 0), midFocus := true
	h.Focus()
}
SetTimer(focusNow, 10)
h.Show("w400 h200")
SetTimer(focusNow, 0)
Sleep 500
check(midFocus, "the Focus arrived while the browser was being created")
check(InStr(focusedClass(h.g), "Chrome_WidgetWin"), "the focus landed in the browser once it existed [" focusedClass(h.g) "]")
h.Hide(), h.g.Destroy()

; a failure after the browser exists (here: the theme script) must not leave that browser attached to the
; window, or the next Show creates a second one on it
browsers(g) {
	n := 0
	try for c in WinGetControls(g.Hwnd)
		n += RegExMatch(c, "^Chrome_WidgetWin_0") ? 1 : 0
	return n
}
failOnce := true, themeScript := WebHost.Prototype.GetOwnPropDesc("ThemeScript").Call
brokenThemeScript(this) {
	global failOnce
	if failOnce {
		failOnce := false
		throw Error("simulated WebView2 failure")
	}
	return themeScript(this)
}
WebHost.Prototype.DefineProp("ThemeScript", {Call: brokenThemeScript})
h := WebHost("webhost reentry failure", "demo/index.html")
threw := false
try h.Show("w400 h200")
catch
	threw := true
Sleep 300
check(threw, "the failure reaches the caller")
check(browsers(h.g) = 0, "the half-built browser was closed (" browsers(h.g) " left on the window)")
check(h.Show("w400 h200") && h.ctrl, "the next Show builds the browser")
Sleep 300
check(browsers(h.g) = 1, "exactly one browser on the window (" browsers(h.g) ")")
h.Hide(), h.g.Destroy()
WebHost.Prototype.DefineProp("ThemeScript", {Call: themeScript})

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
