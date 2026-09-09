;#########################
;LESS CHANGEABLE LABELS AND FUNCTIONS (v1 labels are now functions with a variadic signature)
;#########################

; Used Labels

run_searchpm(*) {
	searchpm()
}

settings(*) {
	gui_Settings()
}

history(*) {
	gui_History()
}

classTool(*) {
	API.runPlugin("external.ignoreWmanager.ahk")
}

tray_deleteFileFolder(*) {
	API.runPlugin("deleteFileFolder.ahk")
}

main(*) {
	aboutGUI()
}

exitClipjump(*) {
	routines_Exit()
	ExitApp
}

reloadCustom(*) {
	resetCustomizations()
	loadCustomizations()
	MsgBox(TXT.TIP_done, PROGNAME, 64)
}

chrHex(n) {
	return Chr(base2Number(n, 16))
}

GetHFONT(Options := "", Name := "") {
	g := Gui()
	g.SetFont(Options, Name)
	ctl := g.Add("Text", , "Dummy")
	HFONT := DllCall("User32.dll\SendMessage", "Ptr", ctl.Hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "UPtr") ; WM_GETFONT
	g.Destroy()
	Return HFONT
}

;BeepAt()
;SoundBeep function
BeepAt(value, freq, duration := 150) {
	if value
		SoundBeep(freq, duration)
}

;EmptyMem()
;	Emtpties free memory

EmptyMem() {
	global ini_ram_flush
	return ini_ram_flush ? DllCall("psapi.dll\EmptyWorkingSet", "UInt", -1) : 0
}

FoolGUI(enable := 1) {
	global CJGUI
	if !enable {
		GuiDestroy("foolgui")
		return
	}
	GuiDestroy("foolgui")
	g := Gui("-Caption +E0x80000 +OwnDialogs +Owner +AlwaysOnTop", "foolgui")
	CJGUI["foolgui"] := g
	g.Show("NA")
	WinActivate("ahk_id " g.Hwnd)
}

;Function for FileCopy, FileMove
FileTransfer(src, dest := "", keep_original := 1, flag := 1) {
	if (dest = "") {
		try FileDelete(src)
		return
	}
	try {
		if keep_original
			FileCopy(src, dest, flag)
		else
			FileMove(src, dest, flag)
	}
}

;Try getting the Clipboard text, retrying while another process holds the clipboard
tryGetClipboard(maxtries := 100) {
	ret := ""
	loop maxtries {
		try {
			ret := A_Clipboard
			break
		} catch {
			MakeClipboardAvailable(0, 10)
		}
	}
	return ret
}

; v1 compatibility: tryGetvar("Clipboard") is the only use in the codebase
tryGetvar(varname, maxtries := 100) {
	if (varname = "Clipboard")
		return tryGetClipboard(maxtries)
	return VarGet(varname)
}

; Parses the string and converts the %....% to their respective values
; From   https://github.com/aviaryan/autohotkey-scripts/blob/master/Functions/ValueOf.ahk
; Supports %var%, %obj.key% and %obj.key.key2%

Valueof(VarinStr) {
	loop
	{
		StrReplace(VarinStr, "%", "%", , &cnt)
		Midpoint := cnt // 2
		if (Midpoint = 0)
			return VarinStr
		p1 := InStr(VarinStr, "%", , 1, Midpoint)
		p2 := InStr(VarinStr, "%", , 1, Midpoint + 1)
		emVar := SubStr(VarinStr, p1 + 1, p2 - p1 - 1)

		if InStr(emVar, ".") {
			parts := StrSplit(emVar, ".")
			emVar := VarGet(Trim(parts[1]))
			loop parts.Length - 1
				emVar := IsObject(emVar) ? emVar[Trim(parts[A_Index + 1])] : ""
		}
		else
			emVar := VarGet(emVar)
		if IsObject(emVar)
			emVar := "" 	; v1 rendered objects as an empty string

		VarinStr := SubStr(VarinStr, 1, p1 - 1) emVar SubStr(VarinStr, p2 + 1)
	}
}


