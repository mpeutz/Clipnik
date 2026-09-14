; HistoryWin.ahk - the Clipboard History window: a WebHost showing ui/history/index.html.
;
;   HistoryWin.Open()   HistoryWin.Close()
;
; Page -> host: list {q, partial, sort, asc, kind}, get {id}, copy {id}, instaPaste {ids}, hold {id}, edit {id},
;               export {id}, delete {ids}, clear, setPartial {partial}, action {id, action}, close
; Host -> page: i18n, list {rows, matched, total, bytes, partial}, kinds {kinds, labels, actions}, preview {record},
;               toast {text}, refreshed

class HistoryWin {
	static host := ""
	static section := "Clipboard_History_window"
	static curView := "history"

	; the page names the table it means on every request that touches a row; the host records it so the
	; actions that follow do not each have to be told again
	static View(d) {
		if (d is Map && d.Has("view"))
			HistoryWin.curView := (d["view"] = "vault") ? "vault" : "history"
		return HistoryWin.curView
	}

	; the record behind an id, from whichever table the page is showing
	static Rec(d, id) {
		return (HistoryWin.View(d) = "vault") ? vaultGet(id) : historyGet(id)
	}

	; puts that record on the clipboard; true when something was written
	static PutOnClipboard(d, id) {
		return (HistoryWin.View(d) = "vault") ? vaultToClipboard(id) : historyToClipboard(id)
	}

