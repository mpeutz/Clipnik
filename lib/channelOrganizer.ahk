/* *****************
  Channel Organizer
 * *****************
*/

; State that v1 kept as statics inside channelOrganizer() now lives in globals initialized in Clipjump.ahk:
;   chOrg_Width, chOrg_Height, chOrg_w_ofSearch                  ; // Needed to make widths and hts save
;   chOrg_t_horizButtons := 8, chOrg_t_startBtn := 2, chOrg_t_commonBtn := 3
;   chOrgLVMenu := Menu(), chOrgLBMenu := Menu(), chOrgSubM := Menu()

/**
 * Function to open channel organizer gui
 * (also the hotkey / tray menu / ACTIONS target that the v1 channelOrganizer label was)
 * @return {void}
 */
channelOrganizer(*){
	global
	local wt, ht, g, lb, lv, sb, ev

	wt := ini_read("Organizer", "w") , ht := ini_read("Organizer", "h")
	if !wt
		wt := A_ScreenWidth>1300 ? 900 : 750
	if !ht
		ht := A_ScreenHeight>800 ? 500 : 400
	chOrg_w_ofSearch := getControlInfo("button", TXT.HST_search, "w", "s10")
	chOrg_Width := wt-158 , chOrg_Height := ht 		; the Size event overwrites these as soon as the window is shown

	;enable tooltips
	OnMessage(0x200, WM_MOUSEMOVE)

	GuiDestroy("chOrg")
	g := Gui("+Resize +MinSize850x500", TXT.ORG__name)
	CJGUI["chOrg"] := g
	g.BackColor := "D2D2D2"
	g.SetFont("s10")
	g.Add("Text", "x" wt - chOrg_w_ofSearch - 200 " y10", TXT.HST_search)
	g.SetFont("s9")
	g.Add("Edit", "x" wt-200 " yp w200 vchOrg_search").OnEvent("Change", chOrg_search_Event) 		; width of EDIT is fixed = 200
	g.SetFont("s10")
	g.Add("Button", "x" 5+115+4+30+4 " yp vchorgNew", TXT.ORG_NewClip).OnEvent("Click", chOrgNew)
	g.Add("Text", "x+30 yp+4", TXT.ORG_chooseCh)
	g.Add("DropDownList", "x+10 w150 yp-3 vchorg_useCh").OnEvent("Change", chorg_UseCh_Event)
	chOrg_addChUseList()
	lb := g.Add("ListBox", "section x5 y+10 w115 h" ht " vchOrg_Lb -LV0X10 AltSubmit") 	; width of LB is fixed = 115
	lb.OnEvent("Change", chOrg_Lb_Event) , lb.OnEvent("DoubleClick", chOrg_Lb_Event)
	chOrg_addChList()

	g.SetFont("s16", "github-octicons")
	g.Add("Button", "x+4 yp+20 w30 h35 +Disabled", chrhex("f040"))
	g.Add("Button", "xp y+20 w30 vchOrgUp", chrhex("f03d")).OnEvent("Click", chOrgUp)			; buttons width = 30
	g.Add("Button", "xp y+2 w30 vchOrgDown", chrhex("f03f")).OnEvent("Click", chOrgDown)
	g.Add("Button", "xp y+2 w30 vchOrgEdit", chrhex("f058")).OnEvent("Click", chOrgEdit)
	g.Add("Button", "xp y+2 w30 vchorg_openPastemode", chrhex("f032")).OnEvent("Click", chOrg_openPasteMode)
	g.Add("Button", "xp y+2 w30 vchOrg_props", chrhex("f015")).OnEvent("Click", chOrg_props)
	g.Add("Button", "xp y+2 w30 vchOrgCut", chrhex("f035")).OnEvent("Click", chOrgCut)
	g.Add("Button", "xp y+2 w30 vchOrgCopy", chrhex("f04d")).OnEvent("Click", chOrgCopy)
	g.Add("Button", "xp y+2 w30 vchOrgDelete", chrhex("f0d0")).OnEvent("Click", chOrgDelete)
	; x = 5+115 + 4 + 30 = 154 + 4
	g.SetFont()
	lv := g.Add("ListView", "x+4 ys -E0x200 w" wt-158 " h" ht " vchOrg_Lv", ["Ch", "#", TXT.HST_clip])
	; v1 g-label (with AltSubmit) fired for clicks, selection/focus changes and column clicks
	for ev in ["Click", "ItemSelect", "ItemFocus", "ColClick", "Focus"]
		lv.OnEvent(ev, chOrg_Lv_Event)
	lv.OnEvent("DoubleClick", chOrg_Lv_DoubleClick)
	lv.ModifyCol(1, "30 Integer") , lv.ModifyCol(2, "30 Integer") , lv.ModifyCol(3, wt-158 -60 -10)
	sb := g.Add("StatusBar", "vchOrg_SB")
	sb.SetParts(5+115)
	g.OnEvent("Size", chOrgGuiSize)
	g.OnEvent("ContextMenu", chOrgGuiContextMenu)
	g.OnEvent("Close", chOrgGuiClose)
	g.OnEvent("Escape", chOrgGuiEscape)
	g.Show()

	lb.Choose(ini_OpenAllChByDef ? 1 : CN.NG+2)
	chOrg_Lb_Event()
	; Gui Done

	; // MENU LV
	chOrgLVMenu.Add(TXT.HST_m_prev, chOrg_preview)
	chOrgLVMenu.Add()
	chOrgLVMenu.Add(TXT.ORG_m_insta, chOrg_paste)
	chOrgLVMenu.Add(TXT.PLG_properties, chOrg_props)
	chOrgLVMenu.Add(TXT.ORG_m_openPst, chOrg_openPasteMode)
		chOrgSubM.Add(TXT.HST_m_edit, chOrgEdit)
		chOrgSubM.Add(TXT.ORG_m_inc , chOrgUp)
		chOrgSubM.Add(TXT.ORG_m_dec , chOrgDown)
		chOrgSubM.Add(TXT.TIP_move "    (" TXT["_!x"] ")", chOrgCut)
		chOrgSubM.Add(TXT.TIP_copy "    (" TXT["_!c"] ")" , chOrgCopy)
	chOrgLVMenu.Add(TXT._more_options, chOrgSubM)
	chOrgLVMenu.Add()
	chOrgLVMenu.Add(TXT.HST_m_ref, chOrg_refresh)
	chOrgLVMenu.Add(TXT.HST_m_del, chOrgDelete)
	chOrgLVMenu.Default := TXT.HST_m_prev

	; // MENU LB
	chOrgLBMenu.Add(TXT._new, chOrgNewCh)
	chOrgLBMenu.Add(TXT.ORG_m_inc, chOrgUp)
	chOrgLBMenu.Add(TXT.ORG_m_dec, chOrgDown)
	chOrgLBMenu.Add(TXT._rename " (F2)", chOrg_renameCh)
	chOrgLBMenu.Add(TXT.HST_m_del, chOrgDelete)

	; Hotkeys
	HotIf(IsChorgActive)
	hkZ("F5", chOrg_refresh)
	hkZ("^f", chOrg_searchfocus)
	hkZ("^n", chOrgNew)
	hkZ("^+n", chOrgNewCh)
	hkZ("^g", chOrg_useChFocus)
	hkZ("!a", chOrg_activateLB)
	hkZ("!s", chOrg_activateLV)
	HotIf()
	HotIf(IsChOrgLVActive)
	hkZ("Enter", chOrg_preview)
	hkZ("Space", chOrg_paste)
	hkZ("!Enter", chOrg_props)
	hkZ("^o", chOrg_openPasteMode)
	hkZ("^h", chOrgEdit)
	hkZ("Del", chOrgDelete)
	hkZ("!Up", chOrgUp)
	hkZ("!Down", chOrgDown)
	hkZ("!x", chOrgCut)
	hkZ("!c", chOrgCopy)
	HotIf()
	HotIf(IsChOrgLBActive)
	hkZ("Del", chOrgDelete)
	hkZ("!Up", chOrgUp)
	hkZ("!Down", chOrgDown)
	hkZ("F2", chOrg_renameCh)
	HotIf()
	HotIf(IsChOrgSearchActive)
	hkZ("Tab", chOrg_activateLV)
	HotIf()
	HotIf(IsPrevActive)
	hkZ("^f", prevSearchfocus)
	HotIf()
}

