; gdiplus_test.ahk - Gdip_* helpers only the tests use, on top of lib/gdiplus.ahk.

; a bitmap of the screen area "x|y|w|h"
Gdip_BitmapFromScreen(area) {
	a := StrSplit(area, "|")
	screen := DllCall("GetDC", "Ptr", 0, "Ptr")
	hdc := CreateCompatibleDC(screen), hbm := CreateDIBSection(a[3], a[4], screen), old := SelectObject(hdc, hbm)
	DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", a[3], "Int", a[4], "Ptr", screen, "Int", a[1], "Int", a[2], "UInt", 0x40CC0020)   ; SRCCOPY | CAPTUREBLT
	SelectObject(hdc, old), DeleteDC(hdc), DllCall("ReleaseDC", "Ptr", 0, "Ptr", screen)
	bitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
	DeleteObject(hbm)
	return bitmap
}
