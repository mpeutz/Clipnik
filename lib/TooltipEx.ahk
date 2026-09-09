; ======================================================================================================================
; ToolTipEx()     Display ToolTips with custom fonts and colors.
;                 Code based on the original AHK ToolTip implementation in Script2.cpp.
; Tested with:    AHK 1.1.15.04 (A32/U32/U64)
; Tested on:      Win 8.1 Pro (x64)
; Change history:
;     1.1.01.00/2014-08-30/just me     -  fixed  bug preventing multiline tooltips.
;     1.1.00.00/2014-08-25/just me     -  added icon support, added named function parameters.
;     1.0.00.00/2014-08-16/just me     -  initial release.
; Parameters:
;     Text           -  the text to display in the ToolTip.
;                       If omitted or empty, the ToolTip will be destroyed.
;     X              -  the X position of the ToolTip.
;                       Default: "" (mouse cursor)
;     Y              -  the Y position of the ToolTip.
;                       Default: "" (mouse cursor)
;     WhichToolTip   -  the number of the ToolTip.
;                       Values:  1 - 20
;                       Default: 1
;     HFONT          -  a HFONT handle of the font to be used.
;                       Default: 0 (default font)
;     BgColor        -  the background color of the ToolTip.
;                       Values:  RGB integer value or HTML color name.
;                       Default: "" (default color)
;     TxColor        -  the text color of the TooöTip.
;                       Values:  RGB integer value or HTML color name.
;                       Default: "" (default color)
;     HICON          -  the icon to display in the upper-left corner of the TooöTip.
;                       This can be the number of a predefined icon (1 = info, 2 = warning, 3 = error - add 3 to
;                       display large icons on Vista+) or a HICON handle. Specify 0 to remove an icon from the ToolTip.
;                       Default: "" (no icon)
;     CoordMode      -  the coordinate mode for the X and Y parameters, if specified.
;                       Values:  "C" (Client), "S" (Screen), "W" (Window)
;                       Default: "W" (CoordMode, ToolTip, Window)
; Return values:
;     On success: The HWND of the ToolTip window.
;     On failure: False (ErrorLevel contains additional informations)
; Ported to AutoHotkey v2 for Clipjump. Behavior unchanged; Buffers replace VarSetCapacity.

