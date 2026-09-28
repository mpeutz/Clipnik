; Creates a WebHost on ui/demo/index.html, waits for the page's "ready" message, posts a reply, screenshots.
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\gdiplus.ahk
#Include lib\gdiplus_test.ahk
#Include ..\lib\vendor\WebView2\WebView2.ahk
#Include ..\lib\vendor\JSON.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\web\WebHost.ahk
SetWorkingDir A_ScriptDir "\.."
global CJGUI := Map(), PROGNAME := "Clipnik", TXT := CJMap()
TXT["WV2_missingTitle"] := "The WebView2 runtime is not installed", TXT["WV2_missingText"] := "Clipboard History and the Channel Organizer need Microsoft Edge WebView2.", TXT["WV2_download"] := "Download the Evergreen runtime from Microsoft"
BrowserRun(u) => Run(u)
Theme.Init("dark")
global got := ""
onMsg(cmd, data, host) {
    global got
    got .= cmd ";"
    host.Post("hello", Map("n", 1))
}
h := WebHost("webhost demo", "demo/index.html")
h.OnMessage(onMsg)
FileAppend("available=" WebHost.Available() "`n", "*")
try h.Show("w500 h200")
catch as e
    FileAppend("ERR " e.Message " (" e.File ":" e.Line ") " e.Extra "`n", "*")
if !WebHost.Available() {
    Sleep 800
    if WinExist("Clipnik ahk_class AutoHotkeyGUI") {
        WinGetPos(&x, &y, &w, &hh)
        p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" hh)
        Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\webhost-missing.png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
        FileAppend("fallback dialog shown`n", "*")
        ExitApp 0
    }
    FileAppend("no fallback dialog`n", "*")
    ExitApp 1
}
t := A_TickCount
while (!got && A_TickCount - t < 8000)
    Sleep 100
FileAppend("got=" got "`n", "*")
Sleep 800
WinGetPos(&x, &y, &w, &hh, h.g.Hwnd)
p := Gdip_Startup(), b := Gdip_BitmapFromScreen(x "|" y "|" w "|" hh)
Gdip_SaveBitmapToFile(b, A_ScriptDir "\out\webhost-demo.png"), Gdip_DisposeImage(b), Gdip_Shutdown(p)
rc := got ? 0 : 1
h.Hide()
h.g.Destroy()
Sleep 300
ExitApp(rc)
