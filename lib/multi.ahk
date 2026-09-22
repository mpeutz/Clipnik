; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;--------------------- CHANNELS FOR CLIPNIK --------------------------
;== IDEAS ==
;	TEMPSAVE, CURSAVE
;		TOTALCLIPS
;
;	Folders to be specified by N ("", 1, 2, 3)
;	CN.TotalClips = unlimited for other modes (1, 2, 3, 4, 5, 6) and as specified in Ini for 0 channel
;	CN.Name = name of channel
;	CN.N = contains Folder names amendment of the active Channel
;	CN.NG = contains real channel indexes 0,1,2
;	CN.Total = Total number of channels
; 	CN.pit_NG = contains item active before the Pit swap
;
;   out of these CN.Total and TEMPSAVE,CURSAVE are only permananent var, all others are temporarily created at channel change.
;----------------------------------------------------------------------

initChannels() {
	global
	local T, temp
	CN := CJMap()
	loop {
		T := (A_Index - 1) ? A_Index - 1 : ""
		if !FileExist("cache\clips" T)
			break
		loop {
			if !FileExist("cache/Clips" T "/" A_Index ".avc") {
				CN["TEMPSAVE" T] := CN["CURSAVE" T] := A_Index - 1
				break
			}
		}
		CN.Total := A_Index
	}
	CN.NG := 0, CN.N := ""

	temp := IniRead(CONFIGURATION_FILE, "channels", CN.NG, "")
	CN.Name := (temp == "") ? "Default" : temp
	ini_write("channels", "0", CN.Name)

	CN["TOTALCLIPS"] := TOTALCLIPS
}

changeChannel(cIndex, backup_old := 1) {
; changes channel
; creates new channel if needed
	global
	local temp, T
	if !IsInteger(cIndex)
		return 0
	cIndex := Integer(cIndex)
	if (cIndex == CN.Total) 	; new channel create
	{
		CN.Total += 1, CDS[cIndex] := CJMap(), CPS[cIndex] := CJMap() 	; create storage objs
		CN["TEMPSAVE" cIndex] := CN["CURSAVE" cIndex] := 0
	} else if (cIndex > CN.Total)
		return 0
	temp := IniRead(CONFIGURATION_FILE, "channels", cIndex, "")
	CN.Name := (temp == "") ? (!cIndex ? "Default" : cIndex) : temp

	if !cIndex
		TOTALCLIPS := CN["TOTALCLIPS"], cIndex := ""
	else
		TOTALCLIPS := CN["TOTALCLIPS" cIndex] ? CN["TOTALCLIPS" cIndex] : 999999999999 			;if exist, use it

	if backup_old
		CN["TEMPSAVE" CN.N] := TEMPSAVE, CN["CURSAVE" CN.N] := CURSAVE, CN.prevCh := CN.NG	;Saving Old - TEMPSAVE is auto-corrected at
		;the end of paste mode and so no need to fix it.
	CN.N := cIndex, CN.NG := !CN.N ? 0 : CN.N 				;note that cIndex has been emptied if 0

	TEMPSAVE := CN["TEMPSAVE" cIndex] + 0, CURSAVE := CN["CURSAVE" cIndex] + 0		;Restoring current

	T := SubStr(CLIPS_dir, -1)
	if IsInteger(T)
		CLIPS_dir := SubStr(CLIPS_dir, 1, -1), THUMBS_dir := SubStr(THUMBS_dir, 1, -1)

	CLIPS_dir .= cIndex, THUMBS_dir .= cIndex

	DirCreate(CLIPS_dir)
	DirCreate(THUMBS_dir)

	LASTCLIP := LASTFORMAT := IScurCBACTIVE := "" 								;make all false as they are different for other channels
	renameChannel(CN.NG, CN.Name)
	OrganizerWin.Notify() 		; the organizer shows the active channel
	EmptyMem()
	return 1
}

