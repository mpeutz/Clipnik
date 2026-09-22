; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;@Plugin-Name Trim Formatting
;@Plugin-Short Trim
;@Plugin-Description Strip off Formatting
;@Plugin-Author Avi
;@Plugin-Tags pformat

;@Plugin-Previewable 0
; Why previewable 0 ? because the text shown in tooltip is only bare text, without formatting... So this function doesn't change anything and thus
; is a waste of time running it.

;@Plugin-param1 Text to remove format off

plugin_pformat_noformatting(zin) {
	global CALLER, STORE, TXT
	zCS := getClipboardFormat()
	if (zCS == "[" TXT.TIP_text "]")
	{
		z := RTrim(zin, "`r`n")
		CALLER := 0, STORE.ClipboardChanged := 1	; make it 0 again to avoid any interference with apps like Excel
		return z
	}
	else
		return zin
}