/**
 * add channel list to the listbox
 */
chOrg_addChList(*) {
	global
	local chList, lb
	chList := RegexReplace( Trim( channel_find(), "`n" ), "`n", "|" )
	chList := Sort(chList, "N D|")
	lb := CJGUI["chOrg"]["chOrg_Lb"]
	lb.Delete()
	lb.Add(StrSplit("|" chList, "|")) 	; v1 "||" chList : the first (blank) item stands for all channels
}

/**
 * gui resize handler
 */
chOrgGuiSize(g, MinMax, W, H) {
	global
	local gui_w, gui_h
	if (MinMax != -1){ 	; -1 = minimized
		gui_w := W , gui_h := H
		g["chOrg_Lv"].Move(, , gui_w-158-5-2, gui_h-80)
		g["chOrg_Lb"].Move(, , , gui_h-80)
		g["chOrg_search"].Move(gui_w-200-5)
		g["Static1"].Move(gui_w- chOrg_w_ofsearch-200-5) , g["Static1"].Redraw()
		chOrg_Width := gui_w-158-5-2
		chOrg_Height := gui_h-80
		g["chOrg_Lv"].ModifyCol(3, chOrg_Width -60 -10)
	}
}

/**
 * context menu handler
 */
chOrgGuiContextMenu(g, ctrl, item, isRightClick, x, y) {
	global
	if IsObject(ctrl) && (ctrl.Name == "chOrg_Lv")
		chOrgLVMenu.Show(x, y)
	else if IsObject(ctrl) && (ctrl.Name == "chOrg_Lb")
	{
		if chOrg_isChActive()
			chOrgLBMenu.Show(x, y)
	}
}

