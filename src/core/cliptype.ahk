; cliptype.ahk - what a text clip is. ClipType.Detect classifies text once at copy time; the kind is stored with
; the clip (history column "kind", channel clip pref "Kind") and read back everywhere a clip is shown.
;
;   ClipType.Detect(text)   -> "url" | "email" | "path" | "color" | "json" | "svg" | "number" | "phone" | "code" | "text" | "image"
;   ClipType.Label(kind)    -> translated upper-case label (TXT.KIND_<kind>, falls back to the kind itself)
;   ClipType.IsKind(s)      -> true for one of the eleven kinds
;
; Detection is deliberately conservative: a clip is a URL only when the whole trimmed text is one URL, an email
; only when it is one address, and so on. Anything ambiguous is "text".

class ClipType {
	static Kinds := ["url", "email", "path", "color", "json", "svg", "number", "phone", "code", "text", "image"]
	static MaxBytes := 65536

	static IsKind(s) {
		for k in ClipType.Kinds
			if (k = s)
				return true
		return false
	}

	static Label(kind) {
		global TXT
		key := "KIND_" kind
		try if (TXT[key] != "")
			return StrUpper(TXT[key])
		return StrUpper(kind)
	}

	; stored kind of a channel clip (prefs.ini Kind=), detecting and storing it on first use; "" for images
	static Of(ch, clip) {
		global CDS
		k := clipPref(ch, clip, "Kind")
		if ClipType.IsKind(k)
			return k
		text := ""
		try text := CDS[ch][clip]
		if (text = "")
			return ""
		k := ClipType.Detect(text)
		ClipType.Store(ch, clip, k)
		return k
	}

	static Store(ch, clip, kind) {
		AddClipPref(ch, clip, "Kind", kind)
	}

