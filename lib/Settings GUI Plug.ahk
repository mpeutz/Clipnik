;Gui Settings for Clipjump
;A lot of thanks to chaz

; When adding new settings m remember to update ADVANCED_NUMBER var in the main file
; Tooltip Number for Settings GUI - 4
gui_Settings()
; Preconditions: ini settings in variables starting with _ini
; Postconditions: Builds and shows a GUI in which Clipjump settings can be changed. New settings are written to the configuration file when OK or Apply is pressed, but only if changes have been made.
{
	global
	local settingsHaveChanged := false
	local size_limitmaxclips, size_keepsession, size_cfolderp, left_size, x_ofhotkeys, size_advanced
	local width_hk_control, right_size, height_group, height_downgroup, tempLst, tempSel, tempK, tempV
	local g, chkLimitMaxClips, edtMaxClips, edtThreshold, edtPstK, ddlPformat, btnApply

	; get max sizes possible of window
	size_limitmaxclips := getControlInfo("checkbox", TXT.SET_limitmaxclips, "w")
	size_keepsession := getControlInfo("checkbox", TXT.SET_keepsession, "w")
	width_hk_control := 150
	right_size := size_cfolderp := getControlInfo("text", TXT._cfolderp, "w") + 9 + width_hk_control + 50 ;9=max margin ; 120=width of hotkey control, 50 = cstm gap betn controls
	left_size := ( size_limitmaxclips >= size_keepsession ? size_limitmaxclips : size_keepsession ) + 16 + 50 + 40
	; 16= max margin of any control (maxlcips)  ,  50 = width of updown , 40 = extra for compatibility in other languages

	;enable tooltips
	OnMessage(0x200, WM_MOUSEMOVE)

	height_group := 300
	height_downgroup := 75

	GuiDestroy("Settings")
	g := Gui("", PROGNAME " Settings")
	CJGUI["Settings"] := g
	g.MarginX := 8, g.MarginY := 8
	g.Add("GroupBox", "w" left_size " h" height_group, TXT.SET_main)		; for every new checkbox add 18 pixels to the height, and for every new UpDown control add 26 pixels
	; The total width of the GUI is about 289 x 2

	chkLimitMaxClips := g.Add("CheckBox", "xp+9 yp+22 Section Checked" ini_limitMaxClips " vnew_limitMaxClips", TXT.SET_limitmaxclips)	; when this is checked the following two controls will be disabled
	chkLimitMaxClips.OnEvent("Click", chkbox_limitMaxClips)
	g.Add("Text", "xs+16", TXT.SET_maxclips)
	edtMaxClips := g.Add("Edit", "x" left_size-55 " yp-3 w50 r1 Number vnew_MaxClips") 		; 55 = 50(widthofupdown) + 5(margin)
	edtMaxClips.OnEvent("Change", settingsChanged)
	g.Add("UpDown", "Range1-1000", ini_MaxClips).OnEvent("Change", settingsChanged)

	g.Add("Text", "xs+16", TXT.SET_threshold)
	edtThreshold := g.Add("Edit", "x" left_size-55 " yp-3 w50 r1 Number vnew_Threshold")
	edtThreshold.OnEvent("Change", settingsChanged)
	g.Add("UpDown", "Range1-1000", ini_Threshold).OnEvent("Change", settingsChanged)

	g.Add("Text", "xs", TXT.SET_quality)
	g.Add("Edit", "x" left_size-55 " yp-3 w50 r1 Number vnew_Quality").OnEvent("Change", settingsChanged)
	g.Add("UpDown", "Range1-100", ini_Quality).OnEvent("Change", settingsChanged)

	g.Add("Checkbox", "xs Checked" ini_startSearch " vnew_startSearch", TXT.SET_startSearch).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_revFormat2def " vnew_revFormat2def", TXT.SET_revFormat2def).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_CopyBeep " vnew_copyBeep", TXT.SET_copybeep).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_IsMessage " vnew_IsMessage", TXT.SET_ismessage).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_KeepSession " vnew_KeepSession", TXT.SET_keepsession).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_PreserveClipPos " vnew_PreserveClipPos", TXT.SET_keepactivepos).OnEvent("Click", settingsChanged)
	g.Add("Checkbox", "xs Checked" ini_winClipjump " vnew_winClipjump", TXT.SET_winClipjump).OnEvent("Click", settingsChanged)

	g.Add("Text", "xs y+10", TXT.SET_pformat) 		; the y param is not needed but to make it symmetrical
	; Build pformats list (v1 used a "||" marker in the pipe list; v2 selects by index)
	tempLst := ["-original-"]
	tempSel := (ini_def_pformat = "") ? 1 : 0
	for tempK, tempV in PLUGINS.pformat {
		tempLst.Push(tempV["Name"])
		if (ini_def_pformat == tempV["Name"])
			tempSel := tempLst.Length
	}
	ddlPformat := g.Add("DropDownList", "x" left_size-110 " w110 yp-3  r5	vnew_default_pformat", tempLst)
	if tempSel
		ddlPformat.Choose(tempSel)
	ddlPformat.OnEvent("Change", settingsChanged)


	;---- Clipboard H
	g.Add("GroupBox", "xm y" height_group+16 " w" left_size " h" height_downgroup, TXT.SET_cb)  ;

	g.Add("Text", "xp+9 yp+22", TXT.SET_daystostore)
	g.Add("Edit", "x" left_size-55 " yp-3 w50 r1 Number vnew_DaysToStore").OnEvent("Change", settingsChanged)
	g.Add("UpDown", "Range0-100000", ini_DaysToStore).OnEvent("Change", settingsChanged)

	g.Add("Checkbox", "xs y+8 Checked" ini_IsImageStored " vnew_IsImageStored", TXT.SET_images).OnEvent("Click", settingsChanged)

	;---- Shortcuts
	x_ofhotkeys := left_size+right_size+5 - width_hk_control
	;5 is gap betn two adjacent group boxes , 150 is width of hotkey control
	g.Add("GroupBox", "ym w" right_size " h" height_group " vshortcutgroupbox", TXT.SET_shortcuts)
	g.Add("Text", "xp+9 yp+22 section", TXT.SET_pst)
	edtPstK := g.Add("Edit", "Limit1 Uppercase -Wantreturn x" x_ofhotkeys " yp-3 w" width_hk_control " vpst_K", paste_k)
	edtPstK.OnEvent("Change", hotkey_paste)
	g.Add("Text", "xs y+8", TXT.SET_actmd)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vactmd_K", Actionmode_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT.HST__name)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vhst_K", history_k).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT.SET_org)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vorg_K", chOrg_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT._cfilep)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vcfilep_K", Copyfilepath_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT._cfolderp)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vcfolderp_K", Copyfolderpath_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT._cfiled)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vcfiled_K", Copyfiledata_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT.SET_holdclip)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vhldClip_K", holdClip_K).OnEvent("Change", settingsChanged)
	g.Add("Text", "xs y+8", TXT.PLG__name)
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vplugM_K", pluginManager_K).OnEvent("Change", settingsChanged)

	;---- Channels
	g.Add("GroupBox", "xs-9 y" height_group+16 " w" right_size " h" height_downgroup, PROGNAME " " TXT.SET_channels)
	g.Add("Text", "xs yp+22", TXT._pitswp " Hotkey")
	g.Add("Hotkey", "x" x_ofhotkeys " yp-3 w" width_hk_control " vpitswp_K", pitswap_K).OnEvent("Change", settingsChanged)

	;---- Buttons
	size_advanced := getControlInfo("text", TXT.SET_advanced, "w", "Underline")
	g.SetFont("underline")
	g.Add("Text", "y" height_group+height_downgroup+30 " x" left_size+right_size+5-size_advanced " cBlue", TXT.SET_advanced).OnEvent("Click", settings_open_advanced) 	;+5 for gap betn group boxes
	g.Add("Text", "x9 yp cBlue", TXT.SET_manageignore).OnEvent("Click", classTool)
	g.SetFont("norm")
	g.Add("Button", "x" ((left_size+right_size)/2)-60 " yp+23 Default", "&OK").OnEvent("Click", settingsButtonOk) 	;57 in vertical
	g.Add("Button", "x+8", TXT.SET_cancel).OnEvent("Click", settingsButtonCancel)
	btnApply := g.Add("Button", "x+8 Disabled vsettingsButtonApply", TXT.SET_apply)
	btnApply.OnEvent("Click", settingsButtonApply)
	btnApply.Enabled := false
	g.OnEvent("Close", settingsButtonCancel)
	g.OnEvent("Escape", settingsButtonCancel)

	g.Show()

	if (ini_limitMaxClips = 0)
	{
		edtMaxClips.Enabled := false
		edtThreshold.Enabled := false
	}

	;disable hotkey keys
	; v1 also set "Hotkey, IfWinActive" first, but the "Hotkey, If" below replaced that criterion, so only the If-expression applies
	HotIf(IsHotkeyControlActive)
	hkZ(Copyfilepath_K, shortcutblocker_settings, 1)
	hkZ(Copyfolderpath_K, shortcutblocker_settings, 1)
	hkZ(Copyfiledata_K, shortcutblocker_settings, 1)
	hkZ(channel_K, shortcutblocker_settings, 1)
	hkZ(holdclip_K, shortcutblocker_settings, 1)
	hkZ(pitswap_K, shortcutblocker_settings, 1)
	hkZ(actionmode_k, shortcutblocker_settings, 1)
	hkz(pluginManager_K, shortcutblocker_settings, 1)
	hkz(chOrg_K, shortcutblocker_settings, 1)
	HotIf()
	return

	; The v1 labels below used the local settingsHaveChanged, so they are closures of gui_Settings.
	; They must not use assume-global mode (that would stop them from capturing the locals above).

	chkbox_limitMaxClips(*) {
		if (chkLimitMaxClips.Value = 0)
		{
			edtMaxClips.Value := 0
			edtMaxClips.Enabled := false
			edtThreshold.Enabled := false
		}
		else if (chkLimitMaxClips.Value = 1)
		{
			edtMaxClips.Value := !ini_Maxclips ? 20 : ini_MaxClips
			edtMaxClips.Enabled := true
			edtThreshold.Enabled := true
		}
		; there isn't a return on purpose
		settingsChanged()
	}

	; one handler for every v1 label that fell into settingsChanged (edit_*, updown_*, chkbox_*, dropdown_pformat, hotkey_*)
	settingsChanged(*) {
		btnApply.Enabled := true
		settingsHaveChanged := true
	}

	hotkey_paste(*) {
		global pst_K
		pst_K := Trim(edtPstK.Value, "ESCXZAFH `t")
		if (pst_k = "")
			edtPstK.Value := ""
		btnApply.Enabled := true
		settingsHaveChanged := true
	}

	settingsButtonOk(*) {
		SubmitToGlobals(g)
		if settingsHaveChanged		; we don't it to save if settings haven't changed (to increase performance, though minimal)
		{
			save_Settings()
			load_Settings() , validate_Settings()
			trayMenu(1) 	;update Tray menu
			settingsHaveChanged := false
		}
		GuiDestroy("Settings")
	}

	; settingsButtonCancel / settingsGuiEscape / settingsGuiClose
	settingsButtonCancel(*) {
		GuiDestroy("Settings")
		ToolTip(, , , 4)
		settingsHaveChanged := false
		OnMessage(0x200, WM_MOUSEMOVE, 0)
		EmptyMem()
	}

	settingsButtonApply(*) {
		SubmitToGlobals(g)
		if settingsHaveChanged
		{
			save_Settings()
			load_Settings() , validate_Settings()
			settingsHaveChanged := false
		}
		btnApply.Enabled := false
	}

}