/**
 * gui close/exit handler
 */
chOrgGuiEscape(*) {
	chOrgGuiClose()
}

chOrgGuiClose(*) {
	global
	Ini_write("Organizer", "w", chOrg_Width+158-5-2+2, 0) , Ini_write("Organizer", "h", chOrg_Height+2, 0) 	; +2 dont know why
	GuiDestroy("chOrg")
	chOrgLVMenu.Delete()
	chOrgLBMenu.Delete()
	chOrgSubM.Delete()
	OnMessage(0x200, WM_MOUSEMOVE, 0) 		; This will conflict in case both settings and chorg are active at the same time
	ToolTip(, , , 4)
	EmptyMem()
}

/**
 * handle up/down of clips and channels
 * (v1 chOrgUp / chOrgDown labels; t_Up = 1 moves up)
 */
chOrgUp(*) {
	chOrgUpDown(1)
}

chOrgDown(*) {
	chOrgUpDown(0)
}

chOrgUpDown(t_Up) { 	; dont make this critical
	global
	local lv, rSel, temp_row_s, fch, fcl, spRow, sch, scl, ftxt, stxt, chSel, nCh
	lv := CJGUI["chOrg"]["chOrg_Lv"]
	if !chOrg_isChActive() {
		rSel := chOrg_getSelected()
		if Instr(rSel, "`n")
		{
			chOrg_notification(TXT.ORG_error)
			return
		}
		if (rSel = "")
			return
		temp_row_s := lv.GetNext(0)
		;while (temp_row_s := lv.GetNext(temp_row_s)) {
			fch := lv.GetText(temp_row_s, 1) , fcl := lv.GetText(temp_row_s, 2)
			spRow := t_Up ? temp_row_s-1 : temp_row_s+1
			if (fcl==1) && (t_Up==1) 	; 1st clip not go up - thanks to fump2000
				return
			sch := scl := ""
			if (spRow >= 1) 	; v1 LV_GetText returned blank for a row outside the list; v2 throws
				try sch := lv.GetText(spRow, 1) , scl := lv.GetText(spRow, 2)
			if (sch != "") {
				chOrg_clipSwap(fch, fcl, sch, scl)
				ftxt := lv.GetText(temp_row_s, 3) , stxt := lv.GetText(spRow, 3)
				lv.Modify(temp_row_s, "", fch, fcl, stxt) 		; // change only 3rd col..
				lv.Modify(spRow, "", sch, scl, ftxt)
				lv.Modify(temp_row_s, "-Select -Focus")
				lv.Modify(spRow, "Select")
			}
		;}
	} else {
		chSel := chorg_getChSelected()
		nCh := chSel + (t_Up ? -1 : 1)
		if chOrg_clipFolderSwap(chSel, nCh){
			chOrg_addChList()
			chOrg_addChUseList()
		}
	}
}

