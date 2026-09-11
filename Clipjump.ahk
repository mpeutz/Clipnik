/*
	Clipjump

	Copyright 2013-15 Avi Aryan

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/

;@Ahk2Exe-SetName Clipjump
;@Ahk2Exe-SetDescription Clipjump
;@Ahk2Exe-SetVersion 12.5
;@Ahk2Exe-SetCopyright Avi Aryan
;@Ahk2Exe-SetOrigFilename Clipjump.exe

#Requires AutoHotkey v2.0
#Warn All, StdOut
#Warn Unreachable, Off   ; class definitions after the auto-execute return are hoisted; the warning is spurious
SetWorkingDir A_ScriptDir
#SingleInstance Force
#ClipboardTimeout 0              ;keeping this value low as I already check for OpenClipboard in OnClipboardChange label
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
FileEncoding "UTF-8"
ListLines false
KeyHistory 0
A_HotkeyInterval := 1000
A_MaxHotkeysPerInterval := 1000
SendMode "Event"          ; v1 default; paste-mode timing was tuned against it
SetTitleMatchMode 1       ; v1 default (prefix match)

global ini_LANG := "", H_Compiled := RegExMatch(SubStr(A_AhkPath, InStr(A_AhkPath, "\", , -1) + 1), "iU)^(Clipjump).*(\.exe)$") && (!A_IsCompiled) ? 1 : 0
global mainIconPath := H_Compiled || A_IsCompiled ? A_AhkPath : "icons/icon.ico"

/*
**********************
PROGRAM VARIABLES
**********************
*/

global PROGNAME := "Clipjump"
global VERSION := "12.5"
global CONFIGURATION_FILE := "settings.ini"

; registry of Gui objects keyed by the v1 gui names (History, Settings, chOrg, ...)
global CJGUI := Map()
; storage for dynamically created variables (customizer, API.setVar)
global STORE := CJMap()

ini_LANG := ini_read("System", "lang")
if !ini_LANG
	ini_LANG := "english"
global TXT := Translations_load("languages/" ini_LANG ".txt") 		;Load translations

global AUTHOR := "Mike Peutz"
global ORIGINAL_AUTHOR := "Avi Aryan", AUTHOR_PAGE := "https://github.com/aviaryan/Clipjump"   ; the project this fork continues

global MSG_TRANSFER_COMPLETE := ""
 , MSG_CLIPJUMP_EMPTY := ""
 , MSG_ERROR := ""
 , MSG_MORE_PREVIEW := ""
 , MSG_PASTING := ""
 , MSG_DELETED := ""
 , MSG_ALL_DELETED := ""
 , MSG_CANCELLED := ""
 , MSG_FIXED := ""
 , MSG_HISTORY_PREVIEW_IMAGE := ""
 , MSG_FILE_PATH_COPIED := ""
 , MSG_FOLDER_PATH_COPIED := ""
; Translations_fixglobalVars() runs after the global declarations below (see "GET THE PROGRAM WORKING")

;History Tool
global hidden_date_no := 4, history_w := "", history_partial := 1 ;start off with partial=1 <> much better
global GHICON_PATH := A_ScriptDir "\icons\lucide.ttf"
global DBPATH := "cache\data.db"

/*
****************
BASIC STRUCTURE
****************
*/

; v1 registered its OnClipboardChange label at load time; the clip loader below relies on the callback being live

;Creating Storage Directories
DirCreate("cache")
DirCreate("cache/clips")
DirCreate("cache/thumbs")
DirCreate("cache/history")
try FileSetAttrib("-H", A_WorkingDir "\cache")

;Init Non-Ini Configurations
try FileDelete(A_Temp "/clipjumpcom.txt")
try A_Clipboard := ""


/*
*********
VARIABLES
*********
*/
MonitorGetWorkArea(, &templeft, &temptop, &tempright, &tempbottom)
global WORKINGHT := tempbottom - temptop, restoreCaller := 0, startUpComplete := 0

;Global Inits
global CN := CJMap(), CUSTOMS := CJMap(), CDS := CJMap(), CPS := CJMap(), SEARCHOBJ := CJMap(), HISTORYOBJ := CJMap(), TOTALCLIPS := "", ACTIONMODE := CJMap(), PLUGINS := CJMap()
global cut_is_delete_windows := "XLMAIN QWidget" 			;excel, kingsoft office
global CURSAVE := 0, TEMPSAVE := 0, LASTCLIP := "", LASTFORMAT := "", Islastformat_Changed := 1, IScurCBACTIVE := 0, curPformat := "", curPfunction := "", curPisPreviewable := 0, LASTKIND := ""
global NOINCOGNITO := 1, SPM := CJMap(), protected_DoBeep := 1
global pastemodekey := CJMap(), spmkey := CJMap()
global windows_copy_k := "", windows_cut_k := "", ini_OpenAllChbyDef := 0, pstIdentifier := "^", pstKeyName := (pstIdentifier == "^") ? "Ctrl" : "LWin"

;Initailizing Common Global Variables
global CALLER_STATUS := 1, CLIPJUMP_STATUS := 1
global CALLER := CALLER_STATUS := 1, IN_BACK := 0, MULTIPASTE := 0, PASTEMODE_ACT := 0
global CLIP_ACTION := "", ONCLIPBOARD := 1, ISACTIVEEXCEL := 0, HASCOPYFAILED := 0, ctrlRef := ""		;specific purpose global vars
global wasManualClipboard := false
global LASTIMAGETICK := 0
global Options_Tray := Menu(), Tools_Tray := Menu(), Maintanence_Tray := Menu(), Help_Tray := Menu()

;Global Ini declarations
global ini_IsImageStored := "", ini_Quality := "", ini_MaxClips := "", ini_Threshold := "", ini_isMessage := "", CopyMessage := "", ini_DaysToStore := ""
		, Copyfolderpath_K := "", Copyfilepath_K := "", Copyfiledata_K := "", onetime_K := "", paste_k := "", actionmode_k := "", ini_is_duplicate_copied := "", ini_formatting := ""
		, ini_CopyBeep := "", beepFrequency := "", ignoreWindows := "", ini_defEditor := "", ini_defImgEditor := "", ini_def_Pformat := "", pluginManager_k := "", holdClip_K := "", ini_PreserveClipPos := ""
		, chOrg_K := "", ini_startSearch := "", ini_revFormat2def := "", ini_pstMode_X := "", ini_pstMode_Y := "", ini_HisCloseOnInstaPaste := "", history_K := "", ini_ram_flush := "", ini_winClipjump := 1
		, ini_monitorClipboard := 0, channel_K := "", pitswap_K := "", ini_Version := ""
		, ini_theme := "system", ini_accent := "", ini_toastPosition := "cursor", ini_respectExclusion := 1, ini_searchUsesWindow := 0
		, ini_showPastingTip := 0, ini_instapasteWritesClipboard := 0, ini_winForPasteMode := 0, ini_priority := "N", IGNORE_GROUP := "ignoreGroup", ini_prewarmWebViews := 1, ini_trayMenu := "card"
global ini_limitMaxClips := "", ini_KeepSession := ""
global new_limitMaxClips := "", new_MaxClips := "", new_Threshold := "", new_Quality := "", new_startSearch := "", new_revFormat2def := "", new_copyBeep := ""
	, new_IsMessage := "", new_KeepSession := "", new_PreserveClipPos := "", new_winClipjump := "", new_default_pformat := "", new_DaysToStore := "", new_IsImageStored := ""
	, pst_K := "", actmd_K := "", hst_K := "", org_K := "", cfilep_K := "", cfolderp_K := "", cfiled_K := "", hldClip_K := "", plugM_K := "", pitswp_K := ""

;State shared between the paste-mode routines (v1 kept these as globals written by labels)
global is_pstMode_active := 0, realActive := 0, realclipno := 0, halfClip := "", fixStatus := "", temp_clipboard := ""
		, dopop := 0, oldclip_data := "", oldclip_exist := 0, sleeptime := 300, temp_spmWasActive := 0, firstPasteMode := 0
		, jumpClip_sign := 0, lastClipboardTime := 0, prefs_changed := 0, onetimeOn := 0, isnewdb := 0, temp21 := ""
		, editclip_pid := 0, editclip_cancelled := 0, holdclip_continue := 0, matched_pformat := 0
		, __x := "", __y := "", __fontops := "", __fontname := "", emptyvar := "", empty := "", blank := "", ablankvar := ""

Translations_fixglobalVars() ; copymessage will be globalized and fixed in validateSettings()

; v1 label names resolved to functions for customizer "run = label", API.runLabel and action mode
global ACTIONS := CJMap(
	"paste", paste, "moveBack", moveBack, "cancel", cancel, "delete", delete_mode, "cutclip", cutclip, "copyclip", copyclip, "deleteall", deleteall
	, "nativeCopy", nativeCopy, "nativeCut", nativeCut, "Formatting", Formatting, "fixate", fixate, "TogglejumpClip", TogglejumpClip, "AddjumpClip", AddjumpClip
	, "move_to_first", move_to_first, "navigate_to_first", navigate_to_first, "setClipTag", setClipTag, "multiPaste", multiPaste_run, "endPastemode", endPastemode
	, "Ssuspnd", Ssuspnd, "pstMode_Help", pstMode_Help, "channel_up", channel_up, "channel_down", channel_down, "pitSwap", pitSwap, "holdClip", holdClip
	, "actionmode", actionmode_run, "copyFile", copyFile, "copyFolder", copyFolder, "CopyFileData", CopyFileData, "hlp", hlp, "strtup", strtup
	, "oneTime", oneTime, "incognito", incognito, "export", export, "editclip", editclip_pm, "windows_copy", windows_copy, "windows_cut", windows_cut
	, "disable_clipjump", disable_clipjump, "run_searchpm", run_searchpm, "settings", settings, "history", history, "classTool", classTool
	, "plugin_deleteFileFolder", tray_deleteFileFolder, "main", main, "exit", exitClipjump, "reload", reloadClipjump, "reloadCustom", reloadCustom
	, "emptylabel", emptylabel, "keyblocker", keyblocker, "simplePaste", simplePaste, "searchpm", searchpm, "SPM_dispose", SPM_dispose
	, "channelOrganizer", channelOrganizer, "pluginManagerGUI", pluginManagerGui, "openFaq", openFaq, "openShortcutsHelp", openShortcutsHelp
	, "Exit_actmd", emptylabel)

