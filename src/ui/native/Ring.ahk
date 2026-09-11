; Ring.ahk - the action ring: a round, per-pixel-alpha popup at the pointer that replaces the list menus
; (the paste-mode format menu and Action Mode).
;
;   Ring.Pick(items, opts) -> the picked item's key, or "" when cancelled (blocking, like Hud.Menu)
;   Ring.RenderToFile(state, path)   paints one ring onto an opaque background (tests)
;
; Painted with GDI+ into a 32-bit DIB and shown with UpdateLayeredWindow, so wedges are true arcs with
; antialiased edges and the shadow is part of the bitmap. Hit testing is RingGeom arithmetic on the pointer.

class Ring {
	static token := 0, fontSet := ""
	static g := "", visible := false, isOpen := false, pages := [], page := 1, hover := -1
	static cx := 0, cy := 0, sx := 0, sy := 0, held := false, openedAt := 0, pressZone := ""
	static result := "", done := false, opts := "", prevAlpha := ""

	static Pick(items, opts := "") {
		if Ring.isOpen
			return ""
		o := IsObject(opts) ? opts : {}
		Ring.opts := o, Ring.pages := RingGeom.Pages(items), Ring.page := 1, Ring.hover := -1
		Ring.result := "", Ring.done := false, Ring.pressZone := ""
		Ring.Window()
		MouseGetPos(&mx, &my)
		Theme.WorkAreaAt(mx, my, &l, &t, &r, &b)
		s := RingGeom.Sizes(Theme.Scale)
		c := RingGeom.Clamp(mx, my, s.r1 + s.shadow + 2, l, t, r, b)
		Ring.cx := c[1], Ring.cy := c[2], Ring.sx := mx, Ring.sy := my
		Ring.held := o.HasProp("trigger") && o.trigger != "" && GetKeyState(o.trigger)
		Ring.openedAt := A_TickCount
		if o.HasProp("dim") && o.dim {
			Ring.prevAlpha := ""
			try Ring.prevAlpha := WinGetTransparent("ahk_id " o.dim)
			try WinSetTransparent(128, "ahk_id " o.dim)
		}
		Ring.isOpen := true
		Ring.BindKeys(true)
		Ring.Draw()
		SetTimer(Ring_Tick, 16)
		while !Ring.done {
			Sleep 15
			if o.HasProp("until") && o.until.Call()
				Ring.Close("")
		}
		SetTimer(Ring_Tick, 0)
		Ring.BindKeys(false)
		DllCall("ShowWindow", "Ptr", Ring.g.Hwnd, "Int", 0)
		Ring.visible := false
		if o.HasProp("dim") && o.dim
			try WinSetTransparent(Ring.prevAlpha = "" ? "Off" : Ring.prevAlpha, "ahk_id " o.dim)
		Ring.isOpen := false
		return Ring.result
	}

	; one reusable layered, never-activated window; UpdateLayeredWindow sizes and places it
	static Window() {
		if Ring.g
			return
		Ring.g := Gui("-Caption +E0x80000 +E0x08000000 +AlwaysOnTop +ToolWindow -DPIScale +Owner" A_ScriptHwnd, "Clipjump_Ring")
	}

	static Draw() {
		global TXT
		items := Ring.pages[Ring.page], o := Ring.opts
		h := Ring.hover >= 0 ? items[Ring.hover + 1] : ""
		if IsObject(h) {
			isNav := h.HasProp("nav")
			title := isNav ? Ring.NavLabel(h.nav) : h.label
			sub := isNav ? (h.nav = "more" ? TXT.RNG_moreDesc : TXT.RNG_backDesc) : (h.HasProp("desc") ? h.desc : "")
			st := Ring.State(items, Ring.hover, title, sub, false)
		} else {
			sub := o.HasProp("idleSub") ? o.idleSub : ""
			if (Ring.pages.Length > 1)
				sub := sub (sub != "" ? "  ·  " : "") Ring.page "/" Ring.pages.Length
			st := Ring.State(items, -1, o.HasProp("idleTitle") ? o.idleTitle : "", sub, true)
		}
		Ring.Present(st)
	}

