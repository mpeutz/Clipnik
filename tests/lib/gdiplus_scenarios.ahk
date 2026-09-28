; gdiplus_scenarios.ahk - the images tests/gdiplus.ahk draws, saves and reads back through the Gdip_* functions,
; each written to a file in dir. The reference copies in tests/fixtures/gdiplus were made the same way with the
; Gdip_All library these functions replaced. Needs lib/gdiplus.ahk (or a library with the same functions),
; Theme, RingGeom, Ring and translations included, and the working dir at the repository root.

GdipScenarios(dir) {
	token := Gdip_Startup()

	; shapes: a clear, an ellipse, a rounded path, a pen outline and a translucent rectangle, antialiased
	bm := Gdip_CreateBitmap(96, 64), g := Gdip_GraphicsFromImage(bm)
	Gdip_SetSmoothingMode(g, 4)
	Gdip_GraphicsClear(g, 0xFF20304A)
	br := Gdip_BrushCreateSolid(0xCCFF8800), Gdip_FillEllipse(g, br, 10, 8, 50, 40), Gdip_DeleteBrush(br)
	path := Gdip_CreatePath()
	DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 40, "Float", 20, "Float", 20, "Float", 20, "Float", 180, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 70, "Float", 20, "Float", 20, "Float", 20, "Float", 270, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 70, "Float", 40, "Float", 20, "Float", 20, "Float", 0, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 40, "Float", 40, "Float", 20, "Float", 20, "Float", 90, "Float", 90)
	DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
	br := Gdip_BrushCreateSolid(0x9966CCFF), Gdip_FillPath(g, br, path), Gdip_DeleteBrush(br), Gdip_DeletePath(path)
	pen := Gdip_CreatePen(0xFFFFFFFF, 1.5)
	DllCall("gdiplus\GdipDrawEllipse", "Ptr", g, "Ptr", pen, "Float", 4, "Float", 4, "Float", 30, "Float", 30)
	Gdip_DeletePen(pen)
	br := Gdip_BrushCreateSolid(0x80FFFFFF), Gdip_FillRectangle(g, br, 60, 30, 30, 20), Gdip_DeleteBrush(br)
	Gdip_DeleteGraphics(g)
	GdipScenarios_Write(Gdip_SaveBitmapToFile(bm, dir "\shapes.png") "`n", dir "\status.txt")
	GdipScenarios_Write(Gdip_SaveBitmapToFile(bm, dir "\shapes-q90.jpg", 90) "`n", dir "\status.txt")
	GdipScenarios_Write(Gdip_SaveBitmapToFile(bm, dir "\shapes-q40.jpg", 40) "`n", dir "\status.txt")
	GdipScenarios_Write(Gdip_SaveBitmapToFile(bm, dir "\shapes.bmp") "`n", dir "\status.txt")

	; a GDI bitmap of it, pixels as GetObject sees them
	hbm := Gdip_CreateHBITMAPFromBitmap(bm)
	GdipScenarios_Bits(hbm, dir "\hbitmap.bin")
	DllCall("DeleteObject", "Ptr", hbm)
	Gdip_DisposeImage(bm)

	; read back from the file
	bm := Gdip_CreateBitmapFromFile(dir "\shapes.png")
	GdipScenarios_Write(Gdip_GetImageWidth(bm) "x" Gdip_GetImageHeight(bm) "`n", dir "\dims.txt")
	Gdip_SaveBitmapToFile(bm, dir "\reload.png")
	Gdip_DisposeImage(bm)
	GdipScenarios_Write(Gdip_CreateBitmapFromFile(dir "\missing.png") "`n", dir "\dims.txt")

	; text: measured and drawn
	bm := Gdip_CreateBitmap(160, 60), g := Gdip_GraphicsFromImage(bm)
	Gdip_GraphicsClear(g, 0xFFFFFFFF)
	Gdip_SetSmoothingMode(g, 4), Gdip_SetTextRenderingHint(g, 4)
	fam := 0, font := 0, fmt := 0
	DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
	DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", 13, "Int", 1, "Int", 2, "Ptr*", &font)
	DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x2000, "Int", 0, "Ptr*", &fmt)
	text := "Clipnik measures how many lines this sentence wraps to"
	CreateRectF(&rc, 0, 0, 150, 200)
	parts := StrSplit(Gdip_MeasureString(g, text, font, fmt, &rc), "|")
	GdipScenarios_Write(Round(parts[1], 2) "|" Round(parts[2], 2) "|" Round(parts[3], 2) "|" Round(parts[4], 2) "|" parts[5] "|" parts[6] "`n", dir "\measure.txt")
	br := Gdip_BrushCreateSolid(0xFF223344)
	CreateRectF(&rc, 4, 4, 152, 52)
	DllCall("gdiplus\GdipDrawString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", br)
	Gdip_DeleteBrush(br)
	DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt), DllCall("gdiplus\GdipDeleteFont", "Ptr", font), DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
	Gdip_DeleteGraphics(g)
	Gdip_SaveBitmapToFile(bm, dir "\text.png")
	Gdip_DisposeImage(bm)

	; a DIB section drawn through its device context, as the ring does for its layered window
	hbm := CreateDIBSection(40, 30), hdc := CreateCompatibleDC(), old := SelectObject(hdc, hbm)
	g := Gdip_GraphicsFromHDC(hdc)
	Gdip_SetSmoothingMode(g, 4)
	br := Gdip_BrushCreateSolid(0xC0008060), Gdip_FillEllipse(g, br, 2, 2, 36, 26), Gdip_DeleteBrush(br)
	Gdip_DeleteGraphics(g), SelectObject(hdc, old), DeleteDC(hdc)
	GdipScenarios_Bits(hbm, dir "\dib.bin")
	DeleteObject(hbm)

	; the action ring itself, two themes and two modes
	items := [{key: "O", label: "Original", short: "Original"}, {key: "T", label: "Trim Formatting", short: "Trim", active: true}
		, {key: "U", label: "Upper case", short: "UPPER", dim: true}, {key: "M", label: "Markdown link", short: "Markdown"}]
	Theme.Init("dark", "76B84E")
	Ring.RenderToFile(Ring.State(items, -1, "Trim Formatting", "active format", true), dir "\ring-dark.png")
	Theme.Init("light", "4270C4")
	Ring.RenderToFile(Ring.State(items, 1, "Trim Formatting", "active format", true), dir "\ring-light-hover.png")

	Gdip_Shutdown(token)
}

