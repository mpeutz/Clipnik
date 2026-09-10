; TrayMenuWin.ahk - the tray menu as a popup card in the Windows 11 Explorer style: an icon row with the everyday
; actions, a header with the active channel, then text items with submenus that open beside the card.
;
;   TrayCard.Init()          hooks the tray icon ([Main] TrayMenu=card); the standard A_TrayMenu stays as fallback
;   TrayCard.Open(x, y)      opens the card at a screen point (default: the cursor)
;   TrayCard.Close()
;
; Cards are rebuilt on every open (channel list and toggle states change). Rows are opaque Text controls that
; never overlap (see SettingsWin for why). Windows created with -DPIScale; sizes are multiplied by Theme.Scale.

class TrayCard {
	static cards := []            ; [main, sub]
	static isOpen := false
	static hover := ""            ; {card, row}
	static hoverSince := 0
	static sel := ""              ; keyboard selection {card, row}
	static W := 280, IconTile := 50, RowH := 32, Pad := 6
	static hooked := false

	static Init() {
		global ini_trayMenu
		if (TrayCard.hooked || ini_trayMenu != "card")
			return
		TrayCard.hooked := true
		OnMessage(0x404, TrayMenu_OnNotify)
		OnMessage(0x06, TrayMenu_OnActivate)
		HotIf(TrayMenu_IsOpen)
		for k in ["Up", "Down", "Left", "Right", "Enter", "Space", "Escape", "Home", "End"]
			Hotkey(k, TrayMenu_OnKey, "On")
		HotIf()
	}

	; ---------- menu content ----------

	static MainSpec() {
		global TXT, PROGNAME, VERSION, CN, NOINCOGNITO, CLIPJUMP_STATUS
		icons := [
			{glyph: "history", label: TXT.TRY_iHistory, fn: history},
			{glyph: "layout-grid", label: TXT.TRY_iChannels, fn: channelOrganizer},
			{glyph: "settings", label: TXT.TRY_iSettings, fn: settings},
			{glyph: "eye-off", label: TXT.TRY_iIncognito, fn: incognito, on: !NOINCOGNITO},
			{glyph: "ban", label: TXT.TRY_iDisable, fn: disable_clipjump, on: !CLIPJUMP_STATUS}]
		items := [
			{label: TXT.TRY_channels, sub: "channels"},
			{label: TXT.TRY_tools, sub: "tools"},
			{label: TXT.TRY_options, sub: "options"},
			{label: TXT.TRY_help, sub: "help"},
			{sep: true},
			{label: TXT.TRY_reloadcustom, fn: reloadCustom},
			{label: TXT.TRY_restart, fn: reloadClipjump},
			{label: TXT.TRY_exit, fn: exitClipjump}]
		return {icons: icons, header: {title: PROGNAME " " VERSION, sub: TXT.TRY_channelIs " " CN.Name, fn: main}, items: items}
	}

	static SubSpec(name) {
		global TXT, CN, NOINCOGNITO, CLIPJUMP_STATUS, PROGNAME, chOrg_K, actionmode_k, pluginManager_k, history_k
		items := []
		switch name {
			case "channels":
				loop CN.Total {
					n := A_Index - 1
					nm := ini_read("Channels", n)
					items.Push({label: n "   " (nm != "" ? nm : (n ? n : "Default")), check: (n = CN.NG), fn: TrayMenu_UseChannel.Bind(n)})
				}
				items.Push({sep: true}, {label: TXT.SET_org "…", key: Hparse_Rev(chOrg_K), fn: channelOrganizer})
			case "tools":
				items.Push({label: TXT.SET_actmd, key: Hparse_Rev(actionmode_k), fn: actionmode_run}
					, {label: TXT.HST__name, key: Hparse_Rev(history_k), fn: history}
					, {label: TXT.PLG__name, key: Hparse_Rev(pluginManager_k), fn: pluginManagerGui}
					, {label: TXT.IGN__name, fn: classTool}
					, {label: TXT.PLG_delFileFolder, fn: tray_deleteFileFolder})
			case "options":
				items.Push({label: StrReplace(TXT.TRY_incognito, "&"), check: !NOINCOGNITO, fn: incognito}
					, {label: StrReplace(TXT.TRY_disable, "&") " " PROGNAME, check: !CLIPJUMP_STATUS, fn: disable_clipjump}
					, {label: TXT.TRY_startup, check: FileExist(A_Startup "\Clipjump.lnk") ? true : false, fn: strtup})
			case "help":
				items.Push({label: TXT.TRY_pstmdshorts, fn: openShortcutsHelp}, {label: "FAQ", fn: openFaq}, {label: "Clipjump.chm", fn: hlp})
		}
		return {items: items}
	}