/**
 * clip/channel delete handler
 * also allows emptying a channel
 */
chOrgDelete(*) {
	global
	local lv, lbv, rSel, tobj, k, v, z, lvgcb, cons, tch, tcl, chSel, r
	Critical "On"
	lv := CJGUI["chOrg"]["chOrg_Lv"]
	if !chOrg_isChActive() {
		rSel := chOrg_getSelected()
		tobj := CJMap()
		loop parse rSel, "`n"
		{
			k := Substr(A_LoopField, 1, Instr(A_LoopField, "-")-1) , v := Substr(A_LoopField, Instr(A_LoopField, "-")+1)
			tobj[k] .= v "`n"
		}
		; Sort and delete
		for k,v in tobj
		{
			v := Sort(v, "N R") ; reverse
			v := Trim(v)
			loop parse v, "`n"
			{
				if (Trim(A_LoopField) == "")
					continue
				API.deleteClip(k, A_LoopField)
				z := A_LoopField
				lvgcb := lv.GetCount()
				cons := 0
				loop lvgcb ; Silent delete
				{
					tch := ""
					try tch := lv.GetText(A_index+cons, 1) 	; rows past the end read as blank like v1
					if (tch != k)
						continue
					tcl := lv.GetText(A_index+cons, 2)
					if (tcl < z)
						continue
					if (tcl == z){
						lv.Delete(A_index)
						cons := -1
						continue
					}
					lv.Modify(A_index+cons, "Col2", tcl-1)
				}
			}
		}
		chOrg_notification(TXT.ORG_clpdelMsg)
	}
	else {
		lbv := CJGUI["chOrg"]["chOrg_Lb"].Value
		if (lbv != "") && (lbv>1) {
			chSel := chorg_getChSelected()
			r := MsgBox(TXT.ORG_delCnlMsg, TXT.ORG_delCnlMsgTitle, 67)
			if (r = "Yes")
			{
				manageChannel(chSel)
				chOrg_addChList()
				chOrg_addChUseList()
			}
			if (r = "No")
			{
				API.emptyChannel(chSel)
				lv.Delete()
			}
			if (r = "Cancel")
				chOrg_notification( TXT.TIP_cancelled)
			else chOrg_notification(TXT.TIP_done)
		}
	}
}

/**
 * clip copy/move handler
 * (v1 chOrgCut / chOrgCopy labels; flag = 1 copies, 0 moves)
 */
chOrgCut(*) {
	chOrgCutCopy(0)
}

chOrgCopy(*) {
	chOrgCutCopy(1)
}

chOrgCutCopy(flag) {
; single cut/ multi copy supported
	global
	local rSel, ret
	rSel := chOrg_getSelected()
	chOrg_notification(flag ? TXT.ORG_copyingclp : TXT.ORG_movingclp, 99999999)
	if !flag && Instr(rSel, "`n")
	{
		chOrg_notification(TXT.ORG_error)
		return
	}
	ret := chooseChannelGui(TXT._destChannel)
	if (ret = "")
	{
		chOrg_notification(TXT.TIP_cancelled)
		return
	}
	loop parse rSel, "`n"
	{
		API.manageClip(ret, Substr(A_LoopField, 1, Instr(A_LoopField, "-")-1) , Substr(A_LoopField, Instr(A_LoopField, "-")+1) , flag )
		chOrg_notification("In Process")
	}
	chOrg_notification(TXT.TIP_done)
	chOrg_refresh()
}