settings_open_advanced(*) {
	global
	try {
		Run("notepad.exe " CONFIGURATION_FILE)
		;WinWaitActive, ahk_class Notepad
		;Send ^{vk47} 					;^g
		;sleep 100
		;;Winwait, Go To Line
		;Send % NUMBER_ADVANCED "{vk0d}"
	}
	catch {
		MsgBox(PROGNAME " " TXT.SET_advanced_error, "ERROR", 16)
	}
}

load_Settings(all := false){
; Preconditions: None
; Postconditions: Reads settings from the configuration file and saves them in corresponding variables beginning with "ini_".
	global
	local t, priority, tempVar, MSG_PASTING_t
	ini_limitMaxClips := IniRead(CONFIGURATION_FILE, "Main", "limit_MaxClips", "ERROR")
	ini_MaxClips := IniRead(CONFIGURATION_FILE, "Main", "Minimum_No_Of_Clips_to_be_Active", "ERROR")
	ini_Threshold := IniRead(CONFIGURATION_FILE, "Main", "Threshold", "ERROR")
	ini_IsMessage := IniRead(CONFIGURATION_FILE, "Main", "Show_Copy_Message", "ERROR")
	ini_Quality := IniRead(CONFIGURATION_FILE, "Main", "Quality_of_Thumbnail_Previews", "ERROR")
	ini_CopyBeep := IniRead(CONFIGURATION_FILE, "Main", "CopyBeep", "ERROR")
	ini_KeepSession := IniRead(CONFIGURATION_FILE, "Main", "Keep_Session", "ERROR")
	ini_Version := IniRead(CONFIGURATION_FILE, "System", "Version", "ERROR")
	ini_DaysToStore := IniRead(CONFIGURATION_FILE, "Clipboard_History", "Days_to_store", "ERROR")
	ini_IsImageStored := IniRead(CONFIGURATION_FILE, "Clipboard_History", "Store_images", "ERROR")

	Copyfilepath_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "Copyfilepath_K", "")
	Copyfolderpath_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "Copyfolderpath_K", "")
	Copyfiledata_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "Copyfiledata_K", "")
	paste_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "paste_K", "ERROR") 	; v1 read this without a default; validate_Settings() turns ERROR into "V"
	Actionmode_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "actionmode_k", "")

	pitswap_K := ini_read("Channels", "pitswap_K")

	holdClip_K := ini_read("Shortcuts", "holdClip_K")
	ini_PreserveClipPos := ini_read("Main", "ini_PreserveClipPos")
	pluginManager_K := ini_read("Shortcuts", "pluginManager_K")
	ini_def_pformat := ini_read("Main", "default_pformat")
	chOrg_K := ini_read("Shortcuts", "chOrg_K")
	ini_startSearch := ini_read("Main", "startSearch")
	ini_revFormat2def := ini_read("Main", "revFormat2def")
	history_k := ini_read("Shortcuts", "history_k")

	copyCutShortcuts(0) ; end all old shortcuts
	ini_winClipjump := ini_read("Main", "winClipjump")
	copyCutShortcuts() ; create new shortcuts

	; // below are INI only settings , not loaded by settings editor

	if (all) {
		history_partial := Ini_read("Clipboard_history_window", "partial") ? 1 : 0 	; Important as the use of the var in History tool is such that false = 0 .

		MSG_PASTING_t := IniRead(CONFIGURATION_FILE, "Advanced", "Show_pasting_tip", "")
		MSG_PASTING := MSG_PASTING_t ? MSG_PASTING : ""

		windows_copy_k := IniRead(CONFIGURATION_FILE, "Advanced", "windows_copy_shortcut", "")
		windows_cut_k := IniRead(CONFIGURATION_FILE, "Advanced", "windows_cut_shortcut", "")
		windows_copy_k := HParse(windows_copy_k) , windows_cut_k := Hparse(windows_cut_k)

		ini_is_duplicate_copied := IniRead(CONFIGURATION_FILE, "Advanced", "is_duplicate_copied", "")

		beepFrequency := ini_read("Advanced", "beepFrequency")
		if !beepFrequency
			beepFrequency := 1500

		ignoreWindows := ini_read("Advanced", "ignoreWindows")
		cut_is_delete_windows := ini_read("Advanced", "cut_equalto_delete")
		ini_defEditor := (t:=ini_read("System", "default_editor")) ? t : "Notepad.exe"
		;change priority once
		priority := ini_read("System", "Priority")
		try ProcessSetPriority(priority)
		;v10.7.3
		ini_defImgEditor := (t:=ini_read("System", "default_image_editor")) ? t : "mspaint.exe"
		ini_pstMode_X := ini_read("Advanced", "pstMode_X")
		ini_pstMode_Y := ini_read("Advanced", "pstMode_Y")
		ini_HisCloseOnInstaPaste := ini_read("Advanced", "HisCloseOnInstaPaste")
		; v11.6.1+
		ini_ram_flush := ini_read("Advanced", "RAM_Flush")
		; v12+
		tempVar := ini_read("Advanced", "WinForPasteMode")
		manageWinPasteMode(tempVar ? 1 : 0, 0)
		; v12.5
		ini_monitorClipboard := ini_read("Main", "monitorClipboard")
	}

}