renameChannel(ch, nm) {
	global
	ini_write("Channels", ch, Trim(nm), 0)
	if (CN.NG == ch) {
		CN.Name := nm
		CopyMessage := !ini_IsMessage ? "" : MSG_TRANSFER_COMPLETE " {" CN.Name "}"
		A_IconTip := PROGNAME " {" CN.Name "}"
	}
}

;--------------------------- select channel box --------------------------------------------------------------

; Modal list of channels. Returns the chosen channel index, or "" when cancelled.
choosechannelgui(guiname := "") {
	global CJGUI, TXT
	if (guiname = "")
		guiname := TXT.CHC_name
	channel_list := ""
	cancelled := 0
	done := 0
	GuiDestroy("choosech")
	g := Gui("+ToolWindow -MaximizeBox", guiname)
	CJGUI["choosech"] := g
	g.MarginX := 16, g.MarginY := 16
	Theme.ApplyToGui(g)
	g.Add("Text", "x16 y16 w300", TXT.CNL_choose)
	lb := Theme.Add(g, "ListBox", "x16 y+8 w300 h180 -E0x200 +Border", StrSplit(channel_find(), "`n"))
	lb.OnEvent("DoubleClick", onOK)
	Theme.Add(g, "Button", "x" (16 + 300 - 76 - 8 - 76) " y+12 w76 h28 Default", "OK").OnEvent("Click", onOK)
	Theme.Add(g, "Button", "x+8 yp w76 h28", TXT.SET_cancel).OnEvent("Click", onCancel)
	g.OnEvent("Close", onCancel)
	g.OnEvent("Escape", onCancel)
	g.Show()
	while !done
		Sleep 50
	channel_list := Trim(SubStr(channel_list, 1, InStr(channel_list, "-") - 1))
	return cancelled ? "" : channel_list

	onOK(*) {
		channel_list := lb.Text
		if (channel_list != "") {
			GuiDestroy("choosech")
			done := 1
		}
	}

	onCancel(*) {
		cancelled := 1
		GuiDestroy("choosech")
		done := 1
	}
}

;--------------------------- find a channel ------------------------------------------------------------------

channel_find(name := "") {
	global CN, CONFIGURATION_FILE
	; returns list of channels if name is empty
	rINI := Ini2Obj(CONFIGURATION_FILE)
	name := Trim(name)
	str := ""

	if IsNumber(name)
		return name
	else if (name != "") {
		for k, v in rINI["Channels"]
			if (v = name)
				return k
	}
	else
		loop CN.Total
			str .= A_Index - 1 " - " rINI["Channels"][A_Index - 1] "`n"
	return RTrim(str, "`n")
}

;--------------------------- Other functions ------------------------------------------------------

; moves a channel or deletes it; in moving dest channel if exists is deleted
manageChannel(orig, new := "") {
	global
	static l := ["clips", "thumbs"]
	local c, z, bk, d

	if (new = "") {
		if !orig
			return 	; dnt delete 0
		for d in l
			try DirDelete("cache\" d orig, 1)
		ini_delete("Channels", orig)
		CDS[orig] := CJMap(), CPS[orig] := CJMap()
		; move channels one step back
		c := 0
		loop CN.Total - orig - 1
		{
			c := A_Index
			for d in l
				try DirMove("cache\" d (orig + c), "cache\" d (orig + c - 1), "R")
			CDS[orig + c - 1] := CDS[orig + c], CPS[orig + c - 1] := CPS[orig + c]
			ini_write("Channels", orig + c - 1, (z := Ini_read("Channels", orig + c)) && (z != orig + c) ? z : orig + c - 1, 0)
		}
		;done ... final steps
		ini_delete("Channels", orig + c), CDS[orig + c] := CJMap(), CPS[orig + c] := CJMap()			; delete any name to avoid confusion

		bk := CN.NG
		initChannels()
		if (bk >= orig)
			changeChannel(bk - 1, 0) 		; change the channel using proper methodology as initchannels() disturbs it
		else
			changeChannel(bk, 0)
		prefs2Ini()
	}
	else
	{
		;NOT IMPLEMENTED YET - implement CDS also
	}
}
