; gdiplus.ahk - the GDI+ and GDI calls Clipnik draws, converts and saves images with, written for Clipnik from
; Microsoft's GDI+ flat API and Win32 documentation. The Gdip_* names are the ones the code base calls; each takes
; only the arguments its callers pass. Handles are plain pointers: the caller frees what it creates.

; ---------- start and stop ----------

; starts GDI+ (version 1, its own background thread) and returns the token Gdip_Shutdown takes; 0 on failure
Gdip_Startup() {
	if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
		DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
	input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)   ; GdiplusStartupInput
	NumPut("UInt", 1, input)
	token := 0
	DllCall("gdiplus\GdiplusStartup", "UPtr*", &token, "Ptr", input, "Ptr", 0)
	return token
}

Gdip_Shutdown(token) {
	DllCall("gdiplus\GdiplusShutdown", "UPtr", token)
	return 0
}

; ---------- bitmaps ----------

; an empty w x h bitmap, 32 bits per pixel with alpha by default
Gdip_CreateBitmap(w, h, pixelFormat := 0x26200A) {
	bitmap := 0
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", pixelFormat, "Ptr", 0, "Ptr*", &bitmap)
	return bitmap
}

Gdip_CreateBitmapFromFile(path) {
	bitmap := 0
	DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", path, "Ptr*", &bitmap)
	return bitmap
}

Gdip_GetImageWidth(image) {
	w := 0
	DllCall("gdiplus\GdipGetImageWidth", "Ptr", image, "UInt*", &w)
	return w
}

Gdip_GetImageHeight(image) {
	h := 0
	DllCall("gdiplus\GdipGetImageHeight", "Ptr", image, "UInt*", &h)
	return h
}

Gdip_DisposeImage(image) => DllCall("gdiplus\GdipDisposeImage", "Ptr", image)

; a bitmap with its own copy of a GDI bitmap's pixels, so hbm can be freed (or given back) right away: a bitmap
; made from an HBITMAP may keep using it, so this one is cloned from that and the go-between is disposed
Gdip_CreateBitmapFromHBITMAP(hbm) {
	src := 0, copy := 0, pixelFormat := 0
	DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &src)
	if !src
		return 0
	DllCall("gdiplus\GdipGetImagePixelFormat", "Ptr", src, "Int*", &pixelFormat)
	DllCall("gdiplus\GdipCloneBitmapAreaI", "Int", 0, "Int", 0, "Int", Gdip_GetImageWidth(src), "Int", Gdip_GetImageHeight(src)
		, "Int", pixelFormat, "Ptr", src, "Ptr*", &copy)
	Gdip_DisposeImage(src)
	return copy
}

; a GDI bitmap of the image; transparent pixels are laid over background (ARGB)
Gdip_CreateHBITMAPFromBitmap(bitmap, background := 0xFFFFFFFF) {
	hbm := 0
	DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbm, "UInt", background)
	return hbm
}

; saves by the file's extension (.png, .jpg, .bmp, .gif, .tif); quality 0-100 applies to JPEG. 0 on success,
; otherwise a GDI+ status, or -1 when no encoder handles the extension
Gdip_SaveBitmapToFile(bitmap, path, quality := 75) {
	SplitPath(path, , , &ext)
	if !(clsid := Gdip_EncoderFor(ext))
		return -1
	params := 0
	if (ext ~= "i)^(jpg|jpeg|jpe|jfif)$") {
		value := Buffer(4), NumPut("UInt", quality, value)
		; EncoderParameters holding one EncoderParameter: EncoderQuality, one value of type Long
		off := A_PtrSize = 8 ? 8 : 4
		params := Buffer(off + 16 + 8 + A_PtrSize, 0)
		NumPut("UInt", 1, params)
		DllCall("ole32\CLSIDFromString", "WStr", "{1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB}", "Ptr", params.Ptr + off)
		NumPut("UInt", 1, "UInt", 4, "Ptr", value.Ptr, params, off + 16)
	}
	return DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", path, "Ptr", clsid, "Ptr", params, "Int")
}