	; ---------- open / close ----------

	static Open(x := "", y := "") {
		if TrayCard.isOpen
			TrayCard.Close()
		if (x = "") {
			CoordMode("Mouse", "Screen")
			MouseGetPos(&x, &y)
		}
		card := TrayCard.BuildCard(TrayCard.MainSpec(), 0)
		TrayCard.cards := [card]
		TrayCard.isOpen := true
		TrayCard.hover := "", TrayCard.sel := ""
		Theme.WorkAreaAt(x, y, &l, &t, &r, &b)
		px := x - card.w, py := y - card.h
		if (px < l)
			px := Min(x, r - card.w)
		if (py < t)
			py := Min(y, b - card.h)
		card.x := px, card.y := py
		TrayCard.shownAt := A_TickCount
		Theme.ShowPopup(card.g, px, py, card.w, card.h, true)
		SetTimer(TrayMenu_Poll, 40)
	}

	static Close() {
		if !TrayCard.isOpen
			return
		TrayCard.isOpen := false
		SetTimer(TrayMenu_Poll, 0)
		cards := TrayCard.cards
		TrayCard.cards := []              ; handlers that run while the windows go away see an empty list
		TrayCard.hover := "", TrayCard.sel := ""
		for c in cards
			try c.g.Destroy()
	}

	static Run(fn) {
		TrayCard.Close()
		SetTimer(fn, -10)
	}

	; ---------- building ----------