ToolTipEx(Text := "", X := "", Y := "", WhichToolTip := 1, HFONT := "", BgColor := "", TxColor := "", HICON := "", CoordMode := "W") {
	; ToolTip messages
	Static ADDTOOL  := 0x0432 ; TTM_ADDTOOLW
	Static BKGCOLOR := 0x0413 ; TTM_SETTIPBKCOLOR
	Static MAXTIPW  := 0x0418 ; TTM_SETMAXTIPWIDTH
	Static SETMARGN := 0x041A ; TTM_SETMARGIN
	Static SETTHEME := 0x200B ; TTM_SETWINDOWTHEME
	Static SETTITLE := 0x0421 ; TTM_SETTITLEW
	Static TRACKACT := 0x0411 ; TTM_TRACKACTIVATE
	Static TRACKPOS := 0x0412 ; TTM_TRACKPOSITION
	Static TXTCOLOR := 0x0414 ; TTM_SETTIPTEXTCOLOR
	Static UPDTIPTX := 0x0439 ; TTM_UPDATETIPTEXTW
	; Other constants
	Static MAX_TOOLTIPS := 20 ; maximum number of ToolTips to appear simultaneously
	Static SizeTI   := (4 * 6) + (A_PtrSize * 6) ; size of the TOOLINFO structure
	Static OffTxt   := (4 * 6) + (A_PtrSize * 3) ; offset of the lpszText field
	Static TT := [] ; ToolTip array: {HW, TX (Buffer holding the text)}
	; HTML Colors (BGR)
	Static HTML := Map("AQUA", 0xFFFF00, "BLACK", 0x000000, "BLUE", 0xFF0000, "FUCHSIA", 0xFF00FF, "GRAY", 0x808080, "GREEN", 0x008000
					  , "LIME", 0x00FF00, "MAROON", 0x000080, "NAVY", 0x800000, "OLIVE", 0x008080, "PURPLE", 0x800080, "RED", 0x0000FF
					  , "SILVER", 0xC0C0C0, "TEAL", 0x808000, "WHITE", 0xFFFFFF, "YELLOW", 0x00FFFF)
	; -------------------------------------------------------------------------------------------------------------------
	; Init TT on first call
	If (TT.Length = 0)
		Loop MAX_TOOLTIPS
			TT.Push({HW: 0, TX: ""})
	; -------------------------------------------------------------------------------------------------------------------
	; Check params
	TTTX := Text
	TTXP := X
	TTYP := Y
	TTIX := WhichToolTip = "" ? 1 : WhichToolTip
	TTHF := HFONT = "" ? 0 : HFONT
	TTBC := BgColor
	TTTC := TxColor
	TTIC := HICON
	TTCM := CoordMode = "" ? "W" : SubStr(CoordMode, 1, 1)
	If (TTXP != "") && !IsDigit(String(TTXP))
		Return False
	If (TTYP != "") && !IsDigit(String(TTYP))
		Return False
	If (TTIX < 1) || (TTIX > MAX_TOOLTIPS)
		Return False
	If (TTHF) && !(DllCall("Gdi32.dll\GetObjectType", "Ptr", TTHF, "UInt") = 6) ; OBJ_FONT
		Return False
	If IsInteger(TTBC)
		TTBC := ((TTBC >> 16) & 0xFF) | (TTBC & 0x00FF00) | ((TTBC & 0xFF) << 16)
	Else
		TTBC := HTML.Has(StrUpper(TTBC)) ? HTML[StrUpper(TTBC)] : ""
	If IsInteger(TTTC)
		TTTC := ((TTTC >> 16) & 0xFF) | (TTTC & 0x00FF00) | ((TTTC & 0xFF) << 16)
	Else
		TTTC := HTML.Has(StrUpper(TTTC)) ? HTML[StrUpper(TTTC)] : ""
	If !InStr("CSW", TTCM)
		Return False
	; -------------------------------------------------------------------------------------------------------------------
	; Destroy the ToolTip window, if Text is empty
	TTHW := TT[TTIX].HW
	If (TTTX = "") {
		If TTHW && DllCall("User32.dll\IsWindow", "Ptr", TTHW, "UInt")
			DllCall("User32.dll\DestroyWindow", "Ptr", TTHW)
		TT[TTIX] := {HW: 0, TX: ""}
		Return True
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Get the virtual desktop rectangle
	DTW := {L: SysGet(76), T: SysGet(77)}
	DTW.R := DTW.L + SysGet(78), DTW.B := DTW.T + SysGet(79)
	; -------------------------------------------------------------------------------------------------------------------
	; Initialise the ToolTip coordinates. If either X or Y is empty, use the cursor position for the present.
	PT := {X: 0, Y: 0}
	Cursor := {X: 0, Y: 0}
	If (TTXP = "") || (TTYP = "") {
		CursorBuf := Buffer(8, 0)
		DllCall("User32.dll\GetCursorPos", "Ptr", CursorBuf)
		Cursor := {X: NumGet(CursorBuf, 0, "Int"), Y: NumGet(CursorBuf, 4, "Int")}
		PT := {X: Cursor.X + 16, Y: Cursor.Y + 16}
	}
	; -------------------------------------------------------------------------------------------------------------------
	; If either X or Y  is specified, get the position of the active window considering CoordMode.
	Origin := {X: 0, Y: 0}
	If ((TTXP != "") || (TTYP != "")) && ((TTCM = "W") || (TTCM = "C")) {
		HWND := DllCall("User32.dll\GetForegroundWindow", "UPtr")
		If (TTCM = "W") {
			WX := 0, WY := 0
			try WinGetPos(&WX, &WY, , , "ahk_id " HWND)
			Origin := {X: WX, Y: WY}
		}
		Else {
			OriginPT := Buffer(8, 0)
			DllCall("User32.dll\ClientToScreen", "Ptr", HWND, "Ptr", OriginPT)
			Origin := {X: NumGet(OriginPT, 0, "Int"), Y: NumGet(OriginPT, 0, "Int")}
		}
	}
	; -------------------------------------------------------------------------------------------------------------------
	; If either X or Y is specified, use the window related position for this parameter.
	If (TTXP != "")
		PT.X := TTXP + Origin.X
	If (TTYP != "")
		PT.Y := TTYP + Origin.Y
	; -------------------------------------------------------------------------------------------------------------------
	; Create and fill a TOOLINFO structure. The text buffer must outlive the call, so it is kept in TT.
	TXB := Buffer(StrPut(TTTX, "UTF-16"))
	StrPut(TTTX, TXB, "UTF-16")
	TT[TTIX].TX := TXB
	TI := Buffer(SizeTI, 0) ; TOOLINFO structure
	NumPut("UInt", SizeTI, TI, 0)
	NumPut("UInt", 0x0020, TI, 4) ; TTF_TRACK
	NumPut("Ptr", TXB.Ptr, TI, OffTxt)
	; -------------------------------------------------------------------------------------------------------------------
	; If the ToolTip window doesn't exist, create it.
	If !(TTHW) || !DllCall("User32.dll\IsWindow", "Ptr", TTHW, "UInt") {
		; ExStyle = WS_TOPMOST, Style = TTS_NOPREFIX | TTS_ALWAYSTIP
		TTHW := DllCall("User32.dll\CreateWindowEx", "UInt", 8, "Str", "tooltips_class32", "Ptr", 0, "UInt", 3
								, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr", A_ScriptHwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", ADDTOOL, "Ptr", 0, "Ptr", TI)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", MAXTIPW, "Ptr", 0, "Ptr", A_ScreenWidth)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKPOS, "Ptr", 0, "Ptr", (PT.X & 0xFFFF) | (PT.Y << 16))
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKACT, "Ptr", 1, "Ptr", TI)
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Update the text and the font and colors, if specified.
	If (TTBC != "") || (TTTC != "") { ; colors
		DllCall("UxTheme.dll\SetWindowTheme", "Ptr", TTHW, "Ptr", 0, "Str", "")
		RC := Buffer(16, 0)
		NumPut("Int", 4, "Int", 4, "Int", 4, "Int", 1, RC)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", SETMARGN, "Ptr", 0, "Ptr", RC)
		If (TTBC != "")
			DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", BKGCOLOR, "Ptr", TTBC, "Ptr", 0)
		If (TTTC != "")
			DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TXTCOLOR, "Ptr", TTTC, "Ptr", 0)
	}
	If (TTIC != "")
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", SETTITLE, "Ptr", TTIC, "Str", " ")
	If (TTHF) ; font
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", 0x0030, "Ptr", TTHF, "Ptr", 1) ; WM_SETFONT
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", UPDTIPTX, "Ptr", 0, "Ptr", TI)
	; -------------------------------------------------------------------------------------------------------------------
	; Get the ToolTip window dimensions.
	RC := Buffer(16, 0)
	DllCall("User32.dll\GetWindowRect", "Ptr", TTHW, "Ptr", RC)
	TTRC := {L: NumGet(RC, 0, "Int"), T: NumGet(RC, 4, "Int"), R: NumGet(RC, 8, "Int"), B: NumGet(RC, 12, "Int")}
	TTW := TTRC.R - TTRC.L
	TTH := TTRC.B - TTRC.T
	; -------------------------------------------------------------------------------------------------------------------
	; Check if the Tooltip will be partially outside the virtual desktop and adjust the position, if necessary.
	If (PT.X + TTW >= DTW.R)
		PT.X := DTW.R - TTW - 1
	If (PT.Y + TTH >= DTW.B)
		PT.Y := DTW.B - TTH - 1
	; -------------------------------------------------------------------------------------------------------------------
	; Check if the cursor is inside the ToolTip window and adjust the position, if necessary.
	If (TTXP = "") || (TTYP = "") {
		TTRC.L := PT.X, TTRC.T := PT.Y, TTRC.R := TTRC.L + TTW, TTRC.B := TTRC.T + TTH
		If (Cursor.X >= TTRC.L) && (Cursor.X <= TTRC.R) && (Cursor.Y >= TTRC.T) && (Cursor.Y <= TTRC.B)
			PT.X := Cursor.X - TTW - 3, PT.Y := Cursor.Y - TTH - 3
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Show the Tooltip using the final coordinates.
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKPOS, "Ptr", 0, "Ptr", (PT.X & 0xFFFF) | (PT.Y << 16))
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKACT, "Ptr", 1, "Ptr", TI)
	TT[TTIX].HW := TTHW
	Return TTHW
}
