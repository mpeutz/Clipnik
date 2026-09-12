; transforms.ahk - built-in paste formats. They join the pformat plugins in PLUGINS.pformat, so the Z menu, the
; Settings default-format list and the paste path treat them like any plugin. Each entry also says which clip
; kinds it fits ("kinds") and its menu letter ("key").
;
;   Transforms.Register()            adds the entries (safe to call twice)
;   Transforms.AppliesTo(entry, kind)
;   Transform_<Name>(text) -> text   the format functions

class Transforms {
	static List := [
		["upper", "TRF_upper", "Transform_Upper", "text,code", "U"],
		["lower", "TRF_lower", "Transform_Lower", "text,code", "W"],
		["title", "TRF_title", "Transform_Title", "text", "I"],
		["oneLine", "TRF_oneLine", "Transform_OneLine", "text,code", "L"],
		["slugify", "TRF_slugify", "Transform_Slugify", "text", "G"],
		["stripTracking", "TRF_stripTracking", "Transform_StripTracking", "url", "S"],
		["markdownLink", "TRF_markdownLink", "Transform_MarkdownLink", "url", "M"],
		["prettyJson", "TRF_prettyJson", "Transform_PrettyJson", "json", "P"],
		["minifyJson", "TRF_minifyJson", "Transform_MinifyJson", "json", "J"],
		["base64", "TRF_base64", "Transform_Base64", "text", "B"]]

	static Register() {
		global PLUGINS
		for t in Transforms.List {
			if PLUGINS.pformat.HasKey(t[1])
				continue
			e := CJMap()
			e["name"] := ClipType_T(t[2]), e["*"] := t[3], e["Previewable"] := 1, e["kinds"] := t[4], e["key"] := t[5], e["builtin"] := 1, e["desc"] := ClipType_T("TRF_desc_" t[1]), e["short"] := ClipType_T("TRF_short_" t[1])
			; the Plugin Manager lists these beside the plugin files, so give them the same displayable fields
			e["Description"] := e["desc"], e["Author"] := "Clipjump", e["Tags"] := "pformat builtin"
			e["Letter"] := t[5], e["Applies to"] := Transforms.KindLabels(t[4]), e["Wedge label"] := e["short"]
			PLUGINS.pformat[t[1]] := e
		}
	}

	; a format with no kinds fits everything (plugins); "" and "text" kinds are the same thing
	; the clip kinds a format applies to, by label, for the Plugin Manager properties view ("" = every kind)
	static KindLabels(kinds) {
		global TXT
		if (kinds = "")
			return TXT.PLG_everyKind
		labels := ClipType_Labels(), out := ""
		for k in StrSplit(kinds, ",")
			out .= (out = "" ? "" : ", ") (labels.Has(k) ? labels[k] : k)
		return out
	}

	static AppliesTo(entry, kind) {
		kinds := ""
		try kinds := entry["kinds"]
		if (kinds = "")
			return true
		kind := (kind = "") ? "text" : kind
		return InStr("," kinds ",", "," kind ",") ? true : false
	}

	static PrettyJson(text) => Transform_PrettyJson(text)
	static MinifyJson(text) => Transform_MinifyJson(text)
}

Transform_Upper(t) => StrUpper(t)
Transform_Lower(t) => StrLower(t)
Transform_Title(t) => RegExReplace(t, "(?<=^|\s)([a-z])", "$U1")
Transform_OneLine(t) => Trim(RegExReplace(t, "\s+", " "))
Transform_Slugify(t) {
	s := StrLower(Trim(t))
	s := RegExReplace(s, "[^a-z0-9]+", "-")
	return Trim(s, "-")
}
Transform_StripTracking(t) => ClipType.StripTracking(Trim(t))
Transform_MarkdownLink(t) => ClipType.IsUrl(Trim(t)) ? ClipType.MarkdownLink(Trim(t)) : t

; minimal JSON re-formatter: walks the text once, tracking strings; no parsing of values
Transform_PrettyJson(t) {
	if !ClipType.IsJson(Trim(t))
		return t
	src := Transform_MinifyJson(t)
	out := "", depth := 0, inString := false, esc := false
	loop parse src {
		c := A_LoopField
		if inString {
			out .= c
			if esc
				esc := false
			else if (c = "\")
				esc := true
			else if (c = '"')
				inString := false
			continue
		}
		switch c {
			case '"': inString := true, out .= c
			case "{", "[":
				depth++
				out .= c "`n" Transform_Indent(depth)
			case "}", "]":
				depth--
				out .= "`n" Transform_Indent(depth) c
			case ",": out .= c "`n" Transform_Indent(depth)
			case ":": out .= ": "
			default: out .= c
		}
	}
	return out
}
Transform_Indent(depth) {
	s := ""
	loop depth
		s .= "  "
	return s
}
Transform_MinifyJson(t) {
	if !ClipType.IsJson(Trim(t))
		return t
	out := "", inString := false, esc := false
	loop parse Trim(t) {
		c := A_LoopField
		if inString {
			out .= c
			if esc
				esc := false
			else if (c = "\")
				esc := true
			else if (c = '"')
				inString := false
			continue
		}
		if (c = '"')
			inString := true, out .= c
		else if (c = " " || c = "`t" || c = "`r" || c = "`n")
			continue
		else
			out .= c
	}
	return out
}
Transform_Base64(t) {
	s := RegExReplace(t, "\s")
	if !RegExMatch(s, "^[A-Za-z0-9+/]+={0,2}$") || Mod(StrLen(s), 4) != 0 || StrLen(s) < 8
		return t
	if !DllCall("crypt32\CryptStringToBinaryW", "Str", s, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &n := 0, "Ptr", 0, "Ptr", 0)
		return t
	buf := Buffer(n)
	DllCall("crypt32\CryptStringToBinaryW", "Str", s, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &n, "Ptr", 0, "Ptr", 0)
	out := StrGet(buf, n, "UTF-8")
	return InStr(out, Chr(0xFFFD)) ? t : out   ; binary payloads stay as they were
}
