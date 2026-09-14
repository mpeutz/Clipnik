; The Vault against a RUNNING Clipjump: entries reach the page, keep the user's order, survive an edit with a
; re-detected kind, are reachable from Clipboard History and the Organizer, and are never pruned.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\vault_flow.ahk
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 1
cj := Clipjump()
title := "Clipjump Clipboard History ahk_class AutoHotkeyGUI"
logFile := A_Temp "\Clipjump\webhost.log"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
step(s) => FileAppend("     .. " s "`n", "*")
; the host appends to this file constantly; a read that collides with a write must not take the suite down
readLog() {
	global logFile
	try
		return FileExist(logFile) ? FileRead(logFile) : ""
	catch
		return ""
}
waitUntil(cond, ms := 6000) {
	t := A_TickCount
	loop {
		if cond()
			return true
		if (A_TickCount - t > ms)
			return false
		Sleep 100
	}
}
lastList() {
	last := ""
	for line in StrSplit(readLog(), "`n", "`r")
		if InStr(line, '"cmd":"list"') && InStr(line, '"rows"')
			last := line
	return last
}
; the order comes from the store, not from the page's log line: the host truncates that at 200 characters
order() {
	global cj
	return cj.runFunction("Vault_Order()")
}
lastId() {
	ids := StrSplit(order(), ",")
	return ids.Length ? ids[ids.Length] : 0
}
; the host truncates each log line at 200 characters, so a row's text may not be in it at all. "matched"
; sits at the front of the payload, so compare that instead. The expected value is read once: asking the app
; on every poll would put a WM_COPYDATA round trip inside a 100 ms loop.
global expectedMatched := ""
vaultListShown() {
	global expectedMatched
	return InStr(lastList(), '"matched":"' expectedMatched '"') ? true : false
}
; where an id sits in the whole vault order, so the checks work with entries the user already had
posOf(id) {
	i := 0
	for v in StrSplit(order(), ",") {
		i++
		if (v = id)
			return i
	}
	return 0
}

before := Integer(cj.runFunction("vaultCount()"))
stamp := A_TickCount

step("entries added to the store reach the page")
a := Integer(cj.runFunction("vaultAdd(vault-one-" stamp ",0)"))
b := Integer(cj.runFunction("vaultAdd(https://example.com/v" stamp ",0)"))
check("two entries were added", a && b && Integer(cj.runFunction("vaultCount()")) = before + 2)
cj.runFunction("vaultSetName(" a ",Alpha Entry)")
check("the name is stored trimmed", cj.runFunction("Vault_NameOf(" a ")") = "Alpha Entry")

try FileDelete(logFile)
cj.runLabel("history")
check("the history window opens", WinWait(title, , 8) != 0)
WinActivate(title)
Sleep 1500
; the window keeps whichever view it was left in, and Close only hides it, so put it on history explicitly
; rather than assuming a fresh page: setView does nothing when it is already on the view being asked for
cj.runFunction("History_SetView(history)")
Sleep 1000
check("the history view does not show vault entries", !InStr(lastList(), "vault-one-" stamp))
expectedMatched := cj.runFunction("vaultCount()")
cj.runFunction("History_SetView(vault)")
check("the vault list reaches the page", waitUntil(vaultListShown))

step("the order is the user's")
check("new entries land at the end, in the order they were added", posOf(a) > 0 && posOf(b) = posOf(a) + 1)
check("moving the second entry up succeeds", cj.runFunction("vaultMove(" b ",-1)") = 1)
check("the two swapped places", posOf(b) + 1 = posOf(a))
first := StrSplit(order(), ",")[1]
check("moving whatever is first up is a no-op", cj.runFunction("vaultMove(" first ",-1)") = 0)

step("editing rewrites the entry and its kind")
cj.runFunction("vaultSetText(" a ",https://example.com/edited" stamp ")")
check("the text changed", InStr(cj.runFunction("Vault_TextOf(" a ")"), "example.com/edited" stamp))
check("the kind was re-detected", cj.runFunction("Vault_KindOf(" a ")") = "url")

step("a clip reaches the Vault from Clipboard History")
A_Clipboard := "from-history-" stamp
Sleep 1500
hid := cj.runFunction("History_NewestId()")
cj.runFunction("History_SaveToVault(" hid ")")
Sleep 500
check("the history row was copied in", InStr(cj.runFunction("Vault_TextOf(" lastId() ")"), "from-history-" stamp))
fromHistory := lastId()

step("an image reaches the Vault from the Organizer at full size")
p := Gdip_Startup()
bmp := Gdip_CreateBitmap(140, 90)
gr := Gdip_GraphicsFromImage(bmp)
br := Gdip_BrushCreateSolid(0xFFCC3366)
Gdip_FillRectangle(gr, br, 0, 0, 140, 90)
Gdip_DeleteBrush(br), Gdip_DeleteGraphics(gr)
Gdip_SetBitmapToClipboard(bmp)
Gdip_DisposeImage(bmp), Gdip_Shutdown(p)
Sleep 2500
cj.runFunction("Organizer_SaveToVault(" cj["CN.NG"] ",1)")
Sleep 1500
img := lastId()
check("it is an image entry", cj.runFunction("Vault_KindOf(" img ")") = "image")
rel := cj.runFunction("Vault_FileOf(" img ")")
check("with a file of its own: " rel, rel != "" && FileExist(A_ScriptDir "\..\" rel))
w := 0, h := 0
p2 := Gdip_Startup()
if (bm2 := Gdip_CreateBitmapFromFile(A_ScriptDir "\..\" rel)) {
	w := Gdip_GetImageWidth(bm2), h := Gdip_GetImageHeight(bm2)
	Gdip_DisposeImage(bm2)
}
Gdip_Shutdown(p2)
check("saved at the original size, not the thumbnail's (" w "x" h ")", w = 140 && h = 90)

step("nothing prunes the Vault")
; historyCleanup, not historyPrune with limits of our own: this runs against the user's real database, and a
; call like historyPrune(1,1,1) would trim their Clipboard History to a single row every time the suite ran.
; historyCleanup applies the limits already configured in settings, which is what happens daily anyway.
; The limits themselves are covered against a temporary database in tests/history_prune.ahk.
n := Integer(cj.runFunction("vaultCount()"))
hist := Integer(cj.runFunction("History_Count()"))
cj.runFunction("historyCleanup()")
check("the cleanup that runs daily leaves the Vault alone", Integer(cj.runFunction("vaultCount()")) = n)
check("and it did not empty history either (" hist " rows)", Integer(cj.runFunction("History_Count()")) > 0 || hist = 0)

step("delete takes the entry and its file")
cj.runFunction("vaultDelete(" img ")")
check("the image entry is gone", cj.runFunction("Vault_KindOf(" img ")") = "")
check("and so is its file", !FileExist(A_ScriptDir "\..\" rel))
cj.runFunction("vaultDelete(" a ")")
cj.runFunction("vaultDelete(" b ")")
cj.runFunction("vaultDelete(" fromHistory ")")
check("the vault is back where it started", Integer(cj.runFunction("vaultCount()")) = before)

cj.runFunction("History_SetView(history)")
cj.runFunction("History_Close()")
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