; the CLSID of the encoder whose file extensions include ext, 0 when none does
Gdip_EncoderFor(ext) {
	static found := Map()
	ext := StrLower(ext)
	if found.Has(ext)
		return found[ext]
	count := 0, size := 0
	DllCall("gdiplus\GdipGetImageEncodersSize", "UInt*", &count, "UInt*", &size)
	list := Buffer(size)
	DllCall("gdiplus\GdipGetImageEncoders", "UInt", count, "UInt", size, "Ptr", list)
	; ImageCodecInfo: Clsid, FormatID, then five string pointers, FilenameExtension the fourth ("*.JPG;*.JPEG")
	infoSize := 48 + 7 * A_PtrSize, extOff := 32 + 3 * A_PtrSize
	loop count {
		info := list.Ptr + (A_Index - 1) * infoSize
		for pattern in StrSplit(StrGet(NumGet(info, extOff, "Ptr"), "UTF-16"), ";")
			if (StrLower(pattern) = "*." ext) {
				clsid := Buffer(16)
				DllCall("RtlMoveMemory", "Ptr", clsid, "Ptr", info, "UPtr", 16)
				return found[ext] := clsid
			}
	}
	return found[ext] := 0
}

; ---------- the clipboard ----------

; the clipboard's image as a bitmap: -1 while another program holds the clipboard open, 0 when it has no image
Gdip_CreateBitmapFromClipboard() {
	if !DllCall("OpenClipboard", "Ptr", 0)
		return -1
	bitmap := 0
	if (hbm := DllCall("GetClipboardData", "UInt", 2, "Ptr"))   ; CF_BITMAP; Windows makes it from a DIB on request
		bitmap := Gdip_CreateBitmapFromHBITMAP(hbm)            ; copied while the clipboard, which owns hbm, is open
	DllCall("CloseClipboard")
	return bitmap
}

; puts the bitmap on the clipboard as a device-independent bitmap (CF_DIB), replacing what is there
Gdip_SetBitmapToClipboard(bitmap) {
	if !(hbm := Gdip_CreateHBITMAPFromBitmap(bitmap))
		return -1
	; DIBSECTION: BITMAP (its bits pointer last), then the BITMAPINFOHEADER
	ds := Buffer(A_PtrSize = 8 ? 104 : 84, 0)
	DllCall("GetObject", "Ptr", hbm, "Int", ds.Size, "Ptr", ds)
	bitsOff := A_PtrSize = 8 ? 24 : 20, headOff := A_PtrSize = 8 ? 32 : 24
	stride := NumGet(ds, 12, "Int"), rows := Abs(NumGet(ds, 8, "Int"))
	size := stride * rows
	hdib := DllCall("GlobalAlloc", "UInt", 2, "UPtr", 40 + size, "Ptr")   ; GMEM_MOVEABLE
	p := DllCall("GlobalLock", "Ptr", hdib, "Ptr")
	DllCall("RtlMoveMemory", "Ptr", p, "Ptr", ds.Ptr + headOff, "UPtr", 40)
	DllCall("RtlMoveMemory", "Ptr", p + 40, "Ptr", NumGet(ds, bitsOff, "Ptr"), "UPtr", size)
	DllCall("GlobalUnlock", "Ptr", hdib)
	DllCall("DeleteObject", "Ptr", hbm)
	if !DllCall("OpenClipboard", "Ptr", 0) {
		DllCall("GlobalFree", "Ptr", hdib)
		return -2
	}
	DllCall("EmptyClipboard")
	ok := DllCall("SetClipboardData", "UInt", 8, "Ptr", hdib, "Ptr")   ; CF_DIB: the clipboard owns the memory now
	DllCall("CloseClipboard")
	if !ok
		DllCall("GlobalFree", "Ptr", hdib)
	return ok ? 0 : -3
}

; ---------- drawing ----------

Gdip_GraphicsFromImage(image) {
	g := 0
	DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", image, "Ptr*", &g)
	return g
}

Gdip_GraphicsFromHDC(hdc) {
	g := 0
	DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &g)
	return g
}

