; imageclip.ahk - turning an image clip into something an action can use: a PNG on disk, or a data URI.
;
;   ImageClip.PngFrom(ref, outPath)   ref is a file path, or "" for the image on the clipboard right now
;   ImageClip.DataUri(ref, maxBytes)  "" when the source is missing or the PNG exceeds maxBytes
;   ImageClip.SvgDataUri(markup)      url-encoded data:image/svg+xml
;   ImageClip.Temp(ext)               a fresh path under A_Temp\Clipjump

class ImageClip {
	static MaxUriBytes := 2097152

	static Temp(ext) {
		DirCreate(A_Temp "\Clipjump")
		loop
			p := A_Temp "\Clipjump\clip-" A_TickCount "-" A_Index "." ext
		until !FileExist(p)
		return p
	}

	; writes the source as a PNG; 1 on success
	static PngFrom(ref, outPath) {
		t := Gdip_Startup()
		bm := (ref != "" && FileExist(ref)) ? Gdip_CreateBitmapFromFile(ref) : Gdip_CreateBitmapFromClipboard()
		ok := 0
		if (bm > 0) {
			ok := (Gdip_SaveBitmapToFile(bm, outPath) = 0) ? 1 : 0
			Gdip_DisposeImage(bm)
		}
		Gdip_Shutdown(t)
		return ok
	}

	static DataUri(ref, maxBytes := 0) {
		if !maxBytes
			maxBytes := ImageClip.MaxUriBytes
		png := ImageClip.Temp("png")
		if !ImageClip.PngFrom(ref, png)
			return ""
		big := FileGetSize(png) > maxBytes
		b64 := big ? "" : ImageClip.Base64(png)
		try FileDelete(png)
		return b64 = "" ? "" : "data:image/png;base64," b64
	}

	static Base64(path) {
		buf := FileRead(path, "RAW")
		size := 0
		if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &size)
			return ""
		out := Buffer(size * 2, 0)
		if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out, "UInt*", &size)
			return ""
		return StrGet(out, "UTF-16")
	}

	static SvgDataUri(markup) {
		s := Trim(markup, " `t`r`n")
		if (s = "")
			return ""
		s := StrReplace(s, "`r`n", " "), s := StrReplace(s, "`n", " "), s := StrReplace(s, "`t", " ")
		s := StrReplace(s, "%", "%25"), s := StrReplace(s, "#", "%23")
		s := StrReplace(s, "<", "%3C"), s := StrReplace(s, ">", "%3E")
		s := StrReplace(s, '"', "'")
		return "data:image/svg+xml," s
	}
}