	; RGB integer for a color clip (#hex, rgb(), hsl()); -1 when it cannot be read
	static ColorRgb(text) {
		t := Trim(text)
		if RegExMatch(t, "i)^#([0-9a-f]{3})$", &m)
			return Integer("0x" SubStr(m[1], 1, 1) SubStr(m[1], 1, 1) SubStr(m[1], 2, 1) SubStr(m[1], 2, 1) SubStr(m[1], 3, 1) SubStr(m[1], 3, 1))
		if RegExMatch(t, "i)^#([0-9a-f]{6})(?:[0-9a-f]{2})?$", &m)
			return Integer("0x" m[1])
		if RegExMatch(t, "i)^rgba?\(\s*(\d+)\s*[, ]\s*(\d+)\s*[, ]\s*(\d+)", &m)
			return (Min(255, m[1]) << 16) | (Min(255, m[2]) << 8) | Min(255, m[3])
		if RegExMatch(t, "i)^hsla?\(\s*([\d.]+)\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%", &m) {
			hh := Mod(m[1], 360) / 60, s := m[2] / 100, l := m[3] / 100
			c := (1 - Abs(2 * l - 1)) * s, x := c * (1 - Abs(Mod(hh, 2) - 1)), mm := l - c / 2
			r := 0, g := 0, b := 0
			if (hh < 1)
				r := c, g := x
			else if (hh < 2)
				r := x, g := c
			else if (hh < 3)
				g := c, b := x
			else if (hh < 4)
				g := x, b := c
			else if (hh < 5)
				r := x, b := c
			else
				r := c, b := x
			return (Round((r + mm) * 255) << 16) | (Round((g + mm) * 255) << 8) | Round((b + mm) * 255)
		}
		return -1
	}

	static Detect(text) {
		if (StrLen(text) * 2 > ClipType.MaxBytes)
			return "text"
		t := Trim(text, " `t`r`n")
		if (t = "")
			return "text"
		oneLine := !InStr(t, "`n")
		if oneLine {
			if ClipType.IsUrl(t)
				return "url"
			if ClipType.IsEmail(t)
				return "email"
			if ClipType.IsPath(t)
				return "path"
			if ClipType.IsColor(t)
				return "color"
		}
		if ClipType.IsJson(t)
			return "json"
		if ClipType.IsSvg(t)
			return "svg"
		if oneLine {
			if ClipType.IsNumber(t)
				return "number"
			if ClipType.IsPhone(t)
				return "phone"
		}
		if ClipType.IsCode(t)
			return "code"
		return "text"
	}

	static IsUrl(t) => !InStr(t, " ") && RegExMatch(t, "i)^(?:(?:https?|ftp|file)://[^\s]+|www\.[a-z0-9-]+(?:\.[a-z0-9-]+)+[^\s]*)$")

	static IsEmail(t) => RegExMatch(t, "i)^[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$")

	static IsPath(t) => RegExMatch(t, '^(?:[A-Za-z]:\\|\\\\[^\\/:*?"<>|]+\\)[^\x00-\x1f/:*?"<>|]*$')

	static IsColor(t) => RegExMatch(t, "i)^(?:#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})|rgba?\([^)]*\)|hsla?\([^)]*\))$")

	; starts with { or [, ends with the matching bracket, brackets balance outside strings, and there is at least
	; one : or , outside strings so "{word}" is not JSON
	static IsJson(t) {
		first := SubStr(t, 1, 1), last := SubStr(t, -1)
		if !((first = "{" && last = "}") || (first = "[" && last = "]"))
			return false
		depth := 0, inString := false, esc := false, punct := false
		loop parse t {
			c := A_LoopField
			if inString {
				if esc
					esc := false
				else if (c = "\")
					esc := true
				else if (c = '"')
					inString := false
				continue
			}
			switch c {
				case '"': inString := true
				case "{", "[": depth++
				case "}", "]":
					depth--
					if (depth < 0)
						return false
				case ":", ",": punct := true
			}
		}
		return depth = 0 && !inString && punct
	}

	; svg markup: an <svg> root with opening tag at a tag boundary, optionally behind an xml declaration
	; and/or DOCTYPE (including with internal subset). May end with </svg> or self-closing />.
	; Uses string scanning, not regex, for trailing comments and the xml-declaration prologue: both can
	; be arbitrarily large (a generator's trailing comment block), and a matching-quantifier regex over
	; unbounded input is the kind of construct that has already produced silent false negatives here.
	static IsSvg(t) {
		s := Trim(t, " `t`r`n")
		sLen := StrLen(s)

		; Strip trailing comments and whitespace. Loop: trim whitespace and comments from the end
		; until nothing more to strip.
		loop {
			origLen := sLen

			; Trim trailing whitespace (space, tab, CR, LF)
			s := RTrim(s, " `t`r`n")
			sLen := StrLen(s)

			; Then check if ends with --> and remove the complete comment
			if sLen >= 3 && SubStr(s, sLen - 2, 3) = "-->" {
				; Find the last <!-- (comments don't contain -->, so this is exact)
				commentStart := InStr(s, "<!--", , -1)
				if commentStart {
					; Remove the comment
					s := SubStr(s, 1, commentStart - 1)
					sLen := StrLen(s)
				} else {
					; Malformed: ends with --> but no comment start
					break
				}
			}

			; If nothing changed, we're done
			if sLen = origLen
				break
		}

		; After stripping, the string must end with </svg> or />
		if sLen >= 6 && SubStr(s, sLen - 5, 6) = "</svg>" {
			; Has closing tag
		} else if sLen >= 2 && SubStr(s, sLen - 1, 2) = "/>" {
			; Has self-closing
		} else {
			return false
		}

		; Check the opening: must be <svg at a tag boundary (followed by whitespace, >, or /)
		; This prevents matching <svgfoo ...> or similar malformed tags
		if RegExMatch(s, "s)^<svg[\s>/]")
			return true

		; Or start with <?xml declaration followed by svg root
		if !RegExMatch(s, "s)^<\?xml")
			return false

		; Find end of XML declaration
		declEnd := InStr(s, "?>")
		if !declEnd
			return false

		; Forward-scan past the declaration: skip whitespace, then skip any run of comments and/or
		; DOCTYPE declarations (in any order), then require the root tag at a boundary.
		p := declEnd + 2
		loop {
			while (p <= sLen) {
				c := SubStr(s, p, 1)
				if (c != " " && c != "`t" && c != "`r" && c != "`n")
					break
				p++
			}
			if (SubStr(s, p, 4) == "<!--") {
				closeAt := InStr(s, "-->", true, p + 4)
				if !closeAt
					return false
				p := closeAt + 3
				continue
			}
			if (SubStr(s, p, 9) == "<!DOCTYPE") {
				q := p + 9
				gtPos := InStr(s, ">", true, q)
				bracketPos := InStr(s, "[", true, q)
				if (bracketPos && (!gtPos || bracketPos < gtPos)) {
					closeBracket := InStr(s, "]", true, bracketPos + 1)
					if !closeBracket
						return false
					gtPos := InStr(s, ">", true, closeBracket + 1)
				}
				if !gtPos
					return false
				p := gtPos + 1
				continue
			}
			break
		}
		return RegExMatch(SubStr(s, p), "s)^<svg[\s>/]") > 0
	}

	static IsNumber(t) => RegExMatch(t, "^[-+]?[$€£¥]?\s?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?%?$")

	static IsPhone(t) {
		if !RegExMatch(t, "^\+?[\d\s().-]+$")
			return false
		digits := RegExReplace(t, "\D")
		return StrLen(digits) >= 7 && StrLen(digits) <= 15
	}

	; two or more lines and a strong signal; checked on the first 40 lines only
	static IsCode(t) {
		if !InStr(t, "`n")
			return false
		lines := StrSplit(t, "`n", "`r")
		if (lines.Length < 2)
			return false
		if RegExMatch(lines[1], "^#!")
			return true
		ending := 0, keyword := 0, indented := 0, n := 0
		for line in lines {
			if (++n > 40)
				break
			s := RTrim(line)
			if (s = "")
				continue
			if RegExMatch(s, "[;{]$")
				ending++
			if RegExMatch(s, "^\s*(?:def |function |import |class |#include|using |from \w+ import |public |private |const |let |var |return |if \(|for \(|while \()")
				keyword++
			if RegExMatch(s, "^(?:\t| {2,})")
				indented++
		}
		return ending >= 2 || keyword >= 1 || (indented >= 1 && InStr(t, "{") && InStr(t, "}"))
	}

	; ---------- actions ----------
	; per kind: ordered {id, label (TXT key), short (TXT key for the toast chip)}; the first entry is the primary one
	static ActionTable := Map(
		"url", [{id: "open", label: "ACT_open", short: "ACT_openShort"}, {id: "stripTracking", label: "ACT_stripTracking", short: ""}],
		"email", [{id: "compose", label: "ACT_compose", short: "ACT_compose"}],
		"path", [{id: "reveal", label: "ACT_reveal", short: "ACT_revealShort"}, {id: "openPath", label: "ACT_openPath", short: ""}, {id: "copyFolder", label: "ACT_copyFolder", short: ""}],
		"color", [{id: "copyHex", label: "ACT_copyHex", short: "ACT_copyHexShort"}, {id: "copyRgb", label: "ACT_copyRgb", short: "ACT_copyRgbShort"}],
		"json", [{id: "pretty", label: "ACT_pretty", short: "ACT_prettyShort"}, {id: "minify", label: "ACT_minify", short: ""}],
		"number", [{id: "formatNumber", label: "ACT_formatNumber", short: "ACT_formatNumberShort"}],
		"image", [{id: "openImage", label: "ACT_openImage", short: "ACT_openImageShort"}, {id: "imageDataUri", label: "ACT_dataUri", short: "ACT_dataUriShort"}],
		"svg", [{id: "svgomg", label: "ACT_svgomg", short: "ACT_svgomgShort"}, {id: "openVector", label: "ACT_openVector", short: "ACT_openVectorShort"}, {id: "svgDataUri", label: "ACT_dataUri", short: "ACT_dataUriShort"}])

	static Actions(kind) {
		global TXT
		out := []
		if !ClipType.ActionTable.Has(kind)
			return out
		for a in ClipType.ActionTable[kind]
			out.Push({id: a.id, label: ClipType_T(a.label), short: a.short != "" ? ClipType_T(a.short) : ClipType_T(a.label)})
		return out
	}

	; primary action for a kind and clip text; "" when the kind has none
	static Primary(kind, text := "") {
		acts := ClipType.Actions(kind)
		if !acts.Length
			return ""
		if (kind = "color" && InStr(Trim(text), "#") = 1)
			return acts[2]   ; already hex: offer rgb
		return acts[1]
	}

	; runs an action on the clip text; "copy" style actions place the result on the clipboard as a normal copy
	static Run(id, text, ref := "") {
		global ini_defImgEditor, ini_defVectorEditor
		switch id {
			case "open": BrowserRun(Trim(text))
			case "stripTracking": ClipType.ToClipboard(ClipType.StripTracking(Trim(text)))
			case "compose": try Run("mailto:" Trim(text))
			case "reveal": try Run('explorer.exe /select,"' Trim(text) '"')
			case "openPath": try Run('"' Trim(text) '"')
			case "copyFolder": ClipType.ToClipboard(ClipType.FolderOf(Trim(text)))
			case "copyHex": ClipType.ToClipboard(ClipType.ColorHex(text))
			case "copyRgb": ClipType.ToClipboard(ClipType.ColorRgbText(text))
			case "pretty": ClipType.ToClipboard(Transforms.PrettyJson(text))
			case "minify": ClipType.ToClipboard(Transforms.MinifyJson(text))
			case "formatNumber": ClipType.ToClipboard(ClipType.FormatNumber(text))
			case "openImage":
				png := ImageClip.Temp("png")
				if ImageClip.PngFrom(ref, png)
					ClipType.OpenWith(ini_defImgEditor, png)
				else
					Toast.Show(ClipType_T("ACT_imageUnavailable"), 1600, "warn")
			case "imageDataUri":
				uri := ImageClip.DataUri(ref)
				if (uri = "")
					Toast.Show(ClipType_T("ACT_imageTooBig"), 1800, "warn")
				else
					ClipType.ToClipboard(uri)
			case "svgomg":
				ClipType.ToClipboard(text)
				BrowserRun("https://jakearchibald.github.io/svgomg/")
			case "openVector":
				f := ImageClip.Temp("svg")
				try FileAppend(text, f, "UTF-8")
				ClipType.OpenWith(ini_defVectorEditor, f)
			case "svgDataUri": ClipType.ToClipboard(ImageClip.SvgDataUri(text))
		}
	}

	; runs a configured editor on a file, or says the editor is not set
	static OpenWith(exe, file) {
		if (Trim(exe) = "") {
			Toast.Show(ClipType_T("ACT_noEditor"), 2200, "warn")
			return
		}
		try Run('"' exe '" "' file '"')
	}

	static ToClipboard(text) {
		if (text = "")
			return
		try A_Clipboard := text
	}

	static StripTracking(url) {
		if !RegExMatch(url, "^([^?#]*)\?([^#]*)(#.*)?$", &m)
			return url
		keep := []
		loop parse m[2], "&" {
			if (A_LoopField = "")
				continue
			key := StrSplit(A_LoopField, "=")[1]
			if RegExMatch(key, "i)^(?:utm_\w+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid|igshid|ref|ref_src|yclid|_hsenc|_hsmi)$")
				continue
			keep.Push(A_LoopField)
		}
		q := ""
		for i, p in keep
			q .= (i > 1 ? "&" : "") p
		return m[1] (q != "" ? "?" q : "") (m.Count >= 3 ? m[3] : "")
	}

	static FolderOf(path) {
		p := RTrim(path, "\")
		i := InStr(p, "\", , -1)
		return i ? SubStr(p, 1, i - 1) : p
	}

	static ColorHex(text) {
		rgb := ClipType.ColorRgb(text)
		return rgb < 0 ? "" : Format("#{:06X}", rgb)
	}

	static ColorRgbText(text) {
		rgb := ClipType.ColorRgb(text)
		return rgb < 0 ? "" : Format("rgb({}, {}, {})", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
	}

	static FormatNumber(text) {
		t := RegExReplace(Trim(text), "[,\s]")
		if !RegExMatch(t, "^([-+]?)([$€£¥]?)(\d+)(\.\d+)?(%?)$", &m)
			return Trim(text)
		int := m[3], out := ""
		while (StrLen(int) > 3)
			out := "," SubStr(int, -3) out, int := SubStr(int, 1, -3)
		return m[1] m[2] int out m[4] m[5]
	}

	static MarkdownLink(url) {
		host := RegExMatch(url, "i)^(?:https?|ftp)://([^/?#]+)", &m) ? m[1] : url
		return "[" host "](" url ")"
	}
}

; Map kind -> label, for the pages
ClipType_Labels() {
	labels := Map()
	for k in ClipType.Kinds
		labels[k] := ClipType.Label(k)
	return labels
}

; Map kind -> Array of {id, label, short}, for every kind that has actions; lets a page build a row's context
; menu synchronously from the row's own "kind" instead of waiting on an async preview/clip fetch
ClipType_ActionTable() {
	out := Map()
	for kind, _ in ClipType.ActionTable
		out[kind] := ClipType.Actions(kind)
	return out
}

ClipType_T(key) {
	global TXT
	try if (TXT[key] != "")
		return TXT[key]
	return key
}

; runs an action outside the click handler's thread so a clipboard write is a normal copy
ClipType_RunLater(id, text, ref := "", *) {
	SetTimer(ClipType_RunNow.Bind(id, text, ref), -10)
}
ClipType_RunNow(id, text, ref := "") {
	ClipType.Run(id, text, ref)
}
