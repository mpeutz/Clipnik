;History Gui labels and functions
;A lot Thanks to chaz who first improved it

/**
 * Creates and shows a GUI for managing and viewing the clipboard history
 * @return {void}
 */
gui_History(){
	global
	static x := "", y := "", how_sort := 0, col_sort := CJMap(2, 0, 3, 0), what_sort := 2
	local selected_row := 0, thisguisize := 0, h, g, lv, sb, searchBox, partialCB, HisMenu
	local hst_genWt := 750, gui_w := 0, gui_h := 0, history_SearchBoxx := 0
	;col_sort[2], col_sort[3] are the vars storing how cols are sorted , 1 means in Sort ; 0 means SortDesc

	GuiDestroy("History")
	g := Gui("+Resize +MinSize500x300", PROGNAME " " TXT.HST__name)
	CJGUI["History"] := g
	g.BackColor := "F6F8E1"
	g.MarginX := 7, g.MarginY := 7

	history_w := IniRead(CONFIGURATION_FILE, "Clipboard_History_window", "w", "")
	h := IniRead(CONFIGURATION_FILE, "Clipboard_History_window", "h", "")

	g.Add("Button", "h23 Section Default vhistory_ButtonPreview", TXT.HST_preview).OnEvent("Click", history_ButtonPreview)
	g.Add("Button", "x+6 ys h23 vhistory_ButtonDelete", TXT.HST_del).OnEvent("Click", history_ButtonDelete)
	g.Add("Button", "x+6 ys h23 vhistory_ButtonDeleteAll", TXT.HST_clear).OnEvent("Click", history_ButtonDeleteAll)
	g.Add("Text", "x+35 ys+5 vhistory_SearchText", TXT.HST_search)
	partialCB := g.Add("Checkbox", "x+10 ys+5 Checked" history_partial " vhistory_partial", TXT.HST_partial)
	partialCB.OnEvent("Click", history_SearchBox_Event)
	searchBox := g.Add("Edit", "ys vhistory_SearchBox")
	searchBox.OnEvent("Change", history_SearchBox_Event)
	g.SetFont("s9", "Courier New")
	g.SetFont("s9", "Consolas")
	lv := g.Add("ListView", "xs+1 vhistoryLV LV0x4000 w" (history_w ? history_w - 25 : hst_genWt - 25), [TXT.HST_clip, TXT.HST_date, TXT.HST_size, "Hiddendate"])
	lv.OnEvent("DoubleClick", historyLV_DoubleClick)
	lv.OnEvent("ColClick", historyLV_Event)

	sb := g.Add("StatusBar", "vhistoryStatusBar")
	g.SetFont()
	searchBox.Focus()

	;History Right-Click Menu
	HisMenu := Menu()
	HisMenu.Add(TXT.HST_m_prev, history_MenuPreview)
	HisMenu.Add()
	;Use a Space and a tab to separate
	HisMenu.Add(TXT.HST_m_copy, history_clipboard)
	HisMenu.Add(TXT.HST_m_insta, history_InstaPaste)
	HisMenu.Add(TXT.SET_HoldClip " `t(" TXT["_!c"] ")", history_HoldClip)
	HisMenu.Add(TXT.HST_m_edit, history_EditClip)
	HisMenu.Add(TXT.HST_m_export, history_exportclip)
	HisMenu.Add()
	HisMenu.Add(TXT.HST_m_ref, history_SearchBox_Event)
	HisMenu.Add(TXT.HST_m_del, history_ButtonDelete)
	HisMenu.Default := TXT.HST_m_prev

	g.OnEvent("ContextMenu", historyGuiContextMenu)
	g.OnEvent("Size", historyGuiSize)
	g.OnEvent("Close", historyGuiClose)
	g.OnEvent("Escape", historyGuiClose)

	historyUpdate()
	history_UpdateSTB()
	lv.ModifyCol(what_sort, how_sort ? "Sort" : "SortDesc")

	if (IsNumber(h) && h + 0 == WORKINGHT)
	{
		g.Show("Maximize")
		WinMinimize("ahk_id " g.Hwnd)
		WinMaximize("ahk_id " g.Hwnd)
		searchBox.Focus()
	}
	else
		g.Show((x != "" ? "x" x " y" y : "") " w" (history_w ? history_w : hst_genWt) " h" (h ? h : 500))

	WinWaitActive("ahk_id " g.Hwnd)
	WinGetPos(&x, &y, , , "ahk_id " g.Hwnd)

	;resize the search box
	searchBox.GetPos(&history_SearchBoxx) 		;extract x for later use
	WinGetPos(, , &thisguisize, , "ahk_id " g.Hwnd)
	searchBox.Move(, , thisguisize - history_SearchBoxx - 21) 		;7,7 for outer border, 7 for inner border

	;create hotkeys
	HotIfWinActive(PROGNAME " " TXT.HST__name)
	Hotkey("F5", history_SearchBox_Event, "On")
	HotIf()
	HotIf(IsHisListViewActive)
	hkZ("^c", history_clipboard)
	hkZ("^e", history_exportclip)
	hkZ("^h", history_EditClip)
	hkZ("!d", historySearchfocus)
	hkZ("^f", historySearchfocus)
	hkZ("!c", history_HoldClip)
	HotIf()
	HotIf(IsPrevActive)
	hkZ("^f", prevSearchfocus)
	HotIf()
	return

	/**
	 * label to invoke preview button
	 */
	history_MenuPreview(*) {
		Send("{vk0d}")
	}

	/**
	 * label triggered when search box contents are changed and then updates the list
	 */
	history_SearchBox_Event(*) {
		Critical("On")
		history_partial := partialCB.Value
		historyUpdate(searchBox.Value, 0, history_partial)
		lv.ModifyCol(what_sort, how_sort ? "Sort" : "SortDesc") 		;sort column correctly
	}

	/**
	 * trigerred when button preview is pressed
	 * opens the preview window
	 */
	history_ButtonPreview(*) {
		local v, clip_id, data, clip_data, path
		if (lv.GetNext() == 0)
			v := selected_row
		else v := lv.GetNext()
		if !v
			return

		clip_id := lv.GetText(v, hidden_date_no)
		if (HISTORYOBJ[clip_id] == 0){ ;type text
			data := getFromTable("history", "data", "id=" clip_id)
			clip_data := data ? data[1] : ""
			genHTMLforPreview(clip_data)
			gui_Clip_Preview(PREV_FILE, searchBox.Value)
		} else {
			data := getFromTable("history", "fileid", "id=" clip_id)
			gui_Clip_Preview(path := (data ? data[1] : ""), searchBox.Value)
		}
	}

	/**
	 * button event to delete all history
	 */
	history_ButtonDeleteAll(*) {
		g.Opt("+OwnDialogs")
		if (MsgBox(TXT.HST_delall_msg, "Clear History", 257) = "OK")
		{
			try FileDelete("cache\history\*")
			execSql("delete from history")
			historyUpdate()
			history_UpdateSTB()
		}
	}

	/**
	 * list view (clips list) handler
	 * responsible for sorting and stuff
	 */
	historyLV_DoubleClick(*) {
		history_ButtonPreview()
	}

	historyLV_Event(ctrl, col) {
		local temp
		LV_SortArrow(lv.Hwnd, col)
		what_sort := col
		temp := col_sort[what_sort] 				;retrieve currrent col value
		col_sort[2] := col_sort[3] := 0					;change all cols values
		how_sort := col_sort[what_sort] := !temp 			;update real current col value
	}

	/**
	 * method to allow editing a history clip
	 */
	history_EditClip(*) { 		; closure inside to call history_SearchBox_Event which uses local func variables
		local row, clip_id, data, out
		if !(row := lv.GetNext(0))
			return
		clip_id := lv.GetText(row, hidden_date_no)
		if (HISTORYOBJ[clip_id] == 1){
			data := getFromTable("history", "fileid", "id=" clip_id)
			RunWait(ini_defImgEditor ' "' A_WorkingDir "\" (data ? data[1] : "") '"')
		} else {
			data := getFromTable("history", "data", "id=" clip_id)
			STORE.ErrorLevel := 0
			out := multInputBox("Edit Clip", "Make your changes and then click OK", 10, data ? data[1] : "", "History")
			if (STORE.ErrorLevel == 1){
				execSql('update history set data="' escapeQuotesSql(out) '" where id=' clip_id, 1)
			}
		}
		history_SearchBox_Event()
	}

	/**
	 * add the selected history clip to holdclip
	 */
	history_HoldClip(*) {
		local row, clip_id, data
		while !IsHisListViewActive()
			Sleep(50)
		if !(row := lv.GetNext(0))
			return
		clip_id := lv.GetText(row, hidden_date_no)
		data := getFromTable("history", "data", "id=" clip_id)
		STORE.holdClip_preText := data ? data[1] : ""
		holdClip()
	}

	/**
	 * context menu history gui
	 * reponsible for showing right click on clip menu
	 */
	historyGuiContextMenu(gObj, ctrl, item, isRightClick, mx, my) {
		if !(IsObject(ctrl) && ctrl.Name = "historyLV") || (lv.GetNext() = 0)
			return
		selected_row := lv.GetNext()
		HisMenu.Show(mx, my)
	}

	/**
	 * gui resize handler
	 */
	historyGuiSize(gObj, MinMax, gw, gh) {
		local w2, w3
		if (MinMax != -1)	; ignore minimising
		{
			gui_w := gw, gui_h := gh

			w2 := SendMessage(0x1000+29, 1, 0, lv.Hwnd)
			w3 := SendMessage(0x1000+29, 2, 0, lv.Hwnd)

			lv.Move(, , gui_w - 15, gui_h - 65)     ;+20 H in no STatus Bar
			lv.ModifyCol(1, gui_w-15-w2-w3-25) 				;gui_w - x  where   x  =  width of all cols + 25
			searchBox.Move(, , gui_w - (history_SearchBoxx ? history_SearchBoxx : hst_genWt-300) - 7) ; 7 for innermargin
		}
	}

	/**
	 * gui close handler
	 * saves the position, height, width and exits
	 */
	historyGuiClose(*) {
		local temp_h, w2, w3
		WinGetPos(&x, &y, , &h, "ahk_id " g.Hwnd)

		h := h > WORKINGHT ? WORKINGHT : gui_h               ;gui_h and gui_w are function vars created in the historyGuiSize closure (above).

		Ini_write(temp_h := "Clipboard_History_window", "w", gui_w, 0)
		Ini_write(temp_h, "h", h, 0)

		w2 := SendMessage(0x1000+29, 1, 0, lv.Hwnd)
		w3 := SendMessage(0x1000+29, 2, 0, lv.Hwnd)
		Ini_write(temp_h, "w2", w2, 0)
		Ini_write(temp_h, "w3", w3, 0)

		GuiDestroy("History")
		HisMenu.Delete()
		EmptyMem() 				;Free memory
	}
}

/**
 * shows the preview of a clip
 * param path - path to the html file of the clip generated disk or path to jpg file for image
 * param searchbox - searchbox content of the history gui, same is shown in preview
 * param owner - owner of gui
 */
gui_Clip_Preview(path, searchBox := "", owner := "History")
{
	static wt := Round(A_ScreenWidth / 2.2), ht := Round(A_ScreenHeight / 2.5) ;, maxlines = Round(ht / 13)
	local g, preview, w := 0, h := 0, wf, hf, wn, hn, gui_w := 0, gui_h := 0
	local prev_ax := "", prev_handle := "", prev_document := "", prev_picture := "", prev_copybtn, prev_findtxt, preview_search, prev_findtxtw := 0
	preview := CJMap()

	preview.isimg := InStr(SubStr(path, -3), "jpg") ? 1 : 0
	preview.path := A_WorkingDir "\" path
	preview.owner := owner

	GuiDestroy("Preview")
	g := Gui("", TXT.PRV__name)
	CJGUI["Preview"] := g
	g.MarginX := 0, g.MarginY := 0

	if preview.isimg
	{
		prev_picture := g.Add("Picture", "w" wt " h" ht " vprev_picture")
		Gdip_getLengths(preview.path, &w, &h)
		preview.w := w, preview.h := h
		wf := preview.w / wt, hf := preview.h / ht
		if (wf >= hf) && (wf > 1)
			wn := preview.w / wf, hn := preview.h / wf
		else if (hf > wf) && (hf > 1)
			wn := preview.w / hf, hn := preview.h / hf
		else
			wn := preview.w, hn := preview.h
		try prev_picture.Value := "*w" Round(wn) " *h" Round(hn) " " preview.path
	}
	else
	{
		try {
			prev_ax := g.Add("ActiveX", "w" wt " h" ht " vprev_handle", "Shell.Explorer")
			prev_handle := prev_ax.Value
			ComObjConnect(prev_handle, ActiveXEvent()) 				;do this only when the previous one succeeds
		}
		try prev_handle.Navigate(preview.path)
	}

	g.SetFont("s11")
	prev_copybtn := g.Add("Button", "x5 y+10 h27 Default vprev_copybtn Section", TXT.PRV_copy)
	prev_copybtn.OnEvent("Click", button_Copy_To_Clipboard)
	; button's x till 130 , search's width will 200 p from right
	prev_findtxt := g.Add("Text", "x" wt-200 " yp+2 h23 vprev_findtxt", TXT.PRV_find) 		; +2 to level text
	g.SetFont("norm")
	preview_search := g.Add("Edit", "x+10 yp-2 w155 h23 vpreview_search" (preview.isimg ? " +ReadOnly" : "")) 	; -5 margin on right side
	preview_search.OnEvent("Change", previewSearch)
	g.Add("Text", "x5 y+0 w5") 			; white-space just below the button

	if CJGUI.Has(preview.owner) {
		g.Opt("+Owner" CJGUI[preview.owner].Hwnd)
		CJGUI[preview.owner].Opt("+Disabled")
	}
	g.Opt("+Resize +MaximizeBox -MinimizeBox")
	g.OnEvent("Size", PreviewGuiSize)
	g.OnEvent("Close", previewGuiClose)
	g.OnEvent("Escape", previewGuiClose)
	g.Show("AutoSize")

	prev_findtxt.GetPos(, , &prev_findtxtw)
	if !preview.isimg
		preview_search.Value := searchBox
	return

	/**
	 * copy previewed clip to clipboard
	 */
	button_Copy_To_Clipboard(*) {
		if !preview.isimg {
			try A_Clipboard := prev_handle.Document.body.innerText
		} else
			Gdip_SetImagetoClipboard(preview.path)
		Sleep(500)
		previewGuiClose()
	}

	/**
	 * close preview gui
	 */
	previewGuiClose(*) {
		if CJGUI.Has(preview.owner)
			CJGUI[preview.owner].Opt("-Disabled")
		GuiDestroy("Preview")
		prev_handle := ""
		prev_document := ""
		EmptyMem()
	}

	/**
	 * search in preview gui
	 * highlights the matches too
	 */
	previewSearch(*) {
		local term
		Critical()
		try {
			prev_document := prev_handle.Document.body.createTextRange()
			prev_document.execCommand("BackColor", 0, "White")
		} catch
			return
		term := Trim(preview_search.Value, " ")
		if (term = "")
			return

		try {
		;highlight partial matches
		if history_partial
			loop parse term, " ", " "
			{
				while prev_document.findtext(A_LoopField) {
					prev_document.execCommand("BackColor", 0, "Aqua")
					prev_document.Collapse(0)
				}
				prev_document := prev_handle.Document.body.createTextRange()
			}

		;highlight exact matches
		while prev_document.findtext(term) {
			prev_document.execCommand("BackColor", 0, "Yellow")
			prev_document.Collapse(0)
		}

		}
	}

	/**
	 * preview gui resize handler
	 */
	PreviewGuiSize(gObj, MinMax, gw, gh) {
		if (MinMax != -1)
		{
			gui_w := gw, gui_h := gh
			preview_search.Move(gui_w-160, gui_h-30)
			prev_findtxt.Move(gui_w - (prev_findtxtw ? prev_findtxtw+167 : 210), gui_h-30)
			prev_copybtn.Move(, gui_h-32)
			if !preview.isimg
				prev_ax.Move(, , gui_w, gui_h-42)
			else {
				wn := gui_w, hn := gui_h-42
				if (gui_w+0) > preview.w
					wn := preview.w
				if (gui_h-42) > preview.h
					hn := preview.h

				try prev_picture.Value := "*w" Round(wn) " *h" Round(hn) " " preview.path
			}
		}
	}

}

/**
 * transfers the selected item from listview to clipboard
 * @param  {Number} startRow row to start searching the selected clip. 0
 * @return {Number} selected clip row no
 */
history_clipboard(sTartRow := 0, *){
	; called as a hotkey / menu callback too, where the first parameter is not a row number
	if !IsInteger(sTartRow)
		sTartRow := 0
	if !CJGUI.Has("History")
		return 0
	lv := CJGUI["History"]["historyLV"]
	row_selected := lv.GetNext(sTartRow)
	if !row_selected
		return 0
	clip_id := lv.GetText(row_selected, hidden_date_no)

	if (HISTORYOBJ[clip_id] == 0) {
		temp_read := (data := getFromTable("history", "data", "id=" clip_id)) ? data[1] : ""
		try A_Clipboard := temp_read
	} else if (HISTORYOBJ[clip_id] == 1) { ; in case row_selected=0 , this case ensures the code is not executed
		filepath := (data := getFromTable("history", "fileid", "id=" clip_id)) ? data[1] : ""
		Gdip_SetImagetoClipboard(filepath)
	}
	return row_selected
}

/**
 * updates the clipboard history window list wrt search filter
 * @param  {String}  crit    search filter
 * @param  {Boolean} create  create the gui, useful for first time
 * @param  {Boolean} partial perform partial search
 * @return {void}
 */
historyUpdate(crit := "", create := true, partial := false){
	; Updates the clipboard history window list
	; works when search content is changed
	global HISTORYOBJ
	local totalSize := 0
	local result := "", Row := "", lv, q, likestr, clipdata, clipdate, clipsize, w1, w2, w3

	if !CJGUI.Has("History")
		return
	lv := CJGUI["History"]["historyLV"]
	lv.Delete()

	crit := Trim(crit)
	if (crit == ""){
		q := "select * from history"
	} else if partial {
		likestr := ""
		loop parse crit, " `t", " `t"
			likestr .= 'data like "%' A_LoopField '%" and '
		likestr := SubStr(likestr, 1, -4)
		q := "select * from history where " likestr
	} else {
		q := 'select * from history where data like "%' crit '%"'
	}

	if !DB.GetTable(q, &result) {
		MsgBox("error")
		return
	}
	loop result.RowCount
	{
		result.Next(&Row)
		clipdata := Row[2] ;data
		clipdate := Row[5]
		totalSize += ( clipsize := Row[6] ) ? clipsize : 0
		lv.Add("", clipdata, clipdate, clipsize, Row[1])
		HISTORYOBJ[Row[1]] := Row[3]
	}

	history_UpdateSTB("" totalSize/1024)

	if create
	{
		w2 := IniRead(CONFIGURATION_FILE, "Clipboard_History_window", "w2", 155)
		w3 := IniRead(CONFIGURATION_FILE, "Clipboard_History_window", "w3", 70)
		w2 := w2 ? w2 : 155, w3 := w3 ? w3 : 70
		w1 := history_w ? (history_w - 15 - w2 - w3) : ""
		if (w1 != "")
			lv.ModifyCol(1, w1)
		else
			lv.ModifyCol(1)
		lv.ModifyCol(2, w2), lv.ModifyCol(3, w3 " Integer"), lv.ModifyCol(4, "0")
	}
}

/**
 * reutrns the size of history
 * @param  {String} option no idea
 * @return {number} size in kb
 */
history_GetSize(option := ""){
	R := 0
	if (option == ""){
		data := getFromTable("history", "sum(size)", "id>-1")
		R := (data && data[1] != "") ? data[1] : 0
	} else {

	}

	return R/1024
}

/**
 * update size in status bar
 * @param  {String} size size to show
 * @return {void}
 */
history_UpdateSTB(size := ""){
	; If size is passed, that size is used
	if !CJGUI.Has("History")
		return
	CJGUI["History"]["historyStatusBar"].SetText(TXT.HST_dconsump " : " ( size = "" ? history_GetSize() : size ) " KB")
}

/**
 * deletes selected rows from history
 * @return {void}
 */
history_ButtonDelete(*){
	if !CJGUI.Has("History")
		return
	lv := CJGUI["History"]["historyLV"]

	temp_row_s := 0, rows_selected := "", list_clipfilepath := ""
	while (temp_row_s := lv.GetNext(temp_row_s))
		rows_selected .= temp_row_s ","
	rows_selected := SubStr(rows_selected, 1, -1)     ;get CSV row numbers

	;Get Row names
	loop parse rows_selected, ","
	{
		clip_id := lv.GetText(A_LoopField, hidden_date_no)
		list_clipfilepath .= clip_id "`n" 	;Important for faster results
	}
	;Delete Rows
	loop parse rows_selected, ","
		lv.Delete(A_LoopField + 1 - A_Index)
	;Delete items
	loop parse list_clipfilepath, "`n"
	{
		if (A_LoopField != "")
			deleteHistoryById(A_LoopField)
	}

	CJGUI["History"]["history_SearchBox"].Focus()
	history_UpdateSTB()
}

/**
 * history insta paste feature
 */
history_InstaPaste(*) {
	global
	local clipboard_instapaste, temp_curRow
	clipboard_instapaste := IniRead(CONFIGURATION_FILE, "Advanced", "Instapaste_write_clipboard", "")
	WinHide(PROGNAME " " TXT.HST__name)
	temp_curRow := 0
	loop {
		if clipboard_instapaste
			temp_curRow := history_clipboard(temp_curRow)
		else {
			API.blockMonitoring(1)
			IScurCBACTIVE := 0  			;cur Clipboard is no longer active
			temp_curRow := history_clipboard(temp_curRow)
		}
		if !temp_curRow
			break
		SendInput(( A_Index > 1 ? "{Enter}" : "" ) "^{vk56}")
		Sleep(110)
	}
	API.blockMonitoring(0)
	if ini_HisCloseOnInstaPaste
	{
		WinClose(PROGNAME " " TXT.HST__name)
		WinWaitClose(PROGNAME " " TXT.HST__name)
	} else {
		Sleep(200) 	; extra layer
		WinShow(PROGNAME " " TXT.HST__name)
	}
}

/**
 * exports selected clip
 * gets the clip from clipboard
 */
history_exportclip(*) {
	global
	local temp
	CALLER := 0, ONCLIPBOARD := ""
	history_clipboard()
	while !ONCLIPBOARD 				;wait for onclibboard to be breached
		Sleep(50)
	ClipWait(, 1)
	loop
		if !FileExist(temp := A_MyDocuments "\export" A_Index ".cj")
			break
	try FileAppend(ClipboardAll(), temp)
	CALLER := CALLER_STATUS
	MsgBox("Selected Clip " TXT._exportedto "`n" temp, PROGNAME " " TXT.HST__name, 64)
}


; by Jethrow
; Helps in copy and paste in Shell Explorer
class ActiveXEvent {
	DocumentComplete(prev_handle, *) {
		static doc := ""
		ComObjConnect(doc := prev_handle.document, ActiveXEvent())
	}
	OnKeyPress(doc, *) {
		static keys := CJMap(1, "selectall", 3, "copy", 22, "paste", 24, "cut")
		keyCode := doc.parentWindow.event.keyCode
		if keys.HasKey(keyCode)
			doc.ExecCommand(keys[keyCode])
	}
}


LV_SortArrow(h, c, d := "")	; by Solar (http://www.autohotkey.com/forum/viewtopic.php?t=69642)
; Shows a chevron in a sorted listview column pointing in the direction of sort (like in Explorer)
; h = ListView handle (use +hwnd option to store the handle in a variable)
; c = 1 based index of the column
; d = Optional direction to set the arrow. "asc" or "up". "desc" or "down".
{
	static lvColumn := Buffer(A_PtrSize = 8 ? 56 : 44, 0), LVM_GETCOLUMN := 4191, LVM_SETCOLUMN := 4192, inited := 0
	if (!inited)
		inited := 1, NumPut("UInt", 1, lvColumn) 	; mask = LVCF_FMT
	c -= 1, DllCall("SendMessage", "Ptr", h, "UInt", LVM_GETCOLUMN, "UInt", c, "Ptr", lvColumn)
	if ((fmt := NumGet(lvColumn, 4, "Int")) & 1024) {
		if (d && d = "asc" || d = "up")
			return
		NumPut("Int", fmt & ~1024 | 512, lvColumn, 4)
	} else if (fmt & 512) {
		if (d && d = "desc" || d = "down")
			return
		NumPut("Int", fmt & ~512 | 1024, lvColumn, 4)
	} else {
		loop DllCall("SendMessage", "Ptr", DllCall("SendMessage", "Ptr", h, "UInt", 4127, "Ptr", 0, "Ptr", 0, "Ptr"), "UInt", 4608, "Ptr", 0, "Ptr", 0)
			if ((i := A_Index - 1) != c) {
				DllCall("SendMessage", "Ptr", h, "UInt", LVM_GETCOLUMN, "UInt", i, "Ptr", lvColumn)
				NumPut("Int", NumGet(lvColumn, 4, "Int") & ~1536, lvColumn, 4)
				DllCall("SendMessage", "Ptr", h, "UInt", LVM_SETCOLUMN, "UInt", i, "Ptr", lvColumn)
			}
		NumPut("Int", fmt | (d && d = "desc" || d = "down" ? 512 : 1024), lvColumn, 4)
	}
	return DllCall("SendMessage", "Ptr", h, "UInt", LVM_SETCOLUMN, "UInt", c, "Ptr", lvColumn)
}


; --------------------------- SQL STORAGE FUNCTIONS --------------------------------------

createHisTable(){
; creates the History Table if it doesnt exist
; called by the migrateHistory function
	q := "
	(
		CREATE TABLE if not exists history `(
		id	INTEGER PRIMARY KEY AUTOINCREMENT,
		data 	TEXT,
		type	INTEGER,
		fileid 	TEXT,
		time	TEXT,
		size 	INTEGER
		`)
	)"
	if !DB.Exec(q)
		MsgBox("db create history table")
}

addHistoryText(data, timestamp){
; adds some text data to history
; the timestamp is in A_Now format
	timestamp := convertTimeSql( timestamp )
	q := 'insert into history (data, type, time, size) values ("'
		. escapeQuotesSql(data)
		. '", 0, "'
		. timestamp '", '
		. fileSizeFromStr(data) ")"
	if (!DB.Exec(q))
		MsgBox(q)
}

addHistoryImage(imgpath, timestamp){
; addes image to history
; image specified by image path (imgpath)
; timestamp is in A_Now format
	timestamp := convertTimeSql(timestamp)
	fptr := FileOpen(imgpath, "r")
	size := fptr.Length
	fptr.Close()
	while (FileExist(rname := "cache\history\" getRandomStr(15) ".jpg")){
		; loop till new file name
	}

	FileCopy(imgpath, rname)
	q := "insert into history (data, type, time, size, fileid) values ("
		. '"[IMAGE]", '
		. 1 ","
		. '"' timestamp '", '
		. size ", "
		. '"' rname '")'

	if !DB.Exec(q)
		MsgBox("Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode, "SQLite Error", 16)
}

deleteHistoryById(id){
; deletes a history element by its ID in the table
	if (HISTORYOBJ[id] == 1){
		imgpath := (data := getFromTable("history", "fileid", "id=" id)) ? data[1] : ""
		try FileDelete(imgpath)
	}
	execSql("delete from history where id=" id)
}

fillHISTORYOBJ(){
; fills the HISTORYOBJ array
; It contains ID v/s type information
; HISTORYOBJ[ID] = type ( 0 or 1 )
	global HISTORYOBJ
	local result := "", Row := "", q
	q := "select id,type from history"
	if !DB.GetTable(q, &result) {
		MsgBox("error")
		return
	}
	loop result.RowCount
	{
		result.Next(&Row) 		; v1 never advanced the row (bug); without this HISTORYOBJ stayed empty
		HISTORYOBJ[Row[1]] := Row[2]
	}
}

;------------------------------------ MIGRATE ----------------------------------------------

migrateHistory(){
; migrates History files to the database
	createHisTable()
	DB.Exec("BEGIN TRANSACTION")
	API.showTip("Moving history files to database. This process may take some time.")
	loop files "cache\history\*"
	{
		if (StrLen(A_LoopFileName) != 18) ; YYYYMMDDHHMMSS.ext
			continue
		if (A_LoopFileExt == "jpg"){
			addHistoryImage(A_LoopFileFullPath, SubStr(A_LoopFileName, 1, -4))
			FileDelete(A_LoopFileFullPath)
		} else if (A_LoopFileExt == "txt"){
			tdata := FileRead(A_LoopFileFullPath)
			addHistoryText(tdata, SubStr(A_LoopFileName, 1, -4))
			FileDelete(A_LoopFileFullPath)
		}
	}
	DB.Exec("COMMIT TRANSACTION")
	API.removeTip()
}

;------------------------------------ ACCESSIBILITY SHORTCUTS -------------------------------

historySearchfocus(*) {
	try CJGUI["History"]["history_SearchBox"].Focus()
}
prevSearchfocus(*) {
	try CJGUI["Preview"]["preview_search"].Focus()
}
; Using these function so that #HotIf is created properly and hotkey command works and so no errors in non-eng computers
IsHisListViewActive(*){
	return IsActive("SysListView321", "classnn") && IsActive(PROGNAME " " TXT.HST__name, "window") && ctrlRef == ""
}
IsPrevActive(*){
	return WinActive(TXT.PRV__name " ahk_class AutoHotkeyGUI") && ctrlRef == ""
}

#HotIf IsActive("Edit1", "classnn") and IsActive(PROGNAME " " TXT.HST__name, "window")
	$Down::
	{
		try {
			lv := CJGUI["History"]["historyLV"]
			lv.Focus()
			lv.Modify(1, "Select Focus")
		}
	}
#HotIf
#HotIf IsHisListViewActive()
	Space::history_InstaPaste()
	Del::history_ButtonDelete()
#HotIf
#HotIf IsPrevActive()
#HotIf
#HotIf ( IsActive(PROGNAME " " TXT.HST__name, "window") and ctrlRef == "" )
	MButton::
	{
		KeyWait("MButton")
		Click()
		Sleep(50)
		history_InstaPaste()
	}
#HotIf
