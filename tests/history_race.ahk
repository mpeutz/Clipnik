; Clipboard History with its list replies arriving out of order: the page asked for the history list, then for the
; Vault's, and the history reply comes back last (a large history takes a while). The page must keep showing the
; Vault it switched to, not the late history rows. Standalone: headless Edge against the mock bridge's ?race mode.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\history_race.ahk
#Requires AutoHotkey v2.0
#Include lib\edge_dump.ahk
OnError((e, *) => (FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*"), ExitApp(1)))
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

h := EdgeDump("history\index.html?race=1")
check(InStr(h, 'id="rows"'), "history page rendered (" StrLen(h) " bytes of DOM)")
check(RegExMatch(h, 'id="viewVault"[^>]*class="[^"]*\bon\b') || RegExMatch(h, 'class="[^"]*\bon\b[^"]*"[^>]*id="viewVault"'), "the page switched to the Vault")
check(InStr(h, "Signature") && InStr(h, "Shipping address"), "the Vault's entries are shown")
check(!InStr(h, "Filler clip number"), "the late history reply did not replace them")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
