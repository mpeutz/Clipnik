; Toast.ahk - compact notification cards that never take focus: a Lucide glyph in the kind's color and one line
; of text, on a rounded, shadowed, slightly translucent card.
;
;   Toast.Show(text, ms := 1500, kind := "info", slot := "")   kind: info | warn | error | busy ; ms 0 = sticky until Hide(slot)
;   Toast.Hide(slot)
;   Toast.Position := "cursor" | "bottomright"                  ([Main] ToastPosition, default cursor)
;
; At most Toast.MaxVisible cards are shown; in cursor mode the newest sits below-right of the pointer and older
; ones stack under it, in bottomright mode they stack upward from the work-area corner. A card with the same slot
; name replaces the older one. A sticky card (ms 0) shows the busy glyph.

class Toast {
	static Position := "cursor"
	static MaxVisible := 3
	static cards := []          ; visible cards, oldest first
	static MaxWidth := 360
	static Height := 32
	static Gap := 8
	static Margin := 16

	static Show(text, ms := 1500, kind := "info", slot := "") {
		if (text = "")
			return
		if (slot != "")
			Toast.Hide(slot)
		while (Toast.cards.Length >= Toast.MaxVisible)
			Toast.Remove(Toast.cards[1])
		if (ms = 0 && kind = "info")
			kind := "busy"
		card := Toast.Create(text, kind, slot)
		Toast.cards.Push(card)
		Toast.Layout()
		if (ms > 0)
			SetTimer(card.timer := Toast.Remove.Bind(Toast, card), -ms)
	}

	static Hide(slot) {
		for card in Toast.cards.Clone()
			if (card.slot = slot)
				Toast.Remove(card)
	}

	static Glyph(kind) {
		switch kind {
			case "warn": return ["shield-check", "warn"]
			case "error": return ["x", "danger"]
			case "busy": return ["loader", "accent"]
		}
		return ["check", "accent"]
	}

	static Create(text, kind, slot) {
		s := Theme.Scale
		g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 -DPIScale +Owner" A_ScriptHwnd, "Clipjump_Toast")
		g.MarginX := 0, g.MarginY := 0
		g.BackColor := Theme.Hex("surface")
		Theme.Popup(g)
		gl := Toast.Glyph(kind)
		h := Round(Toast.Height * s), padL := Round(11 * s), padR := Round(14 * s), gw := Round(18 * s), gap := Round(8 * s)
		text := StrReplace(StrReplace(text, "`r`n", " "), "`n", " ")
		pill := ""
		if RegExMatch(text, "^(.*?)\s*\{([^{}]+)\}$", &m)   ; a trailing {channel} becomes an accent pill
			text := m[1], pill := m[2]
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		label := g.Add("Text", "x" (padL + gw + gap) " y0 h" h " +0x200", text)
		label.GetPos(, , &tw)
		pw := 0
		if (pill != "") {
			g.SetFont("s8 bold c" Theme.Hex("accentText"), Theme.FontName)
			meter := g.Add("Text", "x0 y0 +Hidden", pill)
			meter.GetPos(, , &pw)
			Theme.Discard(meter)
			pw += Round(16 * s)
		}
		tw := Min(tw + Round(2 * s), Round(Toast.MaxWidth * s) - padL - gw - gap - padR - (pw ? pw + gap : 0))
		label.Move(, , tw)
		if (pill != "") {
			ph := Round(20 * s)
			Theme.AddPill(g, "x" (padL + gw + gap + tw + gap) " y" ((h - ph) // 2) " w" pw " h" ph, pill, "accent", "accentText")
		}
		if Theme.HasIcons() {
			g.SetFont("s10 c" Theme.Hex(gl[2]), Theme.IconFont)
			g.Add("Text", "x" padL " y0 w" gw " h" h " +0x200 +Center", Theme.Icon(gl[1]))
		}
		w := padL + gw + gap + tw + (pw ? gap + pw : 0) + padR
		g.OnEvent("Close", (*) => 0)
		return {gui: g, w: w, h: h, slot: slot, timer: ""}
	}

	static Layout() {
		s := Theme.Scale
		if (Toast.Position = "cursor") {
			Toast.LayoutAtCursor()
			return
		}
		Toast.Anchor(&ax, &ay, &right, &bottom)
		y := bottom - Round(Toast.Margin * s)
		loop Toast.cards.Length {
			card := Toast.cards[Toast.cards.Length - A_Index + 1]   ; newest at the bottom
			y -= card.h
			x := right - Round(Toast.Margin * s) - card.w
			Theme.ShowPopup(card.gui, x, y, card.w, card.h)
			y -= Round(Toast.Gap * s)
		}
	}

	; cursor mode: the newest card sits just below-right of the pointer, older ones stack below it
	static LayoutAtCursor() {
		if !Toast.cards.Length
			return
		s := Theme.Scale
		MouseGetPos(&mx, &my)
		Theme.WorkAreaAt(mx, my, &l, &t, &r, &b)
		x := mx + Round(16 * s), y := my + Round(20 * s)
		total := 0, widest := 0
		for card in Toast.cards
			total += card.h + Round(Toast.Gap * s), widest := Max(widest, card.w)
		if (x + widest > r - 8)
			x := mx - Round(16 * s) - widest
		if (y + total > b - 8)
			y := my - Round(20 * s) - total
		x := Max(l, x), y := Max(t, y)
		loop Toast.cards.Length {
			card := Toast.cards[Toast.cards.Length - A_Index + 1]   ; newest first
			Theme.ShowPopup(card.gui, x, y, card.w, card.h)
			y += card.h + Round(Toast.Gap * s)
		}
	}

	; bottom-right corner of the work area that should hold the stack
	static Anchor(&x, &y, &right, &bottom) {
		x := 0, y := 0
		try {
			WinGetPos(&wx, &wy, &ww, &wh, "A")
			x := wx + ww // 2, y := wy + wh // 2
		} catch
			MouseGetPos(&x, &y)
		Theme.WorkAreaAt(x, y, &l, &t, &right, &bottom)
	}

	static Remove(card) {
		if card.timer
			SetTimer(card.timer, 0)
		for i, c in Toast.cards
			if (c = card) {
				Toast.cards.RemoveAt(i)
				break
			}
		try Theme.popups.Delete(card.gui.Hwnd)
		try for ctl in card.gui
			Theme.UnregisterDraw(ctl.Hwnd)
		try card.gui.Destroy()
		Toast.Layout()
	}
}
