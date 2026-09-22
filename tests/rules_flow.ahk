; Copy-time rules against a RUNNING Clipnik: a URL rule routes to channel 1 (the toast names that channel and
; the active channel is unchanged), a transform rule rewrites the clip and its kind, an email rule tags the clip,
; an ignore rule drops a clip, and an image rule routes an image clip to a channel. Rules are restored afterwards.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
#Include ..\lib\vendor\Gdip_All.ahk
SetTitleMatchMode 1
cj := Clipnik()
ini := A_ScriptDir "\..\settings.ini"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
; text of the newest copy toast, "|" separated (the message is a Static, the {channel} pill a Button)
toastText() {
	t := "Clipnik_Toast ahk_class AutoHotkeyGUI"
	if !WinExist(t)
		return ""
	out := ""
	for ctl in WinGetControls(t)
		if InStr(ctl, "Static") || InStr(ctl, "Button")
			out .= ControlGetText(ctl, t) "|"
	return out
}
; Clipnik coalesces clipboard notifications that arrive inside 200 ms (unchanged from v1), and AHK's own
; "A_Clipboard :=" clears the clipboard before it writes, so a copy is occasionally swallowed whole. Wait for
; the clip to actually land where the rule should put it, and copy again if it never did, rather than assuming
; one write is always seen. A retry only ever happens when nothing landed, so the strength checks still hold.
copyUntil(text, ch, needle, tries := 4) {
	global cj
	loop tries {
		A_Clipboard := text
		t := A_TickCount
		while (A_TickCount - t < 2500) {
			if InStr(cj.getClipAt(ch, 1), needle)
				return true
			Sleep 150
		}
	}
	return false
}
old := IniRead(ini, "Rules", , "")
; A run killed before its restore block leaves these rules behind in the user's live settings, where they
; go on routing every image and URL to channel 1 and dropping anything starting with "secret-". Never take
; this test's own rules for the user's: drop them here so an interrupted run is cleaned up by the next one.
mine := ["name=mdflip", "name=links", "name=secrets", "name=shots", "action=tag:contact"]
kept := ""
loop parse old, "`n", "`r" {
	line := A_LoopField
	if (line = "")
		continue
	isMine := false
	for m in mine
		if InStr(line, m)
			isMine := true
	if !isMine
		kept .= (kept != "" ? "`n" : "") line
}
old := kept
stamp := A_TickCount
mdName := cj["TXT.TRF_markdownLink"]
try IniDelete(ini, "Rules")
IniWrite("on=1;kinds=url;regex=mdflip;app=;action=transform:" mdName ";name=mdflip", ini, "Rules", 1)
IniWrite("on=1;kinds=url;regex=;app=AutoHotkey64.exe;action=channel:1;name=links", ini, "Rules", 2)
IniWrite("on=1;kinds=email;regex=;app=;action=tag:contact", ini, "Rules", 3)
IniWrite("on=1;kinds=;regex=^secret-;app=;action=ignore;name=secrets", ini, "Rules", 4)
IniWrite("on=1;kinds=image;action=channel:1;name=shots", ini, "Rules", 5)
cj.runFunction("changeChannel(1)")   ; make sure channel 1 exists
Sleep 200
cj.runFunction("changeChannel(0)")
Sleep 200
cj.runFunction("reloadRules()")
g := Gui("+AlwaysOnTop", "cj-rules-target")
g.Add("Edit", "w300 h80")
g.Show()
WinWaitActive("cj-rules-target", , 5)
before1 := Integer(cj.runFunction("API.getChStrength(1)")), before0 := Integer(cj.runFunction("API.getChStrength(0)"))
landed := copyUntil("https://example.com/r" stamp, 1, "example.com/r" stamp)
toast := toastText()
check("url copy was recorded at all", landed)
check("url routed to channel 1", Integer(cj.runFunction("API.getChStrength(1)")) = before1 + 1 && InStr(cj.getClipAt(1, 1), "example.com/r" stamp))
check("active channel unchanged", cj["CN.NG"] = 0)
check("channel 0 did not keep it", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
ch1 := IniRead(ini, "Channels", "1", "")
if (cj["copyMessage"] != "")
	check("toast names the target channel, not the active one [" toast "]"
		, InStr(toast, "|" (ch1 != "" ? ch1 : "1") "|") && !InStr(toast, "|Default|"))
else
	FileAppend("     .. copy messages are off, toast text not checked`n", "*")

check("email copy was recorded at all", copyUntil("r" stamp "@example.com", 0, "@example.com"))
check("email tagged", cj.runFunction("clipPref(0," cj["CURSAVE"] ",Tags)") = "contact")
before0 := Integer(cj.runFunction("API.getChStrength(0)"))
A_Clipboard := "secret-" stamp
Sleep 1200
; the toast proves the rule fired: without it, a copy Clipnik never saw would pass this check too
igToast := toastText()
check("ignore rule announced itself [" igToast "]", InStr(igToast, "secrets"))
check("secret ignored", Integer(cj.runFunction("API.getChStrength(0)")) = before0)

; An image rule: copy-time rules never ran for images before this change. Route the image to channel 1 and
; confirm it lands there with the active channel unchanged, mirroring the URL-routing check above.
before1img := Integer(cj.runFunction("API.getChStrength(1)")), before0img := Integer(cj.runFunction("API.getChStrength(0)"))
pToken := Gdip_Startup()
pBitmap := Gdip_CreateBitmap(50, 40)
imgG := Gdip_GraphicsFromImage(pBitmap)
pBrush := Gdip_BrushCreateSolid(0xFF2266CC)
Gdip_FillRectangle(imgG, pBrush, 0, 0, 50, 40)
Gdip_DeleteBrush(pBrush), Gdip_DeleteGraphics(imgG)
Gdip_SetBitmapToClipboard(pBitmap)
Gdip_DisposeImage(pBitmap)
Sleep 1500
Gdip_Shutdown(pToken)
n1img := Integer(cj.runFunction("API.getChStrength(1)"))
check("image routed to channel 1", n1img = before1img + 1 && cj.runFunction("ClipType_KindOf(1," n1img ")") = "image")
check("active channel unchanged after image rule", cj["CN.NG"] = 0)
check("channel 0 did not keep the image", Integer(cj.runFunction("API.getChStrength(0)")) = before0img)

; A transform rule rewrites the clip, so its kind must be detected again afterwards. This goes last: writing the
; new text back takes Rules_ApplyTransform up to a second with monitoring blocked, and a copy made in that window
; would be lost.
; deliberately not copyUntil here: polling the app over WM_COPYDATA while Rules_ApplyTransform is rewriting
; the clip interrupts the copy path mid-transform and the kind is left un-redetected. Wait it out instead.
A_Clipboard := "https://example.com/mdflip" stamp
Sleep 4000
md := cj.getClipAt(0, 1)
check("transform rule rewrote the clip [" md "]", SubStr(md, 1, 1) = "[" && InStr(md, "mdflip" stamp))
check("kind re-detected after the transform (" cj["LASTKIND"] ")", cj["LASTKIND"] = "text")
check("stored kind re-detected too", cj.runFunction("clipPref(0," cj["CURSAVE"] ",Kind)") = "text")

try IniDelete(ini, "Rules")
if (old != "")
	loop parse old, "`n", "`r"
		if (p := InStr(A_LoopField, "="))
			IniWrite(SubStr(A_LoopField, p + 1), ini, "Rules", SubStr(A_LoopField, 1, p - 1))
cj.runFunction("reloadRules()")
g.Destroy()
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