/*
***********************
GET THE PROGRAM WORKING
***********************
*/

;Setting up Icons
DirCreate("icons")
try FileInstall("icons\no_history.Ico", "icons\no_history.Ico", 0) 			;Allow users to have their icons
try FileInstall("icons\no_monitoring.ico", "icons\no_monitoring.ico", 0)

;MANAGE PROGRAM UPDATE
ini_Version := IniRead(CONFIGURATION_FILE, "System", "Version", "")

if !FileExist(CONFIGURATION_FILE)
{
	save_default(1)
	if !InStr(VERSION, "b") 		; betas have b
	{
		if (MsgBox(TXT.ABT_seehelp, "Recommended", 52) = "Yes")
			hlp()
	}
	if !A_IsAdmin
		MsgBox(TXT.ABT_runadmin, "WARNING", 16)
	try TrayTip(TXT.ABT_cjready, "Clipjump", 1)
}
else if (ini_Version != VERSION)
{
	save_default(0) 			;0 corresponds to selective save
	reloadClipjump() 		; Update plugin includes with what the user has incase he updates his Clipjump
	Sleep 10000 		; to counter race condition
}

; start history
; migrate if needed
global DB := SQLiteDB()
isnewdb := !FileExist(DBPATH) ? 1 : 0
if (!DB.OpenDB(DBPATH))
	MsgBox("some error occured`n" DB.ErrorMsg)

/*
***********************
DEFAULT SETTINGS LOADING
************************
*/
for spmk in StrSplit("Enter|Up|Down|Home", "|")
	spmkey[spmk] := spmk

init_actionmode() ;Initialising Clipjump Channels
initChannels()

/*
********************
LOAD USER SETTINGS
********************
*/
trayMenu() ; before customization and settings as customization can affect tray
;loading Settings
load_Settings(1)
validate_Settings()
loadPlugins()
Transforms.Register()
set_pformat()   ; the default format may be a built-in transform

; ---- modern UI: theme, HUD card, toasts ----
if FileExist(GHICON_PATH)   ; the icon font must be registered before any card is built (Theme caches the font check)
	DllCall("GDI32.DLL\AddFontResourceEx", "Str", GHICON_PATH, "UInt", 0x10, "Int", 0) ; FR_PRIVATE
else
	MsgBox(valueof(TXT.ABT_errorFontIcon), PROGNAME, 16)
Theme.Init(ini_theme, ini_accent)
Theme.OnChange(changeIcon)
changeIcon()   ; the tray icon was set before the theme existed; repaint its ring in the accent
Toast.Position := ini_toastPosition
Hud.Init()
ClipExclusion.Init()
if ini_prewarmWebViews
	SetTimer(WebHost_Prewarm, -3000)
TrayCard.Init()

loop
{
	if !FileExist("cache/Clips/" A_Index ".avc")
	{
		CURSAVE := A_Index - 1, TEMPSAVE := CURSAVE
		break
	}
}


global CLIPS_dir := "cache/clips"
	, THUMBS_dir := "cache/thumbs"
	, FIXATE_txt := "fixed"
	, NUMBER_ADVANCED := 34 + CN.Total 					;the number stores the line number of ADVANCED section

/*
******************************
MORE SETTINGS A/C USER SETTINGS
******************************
*/

for pmk in StrSplit("a|c|s|z|space|x|e|up|down|f|h|Enter|t|F1|q", "|")
	pastemodekey[pmk] := pmk

;Setting Up shortcuts
hkZ((paste_k ? "$" pstIdentifier paste_k : ""), paste)
copyCutShortcuts()
hkZ(Copyfilepath_K, copyFile), hkZ(Copyfolderpath_K, copyFolder)
hkZ(history_K, history)
hkZ(Copyfiledata_K, CopyFileData)
hkZ(onetime_K, oneTime), hkZ(pitswap_K, pitSwap)
hkZ(actionmode_K, actionmode_run), hkZ(pluginManager_k, pluginManagerGui)
hkZ(holdClip_K, holdClip), hkZ(chOrg_K, channelOrganizer)
;more shortcuts
hkZ(windows_copy_k, windows_copy), hkZ(windows_cut_k, windows_cut)

;create Ignore windows group from | separated values
rebuildIgnoreGroup()

/*
*********************
LOAD END-USER CUSTOMIZATIONS
*********************
*/

OnClipboardChange(cjClipboardChanged) 	; after every global above is initialized, before the clips load
loadClipboardDataS()
loadCustomizations()

/*
***************
ERROR HANDLINGS AND
COMPATIBILITY
***************
*/

if (isnewdb == 1) {
	migrateHistory()
}

historyAddKindColumn()
SetTimer(historyBackfillTick, -4000)   ; classify old rows in small batches after startup

/*
**********
LAST WORDS
**********
*/

fillHISTORYOBJ()
historyCleanup() ;Clean History
OnMessage(0x4a, Receive_WM_COPYDATA)  ; 0x4a is WM_COPYDATA
; Portable Startup
if FileExist(A_Startup "/Clipjump.lnk")
{
	FileDelete(A_Startup "/Clipjump.lnk")
	FileCreateShortcut(startupTarget(), A_Startup "/Clipjump.lnk", A_ScriptDir)
	Options_Tray.Check(TXT.TRY_startup)
}
EmptyMem()
lastClipboardTime := 0
startUpComplete := 1
OnExit(onExitHandler)

return

;Tooltip No 1 is used for Paste Mode tips, 2 is used for notifications , 3 is used for updates , 4 was the hover tip , 5 is used in Action Mode
;6 used in Class Tool, 7 in API (Plugin) , 8 used in Customizer, 9 used in history tool, 10 in edit clips, 11 in Channel Organizer

;End Of Auto-Execute================================================================================================================

; what the Startup shortcut should launch: the compiled exe, or the launcher for the portable runtime
startupTarget() {
	global H_Compiled
	if (A_IsCompiled || H_Compiled)
		return A_AhkPath
	return FileExist(A_ScriptDir "\Clipjump.cmd") ? A_ScriptDir "\Clipjump.cmd" : A_ScriptFullPath
}

onExitHandler(*) {
	routines_Exit()
	return 0
}

loadClipboardDataS() {
	global
	local fp, R, Z
	API.showTip(TXT.TIP_initMsg)
	API.blockMonitoring(1)
	loop CN.Total
	{
		fp := "cache\clips" (A_Index - 1 ? A_Index - 1 : "")
		CDS[R := A_Index - 1] := CJMap()
		CPS[R] := ini2Obj(fp "\prefs.ini")
		loop files fp "\*.avc"
		{
			ONCLIPBOARD := "", Z := ""
			if try_ClipboardfromFile(A_LoopFileFullPath, 300)
				Z := tryGetClipboard(500) 	; 300 tries minimize chances of Clipboard recorders like Exekutor to interrupt
			else
				ONCLIPBOARD := 1, Z := ""

			while !ONCLIPBOARD
				Sleep 5
			CDS[R][SubStr(A_LoopFileName, 1, -4)] := Z
		}
	}
	API.removeTip()
	API.blockMonitoring(0)
}

; calls the active paste-format plugin function on text
callPformat(fnName, text) {
	f := FuncByName(fnName)
	return f ? f(text) : text
}

paste(*) {
	global
	Critical "On"
	if WinActive("ahk_group " IGNORE_GROUP)
	{
		Send("^{vk56}")
		return
	}

	CALLER := 0
	if !ctrlRef
		firstPasteMode := 1
	if ini_startSearch && firstPasteMode
		SPM.ACTIVE := 1
	ctrlRef := "pastemode"
	if IN_BACK
		IN_BACK_correction()

	if (TEMPSAVE > CURSAVE) || !TEMPSAVE
		TEMPSAVE := CURSAVE

	if !FileExist(CLIPS_dir "/" TEMPSAVE ".avc")
	{
		if !oldclip_exist
		{
			oldclip_exist := 1
			try oldclip_data := ClipboardAll()
		}

		try A_Clipboard := ""
		hkZ(pstIdentifier pastemodekey.up, channel_up), hkZ(pstIdentifier pastemodekey.down, channel_down) 		;activate the 2 keys to jump channels
		PasteModeTooltip("{" CN.Name "} " MSG_CLIPJUMP_EMPTY, 1) 				;No Clip Exists
		SetTimer(ctrlCheck, 50)
	}
	else
	{
		if !oldclip_exist 					;will be false when V is pressed for 1st time
		{
			oldclip_exist := 1
			try oldclip_data := ClipboardAll()
			catch {
				makeClipboardAvailable(0)  						; make clipbboard available in case it is blocked
			}
		}
		else
			IScurCBACTIVE := 0 				;false it when V is pressed for the 2nd time

		if !is_pstMode_active
			hkZ_pasteMode(1), is_pstMode_active := 1

		if !IScurCBACTIVE 				;if the current clipboard is not asked for , then only load from file
			try_ClipboardfromFile(A_WorkingDir "/" CLIPS_dir "/" TEMPSAVE ".avc") 	; gets file onto clipboard trying 100 times

		temp_clipboard := tryGetClipboard()  	;gets variable with multiple tries

		fixStatus := fixCheck()
		realclipno := CURSAVE - TEMPSAVE + 1

		if (temp_clipboard != "")
		{
			if StrLen(temp_clipboard) > 200
				halfClip := SubStr(temp_clipboard, 1, 200) "`n`n" MSG_MORE_PREVIEW
			else
				halfClip := temp_clipboard
			if curPisPreviewable
				halfClip := callPformat(curPfunction, halfClip)
		}
		realActive := TEMPSAVE
		PasteModeTooltip(temp_clipboard)
		SetTimer(ctrlCheck, 50)

		TEMPSAVE -= 1
		if (TEMPSAVE == 0)
			TEMPSAVE := CURSAVE
	}
	if ini_startSearch && firstPasteMode
		SetTimer(run_searchpm, -10) 	; dont open in this thrd. critical
	firstPasteMode := 0
}

