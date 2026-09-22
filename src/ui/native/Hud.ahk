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
;               matchIndex, matchCount, message, keys, items, mono, title
; modes: normal | cancel | delete | cut | copy | deleteall | search | help | pasting | message | menu | confirm
;
; Look: a rounded, shadowed, slightly translucent card (Theme.Popup). Header: channel pill, count, format and
; paste-format pills, pinned flag. Body: preview panel, thumbnail, or a list of key rows. Footer: tags and key
; chips. Everything is a native control (fast redraws); pills and chips are Buttons painted by Theme.

class Hud {
	static g := ""
	static c := Map()
	static rows := []             ; lazily created key rows for help / menu: [{chip, text}]
	static State := ""
	static anchorX := "", anchorY := ""
	static visible := false
	static MaxWidth := 480, MinWidth := 320, MaxLines := 8, MaxImage := 300, MaxChips := 6
	static lineH := 0, monoLineH := 0
	static lastImage := ""
	static pressed := ""

	static Init() {
		if Hud.g
			return
		g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 -DPIScale +Owner" A_ScriptHwnd, "Clipnik_HUD")
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
			Theme.Discard(ctl)
		for r in Hud.rows
			Theme.Discard(r.chip), Theme.Discard(r.text)
		Hud.c := Map(), Hud.rows := []
		g.BackColor := Theme.Hex("surface")
		Theme.Popup(g)
		c := Hud.c
		text := Theme.Hex("text"), muted := Theme.Hex("muted"), accent := Theme.Hex("accent"), alt := Theme.Hex("surfaceAlt"), surface := Theme.Hex("surface")
		font := Theme.FontName, icons := Theme.HasIcons()
		; header
		g.SetFont("s9 bold c" Theme.Hex("accentText"), font)
		c["lock"] := Theme.AddPill(g, "x0 y0 w10 h10", "", "warn", "accentText")
		c["channel"] := Theme.AddPill(g, "x0 y0 w10 h10", "", "accent", "accentText")
		g.SetFont("s12 bold c" text, font)
		c["countN"] := g.Add("Text", "x0 y0 +0x200", "")
		g.SetFont("s9 norm c" muted, font)
		c["countT"] := g.Add("Text", "x0 y0 +0x200", "")
		g.SetFont("s8 norm c" text, font)
		c["format"] := Theme.AddPill(g, "x0 y0 w10 h10", "", "surfaceAlt", "text")
		c["pformat"] := Theme.AddPill(g, "x0 y0 w10 h10", "", "surfaceAlt", "text")
		g.SetFont("s9 norm c" accent, icons ? Theme.IconFont : font)
		c["pinGlyph"] := g.Add("Text", "x0 y0 +0x200 +Center", icons ? Theme.Icon("pin") : "")
		g.SetFont("s9 norm c" accent, font)
		c["pinText"] := g.Add("Text", "x0 y0 +0x200", TXT.HUD_pinned)
		; search row
		g.SetFont("s9 norm c" muted, icons ? Theme.IconFont : font)
		c["sGlyph"] := g.Add("Text", "x0 y0 +0x200 +Center Background" alt, icons ? Theme.Icon("search") : "")
		g.SetFont("s10 norm c" text, font)
		c["sTerm"] := g.Add("Text", "x0 y0 +0x200 Background" alt, "")
		g.SetFont("s9 norm c" muted, font)
		c["sMatch"] := g.Add("Text", "x0 y0 +0x200 +Right Background" alt, "")
		c["sLine"] := g.Add("Progress", "x0 y0 w10 h1 -Theme Background" accent " c" accent, 100)
		; body
		g.SetFont("s10 norm c" text, font)
		c["preview"] := g.Add("Edit", "x0 y0 w100 h20 +ReadOnly -VScroll -HScroll -E0x200 +Multi -TabStop Background" alt, "")
		c["pic"] := g.Add("Picture", "x0 y0 w10 h10", "")
		g.SetFont("s9 norm c" text, "Consolas")
		c["mono"] := g.Add("Edit", "x0 y0 w100 h20 +ReadOnly -VScroll -HScroll -E0x200 +Multi -TabStop Background" alt, "")
		; message / confirm / list headers: glyph + bold text + right note
		g.SetFont("s12 norm c" accent, icons ? Theme.IconFont : font)
		c["hdGlyph"] := g.Add("Text", "x0 y0 +0x200 +Center", "")
		g.SetFont("s10 bold c" text, font)
		c["hdText"] := g.Add("Edit", "x0 y0 w100 h20 +ReadOnly -VScroll -HScroll -E0x200 +Multi -TabStop Background" surface, "")
		g.SetFont("s9 norm c" muted, font)
		c["hdRight"] := g.Add("Text", "x0 y0 +0x200 +Right", "")
		c["modeText"] := g.Add("Text", "x0 y0 +0x200", "")
		; footer: tags and key chips
		g.SetFont("s9 norm c" muted, icons ? Theme.IconFont : font)
		c["tagGlyph"] := g.Add("Text", "x0 y0 +0x200 +Center", icons ? Theme.Icon("tag") : "#")
		g.SetFont("s9 norm c" muted, font)
		c["tagText"] := g.Add("Text", "x0 y0 +0x200", "")
		loop Hud.MaxChips {
			g.SetFont("s8 bold c" text, font)
			c["k" A_Index] := Theme.AddPill(g, "x0 y0 w10 h10", "", "surfaceAlt", "text")
			g.SetFont("s9 norm c" muted, font)
			c["l" A_Index] := g.Add("Text", "x0 y0 +0x200", "")
		}
		for name, ctl in c
			ctl.Visible := false
		Hud.lineH := Hud.TextHeight(c["preview"])
		Hud.monoLineH := Hud.TextHeight(c["mono"])
		Hud.lastImage := ""
		if Hud.visible && IsObject(Hud.State)
			Hud.Render(Hud.State)
	}