save_Settings()
; WORKS FOR THE SETTINGS EDITOR
; Preconditions: New settings are saved in variables beginning in "new_", corresponding to each setting.
; Postconditions: Settings in variables starting in "new_" are saved in the configuration file in the corresponding key.
{
	global
	IniWrite(new_limitMaxClips, CONFIGURATION_FILE, "Main", "limit_MaxClips")
	IniWrite((new_limitMaxClips ? new_Maxclips : 0), CONFIGURATION_FILE, "Main", "Minimum_No_Of_Clips_to_be_Active")
	IniWrite(new_Threshold, CONFIGURATION_FILE, "Main", "Threshold")
	IniWrite(new_IsMessage, CONFIGURATION_FILE, "Main", "Show_Copy_Message")
	IniWrite(new_Quality, CONFIGURATION_FILE, "Main", "Quality_of_Thumbnail_Previews")
	IniWrite(new_copyBeep, CONFIGURATION_FILE, "Main", "CopyBeep")
	IniWrite(new_KeepSession, CONFIGURATION_FILE, "Main", "Keep_Session")
	IniWrite(new_DaysToStore, CONFIGURATION_FILE, "Clipboard_History", "Days_To_Store")
	IniWrite(new_IsImageStored, CONFIGURATION_FILE, "Clipboard_History", "Store_Images")

	IniWrite(Cfilep_K, CONFIGURATION_FILE, "Shortcuts", "Copyfilepath_K")
	IniWrite(Cfolderp_K, CONFIGURATION_FILE, "Shortcuts", "Copyfolderpath_K")
	IniWrite(Cfiled_K, CONFIGURATION_FILE, "Shortcuts", "Copyfiledata_K")
	IniWrite(pst_k, CONFIGURATION_FILE, "Shortcuts", "paste_K")
	IniWrite(actmd_k, CONFIGURATION_FILE, "Shortcuts", "actionmode_k")

	IniWrite(pitswp_k, CONFIGURATION_FILE, "Channels", "pitswap_K")
	; v10.7.3
	ini_write("Main", "default_pformat", new_default_pformat="-original-" ? "" : new_default_pformat, 0) 	; trim reqd to remove space
	ini_write("Shortcuts", "pluginManager_K", plugM_k, 0)
	ini_write("Shortcuts", "holdClip_K", hldClip_K, 0)
	ini_write("Main", "ini_PreserveClipPos", new_PreserveClipPos, 0)
	ini_write("Shortcuts", "chOrg_K", org_k, 0)
	ini_write("Main", "startSearch", new_startSearch, 0)
	ini_write("Main", "revFormat2def", new_revFormat2def, 0)
	ini_write("Shortcuts", "history_k", hst_k, 0)
	; v12.3+
	ini_write("Main", "winClipjump", new_winClipjump, 0)
	if (new_winClipjump != ini_winClipjump){ ; change win-paste-mode too
		manageWinPasteMode(new_winClipjump, 1)
	}

	;Disable old shortcuts
	  hkZ(Copyfilepath_K, 	copyFile, 0)
	, hkZ(Copyfolderpath_K, copyFolder, 0)
	, hkZ(Copyfiledata_K,   CopyFileData, 0)
	, hkZ(holdClip_K,		holdClip,		0)
	, hkZ(paste_k ? "$" pstIdentifier paste_k : "", paste, 	0)
	, hkZ(pitswap_K, 	   pitSwap, 0)
	, hkZ(actionmode_K, 	actionmode_run, 0)
	, hkZ(pluginManager_K, 	pluginManagerGui, 0)
	, hkZ(chOrg_K, channelOrganizer, 0)
	, hkZ(history_K, history, 0)

	;Re-create shortcuts
	  hkZ(Cfilep_K, copyFile, 1)
	, hkZ(Cfolderp_K, copyFolder, 1)
	, hkZ(Cfiled_K,   CopyFileData, 1)
	, hkZ(hldClip_K,	holdClip,		1)
	, hkZ(pst_k && CLIPJUMP_STATUS ? "$" pstIdentifier pst_k : "", paste, CLIPJUMP_STATUS )
	, hkZ(pitswp_K, pitSwap, 1)
	, hkZ(actmd_k, actionmode_run, 1)
	, hkZ(plugM_k, pluginManagerGui, 1)
	, hkZ(org_K, channelOrganizer, 1)
	, hkZ(hst_k, history, 1)

	;Load settings will load correct values for vars
}

