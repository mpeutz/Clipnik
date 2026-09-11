; settings.ahk - reads, validates and writes settings.ini. The Settings window (src/ui/native/SettingsWin.ahk)
; collects values into a Map and hands them to save_Settings(); nothing here draws anything.

load_Settings(all := false) {
; Postconditions: reads settings from the configuration file into the ini_* globals and the *_K hotkey globals.
; `all` is kept for the callers; every key is read on each call.
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
	paste_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "paste_K", "ERROR") 	; validate_Settings() turns ERROR into "V"
	Actionmode_K := IniRead(CONFIGURATION_FILE, "Shortcuts", "actionmode_k", "")
	onetime_K := ini_read("Shortcuts", "onetime_k")

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

	history_partial := Ini_read("Clipboard_history_window", "partial") ? 1 : 0 	; the History tool relies on false = 0

	ini_showPastingTip := IniRead(CONFIGURATION_FILE, "Advanced", "Show_pasting_tip", "") ? 1 : 0
	MSG_PASTING := ini_showPastingTip ? TXT.TIP_pasting : ""

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
	ini_priority := (t:=ini_read("System", "Priority")) ? t : "N"
	try ProcessSetPriority(ini_priority)
	ini_defImgEditor := (t:=ini_read("System", "default_image_editor")) ? t : "mspaint.exe"
	ini_pstMode_X := ini_read("Advanced", "pstMode_X")
	ini_pstMode_Y := ini_read("Advanced", "pstMode_Y")
	ini_HisCloseOnInstaPaste := ini_read("Advanced", "HisCloseOnInstaPaste")
	ini_instapasteWritesClipboard := ini_read("Advanced", "instapaste_write_clipboard") ? 1 : 0
	; v11.6.1+ (older builds wrote RAM_Flush to [System]; it is read from [Advanced])
	ini_ram_flush := ini_read("Advanced", "RAM_Flush")
	; v12+
	ini_winForPasteMode := ini_read("Advanced", "WinForPasteMode") ? 1 : 0
	manageWinPasteMode(ini_winForPasteMode, 0)
	; v12.5
	ini_monitorClipboard := ini_read("Main", "monitorClipboard")
	; v13
	ini_theme := IniRead(CONFIGURATION_FILE, "Main", "Theme", "system")
	ini_accent := IniRead(CONFIGURATION_FILE, "Main", "Accent", "")
	ini_toastPosition := IniRead(CONFIGURATION_FILE, "Main", "ToastPosition", "cursor")
	ini_respectExclusion := IniRead(CONFIGURATION_FILE, "Main", "respectExclusionFormats", 1)
	ini_searchUsesWindow := IniRead(CONFIGURATION_FILE, "Advanced", "SearchUsesWindow", 0)
	ini_prewarmWebViews := IniRead(CONFIGURATION_FILE, "Advanced", "PrewarmWebViews", 1) ? 1 : 0
	Rules.Load()
	ini_trayMenu := IniRead(CONFIGURATION_FILE, "Main", "TrayMenu", "card") = "system" ? "system" : "card"
}

