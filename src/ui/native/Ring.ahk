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

	; the hub: the full name, its description (two lines at most) and the keys line, one gap inside the hub's edge
	static Hub(G, st, ox, oy) {
		global TXT
		p := st.pal, k := st.k, f := Ring.Fonts(), w := 2 * st.s.hub - 8 * k
		Ring.Text(G, st.hubTitle, f.text, 12 * k, true, 0xFF000000 | (st.titleAccent ? p["accent"] : p["text"]), ox - w / 2, oy - 34 * k, w, 32 * k)
		Ring.Text(G, st.hubSub, f.text, 10 * k, false, 0xFF000000 | p["muted"], ox - w / 2, oy - 2 * k, w, 20 * k)
		Ring.Text(G, TXT.RNG_keys, f.text, 9 * k, false, 0xFF000000 | p["muted"], ox - w / 2, oy + 18 * k, w, 12 * k)
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