set_pformat(pst_format := ""){
; Sets the default pformat at Clipjump startup , runs after all the plugins have been loaded.
	global
	local k, v, success := 0
	pst_format := pst_format="" ? ini_def_pformat : pst_format
	if (pst_format == "-original-")
		pst_format := ""
	for k,v in PLUGINS.pformat
		if ( v["name"] == pst_format )
		{
			curPformat := v["name"] , curPfunction := v["*"] , curPisPreviewable := v["Previewable"]
			success := 1
			break
		}
	if !success 	; if no match was found = default
		curPformat := "" , curPisPreviewable := 0
	return 1
}

save_Default(full := 1){
; Saves the default settings for Clipjump. Runs at start-up on program update or new installation

	if (full){
	IniWrite(1, CONFIGURATION_FILE, "Main", "limit_MaxClips")
	IniWrite(20, CONFIGURATION_FILE, "Main", "Minimum_No_Of_Clips_to_be_Active")
	IniWrite(10, CONFIGURATION_FILE, "Main", "Threshold")
	IniWrite(1, CONFIGURATION_FILE, "Main", "Show_Copy_Message")
	IniWrite(90, CONFIGURATION_FILE, "Main", "Quality_of_Thumbnail_Previews")
	IniWrite(1, CONFIGURATION_FILE, "Main", "Keep_Session")

	IniWrite(30, CONFIGURATION_FILE, "Clipboard_History", "Days_to_store")
	IniWrite(0, CONFIGURATION_FILE, "Clipboard_History", "Store_Images")
	}

	IniWrite(VERSION, CONFIGURATION_FILE, "System", "Version")
	ini_write("System", "Priority", "N")
	ini_write("System", "default_editor", "Notepad.exe")
	s := "Shortcuts"
	Ini_Write(s, "Copyfilepath_K")
	Ini_Write(s, "Copyfolderpath_K")
	Ini_Write(s, "Copyfiledata_K")
	Ini_write(s, "onetime_k") 			;No default specified
	ini_write(s, "paste_k", "V")
	Ini_write(s, "actionmode_k", "^+a")

	ini_write("Channels",  "pitswap_K")
	;---- Non GUI
	Ini_write(s := "Advanced", "instapaste_write_clipboard", "0")
	ini_write(s, "Show_pasting_tip", "0")
	ini_write(s, "windows_copy_shortcut")
	ini_write(s, "windows_cut_shortcut")
	ini_write(s, "is_duplicate_copied", "1")
	ini_write(s, "beepFrequency", 1500)
	ini_write(s, "ignoreWindows", "")

	ini_write("Main", "CopyBeep", "0")
	ini_write("Advanced", "cut_equalto_delete", cut_is_delete_windows)
	; v10.7.3 added
	ini_write("Main", "default_pformat", "")
	ini_write("Shortcuts", "pluginManager_K", "")
	; v10.7.8
	ini_write("System", "default_image_editor", "mspaint.exe")
	; v10.9
	ini_write("Shortcuts", "holdClip_K", "")
	ini_write("Main", "ini_PreserveClipPos", 1)
	ini_write("Shortcuts", "chOrg_K", "")
	ini_write("Main", "startSearch", 0)
	ini_write("Main", "revFormat2def", 0)
	ini_write("Advanced", "pstMode_X")
	ini_write("Advanced", "pstMode_Y")
	ini_write("Advanced", "HisCloseOnInstaPaste", 1)
	; v11.6.1+
	ini_write("System", "RAM_Flush", 0)
	; V12+
	ini_write("Advanced", "WinForPasteMode", 0)
	; v12.3+
	ini_write("Main", "winClipjump", 0)
	ini_write("Main", "monitorClipboard", 1)

	; DELETE KEYS removed v10.7.2.6
	Ini_delete("Advanced", "Start_with_formatting")
	Ini_delete("Advanced", "Actionmode_keys")
	Ini_delete("Advanced", "history_k") 	; v11.6.1
	ini_delete("Shortcuts", "channel_K") ;v11.6.1+
	Ini_delete("Channels", "IsChannelMin")
}