; v is a Map of the values collected by the Settings window (see SettingsWin.Collect for the keys).
save_Settings(v) {
	global
	local uiChanged
	IniWrite(v["limitMaxClips"], CONFIGURATION_FILE, "Main", "limit_MaxClips")
	IniWrite((v["limitMaxClips"] ? v["MaxClips"] : 0), CONFIGURATION_FILE, "Main", "Minimum_No_Of_Clips_to_be_Active")
	IniWrite(v["Threshold"], CONFIGURATION_FILE, "Main", "Threshold")
	IniWrite(v["IsMessage"], CONFIGURATION_FILE, "Main", "Show_Copy_Message")
	IniWrite(v["Quality"], CONFIGURATION_FILE, "Main", "Quality_of_Thumbnail_Previews")
	IniWrite(v["copyBeep"], CONFIGURATION_FILE, "Main", "CopyBeep")
	IniWrite(v["KeepSession"], CONFIGURATION_FILE, "Main", "Keep_Session")
	IniWrite(v["DaysToStore"], CONFIGURATION_FILE, "Clipboard_History", "Days_To_Store")
	IniWrite(v["IsImageStored"], CONFIGURATION_FILE, "Clipboard_History", "Store_Images")

	IniWrite(v["Cfilep_K"], CONFIGURATION_FILE, "Shortcuts", "Copyfilepath_K")
	IniWrite(v["Cfolderp_K"], CONFIGURATION_FILE, "Shortcuts", "Copyfolderpath_K")
	IniWrite(v["Cfiled_K"], CONFIGURATION_FILE, "Shortcuts", "Copyfiledata_K")
	IniWrite(v["pst_k"], CONFIGURATION_FILE, "Shortcuts", "paste_K")
	IniWrite(v["actmd_k"], CONFIGURATION_FILE, "Shortcuts", "actionmode_k")
	ini_write("Shortcuts", "onetime_k", v["onetime_k"], 0)

	IniWrite(v["pitswp_k"], CONFIGURATION_FILE, "Channels", "pitswap_K")
	ini_write("Main", "default_pformat", v["default_pformat"]="-original-" ? "" : v["default_pformat"], 0)
	ini_write("Shortcuts", "pluginManager_K", v["plugM_k"], 0)
	ini_write("Shortcuts", "holdClip_K", v["hldClip_K"], 0)
	ini_write("Main", "ini_PreserveClipPos", v["PreserveClipPos"], 0)
	ini_write("Shortcuts", "chOrg_K", v["org_k"], 0)
	ini_write("Main", "startSearch", v["startSearch"], 0)
	ini_write("Main", "revFormat2def", v["revFormat2def"], 0)
	ini_write("Shortcuts", "history_k", v["hst_k"], 0)
	ini_write("Main", "winClipjump", v["winClipjump"], 0)
	ini_write("Main", "monitorClipboard", v["monitorClipboard"], 0)
	ini_write("Main", "respectExclusionFormats", v["respectExclusion"], 0)

	ini_write("Clipboard_history_window", "partial", v["history_partial"], 0)
	ini_write("Advanced", "HisCloseOnInstaPaste", v["HisCloseOnInstaPaste"], 0)
	ini_write("Advanced", "instapaste_write_clipboard", v["instapasteWritesClipboard"], 0)

	ini_write("Advanced", "windows_copy_shortcut", v["windows_copy_shortcut"], 0)
	ini_write("Advanced", "windows_cut_shortcut", v["windows_cut_shortcut"], 0)
	ini_write("Advanced", "SearchUsesWindow", v["SearchUsesWindow"], 0)
	ini_write("Advanced", "is_duplicate_copied", v["is_duplicate_copied"], 0)
	ini_write("Advanced", "cut_equalto_delete", v["cut_equalto_delete"], 0)
	ini_write("System", "default_editor", v["default_editor"], 0)
	ini_write("System", "default_image_editor", v["default_image_editor"], 0)
	ini_write("System", "Priority", v["Priority"], 0)
	ini_write("Advanced", "RAM_Flush", v["RAM_Flush"], 0)

	ini_write("Main", "Theme", v["Theme"], 0)
	ini_write("Main", "Accent", v["Accent"], 0)
	ini_write("Main", "ToastPosition", v["ToastPosition"], 0)
	ini_write("Advanced", "beepFrequency", v["beepFrequency"], 0)
	ini_write("Advanced", "Show_pasting_tip", v["Show_pasting_tip"], 0)
	ini_write("Advanced", "pstMode_X", v["pstMode_X"], 0)
	ini_write("Advanced", "pstMode_Y", v["pstMode_Y"], 0)

	; Win-based copy/cut also moves paste mode to the Win key (v12.3 behavior); an explicit paste-mode change wins
	if (v["winClipjump"] != ini_winClipjump)
		manageWinPasteMode(v["winClipjump"], 1)
	if (v["WinForPasteMode"] != ini_winForPasteMode)
		manageWinPasteMode(v["WinForPasteMode"], 1)

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
	, hkZ(onetime_K, oneTime, 0)
	, hkZ(windows_copy_k, windows_copy, 0), hkZ(windows_cut_k, windows_cut, 0)

	;Re-create shortcuts
	  hkZ(v["Cfilep_K"], copyFile, 1)
	, hkZ(v["Cfolderp_K"], copyFolder, 1)
	, hkZ(v["Cfiled_K"],   CopyFileData, 1)
	, hkZ(v["hldClip_K"],	holdClip,		1)
	, hkZ(v["pst_k"] && CLIPJUMP_STATUS ? "$" pstIdentifier v["pst_k"] : "", paste, CLIPJUMP_STATUS )
	, hkZ(v["pitswp_K"], pitSwap, 1)
	, hkZ(v["actmd_k"], actionmode_run, 1)
	, hkZ(v["plugM_k"], pluginManagerGui, 1)
	, hkZ(v["org_K"], channelOrganizer, 1)
	, hkZ(v["hst_k"], history, 1)
	, hkZ(v["onetime_k"], oneTime, 1)
	, hkZ(HParse(v["windows_copy_shortcut"]), windows_copy, 1), hkZ(HParse(v["windows_cut_shortcut"]), windows_cut, 1)

	uiChanged := (v["Theme"] != ini_theme) || (v["Accent"] != ini_accent)
	if (v["ToastPosition"] != ini_toastPosition)
		Toast.Position := v["ToastPosition"]
	if uiChanged
		Theme.SetMode(v["Theme"], v["Accent"])
	if (v["pstMode_X"] != ini_pstMode_X || v["pstMode_Y"] != ini_pstMode_Y)
		Hud.ClearAnchor()
	if v.Has("Rules")
		Rules.Save(v["Rules"])
	;load_Settings() then loads the saved values into the globals
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
	; v11.6.1+ (moved from [System], where it was never read)
	t := IniRead(CONFIGURATION_FILE, "System", "RAM_Flush", "ERROR")
	if (t != "ERROR") {
		ini_write("Advanced", "RAM_Flush", t)
		Ini_delete("System", "RAM_Flush")
	}
	ini_write("Advanced", "RAM_Flush", 0)
	; V12+
	ini_write("Advanced", "WinForPasteMode", 0)
	; v12.3+
	ini_write("Main", "winClipjump", 0)
	ini_write("Main", "monitorClipboard", 1)
	; v13
	ini_write("Main", "Theme", "system")
	ini_write("Main", "Accent", "")
	ini_write("Main", "ToastPosition", "cursor")
	ini_write("Main", "respectExclusionFormats", 1)
	ini_write("Advanced", "SearchUsesWindow", 0)
	ini_write("Advanced", "PrewarmWebViews", 1)
	ini_write("Main", "TrayMenu", "card")

	; DELETE KEYS removed v10.7.2.6
	Ini_delete("Advanced", "Start_with_formatting")
	Ini_delete("Advanced", "Actionmode_keys")
	Ini_delete("Advanced", "history_k") 	; v11.6.1
	ini_delete("Shortcuts", "channel_K") ;v11.6.1+
	Ini_delete("Channels", "IsChannelMin")
}

; AutoHotkey cannot remove windows from a group, so every rebuild creates a fresh group name.
rebuildIgnoreGroup() {
	global ignoreWindows, IGNORE_GROUP
	static n := 0
	IGNORE_GROUP := "ignoreGroup" (++n)
	if (ignoreWindows != "")
		loop parse ignoreWindows, "|"
			if (A_LoopField != "")
				GroupAdd(IGNORE_GROUP, "ahk_class " A_LoopField)
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
	ini_respectExclusion := (ini_respectExclusion==0) ? 0 : 1
	ini_searchUsesWindow := ini_searchUsesWindow ? 1 : 0
	ini_is_duplicate_copied := ini_is_duplicate_copied ? 1 : 0
	ini_HisCloseOnInstaPaste := ini_HisCloseOnInstaPaste ? 1 : 0
	if !InStr("|system|dark|light|", "|" ini_theme "|")
		ini_theme := "system"
	if !InStr("|cursor|bottomright|", "|" ini_toastPosition "|")
		ini_toastPosition := "cursor"
	if !Theme.ValidHex(ini_accent)
		ini_accent := ""

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