Gdip_DeleteGraphics(g) => DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
Gdip_GraphicsClear(g, argb := 0x00FFFFFF) => DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", argb)
Gdip_SetSmoothingMode(g, mode) => DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", mode)
Gdip_SetTextRenderingHint(g, hint) => DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", hint)

; a pen width pixels wide
Gdip_CreatePen(argb, width) {
	pen := 0
	DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width, "Int", 2, "Ptr*", &pen)   ; UnitPixel
	return pen
}

Gdip_DeletePen(pen) => DllCall("gdiplus\GdipDeletePen", "Ptr", pen)

Gdip_BrushCreateSolid(argb := 0xFF000000) {
	brush := 0
	DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &brush)
	return brush
}

Gdip_DeleteBrush(brush) => DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)

; an empty path; fill mode 0 = alternate, 1 = winding
Gdip_CreatePath(fillMode := 0) {
	path := 0
	DllCall("gdiplus\GdipCreatePath", "Int", fillMode, "Ptr*", &path)
	return path
}

Gdip_DeletePath(path) => DllCall("gdiplus\GdipDeletePath", "Ptr", path)
Gdip_FillPath(g, brush, path) => DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", path)
Gdip_FillEllipse(g, brush, x, y, w, h) => DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", brush, "Float", x, "Float", y, "Float", w, "Float", h)
Gdip_FillRectangle(g, brush, x, y, w, h) => DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", brush, "Float", x, "Float", y, "Float", w, "Float", h)

; a RectF for the text calls
CreateRectF(&rect, x, y, w, h) {
	rect := Buffer(16)
	NumPut("Float", x, "Float", y, "Float", w, "Float", h, rect)
}

; how text lays out in the RectF rect: "x|y|w|h|characters fitted|lines filled"
Gdip_MeasureString(g, text, font, format, &rect) {
	box := Buffer(16, 0), chars := 0, lines := 0
	DllCall("gdiplus\GdipMeasureString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rect, "Ptr", format
		, "Ptr", box, "Int*", &chars, "Int*", &lines)
	return NumGet(box, 0, "Float") "|" NumGet(box, 4, "Float") "|" NumGet(box, 8, "Float") "|" NumGet(box, 12, "Float")
		. "|" chars "|" lines
}

; ---------- GDI: a DIB to draw into and a layered window to show it ----------

; a w x h DIB section (bottom-up, bpp bits per pixel) for hdc, or for the screen
CreateDIBSection(w, h, hdc := 0, bpp := 32) {
	info := Buffer(40, 0)   ; BITMAPINFOHEADER, BI_RGB
	NumPut("UInt", 40, "Int", w, "Int", h, "UShort", 1, "UShort", bpp, info)
	dc := hdc ? hdc : DllCall("GetDC", "Ptr", 0, "Ptr")
	bits := 0
	hbm := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", info, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
	if !hdc
		DllCall("ReleaseDC", "Ptr", 0, "Ptr", dc)
	return hbm
}

CreateCompatibleDC(hdc := 0) => DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
SelectObject(hdc, obj) => DllCall("SelectObject", "Ptr", hdc, "Ptr", obj, "Ptr")
DeleteObject(obj) => DllCall("DeleteObject", "Ptr", obj)
DeleteDC(hdc) => DllCall("DeleteDC", "Ptr", hdc)

; shows the w x h image selected into hdc as the layered window hwnd at (x, y), using its per-pixel alpha
UpdateLayeredWindow(hwnd, hdc, x, y, w, h, alpha := 255) {
	pos := Buffer(8), NumPut("Int", x, "Int", y, pos)
	size := Buffer(8), NumPut("Int", w, "Int", h, size)
	from := Buffer(8, 0)
	blend := (alpha << 16) | (1 << 24)   ; BLENDFUNCTION: AC_SRC_OVER, SourceConstantAlpha, AC_SRC_ALPHA
	return DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", pos, "Ptr", size, "Ptr", hdc, "Ptr", from
		, "UInt", 0, "UInt*", blend, "UInt", 2)   ; ULW_ALPHA
}