Ini_write(section, key, value := "", ifblank := true){
	;ifblank==true means write only if key doesn't exist

	v := IniRead(CONFIGURATION_FILE, section, key, "ERROR") 	; v1 IniRead without a default returned ERROR for a missing key

	if ifblank && (v == "ERROR")
		IniWrite(value, CONFIGURATION_FILE, section, key)
	if !ifblank
		IniWrite(value, CONFIGURATION_FILE, section, key)
}

Ini_read(section, key){
	; v1 passed A_Space as the default, which the ini API trims to "" for a missing key
	v := IniRead(CONFIGURATION_FILE, section, key, "")
	return v
}

Ini_delete(section, key){
	try IniDelete(CONFIGURATION_FILE, section, key)
}

validate_Settings()
; The function validates the settings for Clipjump .
; The reason validate_Settings() is not inside load_Settings() is conflicts with Ini_MaxClips and its unlimited value (0).
{
	global

	if !ini_MaxClips			; if blank
		ini_MaxClips := 9999999
	if !IsInteger(ini_MaxClips)
		ini_MaxClips := 20
	if !IsInteger(ini_Threshold)
		ini_Threshold := 10

	CopyMessage := !ini_IsMessage ? "" : MSG_TRANSFER_COMPLETE " {" ( (CN.Name=="") ? "Default" : CN.Name ) "}"

	if !IsInteger(ini_Quality)
		ini_Quality := 20
	if !IsInteger(ini_KeepSession)
		ini_KeepSession := 1

	if !ini_KeepSession && !startUpComplete
		clearData()

	TOTALCLIPS := ini_Threshold + ini_Maxclips
	CN.TotalClips := TotalClips

	; reqd for the chkbox to use Checked0 or Checked1
	ini_IsImageStored := ini_IsImageStored = 0 ? 0 : 1
	ini_DaysToStore := (IsNumber(ini_DaysToStore) && ini_DaysToStore < 0) ? 0 : ini_DaysToStore 	; v2 cannot compare "" with a number
	ini_PreserveClipPos := ini_PreserveClipPos ? 1 : 0
	ini_startSearch := ini_startSearch ? 1 : 0
	ini_revFormat2def := ini_revFormat2def ? 1 : 0
	ini_winClipjump := (ini_winClipjump==1) ? 1 : 0
	ini_monitorClipboard := (ini_monitorClipboard==0) ? 0 : 1

	if !ini_DaysToStore
	{
		NOINCOGNITO := false
		if CALLER_STATUS
			try TraySetIcon("icons\no_history.ico")
		Options_Tray.Check(TXT.TRY_incognito)
	}

	if (paste_K = "ERROR")
		paste_K := "V"
	paste_K := Substr(paste_K, 1, 1)

	ini_ram_flush := ini_ram_flush==1 ? 1 : 0
}
