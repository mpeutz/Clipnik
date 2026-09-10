; HistoryWin.ahk - the Clipboard History window: a WebHost showing ui/history/index.html.
;
;   HistoryWin.Open()   HistoryWin.Close()
;
; Page -> host: list {q, partial, sort, asc, kind}, get {id}, copy {id}, instaPaste {ids}, hold {id}, edit {id},
;               export {id}, delete {ids}, clear, setPartial {partial}, close
; Host -> page: i18n, list {rows, matched, total, bytes, partial}, kinds {kinds, labels}, preview {record},
;               toast {text}, refreshed

class HistoryWin {
	static host := ""
	static section := "Clipboard_History_window"

	static Instance() {
		global PROGNAME, TXT
		if !HistoryWin.host {
			h := WebHost(PROGNAME " " TXT.HST__name, "history/index.html", "History")
			h.OnMessage(HistoryWin_OnMessage)
			h.OnClose(HistoryWin_SaveGeometry)
			HistoryWin.host := h
		}
		return HistoryWin.host
	}

	static Prewarm() {
		HistoryWin.Instance().Prewarm()
	}

	static Open() {
		h := HistoryWin.Instance()
		if h.Visible {
			try WinActivate(h.g.Hwnd)
			return
		}
		if h.Show(HistoryWin.Geometry()) {
			h.Focus()
			if h.ready
				h.Post("opened")
		}
	}

	static Close() {
		if HistoryWin.host && HistoryWin.host.Visible {
			HistoryWin_SaveGeometry()
			HistoryWin.host.Hide()
		}
	}

	static Geometry() {
		w := IniRead(CONFIGURATION_FILE, HistoryWin.section, "w", 1040), h := IniRead(CONFIGURATION_FILE, HistoryWin.section, "h", 640)
		x := IniRead(CONFIGURATION_FILE, HistoryWin.section, "x", ""), y := IniRead(CONFIGURATION_FILE, HistoryWin.section, "y", "")
		w := (IsInteger(w) && w >= 500) ? w : 1040, h := (IsInteger(h) && h >= 300) ? h : 640
		return ((IsInteger(x) && IsInteger(y)) ? "x" x " y" y " " : "") "w" w " h" h
	}

	; ---------- page requests ----------

	static SendList(d) {
		global history_partial
		q := d is Map && d.Has("q") ? d["q"] : ""
		partial := d is Map && d.Has("partial") ? (d["partial"] ? true : false) : (history_partial ? true : false)
		sortBy := d is Map && d.Has("sort") ? d["sort"] : "time"
		asc := d is Map && d.Has("asc") ? (d["asc"] ? true : false) : false
		kind := d is Map && d.Has("kind") ? d["kind"] : ""
		r := historyQuery(q, partial, sortBy, asc, 0, 2000, kind)
		for row in r["rows"]
			if (row["type"] = 0 && row["kind"] = "")
				row["kind"] := historyEnsureKind(row["id"])
		r["partial"] := partial ? 1 : 0
		HistoryWin.host.Post("list", r)
		HistoryWin.SendKinds()
	}

	static SendKinds() {
		HistoryWin.host.Post("kinds", Map("kinds", historyKinds(), "labels", ClipType_Labels()))
	}

