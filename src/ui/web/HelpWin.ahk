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

; replaced in Task 2 by the generated reference
Help_Reference() {
	return Map()
}

; test and customizer hooks: RunFunc misroutes dotted names to API.*
Help_Open(topic := "") => HelpWin.Open(topic)
Help_Close() => HelpWin.Close()
Help_GeometrySpec() => HelpWin.Geometry()
