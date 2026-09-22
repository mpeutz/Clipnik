; AboutWin.ahk - the About card: icon, name and version, author link, language, info text, OK / Reset.
;
;   AboutWin.Open()
; The tray menu, language switch (updateLang) and reset logic stay in lib/aboutGUI.ahk.

class AboutWin {
	static g := ""

	static Open() {
		global PROGNAME, VERSION, TXT, AUTHOR, ORIGINAL_AUTHOR, CN, mainIconPath, CJGUI
		if (AboutWin.g && !GuiAlive(AboutWin.g))
			AboutWin.Close()
		if AboutWin.g {
			AboutWin.g.Show()
			return
		}
		g := Gui("-MaximizeBox -MinimizeBox", TXT.ABT__name " " PROGNAME)
		AboutWin.g := g
		CJGUI["2"] := g
		g.MarginX := 0, g.MarginY := 0
		Theme.ApplyToGui(g)
		w := 440
		hIcon := Theme.AccentIcon(mainIconPath, 56)   ; the Picture's own size, so it is never rescaled
		try g.Add("Picture", "x" ((w - 56) / 2) " y20 w56 h56", hIcon ? "HICON:*" hIcon : mainIconPath)
		g.SetFont("s16 bold c" Theme.Hex("text"), Theme.FontName)
		g.Add("Text", "x0 y82 w" w " +Center", PROGNAME)
		g.SetFont("s10 norm c" Theme.Hex("muted"), Theme.FontName)
		g.Add("Text", "x0 y112 w" w " +Center", TXT.ABT_version " " VERSION " · AutoHotkey v" A_AhkVersion " · " TXT.ABT_portable)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		g.Add("Text", "x0 y136 w" w " +Center", AUTHOR)
		g.SetFont("s10 c" Theme.Hex("muted"), Theme.FontName)
		g.Add("Text", "x0 y156 w" w " +Center", "(C) 2013-" A_Year)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		g.Add("Text", "x50 y186 w" (w - 100) " +Center", TXT.ABT_info)
		; "Forked from the original Clipjump by [Avi Aryan]" centered as one line, the name linking to the project
		g.SetFont("s10 c" Theme.Hex("muted"), Theme.FontName)
		lead := g.Add("Text", "x0 y252 h20 +0x200", TXT.ABT_forkOf " ")
		lead.GetPos(, , &lw)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		name := Theme.AddLink(g, "x0 y252 h20 +0x200", ORIGINAL_AUTHOR, blog)
		name.GetPos(, , &nw)
		lead.Move((w - lw - nw) // 2), name.Move((w - lw - nw) // 2 + lw)
		g.Add("Text", "x28 y290 h24 +0x200", TXT._language)
		ddl := Theme.Add(g, "DDL", "x+10 yp w140")
		Translations_loadlist(ddl)
		ddl.OnEvent("Change", updateLang)
		rule := g.Add("Progress", "x0 y340 w" w " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
		btnReset := Theme.Add(g, "Button", "x28 y352 w140 h28", TXT.ABT_reset)
		btnReset.OnEvent("Click", reset)
		ok := Theme.Add(g, "Button", "x" (w - 28 - 76) " y352 w76 h28 Default", "OK")
		ok.OnEvent("Click", (*) => AboutWin.Close())
		g.OnEvent("Close", (*) => AboutWin.Close())
		g.OnEvent("Escape", (*) => AboutWin.Close())
		g.Show("w" w " h392")
		ok.Focus()   ; not the language box: a stray key there would switch languages
	}

	static Close() {
		global CJGUI
		if AboutWin.g
			try AboutWin.g.Destroy()
		AboutWin.g := ""
		try CJGUI.Delete("2")
		EmptyMem()
	}
}
