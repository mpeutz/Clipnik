; Copy-time rules against a RUNNING Clipjump: a URL rule routes to channel 1 with the active channel unchanged,
; an email rule tags the clip, an ignore rule drops a clip. Rules are restored afterwards.
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
old := IniRead(ini, "Rules", , "")
stamp := A_TickCount
try IniDelete(ini, "Rules")
IniWrite("on=1;kinds=url;regex=;app=AutoHotkey64.exe;action=channel:1;name=links", ini, "Rules", 1)
IniWrite("on=1;kinds=email;regex=;app=;action=tag:contact", ini, "Rules", 2)
IniWrite("on=1;kinds=;regex=^secret-;app=;action=ignore;name=secrets", ini, "Rules", 3)
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
check("url routed to channel 1", Integer(cj.runFunction("API.getChStrength(1)")) = before1 + 1 && InStr(cj.getClipAt(1, 1), "example.com/r" stamp))
check("active channel unchanged", cj["CN.NG"] = 0)
check("channel 0 did not keep it", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
A_Clipboard := "r" stamp "@example.com"
Sleep 900
check("email tagged", cj.runFunction("clipPref(0," cj["CURSAVE"] ",Tags)") = "contact")
before0 := Integer(cj.runFunction("API.getChStrength(0)"))
A_Clipboard := "secret-" stamp
Sleep 900
check("secret ignored", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
try IniDelete(ini, "Rules")
if (old != "")
	loop parse old, "`n", "`r"
		if (p := InStr(A_LoopField, "="))
			IniWrite(SubStr(A_LoopField, p + 1), ini, "Rules", SubStr(A_LoopField, 1, p - 1))
cj.runFunction("reloadRules()")
g.Destroy()
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