	; spec: {icons?, header?, items}; returns {g, rows, w, h, x, y, level}
	static BuildCard(spec, level, width := 0) {
		global GHICON_PATH
		s := Theme.Scale
		if !width
			width := TrayCard.W
		g := Gui("-Caption +ToolWindow +AlwaysOnTop -DPIScale +Owner" A_ScriptHwnd, "Clipjump_TrayMenu")
		g.MarginX := 0, g.MarginY := 0
		g.BackColor := Theme.Hex("surface")
		Theme.ApplyToHwnd(g.Hwnd, 2, true)
		card := {g: g, rows: [], w: Round(width * s), h: 0, x: 0, y: 0, level: level, ctl: Map()}
		pad := Round(TrayCard.Pad * s)
		y := pad
		surface := Theme.Hex("surface"), text := Theme.Hex("text"), muted := Theme.Hex("muted"), accent := Theme.Hex("accent")
		hasGlyphs := Theme.HasIcons()
		g.SetFont("s10 norm c" text, Theme.FontName)
		if spec.HasProp("icons") {
			n := spec.icons.Length, tile := Round(TrayCard.IconTile * s)
			gap := (card.w - 2 * pad - n * tile) / (n - 1)
			for i, ic in spec.icons {
				x := Round(pad + (i - 1) * (tile + gap))
				color := ic.HasProp("on") && ic.on ? accent : text
				g.SetFont("s12 c" color, hasGlyphs ? Theme.IconFont : Theme.FontName)
				glyph := g.Add("Text", "x" x " y" y " w" tile " h" Round(30 * s) " +0x200 +0x100 +Center Background" surface, hasGlyphs ? Theme.Icon(ic.glyph) : "")
				g.SetFont("s8 c" (ic.HasProp("on") && ic.on ? accent : muted), Theme.FontName)
				label := g.Add("Text", "x" x " y" (y + Round(30 * s)) " w" tile " h" Round(16 * s) " +0x200 +0x100 +Center Background" surface, ic.label)
				g.SetFont("s10 norm c" text, Theme.FontName)
				row := {kind: "icon", ctls: [glyph, label], fn: ic.fn, y: y, h: tile, x: x, w: tile}
				TrayCard.Register(card, row)
				if (i < n)      ; gap tiles keep the surface opaque between icons
					g.Add("Text", "x" (x + tile) " y" y " w" Round(gap) + 1 " h" tile " Background" surface, "")
			}
			y += tile + Round(4 * s)
		}
		if spec.HasProp("header") {
			g.Add("Progress", "x" pad " y" y " w" (card.w - 2 * pad) " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
			y += 1 + Round(4 * s)
			g.SetFont("s10 bold c" text, Theme.FontName)
			tw := TrayCard.TextWidth(g, spec.header.title) + Round(16 * s)
			t1 := g.Add("Text", "x" pad " y" y " w" tw " h" Round(TrayCard.RowH * s) " +0x200 +0x100 Background" surface, "  " spec.header.title)
			g.SetFont("s9 norm c" muted, Theme.FontName)
			t2 := g.Add("Text", "x" (pad + tw) " y" y " w" (card.w - 2 * pad - tw) " h" Round(TrayCard.RowH * s) " +0x200 +0x100 Background" surface, spec.header.sub)
			g.SetFont("s10 norm c" text, Theme.FontName)
			row := {kind: "item", ctls: [t1, t2], fn: spec.header.fn, y: y, h: Round(TrayCard.RowH * s), x: pad, w: card.w - 2 * pad}
			TrayCard.Register(card, row)
			y += Round(TrayCard.RowH * s)
		}
		for it in spec.items {
			if it.HasProp("sep") {
				g.Add("Text", "x" pad " y" y " w" (card.w - 2 * pad) " h" Round(6 * s) " Background" surface, "")
				g.Add("Progress", "x" (pad + Round(4 * s)) " y" (y + Round(3 * s)) " w" (card.w - 2 * pad - Round(8 * s)) " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
				y += Round(6 * s)
				continue
			}
			rh := Round(TrayCard.RowH * s)
			right := it.HasProp("key") && it.key != "" ? it.key : (it.HasProp("sub") ? (hasGlyphs ? Theme.Icon("chevron-right") : ">") : "")
			rw := 0
			if (right != "") {   ; measure the shortcut or chevron so long shortcuts never clip
				isGlyph := it.HasProp("sub") && hasGlyphs
				g.SetFont("s8 c" muted, isGlyph ? Theme.IconFont : Theme.FontName)
				meter := g.Add("Text", "x0 y0 +Hidden", right)
				meter.GetPos(, , &tw)
				Theme.Discard(meter)
				rw := tw + Round(12 * s)
				g.SetFont("s10 norm c" text, Theme.FontName)
			}
			lead := it.HasProp("check") ? (it.check ? (hasGlyphs ? Theme.Icon("check") : "✓") : "") : ""
			ctls := []
			if it.HasProp("check") {
				g.SetFont("s9 c" accent, hasGlyphs ? Theme.IconFont : Theme.FontName)
				ctls.Push(g.Add("Text", "x" pad " y" y " w" Round(26 * s) " h" rh " +0x200 +0x100 +Center Background" surface, lead))
				g.SetFont("s10 norm c" text, Theme.FontName)
				lx := pad + Round(26 * s)
			} else
				lx := pad
			ctls.Push(g.Add("Text", "x" lx " y" y " w" (card.w - pad - lx - rw) " h" rh " +0x200 +0x100 Background" surface, (it.HasProp("check") ? "" : "  ") StrReplace(it.label, "&")))
			if rw {
				g.SetFont("s8 c" muted, isGlyph ? Theme.IconFont : Theme.FontName)
				ctls.Push(g.Add("Text", "x" (card.w - pad - rw) " y" y " w" (rw - Round(8 * s)) " h" rh " +0x200 +0x100 +Right Background" surface, right))
				g.Add("Text", "x" (card.w - pad - Round(8 * s)) " y" y " w" Round(8 * s) " h" rh " Background" surface, "")
				g.SetFont("s10 norm c" text, Theme.FontName)
			}
			row := {kind: "item", ctls: ctls, fn: it.HasProp("fn") ? it.fn : "", sub: it.HasProp("sub") ? it.sub : "", y: y, h: rh, x: pad, w: card.w - 2 * pad}
			TrayCard.Register(card, row)
			y += rh
		}
		card.h := y + pad
		return card
	}

	static Register(card, row) {
		card.rows.Push(row)
		idx := card.rows.Length
		for c in row.ctls {
			card.ctl[c.Hwnd] := idx
			c.OnEvent("Click", TrayMenu_OnClick.Bind(card, idx))
		}
	}

	static TextWidth(g, text) {
		t := g.Add("Text", "x0 y0", text)
		t.GetPos(, , &w)
		t.Visible := false
		t.Move(-1000, -1000)
		return w
	}

	; ---------- hover, keyboard ----------

	static SetHover(card, idx) {
		h := TrayCard.hover
		if (h && h.card == card && h.row = idx)
			return
		if h && !(h.card.level = 0 && TrayCard.cards.Length > 1 && TrayCard.cards[2].parentRow = h.row && card.level = 1)
			TrayCard.Paint(h.card, h.row, false)
		TrayCard.hover := idx ? {card: card, row: idx} : ""
		TrayCard.hoverSince := A_TickCount
		if idx {
			TrayCard.Paint(card, idx, true)
			TrayCard.sel := {card: card, row: idx}
		}
		; hovering a main row that is not the open submenu's parent closes the submenu
		if (idx && card.level = 0 && TrayCard.cards.Length > 1 && TrayCard.cards[2].parentRow != idx)
			TrayCard.CloseSub()
	}

	static Paint(card, idx, on) {
		if (idx < 1 || idx > card.rows.Length || !TrayCard.Alive(card))
			return
		bg := Theme.Hex(on ? "surfaceAlt" : "surface")
		for c in card.rows[idx].ctls {
			try c.Opt("Background" bg)
			try c.Redraw()
		}
	}

	static OpenSub(name, parentIdx) {
		TrayCard.CloseSub()
		mainCard := TrayCard.cards[1]
		card := TrayCard.BuildCard(TrayCard.SubSpec(name), 1, 240)
		card.parentRow := parentIdx
		row := mainCard.rows[parentIdx]
		Theme.WorkAreaAt(mainCard.x, mainCard.y, &l, &t, &r, &b)
		px := mainCard.x + mainCard.w - Round(4 * Theme.Scale)
		if (px + card.w > r)
			px := mainCard.x - card.w + Round(4 * Theme.Scale)
		py := mainCard.y + row.y - Round(TrayCard.Pad * Theme.Scale)
		if (py + card.h > b)
			py := b - card.h
		card.x := px, card.y := py
		TrayCard.cards.Push(card)
		Theme.ShowPopup(card.g, px, py, card.w, card.h)
	}

	static CloseSub() {
		if (TrayCard.cards.Length < 2)
			return
		sub := TrayCard.cards.Pop()
		if (TrayCard.hover && TrayCard.hover.card == sub)
			TrayCard.hover := ""
		if (TrayCard.sel && TrayCard.sel.card == sub)
			TrayCard.sel := ""
		try sub.g.Destroy()
		if TrayCard.cards.Length
			TrayCard.Paint(TrayCard.cards[1], sub.parentRow, false)
	}

	static Activate(card, idx) {
		row := card.rows[idx]
		if (row.HasProp("sub") && row.sub) {
			TrayCard.OpenSub(row.sub, idx)
			sub := TrayCard.cards[2]
			TrayCard.SetHover(sub, 1)
			return
		}
		if row.fn
			TrayCard.Run(row.fn)
	}

	; false once the card's window has been destroyed
	static Alive(card) {
		try return card.g.Hwnd ? true : false
		catch
			return false
	}

	static IsOurs(hwnd) {
		for c in TrayCard.cards {
			try {
				if (c.g.Hwnd = hwnd)
					return c
			}
		}
		return ""
	}

	static lastMx := -1, lastMy := -1
	static shownAt := 0

	static Poll() {
		CoordMode("Mouse", "Screen")
		MouseGetPos(&mx, &my, &win, &ctl, 2)
		moved := (mx != TrayCard.lastMx || my != TrayCard.lastMy)
		TrayCard.lastMx := mx, TrayCard.lastMy := my
		if !moved {     ; keyboard selection stays until the mouse moves again, like a system menu
			if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
				if !TrayCard.IsOurs(win)
					TrayCard.Close()
			return
		}
		card := TrayCard.IsOurs(win)
		if !card {
			if TrayCard.hover
				TrayCard.SetHover(TrayCard.cards[1], 0)
			if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")   ; a click outside always closes, even without a WM_ACTIVATE
				TrayCard.Close()
			return
		}
		idx := (ctl && card.ctl.Has(ctl)) ? card.ctl[ctl] : 0
		TrayCard.SetHover(card, idx)
		h := TrayCard.hover
		if (h && card.level = 0 && idx && card.rows[idx].HasProp("sub") && card.rows[idx].sub && A_TickCount - TrayCard.hoverSince > 220 && (TrayCard.cards.Length < 2 || TrayCard.cards[2].parentRow != idx))
			TrayCard.OpenSub(card.rows[idx].sub, idx)
	}

	static Key(k) {
		if !TrayCard.cards.Length
			return
		if (TrayCard.sel && !TrayCard.Alive(TrayCard.sel.card))
			TrayCard.sel := ""
		card := TrayCard.sel ? TrayCard.sel.card : TrayCard.cards[TrayCard.cards.Length]
		idx := TrayCard.sel ? TrayCard.sel.row : 0
		rows := card.rows
		switch k {
			case "Escape":
				if (card.level = 1) {
					pr := card.parentRow
					TrayCard.CloseSub()
					TrayCard.SetHover(TrayCard.cards[1], pr)
				} else
					TrayCard.Close()
			case "Down", "Up":
				; Up and Down walk the text rows; Up from the first text row reaches the icon row, Down from an icon leaves it
				step := k = "Down" ? 1 : -1
				firstItem := 1
				while (firstItem <= rows.Length && rows[firstItem].kind = "icon")
					firstItem++
				if (idx && rows[idx].kind = "icon") {
					i := k = "Down" ? firstItem : idx
				} else if (k = "Up" && (idx = firstItem) && firstItem > 1) {
					i := firstItem - 1
				} else {
					i := idx ? idx + step : (k = "Down" ? firstItem : rows.Length)
					if (i > rows.Length)
						i := firstItem
					if (i < firstItem)
						i := rows.Length
				}
				TrayCard.SetHover(card, i)
			case "Home": TrayCard.SetHover(card, 1)
			case "End": TrayCard.SetHover(card, rows.Length)
			case "Left":
				if (idx && rows[idx].kind = "icon")
					TrayCard.SetHover(card, idx > 1 ? idx - 1 : idx)
				else if (card.level = 1) {
					pr := card.parentRow
					TrayCard.CloseSub()
					TrayCard.SetHover(TrayCard.cards[1], pr)
				}
			case "Right":
				if (idx && rows[idx].kind = "icon")
					TrayCard.SetHover(card, rows[idx + 1].kind = "icon" ? idx + 1 : idx)
				else if (idx && rows[idx].HasProp("sub") && rows[idx].sub)
					TrayCard.Activate(card, idx)
			case "Enter", "Space":
				if idx
					TrayCard.Activate(card, idx)
		}
	}
}

TrayMenu_IsOpen(*) {
	return TrayCard.isOpen
}

TrayMenu_OnKey(key) {
	k := RegExReplace(key, "^[~*$!^+#<>]*")
	TrayCard.Key(k)
}

TrayMenu_Poll() {
	if TrayCard.isOpen
		TrayCard.Poll()
}

TrayMenu_OnClick(card, idx, *) {
	if TrayCard.isOpen
		TrayCard.Activate(card, idx)
}

TrayMenu_UseChannel(n, *) {
	changeChannel(n)
}

; AHK_NOTIFYICON: right-click opens the card, double-click opens About; returning 0 suppresses the standard menu
TrayMenu_OnNotify(wParam, lParam, msg, hwnd) {
	if (lParam = 0x205) {          ; WM_RBUTTONUP
		TrayCard.Open()
		return 0
	}
	if (lParam = 0x203) {          ; WM_LBUTTONDBLCLK
		SetTimer(main, -10)
		return 0
	}
	if (lParam = 0x204 || lParam = 0x206)   ; WM_RBUTTONDOWN / DBLCLK: swallow so the default menu never shows
		return 0
}

; WM_ACTIVATE: the card closes when focus goes to a window that is not one of ours
TrayMenu_OnActivate(wParam, lParam, msg, hwnd) {
	if (!TrayCard.isOpen || (wParam & 0xFFFF) != 0)
		return
	if !TrayCard.IsOurs(hwnd)
		return
	if TrayCard.IsOurs(lParam)
		return
	SetTimer(TrayMenu_CloseLater, -1)
}

TrayMenu_CloseLater() {
	if !TrayCard.isOpen
		return
	; Windows may bounce the activation right after Show (no foreground permission); the card still works from the
	; keyboard and the poll, so only a later focus loss closes it
	if (A_TickCount - TrayCard.shownAt < 500) {
		try WinActivate(TrayCard.cards[1].g.Hwnd)
		return
	}
	CoordMode("Mouse", "Screen")
	MouseGetPos(, , &win)
	if TrayCard.IsOurs(win)     ; clicking inside a card deactivates the other card; the click handler takes over
		return
	TrayCard.Close()
}

; plain entry points for the customizer / public API
TrayMenu_Open(*) {
	TrayCard.Open()
}
