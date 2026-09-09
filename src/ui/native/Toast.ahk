; Toast.ahk - small themed notification cards that never take focus.
;
;   Toast.Show(text, ms := 1500, kind := "info", slot := "")   kind: info | warn | error ; ms 0 = sticky until Hide(slot)
;   Toast.Hide(slot)
;   Toast.Position := "bottomright" | "cursor"                  ([Main] ToastPosition)
;
; At most Toast.MaxVisible cards are shown, stacked upward from the bottom-right corner of the work area of the
; monitor that holds the active window (or the cursor). A card with the same slot name replaces the older one.

class Toast {
	static Position := "bottomright"
	static MaxVisible := 3
	static cards := []          ; visible cards, oldest first
	static Width := 300
	static Gap := 8
	static Margin := 16

	static Show(text, ms := 1500, kind := "info", slot := "") {
		if (text = "")
			return
		if (slot != "")
			Toast.Hide(slot)
		while (Toast.cards.Length >= Toast.MaxVisible)
			Toast.Remove(Toast.cards[1])
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

	static Create(text, kind, slot) {
		s := Theme.Scale
		g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000 -DPIScale +Owner" A_ScriptHwnd, "Clipjump_Toast")
		g.MarginX := 0, g.MarginY := 0
		g.BackColor := Theme.Hex("surface")
		Theme.ApplyToHwnd(g.Hwnd, 3, true)
		color := (kind = "error") ? "danger" : (kind = "warn") ? "danger" : "accent"
		w := Round(Toast.Width * s), pad := Round(12 * s), strip := Round(6 * s)
		g.Add("Progress", "x0 y0 w" strip " h10 -Theme Background" Theme.Hex(color) " c" Theme.Hex(color) " vstrip", 100)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		label := g.Add("Text", "x" (strip + pad) " y" pad " w" (w - strip - 2 * pad) " vtxt +Wrap", text)
		label.GetPos(, , , &th)
		h := th + 2 * pad
		g["strip"].Move(, , , h)
		g.OnEvent("Close", (*) => 0)
		card := {gui: g, w: w, h: h, slot: slot, timer: ""}
		return card
	}

	static Layout() {
		s := Theme.Scale
		Toast.Anchor(&ax, &ay, &right, &bottom)
		y := bottom - Round(Toast.Margin * s)
		loop Toast.cards.Length {
			card := Toast.cards[Toast.cards.Length - A_Index + 1]   ; newest at the bottom
			y -= card.h
			x := right - Round(Toast.Margin * s) - card.w
			card.gui.Show("NoActivate x" x " y" y " w" card.w " h" card.h)
			y -= Round(Toast.Gap * s)
		}
	}

	; bottom-right corner of the work area that should hold the stack
	static Anchor(&x, &y, &right, &bottom) {
		x := 0, y := 0
		if (Toast.Position = "cursor") {
			MouseGetPos(&x, &y)
		} else {
			try {
				WinGetPos(&wx, &wy, &ww, &wh, "A")
				x := wx + ww // 2, y := wy + wh // 2
			} catch
				MouseGetPos(&x, &y)
		}
		Theme.WorkAreaAt(x, y, &l, &t, &right, &bottom)
		if (Toast.Position = "cursor") {
			right := Min(right, Round(x + (Toast.Width + Toast.Margin + 24) * Theme.Scale))
			bottom := Min(bottom, Round(y + (Toast.Margin + 90) * Theme.Scale))
		}
	}

	static Remove(card) {
		if card.timer
			SetTimer(card.timer, 0)
		for i, c in Toast.cards
			if (c = card) {
				Toast.cards.RemoveAt(i)
				break
			}
		try card.gui.Destroy()
		Toast.Layout()
	}
}
