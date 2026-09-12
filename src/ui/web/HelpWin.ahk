; HelpWin.ahk - the Help window: a WebHost showing ui/help/index.html.
;
;   HelpWin.Open(topic)   HelpWin.Close()
;
; Page -> host: reference, open {url}, close
; Host -> page: i18n, reference {...}, opened {topic}

class HelpWin {
	static host := ""
	static section := "Help_window"
	static pending := ""
	static probe := ""

	static Instance() {
		global PROGNAME, TXT
		if !HelpWin.host {
			h := WebHost(PROGNAME " " TXT.HLP_title, "help/index.html", "Help")
			h.OnMessage(HelpWin_OnMessage)
			h.OnClose(HelpWin_SaveGeometry)
			HelpWin.host := h
		}
		return HelpWin.host
	}

	static Open(topic := "") {
		h := HelpWin.Instance()
		HelpWin.pending := topic
		if h.Visible {
			try WinActivate(h.g.Hwnd)
			if h.ready
				h.Post("opened", topic)
			return
		}
		if h.Show(HelpWin.Geometry()) {
			h.Focus()
			if h.ready
				h.Post("opened", topic)
		}
	}

	static Close() {
		if HelpWin.host && HelpWin.host.Visible {
			HelpWin_SaveGeometry()
			HelpWin.host.Hide()
		}
	}

	static Geometry() {
		global CONFIGURATION_FILE
		w := IniRead(CONFIGURATION_FILE, HelpWin.section, "w", 900), h := IniRead(CONFIGURATION_FILE, HelpWin.section, "h", 640)
		x := IniRead(CONFIGURATION_FILE, HelpWin.section, "x", ""), y := IniRead(CONFIGURATION_FILE, HelpWin.section, "y", "")
		w := (IsInteger(w) && w >= 520) ? w : 900, h := (IsInteger(h) && h >= 360) ? h : 640
		return ((IsInteger(x) && IsInteger(y)) ? "x" x " y" y " " : "") "w" w " h" h
	}

	static I18n() {
		global TXT
		keys := ["HLP_title", "HLP_search", "HLP_noMatch", "HLP_matches", "HLP_topics", "HLP_key", "HLP_action"
			, "HLP_format", "HLP_appliesTo", "HLP_shortcut", "HLP_description", "HLP_notAvailable"]
		m := Map()
		for k in keys
			m[k] := TXT.%k%
		HelpWin.host.Post("i18n", m)
	}
}

HelpWin_OnMessage(cmd, data, host) {
	switch cmd {
		case "ready":
			HelpWin.I18n()
			host.Post("reference", Help_Reference())
			host.Post("opened", HelpWin.pending)
		case "reference": host.Post("reference", Help_Reference())
		case "open": BrowserRun(data)
		case "close": HelpWin.Close()
		case "probe": HelpWin.probe := data
		case "topic": HelpWin.probe := data
	}
}

HelpWin_SaveGeometry() {
	h := HelpWin.host
	if !h || !h.Visible
		return
	try {
		WinGetPos(&x, &y, , , h.g.Hwnd)
		h.g.GetClientPos(, , &w, &hh)
		s := HelpWin.section
		Ini_write(s, "x", x, 0), Ini_write(s, "y", y, 0), Ini_write(s, "w", w, 0), Ini_write(s, "h", hh, 0)
	}
}

; the ACTIONS entry, so customizer scripts and ACTIONMODE can route to help by name
help(*) {
	HelpWin.Open()
}