; the clipboard half: needs the clipboard to itself, so only with no Clipnik running (tests/gdiplus_clipboard.ahk)
GdipClipScenarios(dir, source) {
	token := Gdip_Startup()
	bm := Gdip_CreateBitmapFromFile(source)
	Gdip_SetBitmapToClipboard(bm)
	Gdip_DisposeImage(bm)
	Sleep 100
	f := FileOpen(dir "\clip-set.bin", "w", "UTF-8-RAW"), f.RawWrite(ClipboardAll()), f.Close()
	bm := Gdip_CreateBitmapFromClipboard()
	GdipScenarios_Write(Gdip_GetImageWidth(bm) "x" Gdip_GetImageHeight(bm) "`n", dir "\clip-dims.txt")
	Gdip_SaveBitmapToFile(bm, dir "\clip-get.png")
	Gdip_DisposeImage(bm)
	A_Clipboard := "no image here"
	Sleep 100
	GdipScenarios_Write((Gdip_CreateBitmapFromClipboard() > 0) "`n", dir "\clip-dims.txt")
	Gdip_Shutdown(token)
}

; text for the results, without a byte order mark whatever the caller's FileEncoding: the references have none
GdipScenarios_Write(text, file) => FileAppend(text, file, "UTF-8-RAW")

; the pixel bytes of a DIB section, as GetObject reports them
GdipScenarios_Bits(hbm, file) {
	ds := Buffer(A_PtrSize = 8 ? 104 : 84, 0)
	DllCall("GetObject", "Ptr", hbm, "Int", ds.Size, "Ptr", ds)
	size := NumGet(ds, 12, "Int") * Abs(NumGet(ds, 8, "Int"))
	f := FileOpen(file, "w", "UTF-8-RAW")
	f.WriteUInt(NumGet(ds, 4, "Int")), f.WriteInt(NumGet(ds, 8, "Int")), f.WriteUShort(NumGet(ds, 18, "UShort"))
	f.RawWrite(NumGet(ds, A_PtrSize = 8 ? 24 : 20, "Ptr"), size)
	f.Close()
}
