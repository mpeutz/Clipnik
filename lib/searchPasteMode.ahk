/*
Search in Paste Mode functions and labels file.
introduced in v10.6
*/

; Creates the search overlay window (title Clipjump_SPM) just above the paste-mode tooltip.
searchPasteMode(x, y, h) {
	global
	local g, edit, counter
	hkZ(pstIdentifier pastemodekey.f, SPM_dispose)

	GuiDestroy("searchpm")
	g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Clipjump_SPM")
	CJGUI["searchpm"] := g
	edit := g.Add("Edit", "x1 y1 w220 R1 vsearchpm -VScroll")
	counter := g.Add("Edit", "x+5 yp w45 r1 vsearchpm_ct +Disabled") ;show like 4/17
	edit.OnEvent("Change", searchpm_edit)
	g.OnEvent("Escape", spm_cancel)
	g.Show("x" x " y" y " w" (220 + 2 + 5 + 45) " h" (h + 2))

	HotIfWinActive("Clipjump_SPM ahk_class AutoHotkeyGUI")
	hkZ(spmkey.enter, spm_paste, 1)
	hkZ(spmkey.home, spm_cancel, 1)
	hkZ(spmkey.up, spm_nextres, 1)
	hkZ(spmkey.down, spm_prevres, 1)
	HotIf()

	searchpm_edit()
}

; current text of the search box ("" when the overlay is not open)
spm_term() {
	global CJGUI
	try return CJGUI["searchpm"]["searchpm"].Value
	return ""
}

spm_setCounter(text) {
	global CJGUI
	try CJGUI["searchpm"]["searchpm_ct"].Value := text
}

searchpm_edit(*) {
	global
	local term := spm_term()
	SPM.cnt := searchpm_search(term)
	searchpm_jumptomatch(SPM.CHANNEL, SPM.TEMPSAVE + 1, 1, (term = "") || (SPM.cnt = 0) ? 1 : 0)
}

spm_paste(*) {
	global
	ctrlref := "pastemode", SPM.KEEP := 1, MULTIPASTE := 0 	;multipaste will end as this step terminates the ops
	SPM_dispose()
}

spm_cancel(*) {
	global
	ctrlref := "cancel", SPM.KEEP := 1, MULTIPASTE := 0
	SPM_dispose()
}

spm_nextres(*) {
	global
	if SPM.cnt {
		correctTEMPSAVE()
		++SEARCHOBJ.pointer
		searchpm_jumptomatch(CN.NG, TEMPSAVE, 1)
	}
}

spm_prevres(*) {
	global
	if SPM.cnt {
		correctTEMPSAVE()
		--SEARCHOBJ.pointer
		searchpm_jumptomatch(CN.NG, TEMPSAVE, -1)
	}
}

SPM_dispose(*) {
	global
	GuiDestroy("searchpm")
	SPM.ACTIVE := 0
	if SPM.KEEP
	{
		while ctrlRef != ""
			Sleep 20
		changeChannel(SPM.CHANNEL, 0), TEMPSAVE := realActive := SPM.TEMPSAVE, SPM.KEEP := 0 ; in paste mode where paste occurs, realactive holds tempsave
	}
	SPM := CJMap(), SEARCHOBJ := CJMap()
}

searchpm(*) {
	global
	local pmtip_x := 0, pmtip_y := 0, h
	SPM.ACTIVE := 1
	GuiDestroy("imgprv")
	try WinGetPos(&pmtip_x, &pmtip_y, , , "ahk_class tooltips_class32")
	SPM.X := pmtip_x, SPM.Y := pmtip_y
	correctTEMPSAVE(), SPM.TEMPSAVE := TEMPSAVE, SPM.CHANNEL := CN.NG
	CN["CURSAVE" CN.N] := CURSAVE, CN["TEMPSAVE" CN.N] := TEMPSAVE 	; load all values in CN obj
	h := getControlInfo("edit", "some", "h") 		; get height of edit box
	searchPasteMode(pmtip_x, pmtip_y - h - 5, h) 		; 5 space betn them
}

searchpm_search(term) {
	global
	local c := 0, r, k, v
	SEARCHOBJ := CJMap()
	loop CN.Total
	{
		r := A_Index - 1
		SEARCHOBJ[r] := CJMap()
		for k, v in CDS[r]
		{
			if SuperInstr(getRealCD(v) " " clipPref(r, k, "Tags"), Trim(term, " "), 1)
				SEARCHOBJ[r][k] := "|", c++
		}
	}
	SEARCHOBJ.pointer := c ? 1 : 0
	SEARCHOBJ.rescount := c
	return c
}

searchpm_jumptomatch(ich, iclip, f, default := 0) {
	global
	local spm_isfound, nextch := "", nextclip := ""
	spm_isfound := searchpm_findmatch(ich, iclip, f, &nextch, &nextclip)
	if (SEARCHOBJ.pointer > SEARCHOBJ.rescount)
		SEARCHOBJ.pointer := 1
	if (SEARCHOBJ.pointer < 1)
		SEARCHOBJ.pointer := SEARCHOBJ.rescount
	if default
		nextch := SPM.CHANNEL, nextclip := SPM.TEMPSAVE
	if spm_isfound
	{
		spm_setCounter(SEARCHOBJ.pointer "/" SEARCHOBJ.rescount)
		changeChannel(nextch, 0) ; 0 = don't save values
		IN_BACK := 0 ; not in back - don't allow TEMPSAVE change
		TEMPSAVE := nextclip
		paste()
		return 1
	}
	else {
		spm_setCounter("0/0")
		if (nextch != "")
			changeChannel(nextch, 0)
		IN_BACK := 0, TEMPSAVE := (nextclip != "") ? nextclip : CURSAVE
		paste()
		return 0
	}
}

searchpm_findmatch(curch, curclip, f := 1, &nextch := "", &nextclip := "") {
	global
	local r, l, n, t, j, done := 0
	loop CN.Total + 1
	{
		r := f > 0 ? (A_Index + curch - 1) : (1 - A_Index + curch)
		if (r >= CN.Total)
			r := r - CN.Total
		if r < 0
			r := CN.Total + r 	;
		l := (A_Index = CN.Total + 1)

		n := SEARCHOBJ[r].MaxIndex()
		loop (n = "" ? 0 : n)
		{
			if f > 0
			{
				if SEARCHOBJ[r].HasKey(t := n - A_Index + 1)
				{
					j := 0, j := (l ? (t >= curclip) : (t < curclip)) + (curch != r)
					if j
						nextch := r, nextclip := t, done := 1
				}
			}
			else
			{
				if SEARCHOBJ[r].HasKey(t := A_Index)
				{
					j := 0, j := (l ? (t <= curclip) : (t > curclip)) + (curch != r)
					if j
						nextch := r, nextclip := t, done := 1
				}
			}
			if done
				return 1
		}
	}
	return 0
}