multInputBox(Title, caption := "", row := 5, default := "", owner := "") {
	global CJGUI, STORE, TXT
	theEdit := ""
	oDone := 0
	kw := A_ScreenWidth < 1200 ? 600 : 700
	GuiDestroy("mIBox")
	g := Gui("", Title)
	CJGUI["mIBox"] := g
	g.SetFont("s10", "Consolas")
	g.Add("Text", "x5 y5", caption)
	g.SetFont("norm", "Consolas")
	editCtl := g.Add("Edit", "xp y+30 w" kw " r" row " vtheEdit", default)
	g.Add("Button", "x5 y+30 Default", "OK").OnEvent("Click", onOK)
	g.Add("Button", "x+30 yp", TXT.SET_Cancel).OnEvent("Click", onClose)
	g.OnEvent("Close", onClose)
	g.OnEvent("Escape", onClose)
	if owner {
		g.Opt("+Owner" CJGUI[owner].Hwnd)
		CJGUI[owner].Opt("+Disabled")
	}
	g.Show()
	while !oDone
		Sleep 50
	return theEdit

	onOK(*) {
		theEdit := editCtl.Value
		STORE.ErrorLevel := 1
		onClose()
	}

	onClose(*) {
		if owner
			CJGUI[owner].Opt("-Disabled")
		GuiDestroy("mIBox")
		oDone := 1
	}
}

errMsgBox(Text) {
	MsgBox(Text "`n`n" TXT.TIP_genErrMsg, TXT["_clipjumpError"], 48)
}

/*
a := CJMap("a", "b", "c", "d")
ret := ObjectEditView(a, ["Title", owner, prompt, width])
for k,v in ret
	msgbox k "`n" v
return

Options (opn), a 1-based Array
	1: Title
	2: owner
	3: prompt
	4: width
*/

ObjectEditView(obj, opn, readonly := 0) {
	global CJGUI, TXT
	oDone := 0
	opt(i) => opn.Has(i) ? opn[i] : ""
	GuiDestroy("objEdit")
	g := Gui("", opt(1))
	CJGUI["objEdit"] := g
	g.SetFont("s10 underline", "Consolas")
	g.Add("Text", "x5 y5", opt(3))
	g.Add("Text", "xp y+15 section")
	g.SetFont("norm", "Consolas")

	maxsize := 0
	for k in obj
		if StrLen(k) > maxsize
			maxsize := StrLen(k)
	maxsize := maxsize * 5 + 100

	fields := []
	for k, v in obj {
		g.Add("Text", "xs y+7", k)
		fields.Push(g.Add("Edit", "x" maxsize " yp" (readonly ? " +Readonly" : "") " w" (opt(4) ? opt(4) : 100), v))
	}
	g.Add("Button", "x5 y+30 Default", readonly ? "OK" : TXT._save).OnEvent("Click", onSave)
	g.Add("Button", "x+30 yp", TXT.SET_Cancel).OnEvent("Click", onClose)
	g.OnEvent("Close", onClose)
	g.OnEvent("Escape", onClose)
	if opt(2) {
		g.Opt("+Owner" CJGUI[opt(2)].Hwnd)
		CJGUI[opt(2)].Opt("+Disabled")
	}
	g.Show()

	while !oDone
		Sleep 50
	return obj

	onClose(*) {
		if opt(2)
			CJGUI[opt(2)].Opt("-Disabled")
		GuiDestroy("objEdit")
		oDone := 1
	}

	onSave(*) {
		i := 0
		for k in obj
			obj[k] := fields[++i].Value
		onClose()
	}
}

;Try getting a file onto Clipboard
try_ClipboardfromFile(file, maxtries := 100) {
	temp_ClipbrdLoaded := 0
	loop maxtries {
		try {
			A_Clipboard := ClipFileRead(file)
			temp_ClipbrdLoaded := 1
			break
		}
	}
	while !DllCall("OpenClipboard", "Ptr", 0)
		Sleep 10
	DllCall("CloseClipboard")
	return temp_ClipbrdLoaded
}

getRealCD(text) {
; Substitues [IMAGE] for blank data in CDS . Used by the search funcs in search paste mode and Organizer
	return text = "" ? TXT.HST_viewimage : text
}

