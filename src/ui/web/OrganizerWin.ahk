; OrganizerWin.ahk - the Channel Organizer window: a WebHost showing ui/organizer/index.html.
;
;   OrganizerWin.Open()   OrganizerWin.Close()   OrganizerWin.Notify()  (channels changed elsewhere)
;
; Clips are addressed the organizer way: n = display number, 1 is the newest clip (real index = strength - n + 1).
; Page -> host: channels, clips {channel}, getClip {channel, n}, useChannel n, setProps {channel, n, tags, fixed},
;               move {channel, n, delta}, transfer {channel, ns, to, copy}, deleteClips {channel, ns},
;               newClip channel, newChannel name, renameChannel {n, name}, deleteChannel {n, mode, to},
;               moveChannel {n, delta}, paste {channel, ns}, pasteMode {channel, n}, edit {channel, n},
;               action {channel, n, action}, close
; Host -> page: i18n, actions {kind -> [{id, label}]}, channels {channels, active}, clips {channel, rows},
;               clip {...}, toast, refresh

class OrganizerWin {
	static host := ""
	static section := "Organizer"

	static Instance() {
		global PROGNAME, TXT
		if !OrganizerWin.host {
			h := WebHost(TXT.ORG__name, "organizer/index.html", "chOrg")
			h.OnMessage(OrganizerWin_OnMessage)
			h.OnClose(OrganizerWin_SaveGeometry)
			OrganizerWin.host := h
		}
		return OrganizerWin.host
	}

	static Prewarm() {
		OrganizerWin.Instance().Prewarm()
	}

	static Open() {
		h := OrganizerWin.Instance()
		if h.Visible {
			try WinActivate(h.g.Hwnd)
			return
		}
		if h.Show(OrganizerWin.Geometry()) {
			h.Focus()
			if h.ready
				h.Post("refresh")
		}
	}

	static Close() {
		if OrganizerWin.host && OrganizerWin.host.Visible {
			OrganizerWin_SaveGeometry()
			OrganizerWin.host.Hide()
		}
	}

	; called by changeChannel() and friends when the channel set or the active channel changed
	static Notify() {
		h := OrganizerWin.host
		if (h && h.Visible && h.ready)
			OrganizerWin.SendChannels()
	}

	static Geometry() {
		s := OrganizerWin.section
		w := IniRead(CONFIGURATION_FILE, s, "w", 1100), h := IniRead(CONFIGURATION_FILE, s, "h", 640)
		x := IniRead(CONFIGURATION_FILE, s, "x", ""), y := IniRead(CONFIGURATION_FILE, s, "y", "")
		w := (IsInteger(w) && w >= 500) ? w : 1100, h := (IsInteger(h) && h >= 300) ? h : 640
		return ((IsInteger(x) && IsInteger(y)) ? "x" x " y" y " " : "") "w" w " h" h
	}

	; ---------- data ----------

	static SendChannels() {
		global CN
		list := []
		loop CN.Total {
			n := A_Index - 1
			name := ini_read("Channels", n)
			list.Push(Map("n", n, "name", name != "" ? name : (n ? "" n : "Default"), "count", API.getChStrength(n)))
		}
		OrganizerWin.host.Post("channels", Map("channels", list, "active", CN.NG))
	}

	static SendClips(ch) {
		global CDS
		ch := IsInteger(ch) ? Integer(ch) : 0
		rows := []
		strength := API.getChStrength(ch)
		loop (strength = "" ? 0 : strength) {
			n := A_Index, real := strength - n + 1
			text := CDS[ch][real]
			thumb := "cache\thumbs" (ch ? ch : "") "\" real ".jpg"
			isImg := (text = "") && FileExist(thumb)
			row := Map("n", n, "clip", SubStr(getRealCD(text), 1, 300), "type", isImg ? 1 : 0, "tags", clipPref(ch, real, "Tags"), "fixed", clipPref(ch, real, "fixed") ? 1 : 0, "kind", isImg ? "image" : ClipType.Of(ch, real))
			if isImg   ; the row's thumbnail; stamped, because the file is named by position (see WebHost.CacheUrl)
				row["url"] := WebHost.CacheUrl(thumb, true), row["dim"] := clipPref(ch, real, "Dim")
			rows.Push(row)
		}
		OrganizerWin.host.Post("clips", Map("channel", ch, "rows", rows))
	}

