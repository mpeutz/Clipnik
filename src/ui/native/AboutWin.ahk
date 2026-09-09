; AboutWin.ahk - the About card: icon, name and version, author link, language, info text, OK / Reset.
;
;   AboutWin.Open()
; The tray menu, language switch (updateLang) and reset logic stay in lib/aboutGUI.ahk.

class AboutWin {
	static g := ""

	static Open() {
		global PROGNAME, VERSION, TXT, AUTHOR_PAGE, CN, mainIconPath, CJGUI
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
		try g.Add("Picture", "x" ((w - 56) / 2) " y20 w56 h56", mainIconPath)
		g.SetFont("s16 bold c" Theme.Hex("text"), Theme.FontName)
		g.Add("Text", "x0 y82 w" w " +Center", PROGNAME)
		g.SetFont("s10 norm c" Theme.Hex("muted"), Theme.FontName)
		g.Add("Text", "x0 y112 w" w " +Center", TXT.ABT_version " " VERSION " · AutoHotkey v" A_AhkVersion " · " TXT.ABT_portable)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		author := Theme.AddLink(g, "x0 y136 w" w " +Center", "Avi Aryan", blog)
		g.SetFont("s10 c" Theme.Hex("muted"), Theme.FontName)
		g.Add("Text", "x0 y156 w" w " +Center", "(C) 2013-" A_Year)
		g.SetFont("s10 c" Theme.Hex("text"), Theme.FontName)
		g.Add("Text", "x50 y186 w" (w - 100) " +Center", TXT.ABT_info)
		g.Add("Text", "x28 y246 h24 +0x200", TXT._language)
		ddl := Theme.Add(g, "DDL", "x+10 yp w140")
		Translations_loadlist(ddl)
		ddl.OnEvent("Change", updateLang)
		rule := g.Add("Progress", "x0 y296 w" w " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
		btnReset := Theme.Add(g, "Button", "x28 y308 w140 h28", TXT.ABT_reset)
		btnReset.OnEvent("Click", reset)
		ok := Theme.Add(g, "Button", "x" (w - 28 - 76) " y308 w76 h28 Default", "OK")
		ok.OnEvent("Click", (*) => AboutWin.Close())
		g.OnEvent("Close", (*) => AboutWin.Close())
		g.OnEvent("Escape", (*) => AboutWin.Close())
		g.Show("w" w " h348")
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