	static Present(st) {
		D := Ring.Side(st.s)
		Ring.Start()
		hbm := CreateDIBSection(D, D), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
		G := Gdip_GraphicsFromHDC(hdc)
		Ring.Paint(G, st, D / 2, D / 2)
		UpdateLayeredWindow(Ring.g.Hwnd, hdc, Round(Ring.cx - D / 2), Round(Ring.cy - D / 2), D, D)
		Gdip_DeleteGraphics(G), SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
		if !Ring.visible {
			DllCall("ShowWindow", "Ptr", Ring.g.Hwnd, "Int", 4)   ; SW_SHOWNOACTIVATE
			Ring.visible := true
		}
	}

	static Choose(idx) {
		it := Ring.pages[Ring.page][idx + 1]
		if it.HasProp("nav") {
			Ring.page := it.nav = "more" ? Ring.page + 1 : 1
			Ring.hover := -1, Ring.Draw()
			return
		}
		Ring.Close(it.key)
	}

	static Close(result) {
		Ring.result := result, Ring.done := true
	}

	static BindKeys(on) {
		o := Ring.opts, pre := o.HasProp("prefix") ? o.prefix : ""
		opt := on ? "On T2" : "Off T1"
		for page in Ring.pages
			for it in page
				if (!it.HasProp("nav") && it.key != "")
					Ring.BindKey(pre it.key, Ring_Key.Bind(it.key), opt)
		Ring.BindKey(pre "Esc", Ring_Esc, opt)
		Ring.BindKey(pre "Enter", Ring_Enter, opt)
		; a click is caught on the mouse hook's own thread (On T2, ~ so it still reaches whatever is under
		; the cursor): a synthetic Click() sent from this same process is a single blocking call with no
		; message-pump gap in it, so GetKeyState polled from another timer can miss the whole down-up pair.
		Ring.BindKey("~LButton", Ring_MouseDown, opt)
		Ring.BindKey("~LButton up", Ring_MouseUp, opt)
		if o.HasProp("extraKeys")
			for kk in o.extraKeys
				Ring.BindKey(pre kk, Ring_Key.Bind(kk), opt)
		if (o.HasProp("triggerHotkey") && o.triggerHotkey != "")
			Ring.BindKey(o.triggerHotkey, Ring_Trigger, opt)
	}

	; Hotkey() with the vk fallback Hud.BindKey uses for letters a layout does not map by name
	static BindKey(key, fn, opt) {
		try {
			Hotkey(key, fn, opt)
			return
		}
		t := ""
		loop parse key
			t .= IsAlpha(A_LoopField) ? "vk" GetVKList(A_LoopField)[1] : A_LoopField
		try Hotkey(t, fn, opt)
	}

	; GDI+ stays started for the life of the process once a ring has been drawn
	static Start() {
		if !Ring.token
			Ring.token := Gdip_Startup()
	}

	; {text, icon}: GDI+ font families. The icon family comes from a private collection because the GDI private
	; font Clipjump registers at startup is invisible to GDI+.
	static Fonts() {
		if IsObject(Ring.fontSet)
			return Ring.fontSet
		Ring.Start()
		f := {text: 0, icon: 0, coll: 0}
		fam := 0
		DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", Theme.FontName, "Ptr", 0, "Ptr*", &fam)
		if !fam
			DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
		f.text := fam
		path := A_WorkingDir "\icons\lucide.ttf"
		if FileExist(path) {
			coll := 0, ifam := 0
			DllCall("gdiplus\GdipNewPrivateFontCollection", "Ptr*", &coll)
			DllCall("gdiplus\GdipPrivateAddFontFile", "Ptr", coll, "WStr", path)
			DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", Theme.IconFont, "Ptr", coll, "Ptr*", &ifam)
			f.coll := coll, f.icon := ifam
		}
		return Ring.fontSet := f
	}

	; everything Paint needs for one ring; hover is 0-based, -1 for none
	static State(items, hover, hubTitle, hubSub, titleAccent := false) {
		iconRing := false
		for it in items
			if (it.HasProp("icon") && it.icon != "")
				iconRing := true
		return {items: items, hover: hover, hubTitle: hubTitle, hubSub: hubSub, titleAccent: titleAccent
			, iconRing: iconRing, pal: Theme.Palette, s: RingGeom.Sizes(Theme.Scale), k: Theme.Scale}
	}

	static NavLabel(nav) {
		global TXT
		return nav = "more" ? TXT.RNG_more : TXT.RNG_back
	}

	; side of the square bitmap that holds one ring and its shadow
	static Side(s) => 2 * (s.r1 + s.shadow + 2)

	static RenderToFile(st, path) {
		D := Ring.Side(st.s)
		Ring.Start()
		bmp := Gdip_CreateBitmap(D, D), G := Gdip_GraphicsFromImage(bmp)
		Gdip_GraphicsClear(G, 0xFF000000 | st.pal["bg"])
		Ring.Paint(G, st, D / 2, D / 2)
		Gdip_SaveBitmapToFile(bmp, path)
		Gdip_DeleteGraphics(G), Gdip_DisposeImage(bmp)
	}

	; paints one ring centred on (ox, oy)
	static Paint(G, st, ox, oy) {
		p := st.pal, s := st.s, k := st.k, n := st.items.Length
		Gdip_SetSmoothingMode(G, 4)
		Gdip_SetTextRenderingHint(G, 4)       ; grayscale: ClearType fringes on a transparent bitmap
		loop 5                                 ; soft shadow
			Ring.Disc(G, ox, oy, s.r1 + s.shadow - (A_Index - 1) * Round(2 * k), (A_Index * 9) << 24)
		Ring.Disc(G, ox, oy, s.r1 + 1, 0x02000000)   ; nearly invisible: the gaps between wedges catch the pointer
		for i, it in st.items {
			idx := i - 1, hot := (idx = st.hover)
			stroke := (!hot && it.HasProp("active") && it.active) ? 0xFF000000 | p["accent"] : 0
			Ring.Wedge(G, ox, oy, idx, n, s, 0xFF000000 | Ring.Fill(it, hot, p), stroke)
			Ring.WedgeContent(G, st, it, idx, n, hot, ox, oy)
		}
		Ring.Disc(G, ox, oy, s.hub, 0xFF000000 | p["surface"])
		pen := Gdip_CreatePen(0x1A000000 | p["text"], 1)
		DllCall("gdiplus\GdipDrawEllipse", "Ptr", G, "Ptr", pen, "Float", ox - s.hub, "Float", oy - s.hub, "Float", 2 * s.hub, "Float", 2 * s.hub)
		Gdip_DeletePen(pen)
		Ring.Hub(G, st, ox, oy)
	}

	static Fill(it, hot, p) {
		if hot
			return p["accent"]
		if (it.HasProp("active") && it.active)
			return p["accentSoft"]
		if it.HasProp("nav")
			return p["surface"]
		if (it.HasProp("dim") && it.dim)
			return Theme.Mix(p["surfaceAlt"], p["bg"], 0.5)
		return p["surfaceAlt"]
	}

	; one word per wedge on one line, trimmed to the wedge's width, with its key chip below; icon rings stack a
	; 16px icon above the word. Everything sits on the middle of the band.
	static WedgeContent(G, st, it, idx, n, hot, ox, oy) {
		p := st.pal, s := st.s, k := st.k, f := Ring.Fonts()
		mid := s.r0 + (s.r1 - s.r0) / 2
		w := Floor(2 * mid * Sin(3.141592653589793 / n) - s.gap - 14 * k)
		isNav := it.HasProp("nav")
		muted := isNav || (it.HasProp("dim") && it.dim)
		fg := 0xFF000000 | (hot ? p["accentText"] : (muted ? p["muted"] : p["text"]))
		label := isNav ? Ring.NavLabel(it.nav) : Ring.Short(it)
		key := isNav ? (it.nav = "more" ? "→" : "←") : it.key
		c := RingGeom.Point(idx, n, mid), x := ox + c[1], y := oy + c[2]
		if st.iconRing {
			if (!isNav && it.HasProp("icon") && it.icon != "" && f.icon)
				Ring.Text(G, it.icon, f.icon, 16 * k, false, 0xFF000000 | (hot ? p["accentText"] : p["muted"])
					, x - 12 * k, y - 28 * k, 24 * k, 24 * k)
			Ring.Text(G, label, f.text, 10 * k, true, fg, x - w / 2, y - 7 * k, w, 16 * k, true)
			Ring.Chip(G, key, x, y + 9 * k, hot, p, k)
		} else {
			Ring.Text(G, label, f.text, 10 * k, true, fg, x - w / 2, y - 16 * k, w, 16 * k, true)
			Ring.Chip(G, key, x, y, hot, p, k)
		}
	}

	; the wedge word: the item's short label, else the first word of its label
	static Short(it) {
		if (it.HasProp("short") && it.short != "")
			return it.short
		return StrSplit(it.label, " ")[1]
	}

	; the hub: the full name, its description and the keys line, one gap inside the hub's edge. The title
	; takes as many lines as it needs (measured, normally 1 or 2); the description gets whatever is left
	; of a fixed block height, so a one-line title leaves room for a two-line description and a two-line
	; title leaves room for one, each ending in an ellipsis rather than clipping when it still doesn't fit.
	static Hub(G, st, ox, oy) {
		global TXT
		p := st.pal, k := st.k, f := Ring.Fonts(), w := 2 * st.s.hub - 8 * k
		twoLine := Ring.MeasureLines(G, st.hubTitle, f.text, 12 * k, w) > 1
		titleH := (twoLine ? 32 : 18) * k, descH := (twoLine ? 16 : 30) * k, keysH := 12 * k
		top := oy - (titleH + descH + keysH) / 2
		Ring.Text(G, st.hubTitle, f.text, 12 * k, true, 0xFF000000 | (st.titleAccent ? p["accent"] : p["text"]), ox - w / 2, top, w, titleH)
		Ring.Text(G, st.hubSub, f.text, 10 * k, false, 0xFF000000 | p["muted"], ox - w / 2, top + titleH, w, descH)
		Ring.Text(G, TXT.RNG_keys, f.text, 9 * k, false, 0xFF000000 | p["muted"], ox - w / 2, top + titleH + descH, w, keysH)
	}

	; how many lines the bold title needs to wrap to at width w, using the same font/format Ring.Text
	; draws it with; frees the font and format it creates for the measurement
	static MeasureLines(G, text, fam, size, w) {
		if (text = "" || !fam)
			return 1
		font := 0, fmt := 0
		DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", 1, "Int", 2, "Ptr*", &font)
		DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x2000, "Int", 0, "Ptr*", &fmt)   ; LineLimit
		DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", fmt, "Int", 4)               ; EllipsisWord
		CreateRectF(&rc, 0, 0, w, 200)
		result := Gdip_MeasureString(G, text, font, fmt, &rc)
		DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
		DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
		parts := StrSplit(result, "|")
		return parts.Length >= 6 ? Integer(parts[6]) : 1
	}

	; key hint centred on cx, top edge at top
	static Chip(G, key, cx, top, hot, p, k) {
		if (key = "")
			return
		w := Max(14, 8 + 6 * StrLen(key)) * k, h := 13 * k
		Ring.RoundRect(G, cx - w / 2, top, w, h, 4 * k, hot ? 0x29000000 : 0xFF000000 | p["surface"])
		Ring.Text(G, key, Ring.Fonts().text, 9 * k, true, 0xFF000000 | (hot ? p["accentText"] : p["muted"]), cx - w / 2, top, w, h)
	}

	; wedge idx of n as a rounded ring sector with even gaps (RingGeom.WedgeArcs), centred on (ox, oy)
	static Wedge(G, ox, oy, idx, n, s, argb, strokeArgb := 0) {
		path := Gdip_CreatePath()
		for a in RingGeom.WedgeArcs(idx, n, s.r0, s.r1, s.gap, s.corner)
			DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", ox + a.cx - a.r, "Float", oy + a.cy - a.r, "Float", 2 * a.r, "Float", 2 * a.r, "Float", a.start, "Float", a.sweep)
		DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillPath(G, br, path)
		Gdip_DeleteBrush(br)
		if strokeArgb {
			pen := Gdip_CreatePen(strokeArgb, 1)
			DllCall("gdiplus\GdipDrawPath", "Ptr", G, "Ptr", pen, "Ptr", path)
			Gdip_DeletePen(pen)
		}
		Gdip_DeletePath(path)
	}

	static Disc(G, cx, cy, r, argb) {
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillEllipse(G, br, cx - r, cy - r, 2 * r, 2 * r)
		Gdip_DeleteBrush(br)
	}

	static RoundRect(G, x, y, w, h, r, argb) {
		path := Gdip_CreatePath(), d := 2 * r
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
		DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillPath(G, br, path)
		Gdip_DeleteBrush(br), Gdip_DeletePath(path)
	}

	; centred text in a box; size in pixels. Only whole lines that fit are drawn and the last one ends in an ellipsis
	; when the text runs over; oneLine keeps it to a single line cut with an ellipsis at the box's width.
	static Text(G, text, fam, size, bold, argb, x, y, w, h, oneLine := false) {
		if (text = "" || !fam)
			return
		font := 0, fmt := 0
		DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font)
		DllCall("gdiplus\GdipCreateStringFormat", "Int", oneLine ? 0x3000 : 0x2000, "Int", 0, "Ptr*", &fmt)   ; LineLimit, + NoWrap
		DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", fmt, "Int", oneLine ? 3 : 4)                   ; ellipsis: character / word
		DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
		DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
		br := Gdip_BrushCreateSolid(argb)
		rc := Buffer(16), NumPut("Float", x, "Float", y, "Float", w, "Float", h, rc)
		DllCall("gdiplus\GdipDrawString", "Ptr", G, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", br)
		Gdip_DeleteBrush(br)
		DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
		DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
	}
}