	static SendClip(d) {
		global CDS
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (real < 1)
			return
		text := CDS[ch][real]
		thumb := "cache\thumbs" (ch ? ch : "") "\" real ".jpg"
		isImg := (text = "") && FileExist(thumb)
		; the page builds its Actions button from the "actions" table keyed by m.kind (same lookup the row
		; context menu already uses), so the clip record itself only needs to carry the kind
		m := Map("channel", ch, "n", n, "data", isImg ? "" : text, "type", isImg ? 1 : 0, "tags", clipPref(ch, real, "Tags"), "fixed", clipPref(ch, real, "fixed") ? 1 : 0, "kind", isImg ? "image" : ClipType.Of(ch, real))
		if isImg {
			m["url"] := WebHost.CacheUrl(thumb, true)
			m["dim"] := clipPref(ch, real, "Dim")
		}
		OrganizerWin.host.Post("clip", m)
	}

	static Action(d) {
		global CDS, TXT
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (real < 1)
			return
		text := CDS[ch][real]
		; keyed on text alone (not FileExist too): the row's kind was fixed at list time, so if the
		; thumbnail has since gone missing this still reaches ImageClip as a real, non-empty path and
		; fails honestly instead of quietly falling back to the live clipboard
		isImg := (text = "")
		ref := A_WorkingDir "\cache\thumbs" (ch ? ch : "") "\" real ".jpg"
		; Squoosh is a compression tool, so hand it the original clipboard bytes while they are still on
		; disk; the thumbnail beside them is an already re-encoded JPEG and a poor thing to compress
		if (isImg && d["action"] = "squoosh") {
			avc := A_WorkingDir "\cache\clips" (ch ? ch : "") "\" real ".avc"
			if FileExist(avc)
				ref := avc
		}
		wrote := isImg
			? ClipType.Run(d["action"], "", ref)
			: ClipType.Run(d["action"], text)
		if wrote
			OrganizerWin.host.Post("toast", TXT.HST_copiedToast)
	}

	; a channel clip still has its original bytes in the .avc, so an image saved from here reaches the Vault at
	; full fidelity, unlike one saved from a history row
	static Toast(t) {
		if OrganizerWin.host
			OrganizerWin.host.Post("toast", t)
	}

	static SaveToVault(d) {
		global CDS, TXT
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (real < 1)
			return
		text := CDS[ch][real]
		if (text != "") {
			vaultAdd(text, 0)
			OrganizerWin.Toast(TXT.VLT_added)
			return
		}
		avc := A_WorkingDir "\cache\clips" (ch ? ch : "") "\" real ".avc"
		if !FileExist(avc) {
			OrganizerWin.Toast(TXT.ACT_imageUnavailable)
			return
		}
		API.blockMonitoring(1)
		try trySetClipboard(ClipFileRead(avc))
		ClipWait(2)
		t := Gdip_Startup()
		bm := Gdip_CreateBitmapFromClipboard()
		saved := "", w := 0, h := 0
		if (bm > 0) {
			png := ImageClip.Temp("png")
			if (Gdip_SaveBitmapToFile(bm, png) = 0)
				saved := png
			w := Gdip_GetImageWidth(bm), h := Gdip_GetImageHeight(bm)
			Gdip_DisposeImage(bm)
		}
		Gdip_Shutdown(t)
		API.blockMonitoring(0)
		if (saved = "") {
			OrganizerWin.Toast(TXT.ACT_imageUnavailable)
			return
		}
		rel := vaultImageFile(saved)
		try FileDelete(saved)
		if (rel != "") {
			vaultAdd("[IMAGE]", 1, rel, "image", w, h)
			OrganizerWin.Toast(TXT.VLT_added)
		} else
			OrganizerWin.Toast(TXT.ACT_imageUnavailable)
	}

	static SetProps(d) {
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (real < 1)
			return
		AddClipPref(ch, real, "Tags", Trim(d["tags"]))
		AddClipPref(ch, real, "fixed", d["fixed"] ? 1 : "")
		Prefs2Ini()
		OrganizerWin.SendClips(ch)
	}

	static Move(d) {
		ch := Integer(d["channel"]), n := Integer(d["n"]), delta := Integer(d["delta"])
		m := n + delta
		if (m < 1 || m > API.getChStrength(ch))
			return
		chOrg_clipSwap(ch, n, ch, m)
		OrganizerWin.SendClips(ch)
	}

