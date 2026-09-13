; imageclip.ahk - turning an image clip into something an action can use: a PNG on disk, or a data URI.
;
;   ImageClip.PngFrom(ref, outPath)   ref is a file path, or "" for the image on the clipboard right now
;   ImageClip.DataUri(ref, maxBytes)  "" when the source is missing or the PNG exceeds maxBytes
;   ImageClip.SvgDataUri(markup)      url-encoded data:image/svg+xml
;   ImageClip.Temp(ext)               a fresh path under A_Temp\Clipjump

class ImageClip {
	static MaxUriBytes := 2097152

	static Temp(ext) {
		dir := A_Temp "\Clipjump"
		DirCreate(dir)
		ImageClip.Sweep(dir)
		loop
			p := dir "\clip-" A_TickCount "-" A_Index "." ext
		until !FileExist(p)
		return p
	}

	; deletes clip-* temp files older than a day; called from Temp() so the folder does not grow forever
	static Sweep(dir) {
		cutoff := DateAdd(A_Now, -1, "Days")
		loop files, dir "\clip-*", "F"
			if (A_LoopFileTimeModified < cutoff)
				try FileDelete(A_LoopFileFullPath)
	}

	; writes the source as a PNG; 1 on success. ref = "" means the clipboard; a non-empty ref means exactly
	; that file, and nothing else -- a ref that does not exist is a failure, never a silent clipboard fallback
	static PngFrom(ref, outPath) {
		if (ref != "" && !FileExist(ref))
			return 0
		t := Gdip_Startup()
		bm := (ref = "") ? Gdip_CreateBitmapFromClipboard() : Gdip_CreateBitmapFromFile(ref)
		ok := 0
		if (bm > 0) {
			ok := (Gdip_SaveBitmapToFile(bm, outPath) = 0) ? 1 : 0
			Gdip_DisposeImage(bm)
		}
		Gdip_Shutdown(t)
		return ok
	}

	; puts the image on the clipboard so a web tool can take a paste. ref = "" means the image is already
	; there, which is the lossless case; a channel clip's .avc holds the original clipboard bytes, so it is
	; preferred over any re-encoded copy; anything else is read as an image file.
	static ToClipboard(ref) {
		if (ref = "")
			return 1
		if !FileExist(ref)
			return 0
		if (StrLower(SubStr(ref, -4)) = ".avc") {
			try A_Clipboard := ClipFileRead(ref)
			catch
				return 0
			return ClipWait(2) ? 1 : 0
		}
		t := Gdip_Startup()
		bm := Gdip_CreateBitmapFromFile(ref)
		ok := 0
		if (bm > 0) {
			Gdip_SetBitmapToClipboard(bm)
			Gdip_DisposeImage(bm)
			ok := 1
		}
		Gdip_Shutdown(t)
		return ok
	}

	static DataUri(ref, maxBytes := 0) {
		if !maxBytes
			maxBytes := ImageClip.MaxUriBytes
		png := ImageClip.Temp("png")
		if !ImageClip.PngFrom(ref, png) {
			try FileDelete(png)
			return ""
		}
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
		s := StrReplace(s, '"', "%22")
		return "data:image/svg+xml," s
	}
}