/**
 * show create new clip dialog
 */
chOrgNew(*) {
	global
	local chSel, out
	chSel := chorg_getChSelected()
	if chSel<0
		chSel := CN.NG
	STORE.ErrorLevel := 0
	out := multInputBox(TXT.ORG_createnew, TXT.ORG_createnewpr " - " chSel, 15, blank, "chOrg")
	if STORE.ErrorLevel
	{
		API.addClip(chSel, out)
		chOrg_refresh()
	} Else
		chOrg_notification(TXT.TIP_cancelled)
}

/**
 * create new channel action
 */
chOrgNewCh(*) {
	global
	local ib
	ib := InputBox("", TXT.ORG_newchname, , CN.Total)
	if (ib.Result = "OK") {
		changeChannel(CN.Total)
		renameChannel(CN.Total-1, ib.Value)
		chOrg_addChList()
		chOrg_addChUseList() ; No need as changeChannel calls it but Needed here as it name changes later on
		; CJGUI["chOrg"]["chOrg_Lb"].Choose(CN.Total+1) ; makes no sense to open an empty channel
	}
}

/**
 * get selected channel id and name
 * @return {int} channel id (chSelname receives the channel name)
 */
chorg_getChSelected(&chSelname := "") {
	chSel := CJGUI["chOrg"]["chOrg_Lb"].Value-2
	chSelname := ini_read("Channels", chSel)
	return chSel
}

/**
 * is channel list active or not
 * not in case clip list is active
 * @return {bool}
 */
chOrg_isChActive() {
	global
	; Cut button not enabled when LB is active
	return (CJGUI["chOrg"]["Button" chOrg_t_startBtn].Text == chrhex("f040")) ? 1 : 0
}

/**
 * get selected clips from the list
 * @return {string} "ch-clip" lines; out_ch / out_cl / last_Row receive the values of the last selected row
 */
chOrg_getSelected(&out_ch := "", &out_cl := "", &last_Row := "") {
	lv := CJGUI["chOrg"]["chOrg_Lv"]
	temp_row_s := 0 , rSel := "" , out_ch := out_cl := last_Row := ""
	while ( temp_row_s := lv.GetNext(temp_row_s) )
	{
		out_ch := lv.GetText(temp_row_s, 1) , out_cl := lv.GetText(temp_row_s, 2)
		rSel .= out_ch "-" out_cl "`n"
		last_Row := temp_row_s
	}
	return Trim(rSel, "`n")
}

/**
 * edit a selected clip or channel
 */
chOrgEdit(*) {
	global
	local out_ch, out_cl, last_Row, ret
	if chOrg_isChActive()
		chOrg_renameCh()
	else {
		if (chOrg_getSelected(&out_ch, &out_cl, &last_Row) = "")
			return
		STORE.ErrorLevel := 0
		ret := editClip(out_ch, out_cl)
		if STORE.ErrorLevel {
			try CJGUI["chOrg"]["chOrg_Lv"].Modify(last_Row, "", out_ch, out_cl, ret) 	; the organizer may have been closed meanwhile
		}
		else chOrg_notification(TXT.TIP_cancelled, 800)
	}
}

/**
 * open paste mode for the selected clip
 */
chOrg_openPasteMode(*) { ; Toggles the interface
	global
	local out_ch, out_cl, opnPstMd_cn, opnPstMd_cl
	if (chOrg_getSelected(&out_ch, &out_cl) = "")
		return
	opnPstMd_cn := out_ch , opnPstMd_cl := API.getChStrength(out_ch)-out_cl+1
	if ( opnPstMd_cn == CN.NG ) && ( opnPstMd_cl == realActive ) && SPM.ACTIVE
	{
		endPastemode()
		opnPstMd_cn := opnPstMd_cl := ""
	}
	else ;WinGetPos(&x, &y, , , TXT.ORG__name " ahk_class AutoHotkeyGUI")
		API.showPasteTipAt(out_ch, out_cl) ;, x+100, y+160)
}

