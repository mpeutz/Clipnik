; RuleDialog.ahk - the rule editor used by the Settings Rules page.
;   RuleDialog.Open(owner, rule) -> edited rule Map, or "" when cancelled

class RuleDialog {
	static g := "", c := Map(), done := false, result := ""

	static Open(owner, rule) {
		global TXT, PLUGINS, CN
		if RuleDialog.g
			return ""
		RuleDialog.done := false, RuleDialog.result := ""
		g := Gui("+ToolWindow -MaximizeBox +Owner" owner.Hwnd, TXT.RUL_title)
		hwnd := g.Hwnd
		RuleDialog.g := g, c := RuleDialog.c := Map()
		owner.Opt("+Disabled")
		g.MarginX := 20, g.MarginY := 14
		Theme.ApplyToGui(g)
		w := 460, x := 20, y := 14
		Theme.Section(g, x, y, w - 40, TXT.RUL_when), y += 30
		col := 0
		for k in ClipType.Kinds {
			on := false
			for rk in rule["kinds"]
				if (rk = k)
					on := true
			c["k_" k] := Theme.Add(g, "CheckBox", "x" (x + col * 140) " y" y " w130 h24 " (on ? "Checked" : ""), ClipType.Label(k))
			col++
			if (col = 3)
				col := 0, y += 26
		}
		if col
			y += 26
		y += 6
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_regex)
		c["regex"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["regex"])
		y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_app)
		c["app"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w150 h24 -E0x200 +Border", rule["app"])
		Theme.Add(g, "Button", "x" (x + 318) " y" y " w102 h24", TXT.RUL_pick).OnEvent("Click", RuleDialog_Pick)
		y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_class)
		c["class"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["class"])
		y += 36
		Theme.Section(g, x, y, w - 40, TXT.RUL_then), y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_action)
		acts := [TXT.RUL_act_channel, TXT.RUL_act_ignore, TXT.RUL_act_transform, TXT.RUL_act_tag]
		sel := 2
		for i, a in Rules.Actions
			if (a = rule["action"])
				sel := i
		c["action"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" sel, acts)
		c["action"].OnEvent("Change", RuleDialog_ActionChanged)
		y += 30
		c["argLabel"] := g.Add("Text", "x" x " y" y " w150 h24 +0x200", "")
		chans := []
		loop CN.Total {
			n := A_Index - 1
			chans.Push(n " · " (Rules.ChannelName(n) != "" ? Rules.ChannelName(n) : n))
		}
		c["channel"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" (IsInteger(rule["arg"]) && rule["arg"] + 1 <= chans.Length ? rule["arg"] + 1 : 1), chans)
		fmts := [], fsel := 1
		for k, v in PLUGINS.pformat {
			fmts.Push(v["name"])
			if (v["name"] = rule["arg"])
				fsel := fmts.Length
		}
		c["transform"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" fsel, fmts)
		c["tag"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["action"] = "tag" ? rule["arg"] : "")
		y += 36
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_name)
		c["name"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["name"])
		y += 40
		c["err"] := g.Add("Text", "x" x " y" y " w260 h24 +0x200 c" Theme.Hex("danger"), "")
		Theme.Add(g, "Button", "x" (w - 20 - 76 - 8 - 76) " y" y " w76 h28 Default", "OK").OnEvent("Click", RuleDialog_Ok)
		Theme.Add(g, "Button", "x" (w - 20 - 76) " y" y " w76 h28", TXT.SET_cancel).OnEvent("Click", RuleDialog_Cancel)
		g.OnEvent("Close", RuleDialog_Cancel), g.OnEvent("Escape", RuleDialog_Cancel)
		RuleDialog_ActionChanged()
		g.Show("w" w " h" (y + 44))
		while !RuleDialog.done && WinExist("ahk_id " hwnd)
			Sleep 30
		try owner.Opt("-Disabled")
		try g.Destroy()
		RuleDialog.g := ""
		return RuleDialog.result
	}

	static Collect() {
		c := RuleDialog.c
		r := Rules.New()
		for k in ClipType.Kinds
			if c["k_" k].Value
				r["kinds"].Push(k)
		r["regex"] := c["regex"].Value, r["app"] := Trim(c["app"].Value), r["class"] := Trim(c["class"].Value), r["name"] := Trim(c["name"].Value)
		r["action"] := Rules.Actions[c["action"].Value]
		switch r["action"] {
			case "channel": r["arg"] := c["channel"].Value - 1
			case "transform": r["arg"] := c["transform"].Text
			case "tag": r["arg"] := Trim(c["tag"].Value)
			default: r["arg"] := ""
		}
		return r
	}
}

RuleDialog_ActionChanged(*) {
	global TXT
	c := RuleDialog.c
	a := Rules.Actions[c["action"].Value]
	c["channel"].Visible := (a = "channel"), c["transform"].Visible := (a = "transform"), c["tag"].Visible := (a = "tag")
	c["argLabel"].Text := a = "channel" ? TXT.RUL_channel : a = "transform" ? TXT.RUL_transform : a = "tag" ? TXT.RUL_tag : ""
}

RuleDialog_Pick(*) {
	if IgnoredWindowsWin.pickActive
		return
	r := IgnoredWindowsWin.Pick()
	if (r["exe"] != "")
		RuleDialog.c["app"].Value := r["exe"]
	try WinActivate(RuleDialog.g.Hwnd)
}

RuleDialog_Ok(*) {
	r := RuleDialog.Collect()
	msg := Rules.Validate(r)
	if (msg != "") {
		RuleDialog.c["err"].Text := msg
		return
	}
	RuleDialog.result := r, RuleDialog.done := true
}

RuleDialog_Cancel(*) {
	RuleDialog.done := true
}
