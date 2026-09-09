; Hud.ahk - the paste-mode card. Replaces the v1 ToolTip HUD, the imgprv picture window, TT_Console menus and the
; TooltipEx help screen with one themed, never-activating window that is created once and re-rendered in place.
;
;   Hud.Init()                       create the hidden window (call once at startup, after Theme.Init)
;   Hud.Render(state)                state: CJMap with the fields below; shows or updates the card
;   Hud.FromPasteVars()              builds the state from the paste engine globals
;   Hud.SetMode(mode)                re-render the current state in another mode
;   Hud.Message(text, ms := 0)       standalone message card (ms > 0 hides it automatically)
;   Hud.Confirm(text, keys) -> key   blocks until one of the space-separated keys is pressed
;   Hud.Menu(items, keys) -> key     items: Array of {key, caption}; blocks like Confirm
;   Hud.Hide(), Hud.Anchor(x, y), Hud.GetPos(&x, &y, &w, &h)
;
; state fields: channel, index, total, format, pformat, tags, fixed, mode, text, imagePath, searchTerm,
;               matchIndex, matchCount, message, keys, items, mono
; modes: normal | cancel | delete | cut | copy | deleteall | search | help | pasting | message | menu | confirm

class Hud {
	static g := ""
	static c := Map()
	static State := ""
	static anchorX := "", anchorY := ""
	static visible := false
	static MaxWidth := 480, MinWidth := 300, MaxLines := 8, MaxImage := 300
	static lineH := 0, monoLineH := 0
	static lastImage := ""
	static pressed := ""

	static Init() {
		if Hud.g
			return
		g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 -DPIScale +Owner" A_ScriptHwnd, "Clipjump_HUD")
		g.MarginX := 0, g.MarginY := 0
		Hud.g := g
		Hud.Restyle()
		g.OnEvent("Close", (*) => 0)
		Theme.OnChange(Hud.Restyle.Bind(Hud))
	}

