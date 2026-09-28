; Thumbnails in the clip tables. Standalone: the real History and Organizer pages are rendered by headless Edge (the
; engine WebView2 embeds) against ui/common/mock-bridge.js, and WebHost.CacheUrl is exercised in a temp folder. No
; running Clipnik, no clipboard, nothing under the user's cache.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\webthumbs.ahk
#Requires AutoHotkey v2.0
; WebHost.ahk mentions HistoryWin and OrganizerWin, which a standalone test does not load; left on, that warning is a
; modal dialog at startup and the test never runs
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\lib\vendor\WebView2\WebView2.ahk
#Include ..\lib\vendor\JSON.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\web\WebHost.ahk
global CJGUI := Map(), PROGNAME := "Clipnik", TXT := CJMap(), STORE := Map()

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

root := RegExReplace(A_ScriptDir, "\\tests$")
edge := A_ProgramFiles " (x86)\Microsoft\Edge\Application\msedge.exe"
if !FileExist(edge)
	edge := A_ProgramFiles "\Microsoft\Edge\Application\msedge.exe"

; the page's DOM once the mock bridge has answered and the images in view have loaded or failed. The command goes
; through a batch file: cmd /c's quote stripping does not survive "Program Files (x86)" plus a redirect, and reading
; Edge's stdout pipe to the end never returns, because its helper processes inherit the pipe and outlive it. cmd
; waits for Edge's main process only; the helpers are closed afterwards, found by this dump's own profile folder.
; Each dump gets a fresh profile, since a previous dump's helpers can still hold theirs and make the next Edge wait
; on them, and a dump that still hangs is ended after 30 s, so the page's checks fail instead of the whole test.
dump(page) {
	global root, edge
	tag := "cnk-edge-profile-" A_TickCount
	profile := A_Temp "\" tag, out := A_Temp "\cnk-dump.html", bat := A_Temp "\cnk-dump.cmd"
	url := "file:///" StrReplace(root "\ui\" page, "\", "/")
	try FileDelete(out)
	try FileDelete(bat)
	FileAppend('@"' edge '" --headless --disable-gpu --user-data-dir="' profile '" --virtual-time-budget=5000 --dump-dom "' url '" > "' out '" 2>nul', bat)
	Run(bat, , "Hide", &pid)
	if ProcessWaitClose(pid, 30)
		try ProcessClose(pid)
	for p in ComObjGet("winmgmts:").ExecQuery("select ProcessId, CommandLine from Win32_Process where Name='msedge.exe'")
		if InStr(p.CommandLine, tag)
			try ProcessClose(p.ProcessId)
	Sleep 300
	try DirDelete(profile, true)
	return FileExist(out) ? FileRead(out, "UTF-8") : ""
}

; one table row's markup, by its data attribute
row(html, attr, id) => RegExMatch(html, 's)<div class="tr[^"]*" data-' attr '="' id '"[^>]*>.*?</div>', &m) ? m[0] : ""

thumbOf(r) => RegExMatch(r, '<img class="thumb"[^>]*>', &m) ? m[0] : ""

; ---- History (and the Vault, which is the same table) ----
h := dump("history\index.html")
check(InStr(h, 'id="rows"'), "history page rendered (" StrLen(h) " bytes of DOM)")
img := row(h, "id", 3), t := thumbOf(img)
check(t != "", "history: an image row shows a thumbnail")
check(InStr(t, 'loading="lazy"') && InStr(t, 'decoding="async"'), "history: the thumbnail loads lazily and decodes off the main thread")
check(InStr(t, 'width="39"') && InStr(t, 'height="22"'), "history: 320x180 is sized 39x22 before it loads, so the row never shifts")
check(InStr(img, "320 × 180") && !InStr(img, "[IMAGE]"), "history: the image row names its dimensions instead of [IMAGE]")
gone := row(h, "id", 60)
check(gone != "" && thumbOf(gone) = "" && InStr(gone, "82 × 70"), "history: an image whose file is missing falls back to its dimensions")
check(thumbOf(row(h, "id", 1)) = "", "history: text rows have no thumbnail")

; ---- Channel Organizer ----
o := dump("organizer\index.html")
check(InStr(o, 'id="rows"'), "organizer page rendered (" StrLen(o) " bytes of DOM)")
oi := row(o, "n", 3), ot := thumbOf(oi)
check(ot != "" && InStr(ot, 'loading="lazy"') && InStr(ot, 'width="39"'), "organizer: an image row shows a lazy, pre-sized thumbnail")
check(InStr(oi, "320 × 180") && !InStr(oi, "[IMAGE]"), "organizer: the image row names its dimensions instead of [IMAGE]")
og := row(o, "n", 4)
check(og != "" && thumbOf(og) = "" && InStr(og, "82 × 70"), "organizer: an image whose file is missing falls back to its dimensions")
check(thumbOf(row(o, "n", 1)) = "", "organizer: text rows have no thumbnail")

; ---- WebHost.CacheUrl, in a scratch working dir ----
hostChecks() {
	dir := A_Temp "\cnk-cacheurl-" A_TickCount
	DirCreate(dir "\cache\thumbs1")
	SetWorkingDir dir
	check(WebHost.CacheUrl("cache\history\abc.jpg") = "https://cache.clipnik/history/abc.jpg", "CacheUrl maps cache\ paths onto cache.clipnik")
	check(WebHost.CacheUrl("cache/thumbs1/5.jpg") = "https://cache.clipnik/thumbs1/5.jpg", "CacheUrl takes forward slashes too")
	FileAppend("first", "cache\thumbs1\5.jpg")
	a := WebHost.CacheUrl("cache\thumbs1\5.jpg", true)
	check(RegExMatch(a, "^https://cache\.clipnik/thumbs1/5\.jpg\?v=\d+-\d+$"), "a stamped CacheUrl carries the file's size and time: " a)
	FileDelete("cache\thumbs1\5.jpg"), FileAppend("a different, longer image", "cache\thumbs1\5.jpg")
	check(WebHost.CacheUrl("cache\thumbs1\5.jpg", true) != a, "a renumbered channel thumbnail gets a new URL, so the WebView cannot serve the old image")
	SetWorkingDir A_ScriptDir
	DirDelete(dir, true)
}
try hostChecks()
catch as e
	check(false, "host checks: " e.Message)

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
