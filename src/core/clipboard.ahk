; clipboard.ahk - clipboard helpers shared by the capture path.
;
; ClipExclusion honors the clipboard formats that password managers and other apps set on private data:
;   ExcludeClipboardContentFromMonitorProcessing  present -> do not record
;   CanIncludeInClipboardHistory                  DWORD 0  -> do not record
;   CanUploadToCloudClipboard                     DWORD 0  -> do not record
; (KeePass, 1Password, Bitwarden, Windows Terminal "copy as private" and others use these.)

class ClipExclusion {
	static fmts := Map()
	static names := ["ExcludeClipboardContentFromMonitorProcessing", "CanIncludeInClipboardHistory", "CanUploadToCloudClipboard"]

	static Init() {
		for n in ClipExclusion.names
			ClipExclusion.fmts[n] := DllCall("RegisterClipboardFormat", "Str", n, "UInt")
	}

	; True when the current clipboard content asks not to be recorded.
	static IsExcluded() {
		if !ClipExclusion.fmts.Count
			ClipExclusion.Init()
		if DllCall("IsClipboardFormatAvailable", "UInt", ClipExclusion.fmts["ExcludeClipboardContentFromMonitorProcessing"])
			return true
		for n in ["CanIncludeInClipboardHistory", "CanUploadToCloudClipboard"]
			if DllCall("IsClipboardFormatAvailable", "UInt", ClipExclusion.fmts[n]) && (ClipExclusion.ReadDword(ClipExclusion.fmts[n]) = 0)
				return true
		return false
	}

	; Reads a DWORD clipboard format; -1 when it cannot be read.
	static ReadDword(fmt) {
		opened := false
		loop 50 {
			if DllCall("OpenClipboard", "Ptr", 0) {
				opened := true
				break
			}
			Sleep 10
		}
		if !opened
			return -1
		v := -1
		try {
			h := DllCall("GetClipboardData", "UInt", fmt, "Ptr")
			if h {
				p := DllCall("GlobalLock", "Ptr", h, "Ptr")
				if p {
					v := NumGet(p, 0, "UInt")
					DllCall("GlobalUnlock", "Ptr", h)
				}
			}
		}
		DllCall("CloseClipboard")
		return v
	}
}
