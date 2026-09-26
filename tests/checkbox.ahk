; The check mark must sit in the middle of its box at every DPI scale. Renders the real
; Theme.DrawCheck into a memory DC and measures the margins around the check. Standalone.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\checkbox.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\src\ui\native\Theme.ahk
SetWorkingDir A_ScriptDir "\.."
global STORE := CJMap(), CJGUI := Map(), ACTIONS := CJMap()

OnError(fatal)
fatal(e, mode) {
	FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*")
	ExitApp 1
}

fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

Theme.Init("light", "4270C4")
g := Gui()
g.BackColor := "808080"      ; distinct from both the accent fill and the white check
cb := g.Add("CheckBox", "w240 h40 Checked", "Monitor the clipboard")
accent := Theme.ToBgr(Theme.Palette["accent"]), mark := Theme.ToBgr(Theme.Palette["accentText"])

for scale in [1, 1.25, 1.5, 1.75, 2] {
	Theme.Scale := scale
	W := 240, H := 40
	sdc := DllCall("GetDC", "Ptr", 0, "Ptr")
	hdc := DllCall("CreateCompatibleDC", "Ptr", sdc, "Ptr")
	hbm := DllCall("CreateCompatibleBitmap", "Ptr", sdc, "Int", W, "Int", H, "Ptr")
	DllCall("ReleaseDC", "Ptr", 0, "Ptr", sdc)
	obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
	rc := Buffer(16), NumPut("Int", 0, "Int", 0, "Int", W, "Int", H, rc)
	Theme.DrawCheck({ctl: cb}, hdc, rc, 0)

	; the box is every accent pixel in the leftmost box-sized strip; the check is the mark pixels inside it
	strip := Round(16 * scale) + 2
	bx0 := by0 := cx0 := cy0 := 9999, bx1 := by1 := cx1 := cy1 := -1
	loop H {
		y := A_Index - 1
		loop strip {
			x := A_Index - 1
			px := DllCall("GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
			if (px = accent)
				bx0 := Min(bx0, x), bx1 := Max(bx1, x), by0 := Min(by0, y), by1 := Max(by1, y)
			else if (px = mark)
				cx0 := Min(cx0, x), cx1 := Max(cx1, x), cy0 := Min(cy0, y), cy1 := Max(cy1, y)
		}
	}
	DllCall("SelectObject", "Ptr", hdc, "Ptr", obm, "Ptr"), DllCall("DeleteObject", "Ptr", hbm), DllCall("DeleteDC", "Ptr", hdc)

	left := cx0 - bx0, right := bx1 - cx1, top := cy0 - by0, bottom := by1 - cy1
	tag := Format("scale {:.2f}: box {}x{}, margins L{} R{} T{} B{}", scale, bx1 - bx0 + 1, by1 - by0 + 1, left, right, top, bottom)
	check(cx1 >= 0 && left >= 1 && right >= 1 && top >= 1 && bottom >= 1, tag " - check drawn inside the box")
	; one pixel of imbalance is the half-pixel floor when box and check extents differ in parity
	check(Abs(left - right) <= 1, tag " - centered horizontally")
	check(Abs(top - bottom) <= 1, tag " - centered vertically")
}

g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