	; the id out of a message that may be a bare id (older callers) or a map
	static IdOf(d) {
		return (d is Map && d.Has("id")) ? d["id"] : d
	}

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
		if (HistoryWin.View(d) = "vault") {
			r := vaultList(q, partial, kind)
			r["partial"] := partial ? 1 : 0
			HistoryWin.host.Post("list", r)
			HistoryWin.SendKinds()
			return
		}
		r := historyQuery(q, partial, sortBy, asc, 0, 2000, kind)
		historyEnsureKinds(r["rows"])   ; one transaction for the whole page, not an update per row
		r["partial"] := partial ? 1 : 0
		HistoryWin.host.Post("list", r)
		HistoryWin.SendKinds()
	}

	static SendKinds() {
		HistoryWin.host.Post("kinds", Map("kinds", historyKinds(), "labels", ClipType_Labels(), "actions", ClipType_ActionTable(true)))
	}

	; the page builds its Actions button from the "kinds" table keyed by rec.kind (same lookup the row
	; context menu already uses), so the preview record itself only needs to carry the kind, not the actions
	static SendPreview(d) {
		id := HistoryWin.IdOf(d)
		if (HistoryWin.View(d) = "vault") {
			rec := vaultGet(id)
			if !rec
				return
			if (rec["type"] = 1) {
				rec["url"] := "https://cache.clipjump/" StrReplace(RegExReplace(rec["fileid"], "^cache[\\/]"), "\", "/")
				rec.Delete("fileid"), rec.Delete("data")
			}
			HistoryWin.host.Post("preview", rec)
			return
		}
		rec := historyGet(id)
		if !rec
			return
		if (rec["type"] = 0 && rec["kind"] = "")
			rec["kind"] := historyEnsureKind(id)
		if (rec["type"] == 1) {
			; the page never needs the raw fileid or the (already blanked) data field
			rec["url"] := "https://cache.clipjump/" StrReplace(RegExReplace(rec["fileid"], "^cache[\\/]"), "\", "/")
			rec.Delete("fileid"), rec.Delete("data")
		}
		HistoryWin.host.Post("preview", rec)
	}

	static Action(d) {
		global TXT
		rec := HistoryWin.Rec(d, d["id"])
		if !rec
			return
		wrote := (rec["type"] == 1)
			? ClipType.Run(d["action"], "", A_WorkingDir "\" rec["fileid"])
			: ClipType.Run(d["action"], rec["data"])
		if wrote
			HistoryWin.host.Post("toast", TXT.HST_copiedToast)
	}

	static Copy(d) {
		global TXT
		id := HistoryWin.IdOf(d)
		if HistoryWin.PutOnClipboard(d, id)
			HistoryWin.host.Post("toast", TXT.HST_copiedToast)
	}

	static InstaPaste(d) {
		global ini_instapasteWritesClipboard, ini_HisCloseOnInstaPaste, IScurCBACTIVE
		ids := (d is Map && d.Has("ids")) ? d["ids"] : d
		HistoryWin.View(d)
		if !(ids is Array) || !ids.Length
			return
		h := HistoryWin.host
		h.Hide()
		Sleep 150
		for i, id in ids {
			if ini_instapasteWritesClipboard
				ok := HistoryWin.PutOnClipboard(d, id)
			else {
				API.blockMonitoring(1)
				IScurCBACTIVE := 0
				ok := HistoryWin.PutOnClipboard(d, id)
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

	static Hold(d) {
		global STORE
		id := HistoryWin.IdOf(d)
		rec := HistoryWin.Rec(d, id)
		if (!rec || rec["type"] == 1)
			return
		STORE.holdClip_preText := rec["data"]
		holdClip()
	}

	static Edit(d) {
		global ini_defImgEditor, STORE, TXT
		id := HistoryWin.IdOf(d)
		vault := HistoryWin.View(d) = "vault"
		rec := HistoryWin.Rec(d, id)
		if !rec
			return
		if (rec["type"] == 1) {
			RunWait(ini_defImgEditor ' "' A_WorkingDir "\" rec["fileid"] '"')
		} else {
			STORE.ErrorLevel := 0
			out := multInputBox(TXT.HST_editTitle, TXT.HST_editPrompt, 10, rec["data"], "History")
			if (STORE.ErrorLevel == 1)
				vault ? vaultSetText(id, out) : historySetText(id, out)
		}
		HistoryWin.host.Post("refreshed")
	}

	static Export(d) {
		global CALLER, ONCLIPBOARD, CALLER_STATUS, PROGNAME, TXT
		id := HistoryWin.IdOf(d)
		CALLER := 0, ONCLIPBOARD := ""
		if !HistoryWin.PutOnClipboard(d, id) {
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

	static Delete(d) {
		global TXT
		ids := (d is Map && d.Has("ids")) ? d["ids"] : d
		vault := HistoryWin.View(d) = "vault"
		if !(ids is Array)
			return
		if vault {
			HistoryWin.host.g.Opt("+OwnDialogs")
			if (MsgBox(TXT.VLT_deleteMsg, TXT.VLT__name, 257) != "OK")
				return
		}
		for id in ids
			if IsInteger(id)
				vault ? vaultDelete(id) : deleteHistoryById(id)
		HistoryWin.host.Post("refreshed")
	}

	static Rename(d) {
		global STORE, TXT
		HistoryWin.View(d)
		rec := vaultGet(d["id"])
		if !rec
			return
		STORE.ErrorLevel := 0
		out := multInputBox(TXT.VLT_nameTitle, TXT.VLT_namePrompt, 1, rec["name"], "History")
		if (STORE.ErrorLevel == 1)
			vaultSetName(d["id"], out)
		HistoryWin.host.Post("refreshed")
	}

	static MoveEntry(d) {
		HistoryWin.View(d)
		if vaultMove(d["id"], Integer(d["delta"]))
			HistoryWin.host.Post("refreshed")
	}

	; saves whatever is on the clipboard right now: an image when Gdip finds one there, otherwise the text
	static AddFromClipboard() {
		global TXT
		HistoryWin.curView := "vault"
		t := Gdip_Startup()
		bm := Gdip_CreateBitmapFromClipboard()
		if (bm > 0) {
			png := ImageClip.Temp("png")
			ok := (Gdip_SaveBitmapToFile(bm, png) = 0)
			w := Gdip_GetImageWidth(bm), h := Gdip_GetImageHeight(bm)
			Gdip_DisposeImage(bm), Gdip_Shutdown(t)
			rel := ok ? vaultImageFile(png) : ""
			try FileDelete(png)
			if (rel != "") {
				vaultAdd("[IMAGE]", 1, rel, "image", w, h)
				HistoryWin.host.Post("toast", TXT.VLT_added)
				HistoryWin.host.Post("refreshed")
			} else
				HistoryWin.host.Post("toast", TXT.VLT_nothingToAdd)
			return
		}
		Gdip_Shutdown(t)
		text := ""
		try text := A_Clipboard
		if (Trim(text) = "") {
			HistoryWin.host.Post("toast", TXT.VLT_nothingToAdd)
			return
		}
		vaultAdd(text, 0)
		HistoryWin.host.Post("toast", TXT.VLT_added)
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
		keys := ["HST_search", "HST_partial", "HST_exact", "HST_refresh", "HST_clear", "HST_clip", "HST_date", "HST_size", "HST_copy", "HST_insta", "HST_hold", "HST_edit", "HST_export", "HST_delete", "HST_empty", "HST_noMatch", "HST_items", "HST_match", "HST_onDisk", "HST_sortedBy", "HST_selectHint", "HST_viewimage", "HST_today", "HST_yesterday", "HST_type", "HST_allTypes", "HST_actions", "HST_viewHistory", "VLT__name", "VLT_yourOrder", "VLT_add", "VLT_rename", "VLT_moveUp", "VLT_moveDown"]
		m := Map()
		for k in keys
			m[k] := TXT.%k%
		HistoryWin.host.Post("i18n", m)
	}
}

; test hooks: plain file-level functions, because RunFunc routes any dotted name to API.*
History_SetView(v) {
	if !HistoryWin.host
		return ""
	HistoryWin.host.Post("setView", v = "vault" ? "vault" : "history")
	return v
}
History_Close() => HistoryWin.Close()
History_AddFromClipboard() => HistoryWin.AddFromClipboard()

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
		case "action": HistoryWin.Action(data)
		case "rename": HistoryWin.Rename(data)
		case "move": HistoryWin.MoveEntry(data)
		case "addClipboard": HistoryWin.AddFromClipboard()
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

; test hook: clicks the preview's Actions button then one menu item inside the real page, so a test can
; exercise the actual click -> bridge.send("action") -> HistoryWin.Action path instead of calling it directly
History_ClickAction(itemId) {
	h := HistoryWin.host
	if (h && h.core)
		h.core.ExecuteScriptAsync("document.getElementById('actions').click();var mi=document.querySelector('.mi[data-id=" itemId "]');if(mi)mi.click();")
}