	; (re)creates the controls with the current palette
	static Restyle() {
		g := Hud.g
		for name, ctl in Hud.c
			try ctl.Visible := false
		Hud.c := Map()
		g.BackColor := Theme.Hex("surface")
		Theme.ApplyToHwnd(g.Hwnd, 3, true)
		text := Theme.Hex("text"), muted := Theme.Hex("muted"), accent := Theme.Hex("accent"), alt := Theme.Hex("surfaceAlt")
		g.SetFont("s10 bold c" text, Theme.FontName)
		Hud.c["channel"] := g.Add("Text", "x0 y0 +0x200", "")
		g.SetFont("s10 norm c" muted, Theme.FontName)
		Hud.c["count"] := g.Add("Text", "x0 y0 +0x200", "")
		g.SetFont("s8 norm c" text, Theme.FontName)
		Hud.c["format"] := g.Add("Text", "x0 y0 +0x200 +Center Background" alt, "")
		g.SetFont("s8 norm c" Theme.Hex("accentText"), Theme.FontName)
		Hud.c["pformat"] := g.Add("Text", "x0 y0 +0x200 +Center Background" accent, "")
		Hud.c["fixed"] := g.Add("Text", "x0 y0 +0x200 +Center Background" accent, "")
		g.SetFont("s9 norm c" muted, Theme.FontName)
		Hud.c["tags"] := g.Add("Text", "x0 y0 +0x200", "")
		g.SetFont("s10 norm c" text, Theme.FontName)
		Hud.c["search"] := g.Add("Text", "x0 y0 +0x200 Background" alt, "")
		g.SetFont("s9 norm c" muted, Theme.FontName)
		Hud.c["match"] := g.Add("Text", "x0 y0 +0x200 +Right", "")
		g.SetFont("s10 norm c" text, Theme.FontName)
		Hud.c["preview"] := g.Add("Edit", "x0 y0 w100 h20 +ReadOnly -VScroll -HScroll -E0x200 +Multi -TabStop Background" Theme.Hex("surface"), "")
		Hud.c["pic"] := g.Add("Picture", "x0 y0 w10 h10", "")
		g.SetFont("s9 norm c" text, "Consolas")
		Hud.c["mono"] := g.Add("Edit", "x0 y0 w100 h20 +ReadOnly -VScroll -HScroll -E0x200 +Multi -TabStop Background" Theme.Hex("surface"), "")
		g.SetFont("s9 norm c" muted, Theme.FontName)
		Hud.c["hint"] := g.Add("Text", "x0 y0 +0x200", "")
		Hud.c["rule"] := g.Add("Progress", "x0 y0 w10 h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
		for name, ctl in Hud.c
			ctl.Visible := false
		Hud.lineH := Hud.TextHeight(Hud.c["preview"])
		Hud.monoLineH := Hud.TextHeight(Hud.c["mono"])
		Hud.lastImage := ""
		if Hud.visible && IsObject(Hud.State)
			Hud.Render(Hud.State)
	}

	; ---------- measuring ----------
	static TextWidth(ctl, text) {
		hFont := SendMessage(0x31, 0, 0, ctl.Hwnd)
		hdc := DllCall("GetDC", "Ptr", ctl.Hwnd, "Ptr")
		old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
		sz := Buffer(8, 0)
		DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz)
		DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
		DllCall("ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
		return NumGet(sz, 0, "Int")
	}

	static TextHeight(ctl) {
		hFont := SendMessage(0x31, 0, 0, ctl.Hwnd)
		hdc := DllCall("GetDC", "Ptr", ctl.Hwnd, "Ptr")
		old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
		tm := Buffer(60, 0)
		DllCall("GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
		DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
		DllCall("ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
		return NumGet(tm, 0, "Int") + NumGet(tm, 32, "Int")   ; tmHeight + tmExternalLeading
	}

	; ---------- state ----------
	static NewState() {
		s := CJMap()
		s.mode := "normal", s.channel := "", s.index := "", s.total := "", s.format := "", s.pformat := ""
		s.tags := "", s.fixed := 0, s.text := "", s.imagePath := "", s.searchTerm := "", s.matchIndex := "", s.matchCount := ""
		s.message := "", s.keys := "", s.items := "", s.mono := "", s.searchActive := 0
		return s
	}

	static FromPasteVars() {
		global CN, realclipno, CURSAVE, curPformat, fixStatus, halfClip, temp_clipboard, THUMBS_dir, TEMPSAVE, realActive, SPM, ctrlRef
		s := Hud.NewState()
		s.channel := CN.Name, s.index := realclipno, s.total := CURSAVE
		s.pformat := curPformat, s.fixed := (fixStatus != "")
		t := clipPref(CN.NG, realActive, "Tags")
		s.tags := (t != "") ? t : ""
		if (temp_clipboard = "") {
			s.format := "IMAGE"
			s.imagePath := A_WorkingDir "\" THUMBS_dir "\" TEMPSAVE ".jpg"
		} else {
			f := GetClipboardFormat()
			s.format := InStr(f, TXT.TIP_file_folder) ? "FILE" : "TEXT"
			s.text := halfClip
		}
		mode := "normal"
		if (ctrlRef = "cancel" || ctrlRef = "delete" || ctrlRef = "cut" || ctrlRef = "copy" || ctrlRef = "deleteAll")
			mode := StrLower(ctrlRef)
		s.mode := mode
		if SPM.ACTIVE {
			s.searchActive := 1
			s.searchTerm := SPM.term, s.matchIndex := SPM.matchIndex, s.matchCount := SPM.matchCount
		}
		return s
	}

	static SetMode(mode) {
		if !IsObject(Hud.State)
			Hud.State := Hud.NewState()
		Hud.State.mode := mode
		Hud.Render(Hud.State)
	}

	static Hints() {
		static h := ""
		if IsObject(h)
			return h
		h := Map()
		h["normal"] := TXT.HUD_hint_normal
		h["search"] := TXT.HUD_hint_search
		h["cancel"] := StrSplit(TXT.TIP_modem, "`n")[1] "  ·  " TXT.HUD_hint_nextmode
		h["delete"] := h["cancel"], h["cut"] := h["cancel"], h["copy"] := h["cancel"], h["deleteall"] := h["cancel"]
		h["help"] := TXT.HUD_hint_help
		h["pasting"] := "", h["message"] := "", h["menu"] := "", h["confirm"] := ""
		return h
	}

	static ModeTitle(mode) {
		switch mode {
			case "cancel": return TXT.TIP_cancelm "  (1)"
			case "delete": return TXT.TIP_delm "  (2)"
			case "cut": return TXT.TIP_move "  (3)"
			case "copy": return TXT.TIP_copy "  (4)"
			case "deleteall": return TXT.TIP_delallm "  (5)"
		}
		return ""
	}

	; ---------- rendering ----------
	static Render(state) {
		Hud.Init()
		Hud.State := state
		g := Hud.g, c := Hud.c, sc := Theme.Scale
		pad := Round(12 * sc), gap := Round(6 * sc), rowGap := Round(8 * sc)
		Hud.AnchorPoint(&ax, &ay)
		Theme.WorkAreaAt(ax, ay, &wl, &wt, &wr, &wb)
		W := Round(Min(Hud.MaxWidth * sc, (wr - wl) * 0.45))
		W := Max(W, Round(Hud.MinWidth * sc))
		bodyW := W - 2 * pad
		for name, ctl in c
			ctl.Visible := false
		y := pad
		mode := state.mode
		showHeader := (state.channel != "") && (mode != "message" && mode != "menu" && mode != "confirm")

		if showHeader {
			x := pad, rowH := Round(20 * sc)
			Hud.Place("channel", "{" state.channel "}", x, y, , rowH), x += c["channel"].w + gap
			if (state.total != "")
				Hud.Place("count", state.index " / " state.total, x, y, , rowH), x += c["count"].w + gap * 2
			if (state.format != "")
				Hud.Badge("format", state.format, x, y, rowH), x += c["format"].w + gap
			if (state.pformat != "")
				Hud.Badge("pformat", state.pformat, x, y, rowH), x += c["pformat"].w + gap
			if state.fixed
				Hud.Badge("fixed", Trim(TXT.TIP_fixed, "[] "), x, y, rowH), x += c["fixed"].w + gap
			if (state.tags != "") {
				tw := W - pad - x
				if (tw > 30 * sc)
					Hud.Place("tags", "#" StrReplace(Trim(state.tags), " ", " #"), x, y, tw, rowH)
			}
			y += rowH + rowGap
		}

		if state.searchActive || (mode = "search") {
			rowH := Round(26 * sc)
			matchTxt := (state.matchCount != "") ? state.matchIndex " / " state.matchCount : ""
			mw := matchTxt != "" ? Hud.TextWidth(c["match"], matchTxt) + gap : 0
			Hud.Place("search", "  " state.searchTerm "▏", pad, y, bodyW - mw, rowH)
			if (matchTxt != "")
				Hud.Place("match", matchTxt, pad + bodyW - mw + gap, y, mw - gap, rowH)
			y += rowH + rowGap
		}

		title := Hud.ModeTitle(mode)
		if (title != "") {
			Hud.MultiLine("preview", title, pad, y, bodyW, Hud.lineH, 2)
			y += c["preview"].h + rowGap
		}
		else if (mode = "message") {
			Hud.MultiLine("preview", StrReplace(RTrim(state.message, "`r`n"), "`r`n", "`n"), pad, y, bodyW, Hud.lineH, 6)
			y += c["preview"].h + rowGap
		}
		else if (mode = "help" || mode = "menu" || mode = "confirm") {
			body := (mode = "help") ? TXT.SET_shortcuts "`n" TXT.TIP_help : state.mono
			body := StrReplace(RTrim(body, "`r`n"), "`r`n", "`n")
			Hud.MultiLine("mono", body, pad, y, bodyW, Hud.monoLineH, 40)
			y += c["mono"].h + rowGap
		}
		else if (state.imagePath != "") {
			if FileExist(state.imagePath) {
				Hud.Image(state.imagePath, pad, y, bodyW, Round(Hud.MaxImage * sc), &ih)
				y += ih + rowGap
			} else {
				Hud.MultiLine("preview", TXT.TIP_error, pad, y, bodyW, Hud.lineH, 2)
				y += c["preview"].h + rowGap
			}
		}
		else if (state.text != "" || mode = "normal") {
			Hud.MultiLine("preview", state.text, pad, y, bodyW, Hud.lineH, Hud.MaxLines)
			y += c["preview"].h + rowGap
		}

		hint := ""
		if (mode = "confirm" || mode = "menu")
			hint := state.keys
		else if state.searchActive
			hint := Hud.Hints()["search"]
		else
			hint := Hud.Hints().Has(mode) ? Hud.Hints()[mode] : ""
		if (hint != "") {
			c["rule"].Move(pad, y, bodyW, 1), c["rule"].Visible := true
			y += Round(6 * sc)
			Hud.Place("hint", hint, pad, y, bodyW, Round(18 * sc))
			y += c["hint"].h
		}
		H := y + pad
		Hud.Show(W, H, ax, ay, wl, wt, wr, wb)
	}

	static Place(name, text, x, y, w := "", h := "") {
		ctl := Hud.c[name]
		if (w = "")
			w := Hud.TextWidth(ctl, text) + Round(2 * Theme.Scale)
		ctl.Text := text
		ctl.Move(x, y, w, h)
		ctl.w := w, ctl.h := h
		ctl.Visible := true
	}

	static Badge(name, text, x, y, h) {
		ctl := Hud.c[name]
		w := Hud.TextWidth(ctl, text) + Round(14 * Theme.Scale)
		Hud.Place(name, text, x, y, w, h)
	}

	static MultiLine(name, text, x, y, w, lineH, maxLines) {
		ctl := Hud.c[name]
		ctl.Move(x, y, w, lineH)
		ctl.Value := text
		lines := SendMessage(0xBA, 0, 0, ctl.Hwnd)   ; EM_GETLINECOUNT
		lines := Max(1, Min(lines, maxLines))
		h := lines * lineH + Round(4 * Theme.Scale)
		ctl.Move(x, y, w, h)
		ctl.w := w, ctl.h := h
		ctl.Visible := true
	}

	static Image(path, x, y, maxW, maxH, &h) {
		ctl := Hud.c["pic"]
		w := 0, h := 0
		try Gdip_getLengths(path, &w, &h)
		if (w < 1 || h < 1)
			w := 100, h := 60
		scale := Min(1, maxW / w, maxH / h)
		dw := Max(1, Round(w * scale)), dh := Max(1, Round(h * scale))
		if (Hud.lastImage != path "|" dw "|" dh) {
			try ctl.Value := "*w" dw " *h" dh " " path
			Hud.lastImage := path "|" dw "|" dh
		}
		ctl.Move(x, y, dw, dh)
		ctl.Visible := true
		h := dh
	}

	; where the card's top-left corner wants to be, before clamping
	static AnchorPoint(&x, &y) {
		global ini_pstMode_X, ini_pstMode_Y
		if (ini_pstMode_X != "" && ini_pstMode_X && ini_pstMode_Y != "" && ini_pstMode_Y) {
			x := ini_pstMode_X, y := ini_pstMode_Y
			return
		}
		if (Hud.anchorX != "" && Hud.anchorY != "") {
			x := Hud.anchorX, y := Hud.anchorY
			return
		}
		MouseGetPos(&mx, &my)
		x := mx + Round(12 * Theme.Scale), y := my + Round(16 * Theme.Scale)
	}

	static Show(W, H, ax, ay, wl, wt, wr, wb) {
		x := Min(ax, wr - W - 8), y := Min(ay, wb - H - 8)
		x := Max(wl, x), y := Max(wt, y)
		Hud.g.Show("NoActivate x" x " y" y " w" W " h" H)
		Hud.visible := true
	}

	static Hide() {
		if Hud.g && Hud.visible {
			Hud.g.Hide()
			Hud.visible := false
		}
	}

	static Anchor(x, y) {
		Hud.anchorX := x, Hud.anchorY := y
	}

	static ClearAnchor() {
		Hud.anchorX := "", Hud.anchorY := ""
	}

	static GetPos(&x, &y, &w, &h) {
		x := y := w := h := 0
		if Hud.g && Hud.visible
			try WinGetPos(&x, &y, &w, &h, "ahk_id " Hud.g.Hwnd)
	}

	; ---------- transient cards ----------
	static Message(text, ms := 0) {
		s := IsObject(Hud.State) ? Hud.State : Hud.NewState()
		s.mode := "message", s.message := text
		Hud.Render(s)
		if (ms > 0)
			SetTimer(Hud.HideLater, -ms)
	}

	static HideLater(*) {
		Hud.Hide()
	}

	; Blocks until one of the space-separated keys is pressed; returns the key name.
	static Confirm(text, keys) {
		s := Hud.NewState()
		s.mode := "confirm", s.mono := text, s.keys := Hud.KeyHint(keys)
		return Hud.WaitKey(s, keys)
	}

	; items: Array of {key, caption}; keys: space-separated hotkeys to accept
	static Menu(items, keys, title := "") {
		s := Hud.NewState()
		s.mode := "menu"
		body := title != "" ? title "`n`n" : ""
		for it in items
			body .= fillWithSpaces(it.caption, 28) " -  " it.key "`n"
		s.mono := RTrim(body, "`n"), s.keys := ""
		return Hud.WaitKey(s, keys)
	}

	static KeyHint(keys) {
		out := ""
		loop parse keys, A_Space
			if (A_LoopField != "")
				out .= (out = "" ? "" : "   ") A_LoopField
		return out
	}

	; Blocks until a key is pressed. If another card replaces this one meanwhile (e.g. a new paste starts), the
	; prompt is treated as cancelled and returns "" so the waiting routine can finish.
	static WaitKey(state, keys) {
		Hud.pressed := ""
		Hud.Render(state)
		check := Hud.KeyPressed.Bind(Hud)
		loop parse keys, A_Space
			if (A_LoopField != "")
				hkZ(A_LoopField, check, 1)
		while (Hud.pressed = "" && Hud.State == state)
			Sleep 20
		loop parse keys, A_Space
			if (A_LoopField != "")
				hkZ(A_LoopField, check, 0)
		Hud.Hide()
		return Hud.pressed
	}

	static KeyPressed(ThisHotkey := "", *) {
		Hud.pressed := ThisHotkey
	}
}