ClipTransfer(sub, cno, nsub := "", ncno := "", keep_original := 1, flag := 1) {
; Copy moves a clip along with the 3 or more files
; TODO Change params in prefs.ini also
	FileTransfer("cache\clips" sub "\" cno ".avc", "cache\clips" nsub "\" ncno ".avc", keep_original, flag)
	FileTransfer("cache\thumbs" sub "\" cno ".jpg", "cache\thumbs" nsub "\" ncno ".jpg", keep_original, flag)
}

ClipSwap(sub, cno, nsub := "", ncno := "") {
	; Swaps two clips
	ClipTransfer(sub, cno, sub, 100000, 0)
	ClipTransfer(nsub, ncno, sub, cno, 0)
	ClipTransfer(sub, 100000, nsub, ncno, 0)
}

ClipFolderTransfer(sub, nsub, keep_original := 1, flag := 1) {
; Copy moves a channel with the 3 folders
	static dirs := ["clips", "thumbs"] ;, "fixate"
	for d in dirs {
		try {
			if keep_original
				DirCopy("cache\" d sub, "cache\" d nsub, flag)
			else
				DirMove("cache\" d sub, "cache\" d nsub, flag)
		}
	}
}

;Checks and makes sure Clipboard is available
;Use 0 as the param when for calling the function, the aim is only to free clipboard and not get its contents
MakeClipboardAvailable(doreturn := 1, sleeptime := 10) {
	while !DllCall("OpenClipboard", "Ptr", 0)
		Sleep sleeptime
	DllCall("CloseClipboard")
	ret := ""
	if doreturn
		try ret := A_Clipboard
	return ret
}

;type=1
;	returns Text
;type=0
;	returns data types
GetClipboardFormat(type := 1) {		;Thanks nnnik
	Critical "On"
	x := "", c := 0
	DllCall("OpenClipboard", "Ptr", 0)
	while c := DllCall("EnumClipboardFormats", "UInt", c, "UInt")
		x .= "," c
	DllCall("CloseClipboard")

	if (type = 1) {
		if InStr(x, ",1") && InStr(x, ",13")
			return "[" TXT.TIP_text "]"
		else if InStr(x, ",15")
			return "[" TXT.TIP_file_folder "]"
		else
			return ""
	}
	return x
}

;--------------------------------------------------------------------------
;      S Q L     F U N C T I O N S
;--------------------------------------------------------------------------

; Converts YYYYMMDDHHMMSS to YYYY-MM-DD HH:MM:SS
convertTimeSql(t := "") {
	if (t == "")
		t := A_Now
	return SubStr(t, 1, 4) "-" SubStr(t, 5, 2) "-" SubStr(t, 7, 2) " " SubStr(t, 9, 2) ":" SubStr(t, 11, 2) ":" SubStr(t, 13, 2)
}

escapeQuotesSql(s) {
	; replace quote (") in data content with double quote ("")
	; works like escaping
	return StrReplace(s, '"', '""')
}

fileSizeFromStr(s) {
	; in bytes
	; + 3 comes from other file constraints
	return StrLen(s) + 3
}

execSql(s, warn := 0) {
	; execute sql
	if !DB.Exec(s)
		if warn
			MsgBox(DB.ErrorCode "`n" DB.ErrorMsg)
}

getFromTable(tbl, cols, condition) {
	; get from table
	; get only particular columns if necessary
	; returns the first matching row as an Array, or "" when nothing matches
	q := "select " . cols . " from " . tbl . " where " condition
	if !DB.Query(q, &recordSet) {
		MsgBox("ERROR")
		return ""
	}
	Row := ""
	if (recordSet.Next(&Row) <= 0)
		Row := ""
	recordSet.Free()
	return Row
}

saveBlobImage(blobobj, path) {
	; saves the image held in a blob Buffer at path
	if !IsObject(blobobj) || !blobobj.Size {
		MsgBox("Empty blob", "Error")
		return
	}
	HFILE := FileOpen(path, "w")
	HFILE.RawWrite(blobobj)
	HFILE.Close()
}

;-------------------------------------------------------------


getRandomStr(len) {
	rStr := "abcdefghijiklmnopqrstuvwxyz0123456789"
	str := ""
	loop len
		str .= SubStr(rStr, Random(1, 36), 1)
	return str
}

genHTMLforPreview(code) {
	try FileDelete(PREV_FILE)
	FileAppend('<pre style="word-break: break-all; word-wrap: break-word;">' deActivateHtml(code), PREV_FILE)
}

deactivateHtml(code) {
	code := StrReplace(code, ">", "&gt;")
	code := StrReplace(code, "<", "&lt;")
	return code
}

TT_Console_PasteMode(text, keys) {
	global ini_pstMode_X, ini_pstMode_Y, SPM
	tx := ini_pstMode_X ? ini_pstMode_X : SPM.X, ty := ini_pstMode_Y ? ini_pstMode_Y : SPM.Y
	return TT_Console(text, keys, tx, ty, , , 1)
}

;GetFile()
;	Gets file path of selected item in Explorer

GetFile(hwnd := "") {
	hwnd := hwnd ? hwnd : WinExist("A")
	cls := WinGetClass("ahk_id " hwnd)
	ToReturn := ""
	if (cls = "CabinetWClass" || cls = "ExploreWClass") {
		sel := ""
		try for window in ComObject("Shell.Application").Windows
			if (window.hwnd == hwnd)
				sel := window.Document.SelectedItems
		if IsObject(sel)
			for item in sel
				ToReturn .= item.path "`n"
	}
	else
		ToReturn := CopytoVar(4)

	return Trim(ToReturn, "`n")
}

;GetFolder()
;	Gets folder path of active window in Explorer

GetFolder() {
	var := WinGetClass("A")
	if (var = "CabinetWClass" || var = "ExplorerWClass" || var = "Progman") {
		v := ""
		if (var = "Progman")
			v := A_Desktop
		else {
			Fullpath := WinGetText("A")
			loop parse Fullpath, "`n", "`r"
			{
				if (p := InStr(A_LoopField, ":\")) {
					v := SubStr(A_LoopField, p - 1)
					break
				}
			}
		}
		return v
	}
	return CopytoVar(2, "!{sc020}^{sc02e}{Esc}") 			;!d^c
}

;BrowserRun()
;	Runs a web-site in default browser safely.

BrowserRun(site) {
	OutputVar := ""
	try OutputVar := RegRead("HKCR\http\shell\open\command")
	if (OutputVar != "") {
		OutputVar := StrReplace(OutputVar, '"')
		SplitPath(OutputVar, , &OutDir, , &OutNameNoExt)
		try Run(OutDir . "\" . OutNameNoExt . ".exe" . ' "' . site . '"')
	}
	else
		try Run('iexplore.exe "' . site . '"')
}

;hkZ()
;	Hotkey command function. fn is a function object (or a name resolved via ACTIONS).

hkZ(key, fn, Status := 1) {
	if (key = "")
		return
	if !(fn is Func)
		fn := actionFor(fn)
	try
		Hotkey(key, fn, Status ? "On" : "Off")
	catch {
		t := ""
		loop parse key
			if IsAlpha(A_LoopField)
				t .= "vk" GetVKList(A_LoopField)[1]
			else
				t .= A_LoopField
		try
			Hotkey(t, fn, Status ? "On" : "Off")
		catch
			MsgBox("It looks like the hotkey " t " doesn't exist ? `nRefer to troubleshooting page in help file.", "Clipjump Warning", 16)
	}
}

/**
 * hkz that prepends pstIdentfier
 */
hkZ_pi(key, fn, status := 1) {
	global pstIdentifier
	return hkZ(pstIdentifier key, fn, status)
}

; Resolves a v1 label name to its function (ACTIONS map), falling back to keyblocker.
actionFor(name) {
	global ACTIONS
	if (name is Func)
		return name
	if ACTIONS.Has(name)
		return ACTIONS[name]
	f := FuncByName(name)
	return f ? f : keyblocker
}

; Converts an Ini file to an object
Ini2Obj(Ini) {
	out := CJMap()
	curS := ""
	if !FileExist(Ini)
		return out
	loop read Ini
	{
		if (InStr(l := Trim(A_LoopReadLine), ";") == 1) || !l
			continue
		if RegExMatch(l, "iU)\[.*\]", &ov) {
			curS := SubStr(ov[0], 2, -1), out[curS] := CJMap()
			continue
		}
		if !out.Has(curS)
			out[curS] := CJMap()
		out[curS][k := Trim(SubStr(l, 1, p := InStr(l, "=") - 1))] := Trim(SubStr(l, p + 2))
	}
	return out
}

; Saves an object as an Ini file
Obj2Ini(obj, Ini, saveBlank := false) {
	try FileDelete(Ini)
	t := ""
	for k, v in obj
	{
		t .= "`n[" k "]`r`n"
		if IsObject(v)
			for k2, v2 in v
				if (saveBlank) || (v2 != "")
					t .= k2 " = " v2 "`r`n"
	}
	FileAppend(Trim(t, "`r`n"), Ini)
}

;Gdip_SetImagetoClipboard()
;	Sets some Image to Clipboard

Gdip_SetImagetoClipboard(pImage) {
	;Sets some Image file to Clipboard
	PToken := Gdip_Startup()
	pBitmap := Gdip_CreateBitmapFromFile(pImage)
	Gdip_SetBitmapToClipboard(pBitmap)
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(PToken)
}

;Gdip_CaptureClipboard()
;	Captures Clipboard to file

Gdip_CaptureClipboard(file, quality) {
	PToken := Gdip_Startup()
	pBitmap := Gdip_CreateBitmapFromClipboard()
	Gdip_SaveBitmapToFile(pBitmap, file, quality)
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(PToken)
}

; Gdip_Getdimensions()

Gdip_getLengths(img, &width, &height) {
	GDIPToken := Gdip_Startup()
	pBM := Gdip_CreateBitmapFromFile(img)
	width := Gdip_GetImageWidth(pBM)
	height := Gdip_GetImageHeight(pBM)
	Gdip_DisposeImage(pBM)
	Gdip_Shutdown(GDIPToken)
}

;	Flexible Active entity analyzer

IsActive(what, oftype := "classnn", ispattern := false) {
	O := ""
	try {
		if (oftype = "classnn")
			O := ControlGetClassNN(ControlGetFocus("A"))
		else if (oftype = "window")
			O := WinGetTitle("A")
	}
	if ispattern
		return InStr(O, what) ? 1 : 0
	else
		return (O == what) ? 1 : 0
}

;Taken from Miscellaneous Functions by Avi Aryan
getParams(sum) {
	a := 1, p := ""
	while sum > 0
		loop
		{
			a *= 2
			if (a > sum) {
				a /= 2, p .= Round(a) " ", sum -= a, a := 1
				break
			}
		}
	return SubStr(p, 1, -1)
}

autoTooltip(Text, Time, which := 1) {
	ToolTip(Text, , , which)
	SetTimer(CJ_TooltipOff(which), -Time)
}

; Returns the (cached) function that clears tooltip number n, usable with SetTimer on/off.
CJ_TooltipOff(n := 1) {
	static fns := Map()
	if !fns.Has(n) {
		fns[n] := off
		off(*) {
			SetTimer(fns[n], 0)
			ToolTip(, , , n)
		}
	}
	return fns[n]
}

emptylabel(*) {
}

keyblocker(*) {
}

simplePaste(*) { 		; simple label to paste CURRENT content on cb.
	Send("^{vk56}")
}

shortcutblocker_settings(ThisHotkey := "", *) {
	try GuiCtrlFromHwnd(ControlGetFocus("A")).Value := ThisHotkey
}

IsHotkeyControlActive(*) {
	return IsActive("msctls_hotkey", "classnn", true)
}

getQuant(str, what) {
	StrReplace(str, what, what, , &count)
	return count
}

;Used for Debugging
debugTip(text, x := "", y := "", tooltipno := 20) {
	ToolTipAt(text, x, y, tooltipno)
}

fillwithSpaces(text := "", limit := 35) {
	r := ""
	loop limit - StrLen(text)
		r .= A_Space
	return text r
}

/**
 * TickCount in 64 bit precision
 */
TickCount64() {
	return DllCall("GetTickCount64", "Cdecl UInt64")
}

/*
SuperInstr()
	Returns min/max position for a | separated values of Needle(s)

	return_min = true  ; return minimum position
	return_max = false ; return maximum position

*/
SuperInstr(Hay, Needles, return_min := true, CaseSense := false, Startpoint := 1, Occurrence := 1) {
	pos := return_min * StrLen(Hay)
	Needles := RTrim(Needles, " ")

	if return_min {
		loop parse Needles, A_Space
			if (pos > (var := InStr(Hay, A_LoopField, CaseSense, Startpoint, Occurrence)))
				pos := var
	}
	else {
		if (Needles = "")
			return StrLen(Hay)
		loop parse Needles, A_Space
			if ((var := InStr(Hay, A_LoopField, CaseSense, Startpoint, Occurrence)) > pos)
				pos := var
	}
	return pos
}

/*
Compare Versions
*/

IsLatestRelease(prog_ver, cur_ver, exclude_keys := "b|a") {
	if RegExMatch(prog_ver, "(" exclude_keys ")")
		return 1

	prog := StrSplit(prog_ver, ".")
	cur := StrSplit(cur_ver, ".")

	loop cur.Length - prog.Length
		prog.Push(0)

	loop cur.Length
		if !(prog[A_Index] >= cur[A_Index])
			return 0
		else if (prog[A_Index] > cur[A_Index]) 	; in case cur_ver supplied is of old file
			return 1
	return 1
}

;get width and heights of controls
getControlInfo(type := "button", text := "", ret := "w", fontsize := "", fontmore := "") {
	g := Gui()
	g.SetFont(fontsize, fontmore)
	ctl := g.Add(type, , text)
	ctl.GetPos(, , &w, &h)
	g.Destroy()
	if (ret = "w")
		return w
	if (ret = "h")
		return h
}

;GUI Message Box to allow selection
guiMsgBox(title, text, owner := "", isEditable := 0, wait := 0, w := "", h := "") {
	global CJGUI
	wf := getControlInfo("edit", text, "w", "s9", "Lucida Console")
	hf := getControlInfo("edit", text, "h", "s9", "Lucida Console")
	w := !w ? (wf > A_ScreenWidth / 1.5 ? A_ScreenWidth / 1.5 : wf + 200) : w 	;+10 for scl bar
	h := !h ? (hf > A_ScreenHeight ? A_ScreenHeight : hf + 65) : h 		;+10 for margin, +more for the button
	w := Round(w), h := Round(h)

	GuiDestroy("guiMsgBox")
	g := Gui("-MaximizeBox +AlwaysOnTop", title)
	CJGUI["guiMsgBox"] := g
	if (owner != "" && CJGUI.Has(owner))
		g.Opt("+Owner" CJGUI[owner].Hwnd)
	g.SetFont("s9", "Lucida Console")
	box := g.Add("Edit", "x5 y5 w" (w - 10) " h" (h - 35) (isEditable ? " -" : " +") "Readonly +Multi -Border", text)
	btn := g.Add("Button", "x" (w / 2 - 20) " w40 y+5", "OK")
	btn.OnEvent("Click", onClose)
	g.OnEvent("Close", onClose)
	g.OnEvent("Escape", onClose)
	btn.Focus()
	g.Show("w" w " h" h)
	GuiEnds := 0
	result := text
	if wait
		while !GuiEnds
			Sleep 100
	return result

	onClose(*) {
		result := box.Value
		GuiDestroy("guiMsgBox")
		GuiEnds := 1
	}
}


;inputbox function for use with customizer...
cjInputBox(title, text) {
	ib := InputBox(text, title)
	if (ib.Result = "OK")
		return ib.Value
	return ""
}

Base2Number(H, base := 16) {
	S := StrLen(H), N := 0
	loop parse H
		N += (IsDigit(A_LoopField) ? A_LoopField : Ord(StrLower(A_LoopField)) - 87) * base ** (S - A_Index)
	return N
}

; Code by deo http://www.autohotkey.com/board/topic/74348-send-command-when-switching-to-russian-input-language/#entry474543

GetVKList(letter) {
	vk_list := []
	_list := ""
	for i, hkl in KeyboardLayoutList()
	{
		retVK := DllCall("VkKeyScanExW", "UShort", Ord(letter), "Ptr", hkl, "Short")
		if (retVK = -1)
			continue
		vk := Format("{:x}", retVK & 0xFF)
		if !InStr(_list, "|" vk "|") {
			_list .= "|" vk "|"
			vk_list.Push(vk)
		}
	}
	return vk_list
}

KeyboardLayoutList() {
	hkl_num := 20
	hHkls := Buffer(hkl_num * A_PtrSize, 0)
	num := DllCall("GetKeyboardLayoutList", "UInt", hkl_num, "Ptr", hHkls)
	hkl_list := []
	loop num
		hkl_list.Push(NumGet(hHkls, (A_Index - 1) * A_PtrSize, "UPtr"))
	return hkl_list
}
