; IgnoredWindowsWin.ahk - the list of window classes Clipjump ignores (paste mode passes Ctrl+V through in them).
; Replaces plugins/external.ignoreWmanager.ahk: runs in-process, writes [Advanced] ignoreWindows and rebuilds
; the window group right away, so no restart is needed.
;
;   IgnoredWindowsWin.Open(ownerGui := "")

class IgnoredWindowsWin {
	static g := "", lv := "", picking := false, picked := "", pickActive := false

	static Open(owner := "") {
		global PROGNAME, TXT
		if (IgnoredWindowsWin.g && !GuiAlive(IgnoredWindowsWin.g))
			IgnoredWindowsWin.Close()
		if IgnoredWindowsWin.g {
			IgnoredWindowsWin.g.Show()
			return
		}
		g := Gui("-MaximizeBox -MinimizeBox", PROGNAME " " TXT.IGN__name)
		IgnoredWindowsWin.g := g
		g.MarginX := 16, g.MarginY := 16
		Theme.ApplyToGui(g)
		if owner
			g.Opt("+Owner" owner.Hwnd)
		g.SetFont("s9 c" Theme.Hex("muted"))
		g.Add("Text", "x16 y16 w388 h34", TXT.IGN_intro)
		g.SetFont("s10 c" Theme.Hex("text"))
		lv := Theme.Add(g, "ListView", "x16 y60 w388 h224 -Hdr -Multi -E0x200 +Border", ["Class"])
		lv.ModifyCol(1, 380)
		lv.Opt("Background" Theme.Hex("surface"))
		IgnoredWindowsWin.lv := lv
		add := Theme.Add(g, "Button", "x16 y296 w150 h28", TXT.IGN_add)
		add.OnEvent("Click", (*) => IgnoredWindowsWin.Add())
		del := Theme.Add(g, "Button", "x+8 yp w110 h28", TXT.IGN_delete)
		del.OnEvent("Click", (*) => IgnoredWindowsWin.Delete())
		close := Theme.Add(g, "Button", "x328 yp w76 h28 Default", TXT._close)
		close.OnEvent("Click", (*) => IgnoredWindowsWin.Close())
		g.OnEvent("Close", (*) => IgnoredWindowsWin.Close())
		g.OnEvent("Escape", (*) => IgnoredWindowsWin.Close())
		IgnoredWindowsWin.Fill()
		g.Show("w420 h340")
	}

	static Close() {
		if IgnoredWindowsWin.pickActive
			IgnoredWindowsWin.pickActive := false
		if IgnoredWindowsWin.g
			try IgnoredWindowsWin.g.Destroy()
		IgnoredWindowsWin.g := "", IgnoredWindowsWin.lv := ""
	}

	static Fill() {
		global ignoreWindows
		lv := IgnoredWindowsWin.lv
		lv.Delete()
		loop parse ignoreWindows, "|"
			if (A_LoopField != "")
				lv.Add("", A_LoopField)
	}

	static Save() {
		global ignoreWindows
		lv := IgnoredWindowsWin.lv
		s := ""
		loop lv.GetCount()
			s .= lv.GetText(A_Index) "|"
		ignoreWindows := s
		ini_write("Advanced", "ignoreWindows", s, 0)
		rebuildIgnoreGroup()
	}

	static Delete() {
		lv := IgnoredWindowsWin.lv
		row := lv.GetNext(0)
		if !row
			return
		lv.Delete(row)
		IgnoredWindowsWin.Save()
	}

	; Lets the user pick a window: the card follows the active window's class until Space accepts or Esc cancels.
	static Add() {
		global TXT
		if IgnoredWindowsWin.pickActive
			return
		IgnoredWindowsWin.pickActive := true, IgnoredWindowsWin.picked := ""
		hkZ("Esc", IgnoredWindowsWin_PickEnd, 1)
		hkZ("Space", IgnoredWindowsWin_PickAccept, 1)
		SetTimer(IgnoredWindowsWin_PickTick, 200)
		while IgnoredWindowsWin.pickActive
			Sleep 20
		SetTimer(IgnoredWindowsWin_PickTick, 0)
		hkZ("Esc", IgnoredWindowsWin_PickEnd, 0)
		hkZ("Space", IgnoredWindowsWin_PickAccept, 0)
		Hud.Hide()
		if !IgnoredWindowsWin.g
			return
		try WinActivate(IgnoredWindowsWin.g.Hwnd)
		cls := IgnoredWindowsWin.picked
		if (cls = "")
			return
		lv := IgnoredWindowsWin.lv
		loop lv.GetCount()
			if (lv.GetText(A_Index) = cls)
				return
		lv.Add("", cls)
		IgnoredWindowsWin.Save()
	}
}

IgnoredWindowsWin_PickTick() {
	global TXT
	cls := ""
	try cls := WinGetClass("A")
	Hud.Message(cls "`n`n" TXT.IGN_tip)
}

IgnoredWindowsWin_PickAccept(*) {
	try IgnoredWindowsWin.picked := WinGetClass("A")
	IgnoredWindowsWin.pickActive := false
}

IgnoredWindowsWin_PickEnd(*) {
	IgnoredWindowsWin.picked := ""
	IgnoredWindowsWin.pickActive := false
}