	; descending display numbers keep the remaining numbers valid while clips leave the channel
	static SortedDesc(ns) {
		s := ""
		for n in ns
			if IsInteger(n)
				s .= n "`n"
		out := []
		loop parse Sort(Trim(s, "`n"), "N R"), "`n"
			if (A_LoopField != "")
				out.Push(Integer(A_LoopField))
		return out
	}

	static Transfer(d) {
		global TXT
		ch := Integer(d["channel"]), to := Integer(d["to"]), copy := d["copy"] ? 1 : 0
		if (to = ch && !copy)
			return
		for n in OrganizerWin.SortedDesc(d["ns"])
			API.manageClip(to, ch, n, copy)
		OrganizerWin.SendChannels()
		OrganizerWin.SendClips(ch)
		OrganizerWin.host.Post("toast", TXT.TIP_done)
	}

	static DeleteClips(d) {
		global TXT
		ch := Integer(d["channel"])
		for n in OrganizerWin.SortedDesc(d["ns"])
			API.deleteClip(ch, n)
		OrganizerWin.SendChannels()
		OrganizerWin.SendClips(ch)
		OrganizerWin.host.Post("toast", TXT.ORG_clpdelMsg)
	}

	static NewClip(ch) {
		global STORE, TXT, blank
		ch := IsInteger(ch) ? Integer(ch) : 0
		STORE.ErrorLevel := 0
		out := multInputBox(TXT.ORG_createnew, TXT.ORG_createnewpr " - " ch, 15, blank, "chOrg")
		if !STORE.ErrorLevel
			return
		API.addClip(ch, out)
		OrganizerWin.SendChannels()
		OrganizerWin.SendClips(ch)
	}

	static NewChannel(name) {
		global CN
		bk := CN.NG
		newIdx := CN.Total
		changeChannel(newIdx)
		if (Trim(name) != "")
			renameChannel(newIdx, Trim(name))
		changeChannel(bk)
		OrganizerWin.SendChannels()
	}

	static RenameChannel(d) {
		name := Trim(d["name"])
		if (name = "")
			return
		renameChannel(Integer(d["n"]), name)
		OrganizerWin.SendChannels()
	}

	; mode: "move" (clips go to channel `to`), "delete" (clips go too), "empty" (keep the channel, drop its clips)
	static DeleteChannel(d) {
		global CN
		n := Integer(d["n"]), mode := d["mode"]
		if (n < 1 || n >= CN.Total)
			return
		if (mode = "empty") {
			API.emptyChannel(n)
			OrganizerWin.SendChannels(), OrganizerWin.SendClips(n)
			return
		}
		if (mode = "move") {
			to := Integer(d["to"])
			if (to = n)
				return
			strength := API.getChStrength(n)
			loop strength
				API.manageClip(to, n, strength - A_Index + 1, 0)
		}
		manageChannel(n)
		OrganizerWin.SendChannels()
		OrganizerWin.SendClips(CN.NG)
	}

	static MoveChannel(d) {
		n := Integer(d["n"]), delta := Integer(d["delta"])
		if chOrg_clipFolderSwap(n, n + delta)
			OrganizerWin.SendChannels()
	}

	static Paste(d) {
		ch := Integer(d["channel"])
		ns := OrganizerWin.SortedDesc(d["ns"])
		if !ns.Length
			return
		OrganizerWin.Close()
		Sleep 200
		; ascending order pastes the newest clip first, like the old organizer's selection order
		loop ns.Length {
			API.paste(ch, ns[ns.Length - A_Index + 1])
			Sleep 30
			if (A_Index < ns.Length)
				SendInput("{Enter}")
		}
	}

	static PasteMode(d) {
		global CN, realActive, SPM
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (ch == CN.NG && real == realActive && SPM.ACTIVE) {
			endPastemode()
			return
		}
		API.showPasteTipAt(ch, n)
	}

	static Edit(d) {
		global STORE
		ch := Integer(d["channel"]), n := Integer(d["n"])
		STORE.ErrorLevel := 0
		editClip(ch, n)
		OrganizerWin.SendClips(ch)
	}

