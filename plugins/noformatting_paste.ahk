;@Plugin-Name NoFormatting Paste
;@Plugin-Description Pastes current clipboard without formatting. Make first parameter 1 to trim all types of whitespace.
;@Plugin-version 0.2
;@Plugin-Author Avi
;@Plugin-Tags no-format paste
;@Plugin-Silent 1

/*
To create a System Level shortcut, use with Customizer as-

[paste_current_noformatting]
bind = Win+v
run  = API.runPlugin(noformatting_paste.ahk)
	OR
run = API.runPlugin(noformattin_paste.ahk, 1)

*/

plugin_noformatting_paste(trimall := 0) {
	API.blockMonitoring(1) 	; blocks Clipboard monitoring by Clipjump
	try A_Clipboard := trimall ? Trim(A_Clipboard, "`r`n `t") : RTrim(A_Clipboard, "`r`n") 	; Trims clipboard of any formatting
	API.blockMonitoring(0) 	; enable monitoring now
	Send("^{vk56}") 	; i.e. ^v
}