	static SendPreview(id) {
		rec := historyGet(id)
		if !rec
			return
		if (rec["type"] = 0 && rec["kind"] = "")
			rec["kind"] := historyEnsureKind(id)
		if (rec["type"] == 1) {
			rec["url"] := "https://cache.clipjump/" StrReplace(RegExReplace(rec["fileid"], "^cache[\\/]"), "\", "/")
			rec["data"] := ""
		}
		HistoryWin.host.Post("preview", rec)
	}

	static Copy(id) {
		global TXT
		if historyToClipboard(id)
			HistoryWin.host.Post("toast", TXT.HST_copiedToast)
	}

	static InstaPaste(ids) {
		global ini_instapasteWritesClipboard, ini_HisCloseOnInstaPaste, IScurCBACTIVE
		if !(ids is Array) || !ids.Length
			return
		h := HistoryWin.host
		h.Hide()
		Sleep 150
		for i, id in ids {
			if ini_instapasteWritesClipboard
				ok := historyToClipboard(id)
			else {
				API.blockMonitoring(1)
				IScurCBACTIVE := 0
				ok := historyToClipboard(id)
			}
			if !ok
				continue
			SendInput((i > 1 ? "{Enter}" : "") "^{vk56}")
			Sleep 110
		}
		API.blockMonitoring(0)
		if !ini_HisCloseOnInstaPaste {
			Sleep 200
			h.Show(HistoryWin.Geometry())
		}
	}

	static Hold(id) {
		global STORE
		rec := historyGet(id)
		if (!rec || rec["type"] == 1)
			return
		STORE.holdClip_preText := rec["data"]
		holdClip()
	}

	static Edit(id) {
		global ini_defImgEditor, STORE, TXT
		rec := historyGet(id)
		if !rec
			return
		if (rec["type"] == 1) {
			RunWait(ini_defImgEditor ' "' A_WorkingDir "\" rec["fileid"] '"')
		} else {
			STORE.ErrorLevel := 0
			out := multInputBox(TXT.HST_editTitle, TXT.HST_editPrompt, 10, rec["data"], "History")
			if (STORE.ErrorLevel == 1)
				historySetText(id, out)
		}
		HistoryWin.host.Post("refreshed")
	}

	static Export(id) {
		global CALLER, ONCLIPBOARD, CALLER_STATUS, PROGNAME, TXT
		CALLER := 0, ONCLIPBOARD := ""
		if !historyToClipboard(id) {
			CALLER := CALLER_STATUS
			return
		}
		t := A_TickCount
		while (!ONCLIPBOARD && A_TickCount - t < 2000)
			Sleep 50
		ClipWait(1)
		loop
			if !FileExist(temp := A_MyDocuments "\export" A_Index ".cj")
				break
		try FileAppend(ClipboardAll(), temp)
		CALLER := CALLER_STATUS
		HistoryWin.host.g.Opt("+OwnDialogs")
		MsgBox("Selected Clip " TXT._exportedto "`n" temp, PROGNAME " " TXT.HST__name, 64)
	}

	static Delete(ids) {
		if !(ids is Array)
			return
		for id in ids
			if IsInteger(id)
				deleteHistoryById(id)
		HistoryWin.host.Post("refreshed")
	}

	static Clear() {
		global TXT
		HistoryWin.host.g.Opt("+OwnDialogs")
		if (MsgBox(TXT.HST_delall_msg, "Clear History", 257) = "OK") {
			clearHistory()
			HistoryWin.host.Post("refreshed")
		}
	}

	static I18n() {
		global TXT
		keys := ["HST_search", "HST_partial", "HST_exact", "HST_refresh", "HST_clear", "HST_clip", "HST_date", "HST_size", "HST_copy", "HST_insta", "HST_hold", "HST_edit", "HST_export", "HST_delete", "HST_empty", "HST_noMatch", "HST_items", "HST_match", "HST_onDisk", "HST_sortedBy", "HST_selectHint", "HST_viewimage", "HST_today", "HST_yesterday"]
		m := Map()
		for k in keys
			m[k] := TXT.%k%
		HistoryWin.host.Post("i18n", m)
	}
}

HistoryWin_OnMessage(cmd, data, host) {
	global history_partial
	switch cmd {
		case "ready":
			HistoryWin.I18n()
			HistoryWin.SendList(Map("partial", history_partial))
		case "list": HistoryWin.SendList(data)
		case "get": HistoryWin.SendPreview(data)
		case "copy": HistoryWin.Copy(data)
		case "instaPaste": HistoryWin.InstaPaste(data)
		case "hold": HistoryWin.Hold(data)
		case "edit": HistoryWin.Edit(data)
		case "export": HistoryWin.Export(data)
		case "delete": HistoryWin.Delete(data)
		case "clear": HistoryWin.Clear()
		case "setPartial": history_partial := data ? 1 : 0
		case "close": HistoryWin.Close()
	}
}

HistoryWin_SaveGeometry() {
	h := HistoryWin.host
	if !h || !h.Visible
		return
	try {
		WinGetPos(&x, &y, , , h.g.Hwnd)
		h.g.GetClientPos(, , &w, &hh)
		s := HistoryWin.section
		Ini_write(s, "x", x, 0), Ini_write(s, "y", y, 0), Ini_write(s, "w", w, 0), Ini_write(s, "h", hh, 0)
	}
}
