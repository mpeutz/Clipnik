/*
TT_Console() v0.03
	Use Tooltip as a User Interface

By:
	Avi Aryan

Info:
	keys - stores space separated values of keys that are prompted for a user input
	font_options - Font options as in Gui ( eg -> s8 bold underline )
	font_face - Font face names. Separate them by a | to set prority

Returns >
	The key which has been pressed
*/

;EXAMPLE
;a := TT_Console( "Hi`nPress Y to see another message.`nPress N to exit script", "y n", empty_var, empty_var, 1, "s12", "Arial|Consolas")
;if a = y
;...
;return


TT_Console(msg, keys, x := "", y := "", fontops := "", fontname := "", whichtooltip := 1, followMouse := 0) {
	what_pressed := ""
	is_TTkey_pressed := 0

	hFont := getHFONT(fontops, fontname)
	TooltipEx(msg, x, y, whichtooltip, hFont)

	;create hotkeys
	loop parse keys, A_Space, A_Space
		if (A_LoopField != "")
			hkZ(A_LoopField, check, 1)

	while !is_TTkey_pressed
	{
		if followMouse
		{
			TooltipEx(msg, , , whichtooltip)
			Sleep 100
		} else {
			Sleep 20
		}
	}

	TooltipEx(, , , whichtooltip)

	loop parse keys, A_Space, A_Space
		if (A_LoopField != "")
			hkZ(A_LoopField, check, 0)

	return what_pressed

	check(ThisHotkey := "", *) {
		what_pressed := ThisHotkey
		is_TTkey_pressed := 1
	}
}