	; key rows for help and menu, created on first use
	static Row(i) {
		while (Hud.rows.Length < i) {
			g := Hud.g
			g.SetFont("s8 bold c" Theme.Hex("text"), Theme.FontName)
			chip := Theme.AddPill(g, "x0 y0 w10 h10", "", "surfaceAlt", "text")
			g.SetFont("s9 norm c" Theme.Hex("text"), Theme.FontName)
			t := g.Add("Text", "x0 y0 +0x200", "")
			chip.Visible := false, t.Visible := false
			Hud.rows.Push({chip: chip, text: t})
		}
		return Hud.rows[i]
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
		s.tags := "", s.fixed := 0, s.text := "", s.imagePath := "", s.dim := "", s.searchTerm := "", s.matchIndex := "", s.matchCount := ""
		s.message := "", s.keys := "", s.items := "", s.mono := "", s.searchActive := 0, s.title := "", s.kind := "", s.swatch := ""
		s.locked := 0
		return s
	}

	static FromPasteVars() {
		global CN, realclipno, CURSAVE, curPformat, fixStatus, halfClip, temp_clipboard, THUMBS_dir, TEMPSAVE, realActive, SPM, ctrlRef, VAULT, TXT, LOCK
		s := Hud.NewState()
		s.locked := LOCK.ACTIVE ? 1 : 0
		s.channel := CN.Name, s.index := realclipno, s.total := CURSAVE
		s.pformat := curPformat, s.fixed := (fixStatus != "")
		t := clipPref(CN.NG, realActive, "Tags")
		s.tags := (t != "") ? t : ""
		if (temp_clipboard = "") {
			s.format := "IMAGE"
			s.imagePath := A_WorkingDir "\" THUMBS_dir "\" TEMPSAVE ".jpg"
			s.dim := clipPref(CN.NG, realActive, "Dim")
		} else {
			f := GetClipboardFormat()
			s.format := InStr(f, TXT.TIP_file_folder) ? "FILE" : "TEXT"
			s.text := halfClip
			if (s.format = "TEXT") {
				s.kind := ClipType.Of(CN.NG, realActive)
				if (s.kind = "color")
					s.swatch := ClipType.ColorRgb(temp_clipboard)
			}
		}
		; a vault entry has no channel, no clip number, no tags and no fixed flag: it has a name and a place
		; in the user's order, so the card shows those in the same slots
		if VAULT.ACTIVE {
			s.channel := TXT.VLT__name, s.index := VAULT.i, s.total := VAULT.ids.Length, s.fixed := false
			e := vaultGet(VAULT.ids[VAULT.i])
			s.tags := (e && e["name"] != "") ? e["name"] : ""
			if (e && e["type"] = 1) {
				s.format := "IMAGE"
				s.imagePath := A_WorkingDir "\" e["fileid"]
				s.dim := (e["width"] && e["height"]) ? e["width"] "x" e["height"] : ""
			} else if e
				s.kind := e["kind"]
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

	; "key|label;key|label" strings from the language file
	static Chips(spec) {
		out := []
		loop parse spec, ";"
			if InStr(A_LoopField, "|")
				out.Push([Trim(SubStr(A_LoopField, 1, InStr(A_LoopField, "|") - 1)), Trim(SubStr(A_LoopField, InStr(A_LoopField, "|") + 1))])
		return out
	}

	static ModeInfo(mode) {
		switch mode {
			case "cancel": return {title: TXT.TIP_cancelm, glyph: "x", fill: "surfaceAlt", color: "text"}
			case "delete": return {title: TXT.TIP_delm, glyph: "trash-2", fill: "danger", color: "accentText"}
			case "cut": return {title: TXT.TIP_move, glyph: "scissors", fill: "warn", color: "accentText"}
			case "copy": return {title: TXT.TIP_copy, glyph: "copy", fill: "accent", color: "accentText"}
			case "deleteall": return {title: TXT.TIP_delallm, glyph: "trash-2", fill: "danger", color: "accentText"}
		}
		return ""
	}

	; ---------- rendering ----------
	static Render(state) {
		Hud.Init()
		Hud.State := state
		g := Hud.g, c := Hud.c, sc := Theme.Scale
		pad := Round(14 * sc), gap := Round(8 * sc), rowGap := Round(8 * sc)
		Hud.AnchorPoint(&ax, &ay)
		Theme.WorkAreaAt(ax, ay, &wl, &wt, &wr, &wb)
		W := Round(Min(Hud.MaxWidth * sc, (wr - wl) * 0.45))
		W := Max(W, Round(Hud.MinWidth * sc))
		for name, ctl in c
			ctl.Visible := false
		for r in Hud.rows
			r.chip.Visible := false, r.text.Visible := false
		mode := state.mode
		y := pad
		if (mode = "menu" || mode = "help")
			W := (mode = "help") ? Round(600 * sc) : Round(320 * sc)
		else if (mode = "message" || mode = "confirm")
			W := Round(380 * sc)
		bodyW := W - 2 * pad
		info := Hud.ModeInfo(mode)

		if (state.channel != "" && mode != "message" && mode != "menu" && mode != "confirm") {
			x := pad, rowH := Round(22 * sc)
			if (state.locked && !info)
				Hud.Pill("lock", TXT.HUD_locked, x, y, rowH), x += c["lock"].w + gap
			if info {
				Theme.SetPill(c["channel"], info.fill, info.color)
				Hud.Pill("channel", info.title, x, y, rowH), x += c["channel"].w + gap
			} else {
				Theme.SetPill(c["channel"], "accent", "accentText")
				Hud.Pill("channel", state.channel, x, y, rowH), x += c["channel"].w + gap
			}
			if (state.total != "") {
				Hud.Place("countN", "" state.index, x, y, , rowH), x += c["countN"].w
				Hud.Place("countT", " / " state.total, x, y, , rowH), x += c["countT"].w + gap
			}
			if (state.format != "") {
				label := (state.kind != "" && state.kind != "text") ? ClipType.Label(state.kind) : state.format
				sw := (state.kind = "color" && state.swatch != "" && state.swatch != -1) ? state.swatch : ""
				Theme.SetPill(c["format"], "surfaceAlt", "text", sw)
				Hud.Pill("format", label, x, y, rowH, sw != "" ? Hud.TextWidth(c["format"], label) + Round(34 * sc) : ""), x += c["format"].w + gap
			}
			if (state.pformat != "")
				Hud.Pill("pformat", state.pformat, x, y, rowH), x += c["pformat"].w + gap
			if (state.fixed && !info) {
				pw := Hud.TextWidth(c["pinText"], TXT.HUD_pinned) + Round(2 * sc), gw := Round(16 * sc)
				if (x + gw + pw <= W - pad) {
					Hud.Place("pinText", TXT.HUD_pinned, W - pad - pw, y, pw, rowH)
					Hud.Place("pinGlyph", c["pinGlyph"].Text, W - pad - pw - gw, y, gw, rowH)
				}
			}
			y += rowH + rowGap
		}

		if state.searchActive || (mode = "search") {
			rowH := Round(28 * sc), gw := Round(26 * sc)
			matchTxt := (state.matchCount != "") ? state.matchIndex " / " state.matchCount : ""
			mw := matchTxt != "" ? Hud.TextWidth(c["sMatch"], matchTxt) + Round(12 * sc) : Round(8 * sc)
			Hud.Place("sGlyph", c["sGlyph"].Text, pad, y, gw, rowH)
			Hud.Place("sTerm", state.searchTerm "▏", pad + gw, y, bodyW - gw - mw, rowH)
			Hud.Place("sMatch", matchTxt, pad + bodyW - mw, y, mw, rowH)
			c["sLine"].Move(pad, y + rowH, bodyW, 1), c["sLine"].Visible := true
			y += rowH + 1 + rowGap
		}

		if (mode = "message") {
			y := Hud.Headline(state.message, pad, y, bodyW, "loader", "accent", "")
		}
		else if (mode = "confirm") {
			y := Hud.Headline(state.mono, pad, y, bodyW, "trash-2", "danger", "")
		}
		else if (mode = "help" || mode = "menu") {
			y := Hud.Headline(mode = "help" ? TXT.HUD_helpTitle : (state.title != "" ? state.title : TXT.ACT__name), pad, y, bodyW, mode = "help" ? "circle-help" : "zap", "accent", mode = "help" ? TXT.HUD_helpClose : TXT.HUD_menuClose)
			y := Hud.KeyRows(mode = "help" ? Hud.HelpItems() : state.items, pad, y, bodyW, mode = "help" ? 2 : 1)
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
		else if (state.text != "" || mode = "normal" || info) {
			Hud.MultiLine("preview", state.text, pad, y, bodyW, Hud.lineH, Hud.MaxLines)
			y += c["preview"].h + rowGap
		}

		if info {
			Hud.Place("modeText", StrSplit(TXT.TIP_modem, "`n")[1], pad, y, bodyW, Round(18 * sc))
			y += Round(18 * sc) + Round(4 * sc)
		}

		; footer: tags on the left, key chips on the right
		chips := []
		if (mode = "confirm")
			chips := Hud.KeysAsChips(state.keys)
		else if state.searchActive
			chips := Hud.Chips(TXT.HUD_keys_search)
		else if info
			chips := Hud.Chips(TXT.HUD_keys_mode)
		else if (mode = "normal")
			chips := Hud.Chips(state.locked ? (VAULT.ACTIVE ? TXT.HUD_keys_vaultlock : TXT.HUD_keys_lock)
				: (VAULT.ACTIVE ? TXT.HUD_keys_vault : TXT.HUD_keys_normal))
		tags := (mode = "normal" || info) && state.tags != "" ? StrReplace(Trim(state.tags), " ", " · ") : ""
		dim := (mode = "normal" || info) ? state.dim : ""
		if (chips.Length || tags != "" || dim != "") {
			y += Round(2 * sc)
			y := Hud.Footer(chips, tags, dim, pad, y, bodyW)
		}
		H := y + pad
		Hud.Show(W, H, ax, ay, wl, wt, wr, wb)
	}

	; glyph + bold text (+ muted note at the right); returns the next y
	static Headline(text, x, y, w, glyph, color, right) {
		c := Hud.c, sc := Theme.Scale
		gw := Theme.HasIcons() ? Round(24 * sc) : 0
		if gw {
			c["hdGlyph"].SetFont("c" Theme.Hex(color)), c["hdGlyph"].Redraw()
			Hud.Place("hdGlyph", Theme.Icon(glyph), x, y, gw, Round(22 * sc))
		}
		rw := right != "" ? Hud.TextWidth(c["hdRight"], right) + Round(4 * sc) : 0
		if rw
			Hud.Place("hdRight", right, x + w - rw, y, rw, Round(22 * sc))
		Hud.MultiLine("hdText", StrReplace(RTrim(text, "`r`n"), "`r`n", "`n"), x + gw + (gw ? Round(4 * sc) : 0), y + Round(2 * sc), w - gw - rw - Round(8 * sc), Hud.lineH, 6)
		return y + Max(Round(22 * sc), c["hdText"].h + Round(2 * sc)) + Round(8 * sc)
	}

	; items: Array of {key, caption}; cols 1 or 2; returns the next y
	static KeyRows(items, x, y, w, cols) {
		sc := Theme.Scale, rowH := Round(26 * sc), colW := (w - (cols - 1) * Round(18 * sc)) // cols
		n := 0
		for it in items {
			n++
			r := Hud.Row(n)
			col := Mod(n - 1, cols), rowI := (n - 1) // cols
			cx := x + col * (colW + Round(18 * sc)), cy := y + rowI * rowH
			kw := Max(Round(22 * sc), Hud.TextWidth(r.chip, it.key) + Round(12 * sc))
			r.chip.Text := it.key, r.chip.Move(cx, cy + Round(3 * sc), kw, rowH - Round(6 * sc)), r.chip.w := kw, r.chip.Visible := true
			dim := it.HasProp("dim") && it.dim, chk := it.HasProp("check") && it.check
			r.text.Opt("c" Theme.Hex(dim ? "muted" : "text"))
			r.text.Text := (chk ? Chr(0x2713) " " : "") it.caption
			Theme.SetPill(r.chip, chk ? "accent" : "surfaceAlt", chk ? "accentText" : (dim ? "muted" : "text"))
			r.text.Move(cx + kw + Round(8 * sc), cy, colW - kw - Round(8 * sc), rowH), r.text.Visible := true
		}
		rowsN := (n + cols - 1) // cols
		return y + rowsN * rowH + Round(4 * sc)
	}

	static HelpItems() {
		static items := ""
		if IsObject(items)
			return items
		items := []
		loop parse TXT.TIP_help, "`n", "`r" {
			line := Trim(A_LoopField)
			if (line = "" || !InStr(line, " - "))
				continue
			p := InStr(line, " - ")
			items.Push({key: Trim(SubStr(line, 1, p)), caption: Trim(SubStr(line, p + 3))})
		}
		return items
	}

	static KeysAsChips(keys) {
		out := []
		loop parse keys, A_Space
			if (A_LoopField != "")
				out.Push([A_LoopField, ""])
		return out
	}

	static Footer(chips, tags, dim, x, y, w) {
		c := Hud.c, sc := Theme.Scale, rowH := Round(20 * sc), gap := Round(4 * sc), gapBetween := Round(10 * sc)
		; chips right-aligned
		total := 0, widths := []
		for i, ch in chips {
			if (i > Hud.MaxChips)
				break
			kw := Hud.TextWidth(c["k" i], ch[1]) + Round(12 * sc)
			lw := ch[2] != "" ? Hud.TextWidth(c["l" i], ch[2]) + Round(2 * sc) : 0
			widths.Push([kw, lw])
			total += kw + (lw ? gap + lw : 0) + (i > 1 ? gapBetween : 0)
		}
		cx := x + w - total
		for i, wd in widths {
			ch := chips[i]
			Hud.Pill("k" i, ch[1], cx, y + Round(2 * sc), rowH - Round(4 * sc), wd[1]), cx += wd[1]
			if wd[2]
				Hud.Place("l" i, ch[2], cx + gap, y, wd[2], rowH), cx += gap + wd[2]
			cx += gapBetween
		}
		label := dim != "" ? (tags != "" ? dim " · " tags : dim) : tags
		if (label != "") {
			; the glyph is a tag icon: skip it when there is no tag to show (dim-only footer)
			gw := tags != "" ? Round(16 * sc) : 0, tw := x + w - total - Round(12 * sc) - x - gw
			if (tw > 30 * sc) {
				if (tags != "")
					Hud.Place("tagGlyph", c["tagGlyph"].Text, x, y, gw, rowH)
				Hud.Place("tagText", label, x + gw + Round(2 * sc), y, tw, rowH)
			}
		}
		return y + rowH
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

	static Pill(name, text, x, y, h, w := "") {
		ctl := Hud.c[name]
		if (w = "")
			w := Hud.TextWidth(ctl, text) + Round(18 * Theme.Scale)
		ctl.Text := text
		ctl.Move(x, y, w, h)
		ctl.w := w, ctl.h := h
		ctl.Visible := true
		ctl.Redraw()
	}

	; Edits paint from the top of their box, so the panel gets an explicit formatting rectangle (EM_SETRECT)
	; that leaves the same inset above and below the text.
	static MultiLine(name, text, x, y, w, lineH, maxLines) {
		ctl := Hud.c[name]
		panel := (name = "preview" || name = "mono")
		insetX := panel ? Round(10 * Theme.Scale) : 0, insetY := panel ? Round(7 * Theme.Scale) : Round(2 * Theme.Scale)
		ctl.Move(x, y, w, lineH)
		Hud.SetTextRect(ctl, insetX, insetY, w - insetX, insetY + lineH * maxLines)
		ctl.Value := text
		lines := SendMessage(0xBA, 0, 0, ctl.Hwnd)   ; EM_GETLINECOUNT
		lines := Max(1, Min(lines, maxLines))
		h := lines * lineH + 2 * insetY
		ctl.Move(x, y, w, h)
		Hud.SetTextRect(ctl, insetX, insetY, w - insetX, insetY + lines * lineH)
		ctl.w := w, ctl.h := h
		ctl.Visible := true
	}

	static SetTextRect(ctl, l, t, r, b) {
		rc := Buffer(16, 0)
		NumPut("Int", l, "Int", t, "Int", r, "Int", b, rc)
		SendMessage(0xB3, 0, rc.Ptr, ctl.Hwnd)   ; EM_SETRECT
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
		ctl.Move(x + (maxW - dw) // 2, y, dw, dh)
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
		Theme.ShowPopup(Hud.g, x, y, W, H)
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
		s.mode := "confirm", s.mono := text, s.keys := keys
		return Hud.WaitKey(s, keys)
	}

	; items: Array of {key, caption}; keys: space-separated hotkeys to accept
	static Menu(items, keys, title := "") {
		s := Hud.NewState()
		s.mode := "menu", s.items := items, s.title := title, s.keys := ""
		return Hud.WaitKey(s, keys)
	}

	; Blocks until a key is pressed. If another card replaces this one meanwhile (e.g. a new paste starts), the
	; prompt is treated as cancelled and returns "" so the waiting routine can finish.
	static WaitKey(state, keys) {
		Hud.pressed := ""
		Hud.Render(state)
		check := Hud.KeyPressed.Bind(Hud)
		loop parse keys, A_Space
			if (A_LoopField != "")
				Hud.BindKey(A_LoopField, check, "On T2")
		while (Hud.pressed = "" && Hud.State == state && Hud.visible)
			Sleep 20
		loop parse keys, A_Space
			if (A_LoopField != "")
				Hud.BindKey(A_LoopField, check, "Off T1")   ; T1 again: T2 would outlive the card on shared keys
		Hud.Hide()
		return Hud.pressed
	}

	; Hotkey() directly (not hkZ): the card's keys need T2, so a second press of the key whose own thread is
	; blocked here - Z re-pressed to close the format menu - is still delivered. Falls back to vk names like hkZ.
	static BindKey(key, fn, opt) {
		try {
			Hotkey(key, fn, opt)
			return
		}
		t := ""
		loop parse key
			t .= IsAlpha(A_LoopField) ? "vk" GetVKList(A_LoopField)[1] : A_LoopField
		try
			Hotkey(t, fn, opt)
		catch
			MsgBox("It looks like the hotkey " t " doesn't exist ? `nRefer to troubleshooting page in help file.", "Clipnik Warning", 16)
	}

	static KeyPressed(ThisHotkey := "", *) {
		Hud.pressed := ThisHotkey
	}
}
