; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
/**
 * This file has functions which help the settings gui and making changes according to settings.ini in general
 */


/**
 * enable/disable the win for paste mode feature
 * @param  {bool} flag   if 1 then enable, else disable
 * @param  {bool} write  if 1 then also write to settings file
 */
manageWinPasteMode(flag, write := 0) {
	global
	; disable old shortcut
	hkZ((paste_k ? "$" pstIdentifier paste_k : ""), paste, 0)
	; set the vars
	if (flag == 1) {
		pstIdentifier := "#"
		pstKeyName := "LWin"
		pastemodekey.l := "k" 	; Win+L is the OS lock screen: it cannot be hooked
	} else {
		pstIdentifier := "^"
		pstKeyName := "Ctrl"
		pastemodekey.l := "l"
	}
	; set the shortcut
	hkZ((paste_k && CLIPJUMP_STATUS ? "$" pstIdentifier paste_k : ""), paste)
	; write
	if (write == 1)
		ini_write("Advanced", "WinForPasteMode", flag, 0)
}
