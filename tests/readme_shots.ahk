; Takes the README screenshots from a sandbox copy: made-up clips, over a plain full-screen backdrop so nothing
; else on the desktop shows. Saves to %TEMP%\clipnik-readme-shots (the sandbox copy is deleted after a clean run);
; copy the PNGs to docs\screenshots. Runs only when named: tools/test-sandbox.sh readme_shots.ahk
#Requires AutoHotkey v2.0
#Include lib\sandbox_guard.ahk   ; drives a running Clipnik: only ever a sandbox copy's
#Include ..\publicAPI.ahk
#Include ..\lib\gdiplus.ahk
#Include lib\gdiplus_test.ahk
SetTitleMatchMode 2
SendLevel 1
CoordMode "Mouse", "Screen"
fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
	return cond
}
out := A_Temp "\clipnik-readme-shots"
DirCreate(out)
cj := Clipnik()

; the screen area x, y, w, h saved as out\name.png
shot(name, x, y, w, h) {
	global out
	t := Gdip_Startup()
	bm := Gdip_BitmapFromScreen(Round(x) "|" Round(y) "|" Round(w) "|" Round(h))
	ok := Gdip_SaveBitmapToFile(bm, out "\" name ".png") = 0
	Gdip_DisposeImage(bm), Gdip_Shutdown(t)
	check(ok, name ".png " Round(w) "x" Round(h))
}

backdrop := Gui("-Caption +ToolWindow", "readme-backdrop")
backdrop.BackColor := "1F2733"
backdrop.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)

; made-up clips, oldest first; the image ends up newest
clips := ["Meeting moved to Thursday at 10:00 in the small conference room."
	, "https://example.com/articles/clipboard-tips?utm_source=newsletter&utm_medium=email"
	, "hello@example.com"
	, '{"name": "Clipnik", "version": "1.0", "portable": true}'
	, "#4270C4"
	, "C:\Users\Public\Documents\Quarterly report.pdf"]
for c in clips {
	A_Clipboard := c
	Sleep 900
}
t := Gdip_Startup()
bm := Gdip_CreateBitmap(320, 180), g := Gdip_GraphicsFromImage(bm)
Gdip_SetSmoothingMode(g, 4)
Gdip_GraphicsClear(g, 0xFF2F6FB5)
br := Gdip_BrushCreateSolid(0xFFF2B33D), Gdip_FillEllipse(g, br, 200, 30, 90, 90), Gdip_DeleteBrush(br)
br := Gdip_BrushCreateSolid(0xFF2E8B57), Gdip_FillRectangle(g, br, 0, 130, 320, 50), Gdip_DeleteBrush(br)
Gdip_DeleteGraphics(g)
Gdip_SetBitmapToClipboard(bm)
Gdip_DisposeImage(bm), Gdip_Shutdown(t)
Sleep 3000   ; let the copy toasts fade
check(Integer(cj.runFunction("API.getChStrength(0)")) >= 7, "the made-up clips were recorded")

; the paste card, four clips down the stack, over a small editor
ed := Gui("-Caption +Border", "Draft - Notes")   ; no title bar: no AutoHotkey icon or accent color in the shot
ed.SetFont("s11", "Segoe UI")
box := ed.Add("Edit", "w560 h220 +Multi", "Release notes`r`n`r`nThe settings file now lives next to the app:`r`n")
ed.Show("x" (A_ScreenWidth // 2 - 300) " y" (A_ScreenHeight // 2 - 180))
WinWaitActive("Draft - Notes", , 5)
box.Focus(), SendEvent("^{End}")
WinGetPos(&ex, &ey, &ew, &eh, "Draft - Notes")
MouseMove(ex + 120, ey + 150, 0)   ; the card opens by the pointer, so it lands beside the editor
Sleep 300
SendEvent("{Ctrl down}v")
Sleep 300
loop 3 {
	SendEvent("v")
	Sleep 300
}
Sleep 500
if check(WinExist("Clipnik_HUD ahk_class AutoHotkeyGUI"), "the paste card is showing") {
	WinGetPos(&cx, &cy, &cw, &ch, "Clipnik_HUD ahk_class AutoHotkeyGUI")
	x := Min(ex, cx) - 24, y := Min(ey, cy) - 24, w := Max(ex + ew, cx + cw) + 24 - x, h := Max(ey + eh, cy + ch) + 24 - y
	; a card far from the editor makes a large shot that can take in other programs' always-on-top windows
	if check(w <= 1000 && h <= 650, "the card opened beside the editor (" w "x" h ")")
		shot("paste-card", x, y, w, h)
}
SendEvent("{Ctrl up}")
Sleep 600
ed.Destroy()

; the action ring, in the middle of the screen
MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 2, 0)
Sleep 200
SendEvent("^+a")
Sleep 900
if check(WinExist("Clipnik_Ring ahk_class AutoHotkeyGUI"), "the action ring is showing") {
	WinGetPos(&rx, &ry, &rw, &rh, "Clipnik_Ring ahk_class AutoHotkeyGUI")
	shot("action-ring", rx - 16, ry - 16, rw + 32, rh + 32)
}
SendEvent("{Esc}")
Sleep 500

; Clipboard History with the newest clip, the image, selected
cj.runLabel("history")
title := "Clipnik Clipboard History"
if check(WinWait(title, , 10), "History opened") {
	WinActivate(title)
	Sleep 2000
	Send("{Down}")   ; selects the newest clip, the image, so the preview shows it
	Sleep 1200
	WinGetPos(&hx, &hy, &hw, &hh, title)
	shot("history", hx, hy, hw, hh)
	WinClose(title)
}
backdrop.Destroy()
n := 0
loop files out "\*.png"
	n := A_Index
check(n = 3, n " of 3 screenshots in " out)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
