;@Plugin-Name Common Formats
;@Plugin-Description Shows a gui to paste with a format from many types of predefined formats. Can be easily extended to include more formats.
;@Plugin-Description For that edit the pformat.commonformats.lib/user.ahk file. This file if needed is created when you run this plugin for the first time.
;@Plugin-Description Only works for Text ([Text] or [File/Folder]) type data.
;@Plugin-Author Avi
;@Plugin-Tags pformat
;@Plugin-version 0.61
;@Plugin-Previewable 0

;@Plugin-Param1 The Input Text

;------------------------------------------------------------- Paste Formats ------------------------------------

; ###### ADD USER paste formats in user.ahk file (AutoHotkey v2 syntax) #####
#Include *i %A_ScriptDir%\plugins\pformat.commonformats.lib\user.ahk
; ####################################################


plugin_pformat_commonformats_None(zin) {
	global STORE
	STORE["commonformats_None"] := "This returns the original clip rejecting any change made to the clip."
	STORE.ClipboardChanged := 0
	return zin
}

plugin_pformat_commonformats_HTMLList(zin) {
	global STORE
	STORE.ClipboardChanged := 1
	return RegExReplace(Trim(zin, "`r`n "), "m`a)^", "<li>")
}

plugin_pformat_commonformats_BBCodeList(zin) {
	global STORE
	STORE.ClipboardChanged := 1
	return RegExReplace(Trim(zin, "`r`n "), "m`a)^", "[*]")
}

plugin_pformat_commonformats_TrimFormatting(zin) {
	global STORE
	STORE.ClipboardChanged := 1
	return RTrim(zin, "`r`n")
}

plugin_pformat_commonformats_NumberedList(zin) {
	global STORE
	zin := Trim(zin, "`r`n ")
	zout := ""
	loop parse zin, "`n", "`r"
		zout .= A_Index ". " A_LoopField "`r`n"
	STORE.ClipboardChanged := 1
	return zout
}

plugin_pformat_commonformats_lowercase(zin) {
	global STORE
	STORE.ClipboardChanged := 1
	return StrLower(zin)
}

plugin_pformat_commonformats_TrimWhiteSpace(zin) {
	global STORE
	STORE["commonformats_TrimWhiteSpace"] := "Trims white space from the beginning and end of string"
	STORE.ClipboardChanged := 1
	return Trim(zin, "`r`n `t")
}

plugin_pformat_commonformats_DeHTML(zin) {
	global STORE
	STORE["commonformats_DeHTML"] := 'Deactivates HTML code. All (" & < >) are translated to (&quot; &amp; &lt; &gt;) and linefeed \n to <br>.'
	return plugin_pformat_commonformats_TrimWhiteSpace(plugin_pformat_commonformats_htmlEncode(zin))
}

; Equivalent of the v1 "Transform, HTML" command
plugin_pformat_commonformats_htmlEncode(text) {
	out := ""
	loop parse text {
		c := A_LoopField
		code := Ord(c)
		if (c = "&")
			out .= "&amp;"
		else if (c = '"')
			out .= "&quot;"
		else if (c = "<")
			out .= "&lt;"
		else if (c = ">")
			out .= "&gt;"
		else if (c = "`n")
			out .= "<br>`n"
		else if (code > 127)
			out .= "&#" code ";"
		else
			out .= c
	}
	return out
}

plugin_pformat_commonformats_UPPERCASE(zin) {
	global STORE
	STORE.ClipboardChanged := 1
	return StrUpper(zin)
}

#Include *i %A_ScriptDir%\plugins\pformat.commonformats.lib\unhtml.ahk
plugin_pformat_commonformats_UnHTML(zin) {
	global STORE
	STORE["commonformats_unhtml"] := "Converts HTML code to Plain Text. Removes tags from HTML code and converts unicode sequences to characters."
	zin := StrReplace(zin, "<br>", "`n")
	STORE.ClipboardChanged := 1
	return Trim(unhtml(zin), "`n`r`t ")
}

plugin_pformat_commonformats_RegexReplace(zin, zps) {
	global STORE
	STORE["commonformats_RegexReplace"] := "Write Search Needle in first line and replacement string in second line in Input Field. The Replace is based on Autohotkey's"
	 . " RegexReplace(). Learn more at http://www.autohotkey.com/docs/commands/RegExReplace.htm"

	parts := StrSplit(zps, "`n", "`r")
	zps1 := parts.Has(1) ? parts[1] : "", zps2 := parts.Has(2) ? parts[2] : ""
	try
		zout := RegExReplace(zin, zps1, zps2)
	catch
		zout := zin
	STORE.ClipboardChanged := 1
	return zout
}


;--------------------------------- The Plugin File Starts , end of Paste Formats ---------------------------------
;-----------------------------------------------------------------------------------------------------------------


