; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
/*
Search in Paste Mode functions and labels file.
introduced in v10.6

The search box lives inside the HUD card. Typing is captured with an InputHook, so the target application keeps
the keyboard focus and paste lands where the user expects. [Advanced] SearchUsesWindow=1 restores the v1 behavior
(a small activated window with an Edit control) for input methods that need composition.
*/

; Starts the InputHook that feeds the search row of the HUD card.
searchPasteMode_hook() {
	global
	hkZ(pstIdentifier pastemodekey.f, SPM_dispose)
	SPM.ih := InputHook("")
	SPM.ih.KeyOpt("{Enter}{Esc}{Home}{Up}{Down}", "NSI")   ; I: never collected as text, so OnChar stays quiet
	SPM.ih.KeyOpt("{Backspace}", "NS")
	SPM.ih.OnChar := spm_onChar
	SPM.ih.OnKeyDown := spm_onKeyDown
	SPM.ih.Start()
	searchpm_edit()
}

spm_onChar(ih, ch) {
	global SPM
	if SPM.ACTIVE
		searchpm_edit()
}

spm_onKeyDown(ih, vk, sc) {
	global SPM
	if !SPM.ACTIVE
		return
	switch vk {
		case 13: spm_paste()            ; Enter
		case 27, 36: spm_cancel()       ; Esc, Home
		case 38: spm_nextres()          ; Up
		case 40: spm_prevres()          ; Down
		case 8: SetTimer(searchpm_edit, -1)   ; Backspace: the buffer changes after this callback
	}
}

; Legacy: creates the search overlay window (title Clipjump_SPM) just above the card.
searchPasteMode(x, y, h) {
	global
	local g, edit, counter
	hkZ(pstIdentifier pastemodekey.f, SPM_dispose)

	GuiDestroy("searchpm")
	g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Clipjump_SPM")
	CJGUI["searchpm"] := g
	Theme.ApplyToGui(g, 3, true)
	edit := Theme.Add(g, "Edit", "x1 y1 w220 R1 vsearchpm -VScroll")
	counter := Theme.Add(g, "Edit", "x+5 yp w45 r1 vsearchpm_ct +Disabled") ;show like 4/17
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

; current search text
spm_term() {
	global SPM, CJGUI
	if IsObject(SPM.ih)
		return SPM.ih.Input
	try return CJGUI["searchpm"]["searchpm"].Value
	return ""
}

; publishes the match counter; the HUD reads SPM.matchIndex / SPM.matchCount when it renders
spm_setCounter(index, count) {
	global SPM, CJGUI
	SPM.matchIndex := index, SPM.matchCount := count
	try CJGUI["searchpm"]["searchpm_ct"].Value := index "/" count
}

searchpm_edit(*) {
	global
	local term
	; this runs on the search hook's thread and searchpm_search() below walks every clip in every
	; channel, so an Enter arriving mid-scan disposes the search underneath us. SPM and SEARCHOBJ are
	; CJMaps, so once SPM_dispose has reset them every field reads back "" - check on both sides of
	; the scan rather than trusting the state we entered with.
	if !SPM.ACTIVE
		return
	term := spm_term()
	SPM.term := term
	SPM.cnt := searchpm_search(term)
	if !SPM.ACTIVE
		return
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
	if IsObject(SPM.ih)
		try SPM.ih.Stop()
	GuiDestroy("searchpm")
	SPM.ACTIVE := 0
	; the lock has to be CLEARED before the wait below: that loop polls ctrlRef, and a live LOCK.ACTIVE
	; stops ctrlCheck from ever clearing it, which would freeze here for the full ten seconds
	local resumeLock := 0
	if LOCK.ACTIVE
	{
		if SPM.KEEP
			pasteLock_clear() 		; the search committed: let ctrlCheck finish the operation
		else
			resumeLock := 1 		; dismissed: hand the keyboard back, but not until the reset below
	}
	if SPM.KEEP
	{
		loop 500 { 	; wait for ctrlCheck to finish the paste (10 s at most)
			if (ctrlRef = "")
				break
			Sleep 20
		}
		changeChannel(SPM.CHANNEL, 0), TEMPSAVE := realActive := SPM.TEMPSAVE, SPM.KEEP := 0 ; in paste mode where paste occurs, realactive holds tempsave
	}
	SPM := CJMap(), SEARCHOBJ := CJMap()
	; only now: resuming re-registers the bare search key, and a press landing before that reset
	; would start a fresh searchpm() whose SPM/SEARCHOBJ this line then wipes mid-flight
	if resumeLock
		pasteLock_resume()
}

searchpm(*) {
	global
	local px := 0, py := 0, pw := 0, ph := 0, h
	if IsObject(SPM.ih) || GuiExists("searchpm")
		return
	SPM.ACTIVE := 1
	Hud.GetPos(&px, &py, &pw, &ph)
	if pw
		Hud.Anchor(px, py) 	; keep the card where it is while searching
	SPM.X := px, SPM.Y := py
	SPM.term := "", SPM.matchIndex := "", SPM.matchCount := ""
	correctTEMPSAVE(), SPM.TEMPSAVE := TEMPSAVE, SPM.CHANNEL := CN.NG
	CN["CURSAVE" CN.N] := CURSAVE, CN["TEMPSAVE" CN.N] := TEMPSAVE 	; load all values in CN obj
	; the legacy window binds ^Enter/^Home/^Up/^Down, which need a Ctrl the locked card does not have
	if (ini_searchUsesWindow && !LOCK.ACTIVE) {
		h := getControlInfo("edit", "some", "h") 		; get height of edit box
		searchPasteMode(px, py - h - 5, h) 		; 5 space betn them
	} else
		searchPasteMode_hook()
}

searchpm_search(term) {
	global
	local c := 0, r, k, v, found := CJMap()
	; build into a local and publish it in one assignment: a dispose landing mid-scan used to reset
	; SEARCHOBJ between the two halves of SEARCHOBJ[r][k], which then threw on a plain string
	loop CN.Total
	{
		r := A_Index - 1
		found[r] := CJMap()
		for k, v in CDS[r]
		{
			if SuperInstr(getRealCD(v) " " clipPref(r, k, "Tags"), Trim(term, " "), 1)
				found[r][k] := "|", c++
		}
	}
	found.pointer := c ? 1 : 0
	found.rescount := c
	SEARCHOBJ := found
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
		spm_setCounter(SEARCHOBJ.pointer, SEARCHOBJ.rescount)
		changeChannel(nextch, 0) ; 0 = don't save values
		IN_BACK := 0 ; not in back - don't allow TEMPSAVE change
		TEMPSAVE := nextclip
		paste()
		return 1
	}
	else {
		spm_setCounter(0, 0)
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
