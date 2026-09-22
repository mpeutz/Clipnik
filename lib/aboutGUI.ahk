; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;The About GUI for Clipjump


aboutGUI() {
	AboutWin.Open()
}

blog(*) {
	global
	BrowserRun(AUTHOR_PAGE)
}

aboutClose(*) {
	AboutWin.Close()
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
	}

	;Tray Icon
	try setTrayIcon(mainIconPath)
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
		if isRunAtStartup()
			Options_Tray.Check(TXT.TRY_startup)
	A_TrayMenu.Add(TXT.TRY_options, Options_Tray)
		Tools_Tray.Add(TXT.SET_org "`t" Hparse_Rev(chOrg_K), channelOrganizer)
		Tools_Tray.Add(TXT.HST__name "`t" Hparse_Rev(history_K), history)
		Tools_Tray.Add(TXT.IGN__name, classTool)
		Tools_Tray.Add(TXT.PLG__name "`t" Hparse_Rev(pluginManager_k), pluginManagerGui)
		Tools_Tray.Add(TXT.SET__name, settings)
	A_TrayMenu.Add(TXT.TRY_tools, Tools_Tray)
	A_TrayMenu.Add()
	A_TrayMenu.Add(TXT.TRY_help, (*) => HelpWin.Open())
	A_TrayMenu.Add()
	A_TrayMenu.Add(TXT.TRY_reloadcustom, reloadCustom)
	A_TrayMenu.Add(TXT.TRY_restart, reloadClipjump)
	A_TrayMenu.Add(TXT.TRY_exit, exitClipjump)
	A_TrayMenu.Default := TXT.ABT__name " " PROGNAME
}