plugin_pformat_commonformats(zin) {
	global STORE, TXT, CJGUI
	static zchosenformat := ""
	zDone := "", zOut := "", zFobj := ""

	GuiDestroy("commonformat")
	g := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox", "Choose Format")
	CJGUI["commonformat"] := g

	ztF := A_ScriptDir "\plugins\pformat.commonformats.lib\user.ahk"
	formats := plugin_pformat_commonformats_listfunc(A_ScriptDir "\plugins\pformat.commonformats.ahk")
	if (ztemp := plugin_pformat_commonformats_listfunc(ztF))
		formats .= "|" ztemp
	lb := g.Add("ListBox", "x5 y5 r15 w140 vzchosenformat section", StrSplit(formats, "|"))
	editCtl := g.Add("Edit", "x+10 w500 h200 vzedit +Multi", zin)

	g.Add("GroupBox", "xs y+5 h70 w650", "Info")
	info := g.Add("Edit", "xp+5 yp+15 w640 h50 +ReadOnly -Border vzinfo")

	g.Add("Button", "xs y+40 +Default", "OK").OnEvent("Click", onOK)
	g.Add("Button", "x+30 yp", TXT.SET_apply).OnEvent("Click", onApply)
	g.Add("Text", "x+55 yp-15", "Input Field")
	g.SetFont("s10", "Lucida Console")
	g.SetFont("s10", "Consolas")
	inputfield := g.Add("Edit", "x+10 yp-2 w441 h40 vzinputfield")
	g.SetFont()
	lb.OnEvent("Change", onChosen)
	lb.OnEvent("DoubleClick", onChosenDouble)
	inputfield.OnEvent("Change", onInput)
	g.OnEvent("Close", onCancel)
	g.OnEvent("Escape", onCancel)
	g.Show()

	if !FileExist(ztF)
	{
		DirCreate(SubStr(ztF, 1, InStr(ztF, "\", , -1) - 1))
		FileAppend("; Add User paste formats here (AutoHotkey v2 syntax)`n; Prefix - plugin_pformat_commonformats_", ztF)
	}

	lb.Choose(zchosenformat = "" ? "None" : zchosenformat) ; choose the previous active format
	onChosen()
	zDone := 0 	; used as an identifier in onChosen
	while !zDone
		Sleep 200
	GuiDestroy("commonformat") 		; The original clip will be pasted if you close the gui
	return zOut

	onOK(*) {
		STORE.ClipboardChanged := 1, zOut := editCtl.Value
		if (zchosenformat = "None") || (zchosenformat = "")
			zOut := zin, STORE.ClipboardChanged := 0
		zDone := 1
	}

	onCancel(*) {
		zDone := 1
		STORE.ClipboardChanged := 1
		zOut := ""				; cancel paste if user escapes or closes the window
	}

	onApply(*) {
		zin := editCtl.Value
	}

	onInput(*) {
		if !zFobj
			return
		zoutput := (zFobj.MaxParams > 1) ? zFobj(zin, inputfield.Value) : zFobj(zin)
		STORE.ClipboardChanged := 0 		; remove any clipboard change
		editCtl.Value := zoutput
		info.Value := STORE["commonformats_" zchosenformat]
	}

	onChosenDouble(*) {
		if (zDone != "")
			onOK()
	}

	onChosen(*) {
		inputfield.Value := ""
		zchosenformat := lb.Text
		if (zchosenformat = "")
			zchosenformat := "None"
		zFobj := FuncByName("plugin_pformat_commonformats_" zchosenformat)
		if !zFobj
			return
		if (zFobj.MaxParams < 2)
			inputfield.Enabled := false
		else {
			inputfield.Enabled := true
			inputfield.Focus()
		}
		onInput()
	}
}

;---------------------------------- Functions used by this plugin -------------------

; Lists the plugin_pformat_commonformats_* functions defined in a file, sorted, | separated, without the prefix.
plugin_pformat_commonformats_listfunc(file) {
	if !FileExist(file)
		return ""
	z := FileRead(file)
	z := StrReplace(z, "`r")			; important
	z := RegExReplace(z, "mU)`"[^`n]*`"", "") ; strings
	z := RegExReplace(z, "mU)'[^`n]*'", "")
	z := RegExReplace(z, "iU)/\*.*\*/", "") ; block comments
	z := RegExReplace(z, "m);[^`n]*", "")  ; single line comments
	p := 1, z := "`n" z, lst := ""
	while q := RegExMatch(z, "iU)`n[^ `t`n,;``\(\):=\?]+\([^`n]*\)[ `t`n]*{", &o, p)
	{
		zfk := SubStr(RegExReplace(o[0], "\(.*", ""), 2)
		if HasFuncByName(zfk)
			if !InStr("|plugin_pformat_commonformats_listfunc|plugin_pformat_commonformats|plugin_pformat_commonformats_htmlEncode|", "|" zfk "|")
				lst .= "`n" RegExReplace(zfk, "^(plugin_pformat_commonformats_)", "", , 1)
		p := q + StrLen(o[0]) - 1
	}
	lst := Sort(lst)
	return Trim(RegExReplace(lst, "`n", "|"), "|")
}
