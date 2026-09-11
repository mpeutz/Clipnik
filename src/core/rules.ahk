; rules.ahk - copy-time rules. A rule is conditions (kinds, regex, source app, window class; all given must hold)
; plus one action (channel:N, ignore, transform:Name, tag:Text). Stored in settings.ini under [Rules] as numbered
; lines: 1=on=1;kinds=url,email;regex=;app=chrome.exe;action=channel:2;name=Links
;
;   Rules.Load() / Rules.Save(list)      settings.ini <-> Rules.List
;   Rules.Parse(line) / Rules.Serialize(rule)
;   Rules.Match(rule, kind, text, app, cls := "")
;   Rules.Evaluate(list, kind, text, app, cls := "") -> first enabled matching rule or ""
;   Rules.Describe(rule) -> [when, then] for lists
;   Rules.Validate(rule) -> "" or a message

class Rules {
	static List := []
	static Actions := ["channel", "ignore", "transform", "tag"]

	static New() {
		r := Map()
		r["on"] := 1, r["kinds"] := [], r["regex"] := "", r["app"] := "", r["class"] := "", r["action"] := "ignore", r["arg"] := "", r["name"] := ""
		return r
	}

	static Parse(line) {
		r := Rules.New()
		seen := false
		loop parse line, ";" {
			p := InStr(A_LoopField, "=")
			if !p
				continue
			k := Trim(SubStr(A_LoopField, 1, p - 1)), v := Rules.Unescape(SubStr(A_LoopField, p + 1))
			switch StrLower(k) {
				case "on": r["on"] := v ? 1 : 0, seen := true
				case "kinds":
					r["kinds"] := []
					loop parse v, ","
						if ClipType.IsKind(Trim(A_LoopField))
							r["kinds"].Push(Trim(A_LoopField))
				case "regex": r["regex"] := v
				case "app": r["app"] := Trim(v)
				case "class": r["class"] := Trim(v)
				case "name": r["name"] := Trim(v)
				case "action":
					q := InStr(v, ":")
					r["action"] := StrLower(q ? SubStr(v, 1, q - 1) : v), r["arg"] := q ? SubStr(v, q + 1) : ""
			}
		}
		if !seen || !Rules.HasCondition(r) || !Rules.IsAction(r["action"])
			return ""
		return r
	}

	static Serialize(r) {
		kinds := ""
		for i, k in r["kinds"]
			kinds .= (i > 1 ? "," : "") k
		s := "on=" (r["on"] ? 1 : 0) ";kinds=" Rules.Escape(kinds) ";regex=" Rules.Escape(r["regex"]) ";app=" Rules.Escape(r["app"])
			. ";action=" Rules.Escape(r["action"]) (r["arg"] != "" ? ":" Rules.Escape(r["arg"]) : "") ";name=" Rules.Escape(r["name"])
		if (r["class"] != "")
			s .= ";class=" Rules.Escape(r["class"])
		return s
	}

	; ';' separates the fields of a stored line, so a value that contains one is percent-escaped ('%' first, so
	; unescaping in the reverse order cannot turn a literal "%3B" into a separator)
	static Escape(v) => StrReplace(StrReplace(v, "%", "%25"), ";", "%3B")
	static Unescape(v) => StrReplace(StrReplace(v, "%3B", ";"), "%25", "%")

	static HasCondition(r) => r["kinds"].Length || r["regex"] != "" || r["app"] != "" || r["class"] != ""

	static IsAction(a) {
		for x in Rules.Actions
			if (x = a)
				return true
		return false
	}

	; "" when valid, otherwise a TXT message
	static Validate(r) {
		if !Rules.HasCondition(r)
			return ClipType_T("RUL_noCondition")
		if (r["regex"] != "") {
			try RegExMatch("", r["regex"])
			catch
				return ClipType_T("RUL_badRegex")
		}
		if (r["action"] = "channel" && (!IsInteger(r["arg"]) || r["arg"] < 0))
			return ClipType_T("RUL_badChannel")
		return ""
	}

	static Match(r, kind, text, app, cls := "") {
		if !r["on"]
			return false
		if r["kinds"].Length {
			ok := false
			for k in r["kinds"]
				if (k = kind)
					ok := true
			if !ok
				return false
		}
		if (r["regex"] != "") {
			try {
				if !RegExMatch(text, r["regex"])
					return false
			} catch
				return false
		}
		if (r["app"] != "" && !Rules.InList(r["app"], app))
			return false
		if (r["class"] != "" && !Rules.InList(r["class"], cls))
			return false
		return true
	}

	static InList(list, value) {
		loop parse list, ","
			if (Trim(A_LoopField) != "" && Trim(A_LoopField) = value)
				return true
		return false
	}

	static Evaluate(list, kind, text, app, cls := "") {
		for r in list
			if Rules.Match(r, kind, text, app, cls)
				return r
		return ""
	}

	static Describe(r) {
		global TXT
		when := ""
		for i, k in r["kinds"]
			when .= (i > 1 ? ", " : "") ClipType.Label(k)
		if (r["regex"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_matching") " " r["regex"]
		if (r["app"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_from") " " r["app"]
		if (r["class"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_inClass") " " r["class"]
		switch r["action"] {
			case "channel": then := ClipType_T("RUL_act_channel") " " r["arg"] (Rules.ChannelName(r["arg"]) != "" ? " · " Rules.ChannelName(r["arg"]) : "")
			case "ignore": then := ClipType_T("RUL_act_ignore")
			case "transform": then := ClipType_T("RUL_act_transform") " " r["arg"]
			default: then := ClipType_T("RUL_act_tag") " " r["arg"]
		}
		return [when, then]
	}

	static ChannelName(n) {
		global CONFIGURATION_FILE
		if !IsInteger(n)
			return ""
		v := IniRead(CONFIGURATION_FILE, "Channels", n, "")
		return v != "" ? v : (n = 0 ? "Default" : "")
	}

	static Load() {
		global CONFIGURATION_FILE
		Rules.List := []
		sec := IniRead(CONFIGURATION_FILE, "Rules", , "")
		if (sec = "")
			return
		loop parse sec, "`n", "`r" {
			p := InStr(A_LoopField, "=")
			if !p
				continue
			r := Rules.Parse(SubStr(A_LoopField, p + 1))
			if (r = "")
				continue
			if (Rules.Validate(r) != "")
				r["on"] := 0
			Rules.List.Push(r)
		}
	}

	static Save(list) {
		global CONFIGURATION_FILE
		try IniDelete(CONFIGURATION_FILE, "Rules")
		for i, r in list
			IniWrite(Rules.Serialize(r), CONFIGURATION_FILE, "Rules", i)
		Rules.List := list
	}
}