; everything the reference topics show, read from the running app so it cannot drift from the code
Help_Reference() {
	global Actionmode_K, chOrg_K, pluginManager_K, history_k, onetime_K, holdClip_K, Copyfilepath_K
	global Copyfolderpath_K, Copyfiledata_K, pitswap_K, paste_k, pstIdentifier, pstKeyName
	global windows_copy_k, windows_cut_k, VERSION, TXT
	pasteRows := []
	for it in Hud.HelpItems()
		pasteRows.Push(Map("key", it.key, "caption", it.caption))
	keys := [[TXT.SET_actmd, Actionmode_K], [TXT.SET_org, chOrg_K], [TXT.PLG__name, pluginManager_K]
		, [TXT.HST__name, history_k], [TXT._ot, onetime_K], [TXT.SET_holdclip, holdClip_K]
		, [TXT._pitswp, pitswap_K], [TXT._cfilep, Copyfilepath_K], [TXT._cfolderp, Copyfolderpath_K]
		, [TXT._cfiled, Copyfiledata_K], [TXT.SET_winCopyShortcut, windows_copy_k]
		, [TXT.SET_winCutShortcut, windows_cut_k]]
	hot := []
	for k in keys
		if (k[2] != "")
			hot.Push(Map("label", k[1], "keys", HParse_Rev(k[2])))
	hot.Push(Map("label", TXT.SET_pasteMode, "keys", pstKeyName " + " StrUpper(paste_k = "" ? "V" : paste_k)))
	fmts := []
	for it in Formatting_Items("").items
		fmts.Push(Map("key", it.key, "label", it.label, "short", it.HasProp("short") ? it.short : ""
			, "desc", it.HasProp("desc") ? it.desc : "", "kinds", Help_FormatKinds(it.label)))
	acts := []
	for it in ActionRing_Items()
		acts.Push(Map("key", it.key, "label", it.label, "desc", it.HasProp("desc") ? it.desc : ""))
	labels := ClipType_Labels(), kinds := []
	for k in ClipType.Kinds
		kinds.Push(Map("kind", k, "label", labels.Has(k) ? labels[k] : k))
	return Map("pasteMode", pasteRows, "hotkeys", hot, "formats", fmts, "actions", acts
		, "rules", Map("actions", Rules.Actions, "kinds", kinds), "version", VERSION)
}

; the clip kinds a format applies to, as a display string ("" means every kind)
Help_FormatKinds(name) {
	global PLUGINS
	for k, v in PLUGINS.pformat {
		if (v["name"] != name)
			continue
		kinds := ""
		try kinds := v["kinds"]
		return kinds
	}
	return ""
}

; test and customizer hooks: RunFunc misroutes dotted names to API.*
Help_Open(topic := "") => HelpWin.Open(topic)
Help_Close() => HelpWin.Close()
Help_GeometrySpec() => HelpWin.Geometry()

; test hook: applies a filter term to the page directly. Driving this by simulated typing into the WebView2
; search box proved unreliable under the test harness (focus does not always land there in time), so the
; flow test sends this message instead and reads the result back through HelpWin_FilterProbe.
Help_Filter(term := "") {
	if !HelpWin.host
		return
	HelpWin.host.Post("filter", term)
}

; test hook: "shown=<topics listed> hits=<total matches>" for the current filter
HelpWin_FilterProbe() {
	HelpWin.probe := ""
	if !HelpWin.host
		return ""
	HelpWin.host.Post("probe")
	t := A_TickCount
	while (HelpWin.probe = "" && A_TickCount - t < 3000)
		Sleep 50
	return HelpWin.probe
}

; test hook: the topic id currently on screen, through the same probe channel as HelpWin_FilterProbe
HelpWin_TopicProbe() {
	HelpWin.probe := ""
	if !HelpWin.host
		return ""
	HelpWin.host.Post("topic")
	t := A_TickCount
	while (HelpWin.probe = "" && A_TickCount - t < 3000)
		Sleep 50
	return HelpWin.probe
}

; test hook: how many topic fragments ship in ui\help\topics
Help_TopicCount() {
	n := 0
	loop files A_WorkingDir "\ui\help\topics\*.html"
		n++
	return n
}

; test hook: the shape of the reference payload as one line
Help_ReferenceProbe() {
	r := Help_Reference()
	return "pasteMode=" r["pasteMode"].Length " hotkeys=" r["hotkeys"].Length " formats=" r["formats"].Length
		. " actions=" r["actions"].Length " rules=" r["rules"]["actions"].Length
}

; test hook: proves the tray card's Help item is wired as a direct action (not a submenu) and that the
; classic tray menu still carries a Help entry, without clicking either -- the tray card needs real mouse
; input and the user may be at the desktop, so this reads the live structures instead
Help_EntryPointsProbe() {
	global TXT
	card := 0
	for it in TrayCard.MainSpec().items {
		if (it.HasProp("label") && it.label = TXT.TRY_help) {
			card := (it.HasProp("fn") && it.fn && !it.HasProp("sub")) ? 1 : 0
			break
		}
	}
	classic := 0
	hMenu := A_TrayMenu.Handle
	n := DllCall("GetMenuItemCount", "Ptr", hMenu, "Int")
	loop n {
		buf := Buffer(512, 0)
		len := DllCall("GetMenuStringW", "Ptr", hMenu, "UInt", A_Index - 1, "Ptr", buf, "Int", 256, "UInt", 0x400, "Int")   ; MF_BYPOSITION
		if (len && StrGet(buf, "UTF-16") = TXT.TRY_help) {
			classic := 1
			break
		}
	}
	return "card=" card " classic=" classic
}
