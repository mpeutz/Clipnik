;@Plugin-Name Common Formats
;@Plugin-Short Common
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
	g := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox", TXT.CMF_title)
	CJGUI["commonformat"] := g
	Theme.ApplyToGui(g)
	g.MarginX := 20, g.MarginY := 14

	ztF := A_ScriptDir "\plugins\pformat.commonformats.lib\user.ahk"
	formats := plugin_pformat_commonformats_listfunc(A_ScriptDir "\plugins\pformat.commonformats.ahk")
	if (ztemp := plugin_pformat_commonformats_listfunc(ztF))
		formats .= "|" ztemp

	w := 680, x := 20, y := 14, listW := 150, colGap := 16
	editW := w - 2 * x - listW - colGap
	zFormats := StrSplit(formats, "|")
	zRowsMax := 12 	; a long user.ahk list scrolls instead of growing the dialog
	zRowsShown := Min(zFormats.Length, zRowsMax)

	lb := Theme.Add(g, "ListView", "x" x " y" y " w" listW " h200 -Hdr -Multi -E0x200 +Border vzchosenformat", ["Format"])
	lb.Opt("Background" Theme.Hex("surface"))
	for zfName in zFormats
		lb.Add("", zfName)

	; Measure the real row height (LVM_GETITEMRECT) and the control's border overhead so the list
	; is sized to whole rows only, showing every format without scrolling when it fits.
	zItemRc := Buffer(16, 0)
	NumPut("Int", 0, zItemRc, 0) 	; LVIR_BOUNDS
	SendMessage(0x100E, 0, zItemRc.Ptr, lb.Hwnd) 	; LVM_GETITEMRECT, row 0
	zRowTop0 := NumGet(zItemRc, 4, "Int")
	if (zFormats.Length >= 2) {
		NumPut("Int", 0, zItemRc, 0)
		SendMessage(0x100E, 1, zItemRc.Ptr, lb.Hwnd) 	; row 1
		zRowH := NumGet(zItemRc, 4, "Int") - zRowTop0
	} else
		zRowH := NumGet(zItemRc, 12, "Int") - zRowTop0
	zClientRc := Buffer(16, 0)
	DllCall("GetClientRect", "Ptr", lb.Hwnd, "Ptr", zClientRc)
	zBorderH := 200 - (NumGet(zClientRc, 12, "Int") - NumGet(zClientRc, 4, "Int"))
	listH := zRowsShown * zRowH + zBorderH
	lb.Move(,, , listH)

	; the column only needs to leave room for the scrollbar when the list actually scrolls
	zNeedsScroll := zFormats.Length > zRowsShown
	lb.ModifyCol(1, listW - (zNeedsScroll ? SysGet(2) : 0) - 2) 	; SysGet(2) = SM_CXVSCROLL

	g.SetFont("s10", "Consolas")
	editCtl := Theme.Add(g, "Edit", "x" (x + listW + colGap) " y" y " w" editW " h" listH " -E0x200 +Border +Multi vzedit", zin)
	g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
	y += listH + 14

	Theme.Section(g, x, y, w - 2 * x, TXT.CMF_info)
	y += 30
	info := Theme.Add(g, "Edit", "x" x " y" y " w" (w - 2 * x) " h50 +ReadOnly -Border -E0x200 vzinfo")
	info.Opt("Background" Theme.Hex("bg"))
	y += 50 + 14

	g.Add("Text", "x" x " y" y " w100 h28 +0x200", TXT.CMF_input)
	g.SetFont("s10", "Consolas")
	inputfield := Theme.Add(g, "Edit", "x" (x + 110) " y" y " w" (w - 2 * x - 110) " h28 -E0x200 +Border vzinputfield")
	g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
	y += 28 + 16

	Theme.Add(g, "Button", "x" (w - x - 76 - 8 - 76) " y" y " w76 h28 Default", "OK").OnEvent("Click", onOK)
	Theme.Add(g, "Button", "x" (w - x - 76) " y" y " w76 h28", TXT.SET_apply).OnEvent("Click", onApply)

	lb.OnEvent("ItemSelect", onChosen)
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

	zRestoreTarget := zchosenformat = "" ? "None" : zchosenformat 	; choose the previous active format
	zRestoreRow := 0
	loop lb.GetCount()
		if (lb.GetText(A_Index) = zRestoreTarget) {
			zRestoreRow := A_Index
			break
		}
	if !zRestoreRow
		loop lb.GetCount()
			if (lb.GetText(A_Index) = "None") {
				zRestoreRow := A_Index
				break
			}
	if zRestoreRow
		lb.Modify(zRestoreRow, "Select Focus Vis")
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

	onChosen(zCtrl := "", zItem := 0, zSelected := 1) {
		if !zSelected 	; ItemSelect also fires on deselect; only react when a row becomes selected
			return
		inputfield.Value := ""
		zRow := lb.GetNext(0)
		zchosenformat := zRow ? lb.GetText(zRow) : "None"
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