Ring_Tick() {
	if !Ring.isOpen
		return
	MouseGetPos(&mx, &my)
	s := RingGeom.Sizes(Theme.Scale)
	items := Ring.pages[Ring.page]
	h := RingGeom.Hit(mx - Ring.cx, my - Ring.cy, items.Length, s)
	hover := h.zone = "ring" ? h.index : -1
	if (hover != Ring.hover) {
		Ring.hover := hover
		Ring.Draw()
	}
	; releasing the held trigger commits a flick; a quick tap without travel keeps the ring open
	if (Ring.held && !GetKeyState(Ring.opts.trigger)) {
		Ring.held := false
		moved := Sqrt((mx - Ring.sx) ** 2 + (my - Ring.sy) ** 2) >= s.travel
		if (hover >= 0 && (moved || A_TickCount - Ring.openedAt > RingGeom.TapMs))
			return Ring.Choose(hover)
	}
}

; the click's press: recorded only so a release is honoured solely for a press made while the ring was open
Ring_MouseDown(*) {
	if !Ring.isOpen
		return
	MouseGetPos(&mx, &my)
	s := RingGeom.Sizes(Theme.Scale), items := Ring.pages[Ring.page]
	Ring.pressZone := RingGeom.Hit(mx - Ring.cx, my - Ring.cy, items.Length, s).zone
}