cjClipboardChanged(DataType) {
	global
	local timeDiff, clipboard_copy, temp_lastformat, returnV
	Critical "On"
	if !ONCLIPBOARD
	{
		ONCLIPBOARD := 1 	; if let blank, the label ends quickly
		return
	}
	ONCLIPBOARD := 1 		;used by paste/or another to identify if OnCLipboard has been breached
	if !startUpComplete 	;if not started, not allow - after onclipboard=1 as the purpose of onc is served
		return
	; check for machine-done clipboard manipulations
	timeDiff := TickCount64() - lastClipboardTime
	lastClipboardTime := TickCount64()
	if (timeDiff < 200) {
		return
	}
	; check monitor clipboard setting
	if (ini_monitorClipboard == 0) {
		if (wasManualClipboard == false) {
			return
		} else {
			wasManualClipboard := false
			SetTimer(manualClipboardTimer, 0)
		}
	}
	; ignore windows
	if WinActive("ahk_group " IGNORE_GROUP)
		return
	; content marked private by the source app (password managers): never record it
	if ini_respectExclusion && CALLER && ClipExclusion.IsExcluded() {
		LASTCLIP := "", LASTFORMAT := ""
		Toast.Show(TXT.TIP_clipExcluded, 1200, "warn", "copy")
		return
	}

	if CALLER
	{
		STORE.CBCaptured := 0
		clipboard_copy := "", returnV := "", temp_lastformat := ""
		if !WinActive("ahk_class XLMAIN") {
			try clipboard_copy := makeClipboardAvailable(), ISACTIVEEXCEL := 0
		} else {
			try clipboard_copy := LASTCLIP, ISACTIVEEXCEL := 1
		}  	;so that Cj doesnt open excel clipboard (for a longer time) and cause problems
		;clipboard_copy = lastclip as to remove duplicate copies in excel , ^x or ^c makes lastclip empty

		if ISACTIVEEXCEL
			isLastFormat_changed := 1                           ;same reason as above
		else
			try isLastFormat_changed := (LASTFORMAT != (temp_lastformat := GetClipboardFormat(0))) ? 1 : 0
		if isLastFormat_changed || (LASTCLIP != clipboard_copy) || (clipboard_copy == "")
			returnV := clipChange(DataType, clipboard_copy)
		LASTFORMAT := temp_lastformat, CLIP_ACTION := returnV ? "" : CLIP_ACTION  		;make CLIP_ACTION empty if copy/cut succeeded else let it be so that if window uses
			;2 transfers like Excel , the demand can be fulfilled
		IScurCBACTIVE := returnV 									;current clipboard is active after new data copied to clipboard SUCCESSFULLY
		if clipPref(CN.NG, CURSAVE, FIXATE_txt)	; not active if the first clip is FIXED
			IScurCBACTIVE := 0
		if !ISACTIVEEXCEL 				;excel has known bugs with AHK and manipulating clipboard *infront* of it will cause errors
			makeClipboardAvailable(0) 						;close clipboard in case it is still opened by clipjump
		STORE.CBCaptured := 1
	}
	else
	{
		LASTFORMAT := WinActive("ahk_class XLMAIN") ? "" : GetClipboardFormat(0)
		if restoreCaller
			restoreCaller := "", CALLER := CALLER_STATUS
		if onetimeOn
		{
			onetimeOn := 0 ;--- To avoid OnClipboardChange label to open this routine [IMPORTANT]
			Sleep 500 ;--- Allows the restore Clipboard Transfer in apps
			CALLER := CALLER_STATUS
			autoTooltip("One Time Stop " TXT.TIP_deactivated, 600, 2)
			changeIcon()
		}
	}
}

; reads a clip preference (fixed / Tags) without auto-creating intermediate objects
clipPref(ch, clip, name) {
	global CPS
	if !IsObject(CPS[ch]) || !IsObject(CPS[ch][clip])
		return ""
	return CPS[ch][clip][name]
}

