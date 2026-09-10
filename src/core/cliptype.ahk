; cliptype.ahk - what a text clip is. ClipType.Detect classifies text once at copy time; the kind is stored with
; the clip (history column "kind", channel clip pref "Kind") and read back everywhere a clip is shown.
;
;   ClipType.Detect(text)   -> "url" | "email" | "path" | "color" | "json" | "number" | "phone" | "code" | "text"
;   ClipType.Label(kind)    -> translated upper-case label (TXT.KIND_<kind>, falls back to the kind itself)
;   ClipType.IsKind(s)      -> true for one of the nine kinds
;
; Detection is deliberately conservative: a clip is a URL only when the whole trimmed text is one URL, an email
; only when it is one address, and so on. Anything ambiguous is "text".

class ClipType {
	static Kinds := ["url", "email", "path", "color", "json", "number", "phone", "code", "text"]
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
}

; Map kind -> label, for the pages
ClipType_Labels() {
	labels := Map()
	for k in ClipType.Kinds
		labels[k] := ClipType.Label(k)
	return labels
}
