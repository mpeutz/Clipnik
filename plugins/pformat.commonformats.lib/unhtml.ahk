; unhtml.ahk - HTML to plain text for the Common Formats "UnHTML" paste format, written for Clipnik.
; Line breaks become new lines, tags and comments go, then character references are decoded once - after the tags,
; so escaped markup (&lt;b&gt;) stays as text. Named references cover HTML 4.01's Latin-1, special characters and
; common symbols (not Greek or math), case-sensitive; numeric ones cover everything. A reference that is unknown or
; not a valid character is left as it is.

unHTML(html) {
	text := RegExReplace(html, "i)<br\s*/?>", "`n")
	text := RegExReplace(text, "s)<!--.*?-->")
	text := RegExReplace(text, "<[a-zA-Z/!][^>]*>")
	return unHTML_Decode(text)
}

unHTML_Decode(text) {
	out := "", pos := 1
	while RegExMatch(text, "&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);", &m, pos) {
		out .= SubStr(text, pos, m.Pos - pos) unHTML_Char(m[1], m[0])
		pos := m.Pos + m.Len
	}
	return out SubStr(text, pos)
}

; the character a reference names, or the reference itself when it names none
unHTML_Char(ref, whole) {
	if (SubStr(ref, 1, 1) = "#") {
		code := (SubStr(ref, 2, 1) = "x") ? Integer("0x" SubStr(ref, 3)) : Integer(SubStr(ref, 2))
		valid := code > 0 && code <= 0x10FFFF && !(code >= 0xD800 && code <= 0xDFFF)
		return valid ? Chr(code) : whole
	}
	code := unHTML_Named(ref)
	return code ? Chr(code) : whole
}

; the code point of an HTML 4.01 entity name, 0 when it is not one
unHTML_Named(name) {
	static names := ""
	if !names {
		names := Map(), names.CaseSense := true
		; Latin-1: nbsp is 160, each next name the next code point, up to yuml at 255
		for n in StrSplit("nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg plusmn "
			. "sup2 sup3 acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute Acirc "
			. "Atilde Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute "
			. "Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc atilde auml "
			. "aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute ocirc otilde "
			. "ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml", " ")
			names[n] := 159 + A_Index
		; markup-significant, special and common symbol characters
		for pair in StrSplit("quot 34,amp 38,apos 39,lt 60,gt 62,OElig 338,oelig 339,Scaron 352,scaron 353,Yuml 376,"
			. "fnof 402,circ 710,tilde 732,ensp 8194,emsp 8195,thinsp 8201,zwnj 8204,zwj 8205,lrm 8206,rlm 8207,"
			. "ndash 8211,mdash 8212,lsquo 8216,rsquo 8217,sbquo 8218,ldquo 8220,rdquo 8221,bdquo 8222,dagger 8224,"
			. "Dagger 8225,bull 8226,hellip 8230,permil 8240,prime 8242,Prime 8243,lsaquo 8249,rsaquo 8250,euro 8364,"
			. "trade 8482,larr 8592,uarr 8593,rarr 8594,darr 8595,harr 8596,minus 8722,infin 8734,ne 8800,le 8804,"
			. "ge 8805", ",") {
			p := StrSplit(pair, " ")
			names[p[1]] := Integer(p[2])
		}
	}
	return names.Has(name) ? names[name] : 0
}