; the click's release: acts on the zone under the cursor now, using the press to gate a stray release
; (e.g. a button already held when the ring opened) rather than the zone the press itself landed in
Ring_MouseUp(*) {
	if (!Ring.isOpen || Ring.pressZone = "")
		return
	zone := Ring.pressZone, Ring.pressZone := ""
	MouseGetPos(&mx, &my)
	s := RingGeom.Sizes(Theme.Scale), items := Ring.pages[Ring.page]
	h := RingGeom.Hit(mx - Ring.cx, my - Ring.cy, items.Length, s)
	if (zone = "outside")
		return Ring.Close("")
	if (zone = "ring" && h.zone = "ring")
		return Ring.Choose(h.index)
}

Ring_Key(key, *) => Ring.Close(key)
Ring_Esc(*) => Ring.Close("")

Ring_Enter(*) {
	if (Ring.hover >= 0)
		Ring.Choose(Ring.hover)
}

; a second tap of the trigger closes the ring; auto-repeat while it is still held is ignored
Ring_Trigger(*) {
	if !Ring.held
		Ring.Close("")
}

Ring_IsOpen() => Ring.isOpen ? 1 : 0

; screen position of wedge i's centre line (mid-band) on the current page, as "x,y"
Ring_WedgePoint(i) {
	if !Ring.isOpen
		return ""
	s := RingGeom.Sizes(Theme.Scale), n := Ring.pages[Ring.page].Length
	c := RingGeom.Point(i, n, (s.r0 + s.r1) / 2)
	return Round(Ring.cx + c[1]) "," Round(Ring.cy + c[2])
}

Ring_LabelAt(i) {
	if !Ring.isOpen
		return ""
	it := Ring.pages[Ring.page][i + 1]
	return it.HasProp("nav") ? it.nav : it.label
}
