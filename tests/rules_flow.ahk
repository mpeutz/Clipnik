; Copy-time rules against a RUNNING Clipjump: a URL rule routes to channel 1 (the toast names that channel and
; the active channel is unchanged), a transform rule rewrites the clip and its kind, an email rule tags the clip,
; an ignore rule drops a clip. Rules are restored afterwards.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 1
cj := Clipjump()
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
	t := "Clipjump_Toast ahk_class AutoHotkeyGUI"
	if !WinExist(t)
		return ""
	out := ""
	for ctl in WinGetControls(t)
		if InStr(ctl, "Static") || InStr(ctl, "Button")
			out .= ControlGetText(ctl, t) "|"
	return out
}
old := IniRead(ini, "Rules", , "")
stamp := A_TickCount
mdName := cj["TXT.TRF_markdownLink"]
try IniDelete(ini, "Rules")
IniWrite("on=1;kinds=url;regex=mdflip;app=;action=transform:" mdName ";name=mdflip", ini, "Rules", 1)
IniWrite("on=1;kinds=url;regex=;app=AutoHotkey64.exe;action=channel:1;name=links", ini, "Rules", 2)
IniWrite("on=1;kinds=email;regex=;app=;action=tag:contact", ini, "Rules", 3)
IniWrite("on=1;kinds=;regex=^secret-;app=;action=ignore;name=secrets", ini, "Rules", 4)
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
A_Clipboard := "https://example.com/r" stamp
Sleep 900
toast := toastText()
check("url routed to channel 1", Integer(cj.runFunction("API.getChStrength(1)")) = before1 + 1 && InStr(cj.getClipAt(1, 1), "example.com/r" stamp))
check("active channel unchanged", cj["CN.NG"] = 0)
check("channel 0 did not keep it", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
ch1 := IniRead(ini, "Channels", "1", "")
if (cj["copyMessage"] != "")
	check("toast names the target channel, not the active one [" toast "]"
		, InStr(toast, "|" (ch1 != "" ? ch1 : "1") "|") && !InStr(toast, "|Default|"))
else
	FileAppend("     .. copy messages are off, toast text not checked`n", "*")

A_Clipboard := "r" stamp "@example.com"
Sleep 900
check("email tagged", cj.runFunction("clipPref(0," cj["CURSAVE"] ",Tags)") = "contact")
before0 := Integer(cj.runFunction("API.getChStrength(0)"))
A_Clipboard := "secret-" stamp
Sleep 900
check("secret ignored", Integer(cj.runFunction("API.getChStrength(0)")) = before0)

; A transform rule rewrites the clip, so its kind must be detected again afterwards. This goes last: writing the
; new text back takes Rules_ApplyTransform up to a second with monitoring blocked, and a copy made in that window
; would be lost.
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