clipChange(CErrorlevel, clipboard_copy) {
	global
	local temp, activeclass, returnV := "", ruleKind, ruleApp, ruleCls, rule, msg

	if (CErrorlevel = 1)
	{
		if (clipboard_copy != LASTCLIP) || (clipboard_copy == "")        ;dont let go if lastclip = clipboard_copy = <empty>
		{
			; copy-time rules: evaluated before anything is stored. Skipped for Excel, where clipboard_copy is
			; still the previous clip's text and every rule would be judged on the wrong content.
			rule := "", ruleKind := "", ruleApp := "", ruleCls := ""
			if !ISACTIVEEXCEL {
				ruleKind := ClipType.Detect(clipboard_copy)
				try ruleApp := WinGetProcessName("A")
				try ruleCls := WinGetClass("A")
				rule := Rules.Evaluate(Rules.List, ruleKind, clipboard_copy, ruleApp, ruleCls)
				if IsObject(rule) && (rule["action"] = "ignore") {
					LASTCLIP := clipboard_copy
					Toast.Show(StrReplace(TXT.RUL_ignored, "%rule%", rule["name"] != "" ? rule["name"] : Rules.Describe(rule)[1]), 1500, "warn", "copy")
					return
				}
			}
			CURSAVE += 1

			if ISACTIVEEXCEL
				LASTCLIP := clipsaver()
			else
				LASTCLIP := clipboard_copy, temp := clipSaver()

			if HASCOPYFAILED
			{
				CURSAVE -= 1, TEMPSAVE := CURSAVE
				return
			}

			LASTKIND := ClipType.Detect(LASTCLIP)
			ClipType.Store(CN.NG, CURSAVE, LASTKIND)

			if IsObject(rule) {
				switch rule["action"] {
					case "transform":
						Rules_ApplyTransform(rule["arg"])
						LASTKIND := ClipType.Detect(LASTCLIP)       ; the transform rewrote the clip
						ClipType.Store(CN.NG, CURSAVE, LASTKIND)
					case "tag": AddClipPref(CN.NG, CURSAVE, "Tags", rule["arg"])
				}
			}

			if NOINCOGNITO && (CN.Name != "pit") {
				addHistoryText(LASTCLIP, A_Now, LASTKIND)
			}

			BeepAt(ini_CopyBeep, beepFrequency)
			if (copyMessage != "") {
				msg := copyMessage
				if IsObject(rule) && (rule["action"] = "channel") && IsInteger(rule["arg"]) && (rule["arg"] != CN.NG) && (rule["arg"] < CN.Total)
					msg := MSG_TRANSFER_COMPLETE " {" (Rules.ChannelName(rule["arg"]) != "" ? Rules.ChannelName(rule["arg"]) : rule["arg"]) "}"
				showCopyToast(msg)
			}

			if (CLIP_ACTION = "CUT")
			{
				activeclass := WinGetClass("A")
				if InStr(cut_is_delete_windows, activeclass)
					Send("{vk2e}") 			;del
			}

			TEMPSAVE := CURSAVE
			if IsObject(rule) && (rule["action"] = "channel") && IsInteger(rule["arg"]) && (rule["arg"] != CN.NG) && (rule["arg"] < CN.Total) {
				API.manageClip(rule["arg"], CN.NG, 1, 0)   ; move the newest clip out of the active channel
				TEMPSAVE := CURSAVE
			}
			while (CURSAVE >= TOTALCLIPS)
				compacter()

			returnV := 1
		}
	}
	else if (CErrorlevel = 2)
	{
			LASTKIND := ""
			CURSAVE += 1, TEMPSAVE := CURSAVE, LASTCLIP := ""

			clipSaver()
			if HASCOPYFAILED
			{
				CURSAVE -= 1, TEMPSAVE := CURSAVE
				return
			}
			; snipping tools write the same image twice in a row; keep one (a deliberate second Ctrl+C still records)
			if imageIsRepeat()
			{
				try FileDelete(CLIPS_dir "/" CURSAVE ".avc")
				CURSAVE -= 1, TEMPSAVE := CURSAVE
				return
			}
			LASTIMAGETICK := A_TickCount

			BeepAt(ini_CopyBeep, beepFrequency)
			if (copyMessage != "")
				Toast.Show(copyMessage, 900, "info", "copy")
			thumbGenerator()

			if NOINCOGNITO && ini_IsImageStored && (CN.Name != "pit") {
				addHistoryImage(THUMBS_dir "\" CURSAVE ".jpg", A_Now)
			}

			while (CURSAVE >= TOTALCLIPS)
				compacter()

			returnV := 2
	}
	emptyMem()
	return returnV
}

moveBack(*) {
	global
	Critical "On"
	if WinActive("ahk_group " IGNORE_GROUP)
		return
	IN_BACK := true
	TEMPSAVE := realActive + 1
	if (realActive = CURSAVE)
		TEMPSAVE := 1
	realActive := TEMPSAVE
	IScurCBACTIVE := 0 			;the key will be always pressed after V
	try_ClipboardfromFile(CLIPS_dir "/" TEMPSAVE ".avc")
	temp_clipboard := tryGetClipboard()

	fixStatus := fixCheck()
	realClipNo := CURSAVE - TEMPSAVE + 1
	if (temp_clipboard != "")
	{
		if StrLen(temp_clipboard) > 200
			halfClip := SubStr(temp_clipboard, 1, 200) "`n`n" MSG_MORE_PREVIEW
		else
			halfClip := temp_clipboard
		if curPisPreviewable
			halfClip := callPformat(curPfunction, halfClip)
	}
	PasteModeTooltip(temp_clipboard)
	SetTimer(ctrlCheck, 50)
}

IN_BACK_correction() { 	; corrects TEMPSAVE value when C (backwards) is used in paste mode
	global
	IN_BACK := false
	if (TEMPSAVE == 1)
		TEMPSAVE := CURSAVE
	else
		TEMPSAVE -= 1
}

;-------------- paste mode tips ------------------------

multiPaste_run(*) {
	global
	if SPM.ACTIVE && WinExist("Clipjump_SPM ahk_class AutoHotkeyGUI") {
		WinHide("Clipjump_SPM ahk_class AutoHotkeyGUI")
		WinWaitNotActive("Clipjump_SPM ahk_class AutoHotkeyGUI")
		temp_spmWasActive := 1
	}
	MULTIPASTE := PASTEMODE_ACT := 1
	while PASTEMODE_ACT
		Sleep 50 		; wait till ctrlCheck: runs
	if MULTIPASTE 		; if multipaste is still ON, becomes OFF due to release of ctrl (which doesnt disturb when spm is active)
		paste()
	if temp_spmWasActive {
		try WinShow("Clipjump_SPM ahk_class AutoHotkeyGUI")
		temp_spmWasActive := 0
	}
}

cancel(*) {
	global
	ctrlref := "cancel"
	Hud.SetMode("cancel")
	if SPM.ACTIVE
		SPM_dispose() 	; dispose it if There - Note that this step ends the label as ctrlCheck dies so ctrlRef is kept upwards to be updated
	hkZ_pasteMode(0, 0), hkZ_pi(pastemodekey.x, delete_mode, 1)
}

delete_mode(*) {
	global
	ctrlref := "delete"
	Hud.SetMode("delete")
	hkZ_pi(pastemodekey.x, delete_mode, 0), hkZ_pi(pastemodekey.x, cutclip, 1)
}

cutclip(*) {
	global
	ctrlref := "cut"
	Hud.SetMode("cut")
	hkZ_pi(pastemodekey.x, cutclip, 0), hkZ_pi(pastemodekey.x, copyclip, 1)
}

copyclip(*) {
	global
	ctrlref := "copy"
	Hud.SetMode("copy")
	hkZ_pi(pastemodekey.x, copyclip, 0), hkZ_pi(pastemodekey.x, deleteall, 1)
}

deleteall(*) {
	global
	ctrlref := "deleteAll"
	Hud.SetMode("deleteall")
	hkZ_pi(pastemodekey.x, deleteall, 0), hkZ_pi(pastemodekey.x, cancel, 1)
}

nativeCopy(*) {
	global
	Critical "On"
	if WinActive("ahk_class XLMAIN")
	{
		copyCutShortcuts(0)
		hkZ("$^c", keyblocker)
		LASTCLIP := ""
		SetTimer(ctrlForCopy, 50)
	}
	if ini_is_duplicate_copied
		LASTCLIP := "", LASTIMAGETICK := 0
	CLIP_ACTION := "COPY"
	wasManualClipboard := true
	SetTimer(manualClipboardTimer, -1000)
	Send("^{vk43}")
}

nativeCut(*) {
	global
	Critical "On"
	if WinActive("ahk_class XLMAIN")
	{
		copyCutShortcuts(0)
		hkZ("$^x", keyblocker)
		LASTCLIP := ""
		SetTimer(ctrlForCopy, 50)
	}
	if ini_is_duplicate_copied
		LASTCLIP := "", LASTIMAGETICK := 0
	CLIP_ACTION := "CUT"
	wasManualClipboard := true
	SetTimer(manualClipboardTimer, -1000)
	Send("^{vk58}")
}

ctrlForCopy(*) {
	if GetKeyState("Ctrl", "P") = 0		; if key is up
	{
		Critical "On" 			;To make sure the hotkeys are changed
		copyCutShortcuts()	; keyblocker is removed bcoz ^x and ^c overwrites it
		SetTimer(ctrlForCopy, 0)
	}
}

manualClipboardTimer(*) {
	global wasManualClipboard
	wasManualClipboard := false
}

; Z in paste mode: the format ring at the pointer. Formats that fit the clip's kind come first, the rest are
; dimmed; the active format is outlined. Release Z over a wedge, click one, or press its letter; Z again or Esc
; closes. Ctrl stays held throughout; releasing it pastes with the current format and closes the ring.
Formatting(*) {
	global
	local kind, m, picked, letter
	if !is_pstMode_active
		return
	kind := (temp_clipboard != "") ? ClipType.Of(CN.NG, realActive) : ""
	m := Formatting_Items(kind)
	picked := Ring.Pick(m.items, {prefix: pstIdentifier, trigger: pastemodekey.z, triggerHotkey: pstIdentifier pastemodekey.z
		, dim: Hud.g.Hwnd, until: Formatting_Ended, idleTitle: curPformat != "" ? curPformat : TXT.HUD_formatOriginal
		, idleSub: TXT.RNG_activeFormat})
	if !is_pstMode_active      ; Ctrl was released while the ring was open: the paste already happened
		return
	hkZ_pasteMode(1)           ; the ring replaced ^z and the letters; paste-mode keys come back
	letter := StrUpper(picked)
	if (letter != "" && m.byKey.Has(letter)) {
		set_pformat(m.byKey[letter])
		if (temp_clipboard != "") {
			halfClip := StrLen(temp_clipboard) > 200 ? SubStr(temp_clipboard, 1, 200) "`n`n" MSG_MORE_PREVIEW : temp_clipboard
			if curPisPreviewable
				halfClip := callPformat(curPfunction, halfClip)
		}
	}
	PasteModeTooltip(temp_clipboard)
}

Formatting_Ended() {
	global is_pstMode_active
	return !is_pstMode_active
}

; ring items for the format ring; returns {items, byKey}: byKey maps an upper-case letter to a format name
; ("-original-" for Original, the sentinel set_pformat reads as "no format"). Formats are listed in a fixed
; priority order, those that fit the clip's kind first. Letters: formats with a preferred letter (the built-ins)
; claim theirs before the others pick from their names, so a plugin can never take a built-in's letter.
Formatting_Items(kind) {
	global PLUGINS, curPformat, TXT
	static priority := ["noformatting", "stripTracking", "markdownLink", "prettyJson", "minifyJson", "sentencecase"
		, "title", "upper", "lower", "oneLine", "slugify", "base64", "commonformats"]
	used := Map("V", 1, "C", 1, "Z", 1), byKey := Map(), letters := Map(), order := [], seen := Map(), fit := [], rest := []
	seen.CaseSense := "Off"
	for k in priority
		if PLUGINS.pformat.HasKey(k)
			order.Push(k), seen[k] := 1
	for k in PLUGINS.pformat
		if !seen.Has(k)
			order.Push(k)
	oL := Formatting_Letter("", "O", used)
	used[oL] := 1, byKey[oL] := "-original-"
	for pass in [1, 2]
		for k in order {
			v := PLUGINS.pformat[k], pref := ""
			try pref := v["key"]
			if ((pass = 1 && pref = "") || (pass = 2 && pref != ""))
				continue
			l := Formatting_Letter(v["name"], pref, used)
			used[l] := 1, byKey[l] := v["name"], letters[k] := l
		}
	fit.Push({key: oL, label: TXT.HUD_formatOriginal, short: TXT.RNG_origShort, desc: TXT.RNG_origDesc, active: curPformat = ""})
	for k in order {
		v := PLUGINS.pformat[k]
		desc := v["desc"] != "" ? v["desc"] : v["Description"]
		it := {key: letters[k], label: v["name"], short: v["short"], desc: desc, active: curPformat = v["name"]
			, dim: !Transforms.AppliesTo(v, kind)}
		(it.dim ? rest : fit).Push(it)
	}
	items := []
	for it in fit
		items.Push(it)
	for it in rest
		items.Push(it)
	return {items: items, byKey: byKey}
}

; first free letter: the preferred one, then letters of the name, then the alphabet
Formatting_Letter(name, pref, used) {
	if (pref != "" && !used.Has(StrUpper(pref)))
		return StrUpper(pref)
	loop parse StrUpper(name)
		if RegExMatch(A_LoopField, "[A-Z]") && !used.Has(A_LoopField)
			return A_LoopField
	loop 26 {
		l := Chr(64 + A_Index)
		if !used.Has(l)
			return l
	}
	return "?"
}

fixate(*) {
	global
	if clipPref(CN.NG, realActive, FIXATE_txt)
		fixStatus := "", CPS[CN.NG][realActive].Remove(FIXATE_txt)
	else
		fixStatus := MSG_FIXED, AddClipPref(CN.NG, realActive, FIXATE_txt, 1)
	prefs_changed := 1
	PasteModeTooltip(temp_clipboard)
}

TogglejumpClip(*) {
	global jumpClip_sign
	jumpClip_sign := !jumpClip_sign
}

AddjumpClip(ThisHotkey := "", *) {
	global
	if IN_BACK
		IN_BACK_correction()
	TEMPSAVE += (!jumpClip_sign ? -SubStr(ThisHotkey, 2) + 1 : SubStr(ThisHotkey, 2) + 1)
	loop 	; as somthing like +9 could make tempsave = 17 when tempsave was 8 and the cursave is also 8
		if (TEMPSAVE > CURSAVE)
			TEMPSAVE := TEMPSAVE - CURSAVE
		else if TEMPSAVE < 1
			TEMPSAVE := CURSAVE + TEMPSAVE
		else
			break
	paste()
}

move_to_first(*) {
	global
	API.manageClip(CN.NG, CN.NG, realClipNo, 0)
	navigate_to_first()
}

navigate_to_first(*) {
	global
	if IN_BACK
		IN_BACK_correction()
	TEMPSAVE := CURSAVE 		; make tempsave 29 if total clips (cursave) is 29 . so load the first (latest) clip
	paste()
}

setClipTag(*) {
	global
	local ib
	endPastemode()
	ib := InputBox(TXT.TIP_tagprompt, TXT._tags, , clipPref(CN.NG, realActive, "Tags"))
	if (ib.Result = "OK")
		AddClipPref(CN.NG, realActive, "Tags", ib.Value), Prefs2Ini(), autoTooltip(TXT.TIP_done, 800, 2)
	else
		autoTooltip(TXT.TIP_cancelled, 800, 2)
	EmptyMem()
}

clipSaver() {
	global
	local copied := 0, tempC := "", tempCB := "", test := ""
	try FileDelete(CLIPS_dir "/" CURSAVE ".avc")
	HASCOPYFAILED := 0
	temp21 := ""

	while !copied
	{
		if (A_Index = 100) || HASCOPYFAILED {
			HASCOPYFAILED := 1
			return
		}
		try {
			if ISACTIVEEXCEL
			{
				foolGUI(1) 										;foolGUI() is a blank gui to get focus over excel [crazy bug- crazy fix]
				tempC := ClipboardAll()
				tempCB := A_Clipboard
				foolGUI(0)
			}
			else
				tempC := ClipboardAll()

			temp21 := "Y"
			if (SubStr(CN.Name, 1, 1) = "_") 		; protected channels
			{
				Critical "Off"
				BeepAt(protected_DoBeep, 2000, 200)
				temp21 := Hud.Confirm("{" CN.Name "}`n" TXT.TIP_confirmcopy, "Y N Insert")   ; "" = the card was hidden mid-prompt
				Critical "On"
			}
			if (temp21 = "Y")
			{
				FileAppend(tempC, CLIPS_dir "/" CURSAVE ".avc")
				CDS[CN.NG][CURSAVE] := ISACTIVEEXCEL ? tempCB : A_Clipboard
				copied := 1
			}
			else {
				LASTCLIP := "", LASTFORMAT := "", HASCOPYFAILED := 1 	; lastclip was not captured by cj
				if (temp21 = "Insert") {
					Toast.Show(TXT["_processing"], 0, "info", "api")
					SetTimer(addClipLater, -50)
				}
			}
		} catch {
			if ISACTIVEEXCEL
				foolGUI(0)
		}
	}
	; check for empty file
	try test := FileRead(CLIPS_dir "/" CURSAVE ".avc", "RAW")
	if !IsObject(test) || !test.Size {
		HASCOPYFAILED := 1 			;actually the return doesnt matter here
		return ""
	}

	manageFIXATE(CURSAVE, CN.NG, CN.N)
	return tempCB
}

manageFIXATE(clipAdded, channel, Dir_constant) {
	; manages how Fixed clip are re-positioned when a new clip is added disturing the order.
	; It is necessary for the new clip to be added at Clip 1 position
	global
	local path_CLIPS, path_THUMBS, tempNo, t_TempNo, z, rmv
	path_CLIPS := "cache\clips" Dir_constant
	path_THUMBS := "cache\thumbs" Dir_constant

	loop clipAdded
	{
		tempNo := clipAdded - A_Index + 1
		if clipPref(channel, tempNo, FIXATE_txt)
		{
			t_TempNo := tempNo + 1
			try FileMove(path_CLIPS "\" t_TempNo ".avc", path_CLIPS "\" t_TempNo "_a.avc")
			try FileMove(path_CLIPS "\" tempNo ".avc", path_CLIPS "\" t_TempNo ".avc")
			try FileMove(path_CLIPS "\" t_TempNo "_a.avc", path_CLIPS "\" tempNo ".avc")

			z := CDS[channel][t_TempNo], CDS[channel][t_TempNo] := CDS[channel][tempNo], CDS[channel][tempNo] := z
			if FileExist(path_THUMBS "\" tempNo ".jpg")
			{
				try FileMove(path_THUMBS "\" t_TempNo ".jpg", path_THUMBS "\" t_TempNo "_a.jpg")
				try FileMove(path_THUMBS "\" tempNo ".jpg", path_THUMBS "\" t_TempNo ".jpg")
				try FileMove(path_THUMBS "\" t_TempNo "_a.jpg", path_THUMBS "\" tempNo ".jpg")
			}
			rmv := CPS[channel][t_TempNo], CPS[channel][t_TempNo] := CPS[channel][tempNo], CPS[channel][tempNo] := rmv
			prefs_changed := 1
		}
	}
	if prefs_changed
		Prefs2Ini()
}


fixCheck() {
	global
	if clipPref(CN.NG, TEMPSAVE, FIXATE_txt)
		return TXT.TIP_fixed
	return ""
}

;Shows the paste-mode card. notpaste=1 shows a plain message instead of the clip preview.
PasteModeTooltip(cText, notpaste := 0) {
	if (notpaste == 1)
		Hud.Message(cText)
	else
		Hud.Render(Hud.FromPasteVars())
}

ctrlCheck(*) {
	global
	local zCb, Coutput
	if ((!GetKeyState(pstKeyName)) && (!SPM.ACTIVE)) || PASTEMODE_ACT
	{
		Critical "On"
		SetTimer(ctrlCheck, 0)
		CALLER := false, sleeptime := 300, TEMPSAVE := realActive 				; keep the current clip pos saved
		; Change vars a/c MULTIPASTE
		if MULTIPASTE && !GetKeyState(pstKeyName) && !temp_spmWasActive 		;if spmIsActive user is not expected to cancel by releasing Ctrl
			if (ctrlRef = "pastemode")
				ctrlRef := "cancel"
		; ---
		if (ctrlRef = "cancel")
		{
			PasteModeTooltip(MSG_CANCELLED, 1)
			sleeptime := 200
		}
		else if (ctrlRef = "deleteAll")
		{
			Critical "Off" 			;End Critical so that the below function can overlap this thread
			IScurCBACTIVE := 0 		; now not active in clipjump

			temp21 := Hud.Confirm(TXT.TIP_delallprompt, "Y N")
			if (temp21 = "Y")
			{
				PasteModeTooltip(MSG_ALL_DELETED, 1)
				clearData()
			}
			else
				PasteModeTooltip(MSG_CANCELLED, 1)

			Critical "On" 			;Just in case this may be required.
		}
		else if (ctrlRef = "delete")
		{
			IScurCBACTIVE := 0
			PasteModeToolTip(MSG_DELETED, 1)
			clearClip(realActive)
		}
		else if (ctrlRef = "cut" || ctrlRef = "copy")
		{
			Hud.Hide()
			Critical "Off"
			temp21 := choosechannelgui()
			if (temp21 != "") && (InStr(temp21, "-") != 1)
			{
				API.manageClip(temp21, "", "", (ctrlref == "cut") ? 0 : 1)
				PasteModeTooltip(TXT.TIP_done, 1)
			}
			else
				PasteModeTooltip(TXT.TIP_copycutfailed, 1)
			Critical "On"
		}
		else if (ctrlRef = "pastemode")
		{
			PasteModeToolTip(MSG_PASTING, 1)
			if (GetKeyState("Shift")) ; POP
				dopop := 1
			if curPformat 	;use curpf to get the func
			{
				Critical "Off"
				API.blockMonitoring(1) 	; this is done to have the boomerang effect ONCLIPBOARD work.
				STORE.ClipboardChanged := 0
				zCb := tryGetClipboard()
				Coutput := ""
				if HasFuncByName(curPfunction)
					Coutput := callPformat(curPfunction, zCb) 	; don't try here, the exception in fileread-filemissing-commonformats will nt allow it.
				; old pformat plugins flag the change themselves; built-in transforms just return the new text
				if STORE.ClipboardChanged || (Coutput != "" && Coutput !== zCb) {
					try A_Clipboard := Coutput, IScurCBACTIVE := 0
				} else
					ONCLIPBOARD := 1
				API.blockMonitoring(0, 5)
				Critical "On"
				Send("^{vk56}")
				sleeptime := 1
			}
			else
			{
				Send("^{vk56}")
				sleeptime := 100
			}
		}

		IN_BACK := is_pstMode_active := oldclip_exist := jumpClip_sign := 0
		hkZ_pasteMode(0)
		restoreCaller := 1 			; Restore CALLER in the ONC label . This a second line of defence wrt to the last line of this label.

		Critical "Off"
		; The below thread will be interrupted when the Clipboard command is executed. The ONC label will exit as CALLER := 0 in the situtaion
		if ((ctrlRef == "pastemode") && dopop) ; pop clip
		{
			clearClip(TEMPSAVE)
			IScurCBACTIVE := 0
		}
		if !ini_PreserveClipPos
			TEMPSAVE := cursave 		; not preserve active clip

		if (ctrlref = "cancel" || ctrlref = "delete" || ctrlref = "DeleteAll")
			if !IScurCBACTIVE 						;dont disturb current clipboard if it is already active
				try A_Clipboard := oldclip_data       ;The command opens, writes and closes clipboard . The ONCC Label is launched when writing takes place.

		Sleep sleeptime
		Hud.Hide()
		Hud.ClearAnchor()

		restoreCaller := PASTEMODE_ACT := 0 	; restoreCaller - make it 0 in case Clipboard was not touched (Pasting was done)
		if !GetKeyState(pstKeyName) && !SPM.ACTIVE
			MULTIPASTE := 0 		; deactivated when Ctrl released
		ctrlRef := ""
		CALLER := CALLER_STATUS
		if ini_revFormat2def
			set_pformat(ini_def_Pformat)
		if prefs_changed
			Prefs2Ini() 	; save preferences in memory
		EmptyMem()
		dopop := 0
	} else {
		; record previous shift presses too
		; is more user convenient
		if (GetKeyState("Shift"))
			dopop := 1
		else
			dopop := 0
	}
}

endPastemode(*) {
	; ends the paste abruptly - as required by export and suspend
	global
	Hud.Hide()
	Hud.ClearAnchor()
	SetTimer(ctrlCheck, 0)
	if SPM.ACTIVE
		SPM_dispose()
	if !ini_PreserveClipPos
		TEMPSAVE := cursave
	else
		TEMPSAVE := realActive
	API.blockMonitoring(1)
	if !IScurCBACTIVE
		try A_Clipboard := oldclip_data
	API.blockMonitoring(0)
	ctrlRef := "", restoreCaller := is_pstMode_active := IN_BACK := oldclip_exist := jumpClip_sign := 0
	hkZ_pasteMode(0), CALLER := CALLER_STATUS
	if ini_revFormat2def
		set_pformat(ini_def_Pformat)
	if prefs_changed
		Prefs2Ini()
	EmptyMem()
}

Ssuspnd(*) {
	global
	endPastemode()
	addToWinClip(realactive, TXT.TIP_syscb)
}

pstMode_Help(*) {
	Hud.SetMode("help")
}

addClipLater(*) {
	global
	local tempVar
	while !STORE.CBCaptured 	; wait for capture to over
		Sleep 50
	tempVar := ClipboardAll()
	API.AddClip(0, tempVar, 1)
	autoTooltip(TXT.TIP_protectedMoved, 700)
}

hkZ_pasteMode(mode := 0, disableAll := 1) {
; mode=0 is for initialising Clipjump
; mode=1 is for init Paste Mode
	global
	Critical "On"

	loop 9
		hkZ(pstIdentifier A_Index, AddjumpClip, mode) 	; above them to allow any modifications
	hkZ(pstIdentifier "-", TogglejumpClip, mode)
	hkZ_pi(pastemodekey.c, moveBack, mode), hkZ_pi(pastemodekey.x, cancel, mode), hkZ_pi(pastemodekey.z, Formatting, mode)
	hkZ_pi(pastemodekey.space, fixate, mode), hkZ_pi(pastemodekey.s, Ssuspnd, mode), hkZ_pi(pastemodekey.e, export, mode)
	hkZ_pi(pastemodekey.up, channel_up, mode), hkZ_pi(pastemodekey.down, channel_down, mode), hkZ_pi(pastemodekey.a, navigate_to_first, mode)
	hkZ_pi(pastemodekey.f, searchpm, mode), hkZ_pi(pastemodekey.h, editclip_pm, mode), hkZ_pi(pastemodekey.enter, multiPaste_run, mode)
	hkZ_pi(pastemodekey.t, setClipTag, mode), hkZ_pi(pastemodekey.F1, pstMode_Help, mode), hkZ_pi(pastemodekey.q, move_to_first, mode)

	if (!mode) && disableAll        ;init Cj
	{
		hkZ_pi(pastemodekey.x, deleteall, 0), hkZ_pi(pastemodekey.x, delete_mode, 0)
		hkZ_pi(pastemodekey.x, cutclip, 0), hkZ_pi(pastemodekey.x, copyclip, 0)
		hkZ("$^x", keyblocker, 0), hkZ("$^c", keyblocker, 0) 			;taken as a preventive step
		copyCutShortcuts()
	}
}

;--------------------------- CHANNEL FUNCTIONS ----------------------------------------------------------------

channel_up(*) {
	global
	CN.NG += 2
	channel_down()
}

channel_down(*) {
	global
	CN.NG -= 1, correctTEMPSAVE()
	if InStr(CN.NG, "-")
		CN.NG := CN.Total - 1
	else if (CN.NG == CN.Total) 		;if no of channels has exceeded
		CN.NG := 0
	changeChannel(CN.NG), CN.pit_NG := ""
	paste()
}

pitSwap(*) {
	global
	local temp
	if (CN.pit_NG != "")
	{
		changeChannel(CN.pit_NG), CN.pit_NG := ""
		, autoTooltip("PitSwap Deactivated", 500)
		return
	}
	if (temp := channel_find("pit")) == ""
		autoTooltip('"Pit" channel not found !', 800, 2)
	else
		CN.pit_NG := CN.NG, changeChannel(temp)
		, autoTooltip("PitSwap Activated", 500)
	EmptyMem()
}

holdClip(*) {
	global
	local temp_cb := "", keyPressed, t_cb := ""
	; cut - make own by clipjump custom ---- send = this, then del
	API.blockMonitoring(1), ONCLIPBOARD := 0, IScurCBACTIVE := 0
	if (STORE.holdClip_preText == "")
		Send(STORE.holdClip_send ? STORE.holdClip_send : "^{vk43}")
	else
		try A_Clipboard := STORE.holdClip_preText
	STORE.holdClip_send := "^{vk43}", STORE.holdClip_preText := "" 	; default

	while !ONCLIPBOARD
	{
		if A_Index > 20
		{
			API.blockMonitoring(0)
			return
		}
		Sleep 50
	}
	holdclip_continue := 1, hkZ((paste_k ? "$" pstIdentifier paste_k : ""), paste, 0) 	; disable paste mode
	try temp_cb := tryGetClipboard()
	keyPressed := Hud.Confirm(TXT.TIP_holdclip "`n`n" SubStr(temp_cb, 1, 200) " ...", "Insert F2 Esc")
	if (keyPressed = "F2")
	{
		guiMsgBox(TXT["_output"], API.runPlugin("pformat.commonformats.ahk", A_Clipboard))
	}
	else if (keyPressed = "Insert")
	{
		try t_cb := ClipboardAll()
		try A_Clipboard := ""
	}
	API.blockMonitoring(0)
	if (keyPressed = "Insert")
		try A_Clipboard := t_cb
	hkZ((paste_k && CLIPJUMP_STATUS ? "$" pstIdentifier paste_k : ""), paste)
	EmptyMem()
}

;---------------     Clips management based functions       ------------------

correctTEMPSAVE() {
	global
	TEMPSAVE += 1 		;to make active clip index be same when switching channels , counter-effects TEMPSAVE-=1 in paste_mode label.
	if in_back
		IN_BACK_correction()
	if (TEMPSAVE > CURSAVE)
		TEMPSAVE := 1
	return TEMPSAVE
}

compacter() {
	global
	local avcNumber
	loop ini_Threshold
	{
		CDS[CN.NG][A_Index] := ""
		try FileDelete(A_WorkingDir "\" CLIPS_dir "\" A_Index ".avc")
		try FileDelete(A_WorkingDir "\" THUMBS_dir "\" A_Index ".jpg")
		CPS[CN.NG].Remove(A_Index)
	}
	loop CURSAVE - ini_Threshold
	{
		avcNumber := A_Index + ini_Threshold
		CDS[CN.NG][A_Index] := CDS[CN.NG][avcNumber], CDS[CN.NG][avcNumber] := ""
		try FileMove(A_WorkingDir "/" CLIPS_dir "/" avcnumber ".avc", A_WorkingDir "/" CLIPS_dir "/" A_Index ".avc", 1)
		try FileMove(A_WorkingDir "/" THUMBS_dir "/" avcnumber ".jpg", A_WorkingDir "/" THUMBS_dir "/" A_Index ".jpg", 1)
	}
	TEMPSAVE := CURSAVE := CURSAVE - ini_Threshold 	; dont use TOTALCLIPS, could be a late clip compaction due to ini
}

clearData() {
	global
	API.emptyChannel(CN.NG)
}

clearClip(realActive) {
	global
	LASTCLIP := ""
	CDS[CN.NG][realActive] := ""
	try FileDelete(CLIPS_dir "\" realactive ".avc")
	try FileDelete(THUMBS_dir "\" realactive ".jpg")
	CPS[CN.NG].Remove(realActive)
	TEMPSAVE := realActive - 1
	if (TEMPSAVE == 0)
		TEMPSAVE := 1
	renameCorrect(realActive)
	CURSAVE -= 1
}

renameCorrect(realActive) {
	global
	local loopTime, newName
	loopTime := CURSAVE - realactive
	loop loopTime
	{
		newName := realActive
		realActive += 1
		CDS[CN.NG][newname] := CDS[CN.NG][realactive], CDS[CN.NG][realActive] := ""
		try FileMove(CLIPS_dir "/" realactive ".avc", CLIPS_dir "/" newname ".avc", 1)
		try FileMove(THUMBS_dir "/" realactive ".jpg", THUMBS_dir "/" newname ".jpg", 1)
	}
}

; True when the image just saved as clip CURSAVE is byte-identical to clip CURSAVE-1 and arrived within 1.5 s of it.
imageIsRepeat() {
	global
	local prev, a, b, fa, fb
	if (A_TickCount - LASTIMAGETICK > 1500)
		return false
	prev := CURSAVE - 1
	if (prev < 1 || CDS[CN.NG][prev] != "")
		return false
	fa := CLIPS_dir "/" prev ".avc", fb := CLIPS_dir "/" CURSAVE ".avc"
	if !FileExist(fa) || (FileGetSize(fa) != FileGetSize(fb))
		return false
	try {
		a := FileRead(fa, "RAW"), b := FileRead(fb, "RAW")
		return DllCall("ntdll\RtlCompareMemory", "Ptr", a, "Ptr", b, "UPtr", a.Size, "UPtr") = a.Size
	}
	return false
}

thumbGenerator() {
	global
	Critical "On"
	ClipWait(3, 1) 				;Dont need a Clipwait here , but just for special cases I put a wait of 3 secs
	Gdip_CaptureClipboard(A_WorkingDir "\" THUMBS_dir "\" CURSAVE ".jpg", ini_Quality)
}

Prefs2Ini() {
	global
	local fp
	loop CN.Total
	{
		fp := "cache\clips" (A_Index - 1 ? A_Index - 1 : "")
		Obj2Ini(CPS[A_Index - 1], fp "\prefs.ini")
	}
	prefs_changed := 0
}

ClipPref_makeKeys(Ch, Cl) {
	global CPS
	static l := ["fixed", "Tags", "Kind"]
	if !IsObject(CPS[Ch])
		CPS[Ch] := CJMap()
	if !IsObject(CPS[Ch][Cl])
		CPS[Ch][Cl] := CJMap()
	for k in l
		if !CPS[Ch][Cl].HasKey(k)
			CPS[Ch][Cl][k] := ""
}

AddClipPref(Ch, Cl, Pr, val) {
	global CPS
	ClipPref_makeKeys(Ch, Cl)
	CPS[Ch][Cl][Pr] := val
}

;~ ;**************** GUI Functions ***************************************************************************


historyCleanup() {
;Cleans history in bunch
	global ini_DaysToStore, DB
	if !ini_DaysToStore                    ;Dont delete old data
		return

	q := "select id from history where (strftime('%s', date('now', '-" ini_DaysToStore " days')) - strftime('%s', time)) > 0"
	if (!DB.Query(q, &recs)) {
		MsgBox("Error history cleanup `n " DB.ErrorMsg "`n" DB.ErrorCode "`n" q)
		return
	}

	DB.Exec("BEGIN TRANSACTION")
	while (recs.Next(&Row) > 0)
	{
		deleteHistoryById(Row[1])
	}
	recs.Free()
	DB.Exec("COMMIT TRANSACTION")
}


;----------------------- ACTION MODE ----------------------------------------------------

actionmode_run(*) {
	global
	local temp_am, act
	update_actionmode()
	temp_am := Hud.Menu(ACTIONMODE.items, ACTIONMODE.keys, PROGNAME " " TXT.ACT__name)
	act := ACTIONMODE[temp_am]
	if (act != "Exit_actmd")
	{
		if InStr(act, "(")
			RunFunc(act)
		else if act
			actionFor(act)()
		else if IsInteger(temp_am) 			; give user chance to override setting
			if changeChannel(temp_am)
				autoTooltip(RegExReplace(TXT.CNL_chngMsg, "%cv1%", temp_am " {" CN.Name "}"), 800, 2)
			else
				autoTooltip(RegExReplace(TXT.CNL_chNtExst, "%cv1%", temp_am " {" CN.Name "}"), 800, 2)
	}
	else
		EmptyMem()
}

init_actionmode() {
	global
	ACTIONMODE := CJMap("H", "history", "O", "channelOrganizer", "C", "copyfile", "X", "copyfolder", "F", "CopyFileData", "D", "disable_clipjump"
		, "P", "pitswap", "T", "onetime", "E", "settings", "F1", "hlp", "Esc", "Exit_actmd", "M", "pluginManager_GUI()", "F2", "OpenShortcutsHelp", "L", "classTool"
		, "U", "API.runPlugin(updateClipjumpClipboard.ahk)", "B", "holdclip"
		, "H_caption", TXT.HST__name, "O_caption", TXT.SET_org, "C_caption", TXT._cfilep, "X_caption", TXT._cfolderp, "F_caption", TXT._cfiled
		, "D_caption", TXT.ACT_disable " " PROGNAME, "P_caption", TXT._pitswp, "T_caption", TXT._ot, "E_caption", TXT.SET__name
		, "F1_caption", TXT.TRY_help, "Esc_caption", TXT.ACT_exit, "M_caption", TXT.PLG__name, "F2_caption", TXT.try_pstmdshorts, "L_caption", TXT.IGN__name
		, "U_caption", TXT.PLG_sync_cb, "B_caption", TXT.SET_holdclip)
}		; use runPlugin so that user might delete plugin

update_actionmode() {
	global
	static numadd := "0123456789"
	local thetext, thekeys := "", k, v, items
	thetext := ""
	.  PROGNAME " " TXT.ACT__name
	. "`n-----------"
	. "`n"
	ACTIONMODE.Remove("text"), ACTIONMODE.Remove("keys"), ACTIONMODE.Remove("items")
	items := [{key: "0..9", caption: TXT.ACT_switchChannel}]

	thetext .= "`n" fillWithSpaces(TXT.ACT_switchChannel, 25) " -  " "0..9"

	for k, v in ACTIONMODE
	if !InStr(k, "_") && (k != "Esc") && v {
		thekeys .= k " "
		thetext .= "`n" fillwithSpaces(ACTIONMODE[k "_caption"] ? ACTIONMODE[k "_caption"] : v, 25) " -  " k
		items.Push({key: k, caption: ACTIONMODE[k "_caption"] ? ACTIONMODE[k "_caption"] : v})
	}
	if ACTIONMODE.Esc {
		thetext .= "`n`n" fillwithSpaces(ACTIONMODE.Esc_caption ? ACTIONMODE.Esc_caption : ACTIONMODE.Esc, 25) " -  Esc", thekeys .= "Esc"
		items.Push({key: "Esc", caption: ACTIONMODE.Esc_caption ? ACTIONMODE.Esc_caption : ACTIONMODE.Esc})
	}
	loop parse numadd
		thekeys .= " " A_LoopField
	ACTIONMODE.keys := Trim(thekeys)
	ACTIONMODE.text := thetext
	ACTIONMODE.items := items
}

;****************COPY FILE/FOLDER/DATA***************************************************************************

copyFile(*) {
	global
	local selectedFile
	copyMessage := MSG_FILE_PATH_COPIED
	selectedFile := GetFile()
	if (selectedFile != "")
		try A_Clipboard := selectedfile
	CopyMessage := MSG_TRANSFER_COMPLETE " {" CN.Name "}"
}

copyFolder(*) {
	global
	local openedFolder
	copyMessage := MSG_FOLDER_PATH_COPIED
	openedFolder := GetFolder()
	if (openedfolder != "")
		try A_Clipboard := openedFolder
	copyMessage := MSG_TRANSFER_COMPLETE " {" CN.Name "}"
}

CopyFileData(*) {
	global
	local selectedFile, temp_extension, oldclip, temp
	hkZ(Copyfiledata_K, CopyFileData, 0) ;disable key for repeate copies

	selectedFile := GetFile()
	temp_extension := SubStr(selectedFile, InStr(selectedFile, ".", , -1) + 1)

	if InStr("|jpg|jpeg|tiff|png|bmp|gif|", "|" temp_extension "|")
		Gdip_SetImagetoClipboard(selectedFile)

	else if InStr("|cj|avc|", "|" temp_extension "|")
	{
		API.blockMonitoring(1)
		try_ClipboardfromFile(selectedFile)
		ClipWait(1, 1)
		oldclip := ClipboardAll()
		API.blockMonitoring(0)
		try A_Clipboard := oldclip
		oldclip := ""           ;The methodology is adopted due to an AHK Bug
	}
	else
	{
		try {
			temp := FileRead(selectedFile)
			A_Clipboard := temp
		}
	}

	Sleep 1000
	hkZ(CopyFileData_k, CopyFileData)
}

;**********       Extra Functions and Labels            *******************************************************

hlp(*) {
	global
	try {
		if A_IsCompiled || H_Compiled
			Run("Clipjump.chm")
		else
			Run(FileExist("Clipjump.chm") ? "Clipjump.chm" : "website\_site\index.html")
	}
}

strtup(*) {
	global
	Options_Tray.ToggleCheck(TXT.TRY_startup)
	if FileExist(A_Startup "/Clipjump.lnk")
		FileDelete(A_Startup "/Clipjump.lnk")
	else
		FileCreateShortcut(startupTarget(), A_Startup "/Clipjump.lnk", A_ScriptDir)
}


;************************************** Helper FUNCTIONS ****************************************

addToWinClip(lastEntry, extraTip) {
	global
	API.blockMonitoring()
	Hud.Message(Valueof(extraTip))
	if CURSAVE
		try A_Clipboard := ClipFileRead(A_WorkingDir "/" CLIPS_dir "/" lastentry ".avc")
	Sleep 1000
	Hud.Hide()
	API.blockMonitoring(0)
}

/**
 * makes the shortcut responsible for copy and cut to clipjump
 * status - enabled/disabled
 * @return {void}
 */
copyCutShortcuts(status := 1) {
	global
	if (ini_winClipjump == 1) {
		hkZ("$^c", windows_copy, status), hkZ("$^x", windows_cut, status)
		hkZ("#c", nativeCopy, status), hkZ("#x", nativeCut, status)
	} else {
		hkZ("$^c", nativeCopy, status), hkZ("$^x", nativeCut, status)
	}
}

historyBackfillTick() {
	if historyBackfillKinds(200)
		SetTimer(historyBackfillTick, -250)
}

; copy toast: message, channel pill, and for a recognized kind its label (and swatch for colors, and an action chip)
showCopyToast(text) {
	global LASTKIND, LASTCLIP
	extra := ""
	if (LASTKIND != "" && LASTKIND != "text") {
		act := ClipType.Primary(LASTKIND, LASTCLIP)
		clip := LASTCLIP
		extra := {label: ClipType.Label(LASTKIND), swatch: LASTKIND = "color" ? ClipType.ColorRgb(LASTCLIP) : ""
			, action: act != "" ? {label: act.short, fn: ClipType_RunLater.Bind(act.id, clip)} : ""}
	}
	Toast.Show(text, extra != "" ? 2500 : 900, "info", "copy", extra)
}

; rewrites the just-saved clip (file, in-memory text, LASTCLIP) with a paste format applied
Rules_ApplyTransform(formatName) {
	global PLUGINS, LASTCLIP, CDS, CN, CURSAVE, CLIPS_dir
	fn := ""
	for k, v in PLUGINS.pformat
		if (v["name"] = formatName)
			fn := v["*"]
	if (fn = "")
		return
	t := callPformat(fn, LASTCLIP)
	if (t == LASTCLIP || t = "")
		return
	API.blockMonitoring(1)
	try {
		A_Clipboard := t
		FileDelete(CLIPS_dir "/" CURSAVE ".avc")
		FileAppend(ClipboardAll(), CLIPS_dir "/" CURSAVE ".avc")
		CDS[CN.NG][CURSAVE] := t, LASTCLIP := t
	}
	API.blockMonitoring(0, 5)
	Critical "On"
}

reloadRules() {
	Rules.Load()
}

changeIcon() {
	global
	try {
		icon := (A_IsCompiled || H_Compiled) ? A_AhkPath : mainIconPath 	; H_Compiled is a user var created if compiled with ahk_h
		if !NOINCOGNITO
			icon := "icons\no_history.ico"
		if !CALLER_STATUS || !CALLER
			icon := "icons\no_monitoring.ico"
		setTrayIcon(icon)
	}
}

; tray icon with the ring in the accent color when the file can be recolored, the plain file otherwise
setTrayIcon(path) {
	h := Theme.AccentIcon(path, 32)
	Theme.AppIcon := h
	if h
		TraySetIcon("HICON:*" h)
	else
		TraySetIcon(path)
	; title bars of windows that already exist
	DetectHiddenWindows true
	for hwnd in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " ProcessExist())
		if h
			try SendMessage(0x80, 1, h, hwnd), SendMessage(0x80, 0, h, hwnd)
	DetectHiddenWindows false
}

oneTime(*) {
	global
	CALLER := false
	onetimeOn := 1
	autoTooltip("One Time Stop " TXT.TIP_activated, 600, 2)
	changeIcon()
}

incognito(*) {
	global
	Options_Tray.ToggleCheck(TXT.TRY_incognito)
	NOINCOGNITO := !NOINCOGNITO
	changeIcon()
}

export(*) {
	global
	local temp
	endPastemode()
	loop
		if !FileExist(temp := A_MyDocuments "\export" A_Index ".cj")
			break
	Toast.Show("{" CN.Name "} Clip " realClipNo " " TXT._exportedto "`n" temp, 2500)
	try FileAppend(ClipboardAll(), temp)
}

editclip_pm(*) {
	global
	correctTEMPSAVE()
	editClip(CN.NG, CURSAVE - TEMPSAVE + 1, "pstmd")
}

editClip(cnl, clip, owner := "none") {
; Opens def editor for editing a clip
	global
	local ClipLoc, EditImg, tmpsv, temp_clipboard2 := "", temp_clipboardall := ""
	clipLoc := API.getClipLoc(cnl, clip), tmpsv := API.getChStrength(cnl) - clip + 1
	if (owner != "pstmd")
	{
		API.blockMonitoring(1)
		try_ClipboardfromFile(clipLoc)
		API.blockMonitoring(0)
	}
	temp_clipboard := tryGetClipboard()
	Toast.Show(TXT.TIP_editing, 0, "info", "edit")
	if (owner = "pstmd")
	{
		IScurCBACTIVE := 1
		endPastemode()
	}
	EditImg := 0
	editclip_cancelled := 0

	if !GetClipboardFormat()
	{
		EditImg := 1
		Gdip_CaptureClipboard(A_WorkingDir "\cache\edit.jpg", 100)
		if !FileExist("cache\edit.jpg")
		{
			autoTooltip(TXT.TIP_editnotdone, 800, 10)
			return
		}
		Run(ini_defImgEditor ' "' A_WorkingDir '\cache\edit.jpg"', , , &editclip_pid)
	}
	else {
		try FileDelete("cache\edit.txt")
		FileAppend(temp_clipboard, "cache\edit.txt")
		Run(ini_defEditor ' "' A_WorkingDir '\cache\edit.txt"', , , &editclip_pid)
	}

	hkZ("Esc", editclip_cancel, 1)
	Critical "Off"

	loop {
		if !ProcessExist(editclip_pid)
			break
		Sleep 100
	}
	if (editclip_cancelled) {
		editclip_cancelled := 0, autoTooltip(TXT.TIP_editnotdone, 800, 10)
		return
	}

	if EditImg {
		API.blockMonitoring(1)
		Gdip_SetImagetoClipboard(A_WorkingDir "\cache\edit.jpg")
		ClipWait(3, 1)
		try FileAppend(ClipboardAll(), clipLoc)
		Gdip_CaptureClipboard(A_WorkingDir "\cache\thumbs" (!cnl ? "" : cnl) "\" tmpsv ".jpg", ini_Quality)
		try FileDelete("cache\edit.jpg")
		API.blockMonitoring(0)
	} else {
		temp_clipboard2 := FileRead("cache\edit.txt")
		API.Text2Binary(temp_clipboard2, &temp_clipboardall)
		try FileDelete(clipLoc)
		FileAppend(temp_clipboardall, clipLoc)
		CDS[cnl][tmpsv] := temp_clipboard2
		ClipType.Store(cnl, tmpsv, ClipType.Detect(temp_clipboard2))   ; the stored kind described the old text
	}

	Toast.Hide("edit")
	autoTooltip(TXT.TIP_editdone, 800, 10)
	if (owner = "pstmd")
		IScurCBACTIVE := false
	STORE.ErrorLevel := 1
	return EditImg ? TXT.HST_viewimage : temp_clipboard2
}

editclip_cancel(*) {
	global
	Critical "On"
	editclip_cancelled := 1
	hkZ("Esc", editclip_cancel, 0)
	try ProcessClose(editclip_pid)
}

windows_copy(*) {
	API.blockMonitoring(1)
	Send("^{vk43}")
	Sleep 100
	makeClipboardAvailable(0)   ;wait till Clipboard is ready
	API.blockMonitoring(0)
}

windows_cut(*) {
	API.blockMonitoring(1)
	Send("^{vk58}")
	Sleep 100
	makeClipboardAvailable(0)
	API.blockMonitoring(0)
}

;Copies text to a var in the script without invoking Clipjump
CopytoVar(clipwait_time := 3, send_macro := "^{vk43}") {
	global
	local oldclip := "", var := ""
	CALLER := 0
	try oldclip := ClipboardAll()
	try A_Clipboard := ""
	Send(send_macro)
	ClipWait(clipwait_time)
	try var := A_Clipboard
	try A_Clipboard := oldclip
	CALLER := CALLER_STATUS
	return var
}

disable_clipjump(*) {
	global
	CLIPJUMP_STATUS := !CLIPJUMP_STATUS
	CALLER := CALLER_STATUS := CLIPJUMP_STATUS
	copyCutShortcuts(CLIPJUMP_STATUS)
	changeIcon()

	hkZ((paste_k ? "$" pstIdentifier paste_k : ""), paste, CLIPJUMP_STATUS)
	if !CLIPJUMP_STATUS
		Options_Tray.Check(TXT.TRY_disable " " PROGNAME)
	else
		Options_Tray.Uncheck(TXT.TRY_disable " " PROGNAME)
	init_actionmode() 			;refresh enable/disable text in action mode
}

routines_Exit() {
	global
	Ini_write("Clipboard_history_window", "partial", history_partial, 0)
	if IsObject(DB) {
		DB.CloseDb()
		DB := ""
	}
	Prefs2Ini()
	updatePluginIncludes()
	DllCall("GDI32.DLL\RemoveFontResourceEx", "Str", GHICON_PATH, "UInt", 0x10, "Int", 0)
}

;#################### COMMUNICATION ##########################################

;The function enables/disables Clipjump with respect to the Communicator.
Act_CjControl(C) {
	MsgBox("Clipjump Controller has been discontinued.", PROGNAME, 48)
}

Receive_WM_COPYDATA(wParam, lParam, *) {
	static k := "API:", cmd := "cmd:"
	a := ""

	D := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"))  ;unicode transfer
	if !IsInteger(D)
		if !InStr(D, k) 	; if both are false and so the input is garbled (chinese)
			D := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"), "UTF-8")  ;ansi conversion
	if InStr(D, k)
		a := Act_API(D, k) 	; done to not cause error if no lib is included
	else
		Act_CjControl(D)

	if !(a is String || a is Number)
		a := "" 	; objects cannot cross the process boundary (v1 wrote an empty string)
	loop 50 {
		if FileExist(A_Temp "\clipjumpcom.txt")
			break
		try FileAppend(a, A_Temp "\clipjumpcom.txt")
		catch
			Sleep 10
	}

	EmptyMem()
	return 1
}

;##############################################################################

#Include %A_ScriptDir%\lib\v2compat.ahk
#Include %A_ScriptDir%\lib\Searchpastemode.ahk
#Include %A_ScriptDir%\lib\Customizer.ahk
#Include %A_ScriptDir%\lib\API.ahk
#Include %A_ScriptDir%\lib\translations.ahk
#Include %A_ScriptDir%\lib\multi.ahk
#Include %A_ScriptDir%\lib\aboutgui.ahk
#Include %A_ScriptDir%\src\ui\native\Theme.ahk
#Include %A_ScriptDir%\src\ui\native\Toast.ahk
#Include %A_ScriptDir%\src\ui\native\Hud.ahk
#Include %A_ScriptDir%\src\ui\native\RingGeom.ahk
#Include %A_ScriptDir%\src\ui\native\Ring.ahk
#Include %A_ScriptDir%\src\ui\native\SettingsWin.ahk
#Include %A_ScriptDir%\src\ui\native\AboutWin.ahk
#Include %A_ScriptDir%\src\ui\native\IgnoredWindowsWin.ahk
#Include %A_ScriptDir%\src\ui\native\RuleDialog.ahk
#Include %A_ScriptDir%\src\ui\native\TrayMenuWin.ahk
#Include %A_ScriptDir%\src\core\clipboard.ahk
#Include %A_ScriptDir%\src\core\cliptype.ahk
#Include %A_ScriptDir%\src\core\transforms.ahk
#Include %A_ScriptDir%\src\core\rules.ahk
#Include %A_ScriptDir%\lib\vendor\Gdip_All.ahk
#Include %A_ScriptDir%\lib\HotkeyParser.ahk
#Include %A_ScriptDir%\lib\anticj_func_labels.ahk
#Include %A_ScriptDir%\src\core\settings.ahk
#Include %A_ScriptDir%\src\core\history.ahk
#Include %A_ScriptDir%\lib\vendor\WebView2\WebView2.ahk
#Include %A_ScriptDir%\lib\vendor\JSON.ahk
#Include %A_ScriptDir%\src\ui\web\WebHost.ahk
#Include %A_ScriptDir%\src\ui\web\HistoryWin.ahk
#Include %A_ScriptDir%\lib\pluginManager.ahk
#Include %A_ScriptDir%\src\ui\web\OrganizerWin.ahk
#Include %A_ScriptDir%\lib\SQLiteDB\SQLiteDB.ahk
#Include %A_ScriptDir%\lib\settingsHelper.ahk
#Include *i %A_ScriptDir%\plugins\_registry.ahk