/**
 * close the organizer gui and paste the selected clip
 */
chOrg_paste(*) {
	global
	local rSel
	rSel := chOrg_getSelected()
	chOrgGuiClose()
	WinWaitClose(TXT.ORG__name)
	loop parse rSel, "`n"
	{
		API.paste( Substr(A_LoopField, 1, Instr(A_LoopField, "-")-1) , Substr(A_LoopField, Instr(A_LoopField, "-")+1) )
		Sleep 30
		SendInput("{Enter}")
	}
}

/**
 * show properties of the selected clip
 */
chOrg_props(*) {
	global
	local out_ch, out_cl
	if (chOrg_getSelected(&out_ch, &out_cl) = "")
		return
	out_cl := API.getChStrength(out_ch)-out_cl+1
	ClipPref_makeKeys(out_ch, out_cl)
	CJGUI["chOrg"]["chOrg_SB"].SetText(TXT._editing, 2)
	CPS[out_ch][out_cl] := ObjectEditView( CPS[out_ch][out_cl], [TXT.ORG_editprops, "chOrg", TXT.ORG_oEditMsg, 150], 0 )
	prefs2Ini()
	chOrg_notification(blank, 10)
}

/**
 * preview the selected clip
 */
chOrg_preview(*) {
	global
	local out_ch, out_cl, clippath, clipdata
	if (chOrg_getSelected(&out_ch, &out_cl) = "")
		return
	out_cl := API.getChStrength(out_ch) - out_cl + 1
	out_ch := out_ch ? out_ch : ""
	if FileExist(clippath := "cache\thumbs" out_ch "\" out_cl ".jpg")
		gui_Clip_preview(clippath, blank, "chOrg")
	else {
		clipdata := CDS[out_ch ? out_ch : 0][out_cl] 	; dont use LV here, limit of 8192 chrs
		genHTMLforPreview(clipdata)
		gui_Clip_preview(PREV_FILE, CJGUI["chOrg"]["chOrg_search"].Value, "chOrg")
	}
}

/**
 * rename a channel and then refresh the channel list
 */
chOrg_renameCh(*) {
	global
	local chSel, chSelname, ib
	chSel := chorg_getChSelected(&chSelname)
	ib := InputBox(TXT.ORG_renameAsk " -> " chSel, TXT.ORG__name, "w500 h200", chSelname)
	if (ib.Result != "OK") or (ib.Value = "")
		return
	renameChannel(chSel, ib.Value)
	chOrg_addChList()
	chOrg_addChUseList()
}

/**
 * activate a channel
 */
chorg_UseCh_Event(*) {
	global
	changeChannel(channel_find(CJGUI["chOrg"]["chorg_useCh"].Text)) 	; chChannel() will handle that list
}

/**
 * list view (clip list) event handler
 */
chOrg_Lv_Event(*) {
	global
	local g
	g := CJGUI["chOrg"]
	g["Button" chOrg_t_startBtn].Text := chrhex("f03e")
	loop chOrg_t_horizButtons
		g["Button" A_index+chOrg_t_startBtn].Enabled := true
}

chOrg_Lv_DoubleClick(*) {
	chOrg_Lv_Event()
	chOrg_preview()
}

/**
 * activate the list box i.e. channels list
 */
chOrg_activateLB(*) {
	global
	CJGUI["chOrg"]["chOrg_Lb"].Focus()
	Sleep 50 ; Needed
	chOrg_Lb_Event()
}

/**
 * activate the list view i.e. clips list
 */
chOrg_activateLV(*) {
	global
	local lv
	lv := CJGUI["chOrg"]["chOrg_Lv"]
	lv.Focus()
	Sleep 50
	chOrg_Lv_Event()
	lv.Modify(0, "-Select")
	try lv.Modify(1, "Select Focus") 	; the list may be empty
}

/**
 * refresh the clip list
 * triggers when you edit the text in search box
 * or press refresh (F5)
 * or change focus to list box (channels list) in order to change channel
 */
chOrg_refresh(*) {
	chOrg_Lb_Event()
}

chOrg_search_Event(*) {
	chOrg_Lb_Event()
}

chOrg_Lb_Event(*) {
	global
	local g, lbv
	g := CJGUI["chOrg"]
	lbv := g["chOrg_Lb"].Value
	;msgbox here
	g["Button" chOrg_t_startBtn].Text := chrhex("f040")
	if (lbv = 1) { 	; braces needed: in v2 an else after a loop belongs to the loop
		loop chOrg_t_horizButtons 		; in case all channels are selected
			g["Button" A_index+chOrg_t_startBtn].Enabled := false
	}
	else {
		loop chOrg_t_horizButtons-chOrg_t_commonBtn-1 	; 3=buttons common in bth LB LV
			g["Button" A_index+chOrg_t_startBtn+chOrg_t_commonBtn].Enabled := false
		loop chOrg_t_commonBtn
			g["Button" A_Index+chOrg_t_startBtn].Enabled := true
		g["Button" chOrg_t_horizButtons+chOrg_t_startBtn].Enabled := true
	}
	chOrgLV_update(g["chOrg_search"].Value, lbv>1 ? lbv-2 : "")
}

/**
 * add the active channel selector list (the one on top)
 */
chOrg_addChUseList(*) {
	global
	local chList, chListnew, ddl, items, sel
	chList := Trim(channel_find(), "`n")
	chListnew := ""
	loop parse chList, "`n"
		chListnew .= Substr(A_loopfield, Instr(A_loopfield, "-")+1) "|"
	chList := RTrim(chListnew, "|")

	chList := StrReplace(chList, CN.Name, CN.Name "|", , , 1)
	chList .= (Substr(chList, -1) == "|") ? "|" : ""
	; v1 handed "|" chList to the control: a blank field marks the field before it as selected
	items := [] , sel := 0
	loop parse chList, "|"
	{
		if (A_LoopField = "")
			sel := items.Length
		else
			items.Push(A_LoopField)
	}
	ddl := CJGUI["chOrg"]["chorg_useCh"]
	ddl.Delete()
	ddl.Add(items)
	if sel
		ddl.Choose(sel)
}

/**
 * focus on active channel selector
 */
chOrg_useChFocus(*) {
	global
	CJGUI["chOrg"]["chorg_useCh"].Focus()
}

/**
 * focus on search box
 */
chOrg_searchfocus(*) {
	global
	CJGUI["chOrg"]["chOrg_search"].Focus()
}

/**
 * swap two channel
 * essentially their id's will be swapped
 * @param  {int} orig_ch channel 1
 * @param  {int} new_ch  channel 2
 * @return {bool} 1 for success
 */
chOrg_clipFolderSwap(orig_ch, new_ch){
	if (new_ch<0) or ( new_ch >= CN.Total )
		return 0

	origch := orig_ch ? orig_ch : "" , newch := new_ch ? new_ch : ""
	ClipFolderTransfer(newch, newch "_a", 0, "R")
	ClipFolderTransfer(origch, newch, 0, "R")
	ClipFolderTransfer(newch "_a", origch, 0, "R")

	obj_orig := CDS[orig_ch] , obj_new := CDS[new_ch] 	; update cached datas
	CDS[orig_ch] := obj_new , CDS[new_ch] := obj_orig
	obj_orig := CPS[orig_ch] , obj_new := CPS[new_ch] 	; update prefs
	CPS[orig_ch] := obj_new , CPS[new_ch] := obj_orig

	CN["TEMPSAVE" CN.N] := TEMPSAVE , CN["CURSAVE" CN.N] := CURSAVE 	; submit active values
	ts_orig := CN["TEMPSAVE" origch] , cs_orig := CN["CURSAVE" origch] ; update cursave values
	CN["TEMPSAVE" origch] := CN["TEMPSAVE" newch] , CN["CURSAVE" origch] := CN["CURSAVE" newch]
	CN["TEMPSAVE" newch] := ts_orig , CN["CURSAVE" newch] := cs_orig

	orig_name := ini_read("Channels", orig_ch) , Ini_write("Channels", orig_ch, ini_read("Channels", new_ch), 0)
	ini_write("Channels", new_ch, orig_name, 0)

	if ( CN.NG == orig_ch )
		changeChannel(new_ch, 0) 	; 0 for dont save prev values is neccesary
	return 1
}

/**
 * swaps two clips
 * @param  {int} fch first channel
 * @param  {int} fcl first clip
 * @param  {int} sch second channel
 * @param  {int} scl second clip
 * @return {void}
 */
chOrg_clipSwap(fch, fcl, sch, scl){
	f_sub := (fch?fch:"") , s_sub := (sch?sch:"")
	f_cno := API.getChStrength(fch)-fcl+1 , s_cno := API.getChStrength(sch)-scl+1

	ClipTransfer(s_sub, s_cno, s_sub, s_cno "_a", 0)
	ClipTransfer(f_sub, f_cno, s_sub, s_cno, 0)
	ClipTransfer(s_sub, s_cno "_a", f_sub, f_cno, 0)
	bk := CDS[sch][s_cno] , CDS[sch][s_cno] := CDS[fch][f_cno] , CDS[fch][f_cno] := bk
	bk := CPS[sch][s_cno] , CPS[sch][s_cno] := CPS[fch][f_cno] , CPS[fch][f_cno] := bk
}

/**
 * shows notification in the gui status bar
 * @param  {string} text text to show
 * @param  {int} time time to show in ms
 * @return {void}
 */
chOrg_notification(text, time:=800){
	global CJGUI
	if !CJGUI.Has("chOrg")
		return
	CJGUI["chOrg"]["chOrg_SB"].SetText(text, 2)
	SetTimer(chOrg_notificationOff, -time)
}

/**
 * timer'ed function to clear the notification (the v1 chOrg_notification label)
 */
chOrg_notificationOff(*) {
	global CJGUI, empty
	SetTimer(chOrg_notificationOff, 0)
	if CJGUI.Has("chOrg")
		CJGUI["chOrg"]["chOrg_SB"].SetText(empty, 2)
}


IsChorgActive(*){
	return WinActive( TXT.ORG__name " ahk_class AutoHotkeyGUI") && ctrlRef==""
}
IsChOrgLVActive(*){
	return IsActive("SysListView321", "classnn") && WinActive(TXT.ORG__name " ahk_class AutoHotkeyGUI") && ctrlRef==""
}
IsChOrgLBActive(*){
	return IsActive("ListBox1", "classnn") && WinActive(TXT.ORG__name " ahk_class AutoHotkeyGUI") && ctrlRef==""
}
IsChOrgSearchActive(*){
	return IsActive("Edit1", "classnn") && WinActive(TXT.ORG__name " ahk_class AutoHotkeyGUI") && ctrlRef==""
}

/**
 * updates the list view with the current search
 * @param  {String} term    term to filter by
 * @param  {int} channel channel number if any
 * @return {void}
 */
chOrgLV_update(term:="", channel:=""){
	global CDS, CPS, TXT, CJGUI
	g := CJGUI["chOrg"] , lv := g["chOrg_Lv"]
	lv.Delete() , term := Trim(term) , ct := 0
	if (channel = "")
	{
		for k,v in CDS
		{
			maxindex := API.getChStrength(k)
			loop (maxIndex = "" ? 0 : maxIndex)
				if SuperInstr( (v2 := getRealCD( v[maxIndex-A_index+1] )) " " clipPref(k, maxIndex-A_index+1, "Tags") , term, 1)
					lv.Add("", k, A_index, v2) , ct++
		}
	}
	else {
		maxIndex := API.getChStrength(channel)
		loop (maxIndex = "" ? 0 : maxIndex)
			if SuperInstr( (v := getRealCD( CDS[channel][maxIndex-A_index+1] )) " " clipPref(channel, maxIndex-A_index+1, "Tags") , term, 1)
				lv.Add("", channel, A_index, v) , ct++
	}
	g["chOrg_SB"].SetText(TXT.ORG_countStatus " - " ct, 1)
}
