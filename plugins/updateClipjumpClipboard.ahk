; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;@Plugin-Name Sync Clipjump Clipboard
;@Plugin-Silent 1
;@Plugin-Description Updates/Syncs clipjump clipboards with the current active system clipboard
;@Plugin-Author Avi
;@Plugin-Version 0.1
;@Plugin-Tags system clipboard clipjump

;@Plugin-param1 Pass 1 or True to show confirmation message after updating

plugin_updateClipjumpClipboard(zMsg := 1) {
	failed := 0
	try
		zcb := ClipboardAll()
	catch
		failed := 1
	try
		A_Clipboard := zcb
	catch
		failed := 1
	Sleep 500
	if zMsg
		if !failed
			API.showTip("Both Clipboards were synced. Success !", 1200)
		else
			API.showTip("Operation Failed ! There was an error", 1200)
}
