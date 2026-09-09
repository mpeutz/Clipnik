;The About GUI for Clipjump


aboutGUI() {
	global
	local w_ofreset, w_versiontxt, versiontxt, g, ddl
	;About GUI
	w_ofreset := getControlinfo("button", TXT.ABT_reset, "w", "s10", "Arial")
	w_versiontxt := getControlinfo("Text", versiontxt := PROGNAME " v" VERSION, "w", "s18", "Consolas")

	GuiDestroy("2")
	g := Gui("", PROGNAME " [ Channel: " CN.Name " ]")
	CJGUI["2"] := g
	g.MarginX := 0, g.MarginY := 0
	g.SetFont("s18", "Courier New")
	g.SetFont("S18", "Consolas")
	g.Add("Edit", "x0 y0 w0 h0")
	g.Add("Text", "x" Round((522 - w_versiontxt) / 2) " y5", versiontxt)
	g.SetFont("S12")
	g.Add("Link", "x180 y+3", '<a href="' AUTHOR_PAGE '">Avi Aryan</a> (C) ' A_Year).OnEvent("Click", blog)

	g.SetFont("S11 norm", "Arial")
	g.Add("Text", "y+30 x10", TXT._language)
	g.SetFont("s9")
	ddl := g.Add("DropDownList", "yp x+20 vini_LANG")
	Translations_loadlist(ddl) 			;loads the list in the above ddl
	ddl.OnEvent("Change", updateLang)

	g.SetFont("s11", "Courier New")
	g.Add("GroupBox", "x7 y130 w540 h100", TXT.ABT__name)
	g.SetFont("S10", "Arial")

	g.Add("Text", "xp+10 y160 wp-10", TXT.ABT_info)

	g.SetFont("S10", "Arial")
	g.Add("Button", "xp-10 y+60 w70 Default", "OK").OnEvent("Click", aboutClose)
	g.Add("Button", "x" (552 - w_ofreset - 5) " yp", TXT.ABT_reset).OnEvent("Click", reset) 		;leaving 5 as margin
	g.Add("Text", "y+0 h0")
	g.OnEvent("Close", aboutClose)
	g.OnEvent("Escape", aboutClose)

	g.Show("w552")
}

blog(*) {
	global
	BrowserRun(AUTHOR_PAGE)
}

aboutClose(*) {
	global
	if CJGUI.Has("2")
		CJGUI["2"].Hide()
	EmptyMem()
}

updateLang(ctrl, *) {
	global
	ini_LANG := ctrl.Text
	TXT := Translations_load("languages/" ini_LANG ".txt")
	Translations_apply()
	ini_write("System", "Lang", ini_LANG, 0)
}

reset(*) {
	global
	if (MsgBox(TXT.ABT_resetM, "Warning", 20) = "Yes")
	{
		try DirDelete("cache", 1)
		try FileDelete("settings.ini")
		try FileDelete("ClipjumpCustom.ini")
		if A_IsCompiled
			try DirDelete("icons", 1)
		if FileExist(A_Startup "/Clipjump.lnk")
		{
			if (MsgBox(TXT.ABT_removeStart, "Resetting " PROGNAME, 52) = "Yes")
				FileDelete(A_Startup "/Clipjump.lnk")
		}
		MsgBox(PROGNAME " " TXT.ABT_resetfinal, "Reset Complete", 64)
		OnExit(onExitHandler, 0)
		ExitApp
	}
}

openFaq(*) {
	global
	try Run("hh.exe mk:@MSITStore:" A_WorkingDir "\Clipjump.chm::/docs/faq.html")
	catch
		MsgBox(TXT.ABT_chmErr, PROGNAME, 16)
}

openShortcutsHelp(*) {
	global
	try Run("hh.exe mk:@MSITStore:" A_WorkingDir "\Clipjump.chm::/docs/shortcuts.html#pstmd")
	catch
		MsgBox(TXT.ABT_chmErr, PROGNAME, 16)
}

reloadClipjump(*) {
	OnExit(onExitHandler, 0)
	routines_Exit()
	Reload()
}

trayMenu(destroy := 0) {
	global

	if destroy
	{
		A_TrayMenu.Delete()
		Options_Tray.Delete()
		Tools_Tray.Delete()
		Maintanence_Tray.Delete()
		Help_Tray.Delete()
	}

	;Tray Icon
	try TraySetIcon(mainIconPath)
	A_TrayMenu.Delete()   ; NoStandard
	A_TrayMenu.Add(TXT.ABT__name " " PROGNAME, main)
	A_IconTip := PROGNAME " {" CN.Name "}"
	A_TrayMenu.Add()
	A_TrayMenu.Add(TXT.SET_actmd "`t" Hparse_Rev(actionmode_k), actionmode_run)
	A_TrayMenu.Add()		; separator
		Maintanence_Tray.Add(TXT.PLG_delFileFolder, tray_deleteFileFolder)
	A_TrayMenu.Add(TXT._maintenance, Maintanence_Tray)
		Options_Tray.Add(TXT.TRY_incognito, incognito)
		Options_Tray.Add(TXT.TRY_disable " " PROGNAME, disable_clipjump)
		Options_Tray.Add(TXT.TRY_startup, strtup)
	A_TrayMenu.Add(TXT.TRY_options, Options_Tray)
		Tools_Tray.Add(TXT.SET_org "`t" Hparse_Rev(chOrg_K), channelOrganizer)
		Tools_Tray.Add(TXT.HST__name "`t" Hparse_Rev(history_K), history)
		Tools_Tray.Add(TXT.IGN__name, classTool)
		Tools_Tray.Add(TXT.PLG__name "`t" Hparse_Rev(pluginManager_k), pluginManagerGui)
		Tools_Tray.Add(TXT.SET__name, settings)
	A_TrayMenu.Add(TXT.TRY_tools, Tools_Tray)
		Help_Tray.Add(TXT.TRY_pstmdshorts, openShortcutsHelp)
		Help_Tray.Add("FAQ", openFaq)
		Help_Tray.Add()
		Help_Tray.Add("Clipjump.chm", hlp)
	A_TrayMenu.Add()
	A_TrayMenu.Add(TXT.TRY_help, Help_Tray)
	A_TrayMenu.Add()
	A_TrayMenu.Add(TXT.TRY_reloadcustom, reloadCustom)
	A_TrayMenu.Add(TXT.TRY_restart, reloadClipjump)
	A_TrayMenu.Add(TXT.TRY_exit, exitClipjump)
	A_TrayMenu.Default := TXT.ABT__name " " PROGNAME
}