	static I18n() {
		global TXT
		keys := ["ORG_search", "ORG_NewClip", "ORG_newChannel", "ORG_chooseCh", "ORG_channels", "ORG_clip", "ORG_tags", "ORG_fixed", "ORG_insta", "ORG_openPst", "ORG_editBtn", "ORG_moveTo", "ORG_copyTo", "ORG_delete", "ORG_moveUp", "ORG_moveDown", "ORG_countStatus", "ORG_selectHint", "ORG_moveTitle", "ORG_copyTitle", "ORG_moveBtn", "ORG_copyBtn", "ORG_delChTitle", "ORG_delChText", "ORG_delChMove", "ORG_delChDelete", "ORG_delChEmpty", "ORG_renameTitle", "ORG_renameBtn", "ORG_newChTitle", "ORG_createBtn", "ORG_footHint", "ORG_channelStatus", "ORG_clipOf", "HST_viewimage", "HST_actions", "SET_cancel", "_rename", "_new", "KIND_url", "KIND_email", "KIND_path", "KIND_color", "KIND_json", "KIND_svg", "KIND_number", "KIND_phone", "KIND_code", "KIND_text", "KIND_image", "VLT_saveToVault"]
		m := Map()
		for k in keys
			m[k] := StrReplace(TXT.%k%, "&")
		OrganizerWin.host.Post("i18n", m)
	}
}

OrganizerWin_OnMessage(cmd, data, host) {
	global CN
	switch cmd {
		case "ready":
			OrganizerWin.I18n()
			OrganizerWin.host.Post("actions", ClipType_ActionTable(true))
			OrganizerWin.SendChannels()
			OrganizerWin.SendClips(CN.NG)
		case "channels": OrganizerWin.SendChannels()
		case "clips": OrganizerWin.SendClips(data)
		case "getClip": OrganizerWin.SendClip(data)
		case "useChannel":
			changeChannel(channel_find(data))
			OrganizerWin.SendChannels()
		case "setProps": OrganizerWin.SetProps(data)
		case "move": OrganizerWin.Move(data)
		case "transfer": OrganizerWin.Transfer(data)
		case "deleteClips": OrganizerWin.DeleteClips(data)
		case "newClip": OrganizerWin.NewClip(data)
		case "newChannel": OrganizerWin.NewChannel(data)
		case "renameChannel": OrganizerWin.RenameChannel(data)
		case "deleteChannel": OrganizerWin.DeleteChannel(data)
		case "moveChannel": OrganizerWin.MoveChannel(data)
		case "paste": OrganizerWin.Paste(data)
		case "pasteMode": OrganizerWin.PasteMode(data)
		case "edit": OrganizerWin.Edit(data)
		case "saveToVault": OrganizerWin.SaveToVault(data)
		case "action": OrganizerWin.Action(data)
		case "close": OrganizerWin.Close()
	}
}

; test hook: plain file-level, because RunFunc routes dotted names to API.*
Organizer_SaveToVault(ch, n) => OrganizerWin.SaveToVault(Map("channel", ch, "n", n))

OrganizerWin_SaveGeometry() {
	h := OrganizerWin.host
	if !h || !h.Visible
		return
	try {
		WinGetPos(&x, &y, , , h.g.Hwnd)
		h.g.GetClientPos(, , &w, &hh)
		s := OrganizerWin.section
		Ini_write(s, "x", x, 0), Ini_write(s, "y", y, 0), Ini_write(s, "w", w, 0), Ini_write(s, "h", hh, 0)
	}
}

; the two clip helpers the old organizer file provided; everything else in it is replaced by the page

; swaps two clips (organizer numbering: 1 = newest)
chOrg_clipSwap(fch, fcl, sch, scl){
	f_sub := (fch?fch:"") , s_sub := (sch?sch:"")
	f_cno := API.getChStrength(fch)-fcl+1 , s_cno := API.getChStrength(sch)-scl+1

	ClipTransfer(s_sub, s_cno, s_sub, s_cno "_a", 0)
	ClipTransfer(f_sub, f_cno, s_sub, s_cno, 0)
	ClipTransfer(s_sub, s_cno "_a", f_sub, f_cno, 0)
	bk := CDS[sch][s_cno] , CDS[sch][s_cno] := CDS[fch][f_cno] , CDS[fch][f_cno] := bk
	bk := CPS[sch][s_cno] , CPS[sch][s_cno] := CPS[fch][f_cno] , CPS[fch][f_cno] := bk
}

; swaps two channels (their folders, caches, prefs and names)
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

channelOrganizer(*) {
	OrganizerWin.Open()
}
