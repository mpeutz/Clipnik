; unhtml.ahk - stdlib desired name
;
; StdLib compliant collection to convert HTML to Text
;
; v 1.3 / (a & w) Nov 2008 by derRaphael(at)oleco.net
; Ported to AutoHotkey v2 for Clipjump. Entities that cannot be converted are now skipped instead of looping forever.

; Syntax sugar for combined call of StripEntities & StripTags
unHTML(html) {
	Return unHTML_StripTags(unHTML_StripEntities(html))
}

; Removes HTML Tags from given text
unHTML_StripTags(txt) { ; v1 (w) by derRaphael Oct 2008
	Return RegExReplace(txt, "<[^>]+>", "")
}

; Replaces HTML entities in the given text with their characters
unHTML_StripEntities(html) { ; v1.3.1 (w) by derRaphael Nov 2008
	pos := 1
	while (pos := RegExMatch(html, "&[a-zA-Z0-9#]+;", &m, pos)) {
		entity := m[0]
		n := RegExReplace(unHTML_ConvertEntity2Number(entity), "[^\d]")
		if (n != "" && n > 0) {
			html := SubStr(html, 1, pos - 1) Chr(n) SubStr(html, pos + StrLen(entity))
			pos += 1
		} else
			pos += StrLen(entity)
	}
	return html
}

; Thx Jamey: http://www.autohotkey.com/forum/viewtopic.php?t=22522
; Rewrite by derRaphael v 1.3 / Nov 2008
unHTML_ConvertEntity2Number(sEntityName) {
	static entityList := "quot|34,apos|39,amp|38,lt|60,gt|62,nbsp|160,iexcl|161,cent|162,pound|163,curren|164,"
				. "yen|165,brvbar|166,sect|167,uml|168,copy|169,ordf|170,laquo|171,not|172,shy|173,reg|"
				. "174,macr|175,deg|176,plusmn|177,sup2|178,sup3|179,acute|180,micro|181,para|182,middo"
				. "t|183,cedil|184,sup1|185,ordm|186,raquo|187,frac14|188,frac12|189,frac34|190,iquest|"
				. "191,Agrave|192,Aacute|193,Acirc|194,Atilde|195,Auml|196,Aring|197,AElig|198,Ccedil|1"
				. "99,Egrave|200,Eacute|201,Ecirc|202,Euml|203,Igrave|204,Iacute|205,Icirc|206,Iuml|207"
				. ",ETH|208,Ntilde|209,Ograve|210,Oacute|211,Ocirc|212,Otilde|213,Ouml|214,times|215,Os"
				. "lash|216,Ugrave|217,Uacute|218,Ucirc|219,Uuml|220,Yacute|221,THORN|222,szlig|223,agr"
				. "ave|224,aacute|225,acirc|226,atilde|227,auml|228,aring|229,aelig|230,ccedil|231,egra"
				. "ve|232,eacute|233,ecirc|234,euml|235,igrave|236,iacute|237,icirc|238,iuml|239,eth|24"
				. "0,ntilde|241,ograve|242,oacute|243,ocirc|244,otilde|245,ouml|246,divide|247,oslash|2"
				. "48,ugrave|249,uacute|250,ucirc|251,uuml|252,yacute|253,thorn|254,yuml|255,OElig|338,"
				. "oelig|339,Scaron|352,scaron|353,Yuml|376,circ|710,tilde|732,ensp|8194,emsp|8195,thin"
				. "sp|8201,zwnj|8204,zwj|8205,lrm|8206,rlm|8207,ndash|8211,mdash|8212,lsquo|8216,rsquo|"
				. "8217,sbquo|8218,ldquo|8220,rdquo|8221,bdquo|8222,dagger|8224,Dagger|8225,hellip|8230"
				. ",permil|8240,lsaquo|8249,rsaquo|8250,euro|8364,trade|8482"
	nNumber := -1   ;This will remain -1 if the entity name could not be translated.
	nStr := StrLen(sEntityName)

	;Require the input format:  "& ... ;"
	if ((nStr < 3) || (SubStr(sEntityName, 1, 1) != "&") || (SubStr(sEntityName, -1) != ";"))
		return nNumber

	;If the entity was given as its entity-number format, then return the number part.
	sEntityIdentifier := SubStr(sEntityName, 2, nStr - 2)
	if (SubStr(sEntityIdentifier, 1, 1) = "#")
		sEntityIdentifier := SubStr(sEntityIdentifier, 2)

	if IsInteger(sEntityIdentifier)
		return (sEntityIdentifier >= 0) ? Integer(sEntityIdentifier) : nNumber

	;If sEntityName really is a name-format entity, then find its number from the table above.
	loop parse entityList, ","
		if RegExMatch(A_LoopField, "i)^" sEntityIdentifier "\|(?P<Number>\d+)", &n)
			return n.Number

	return sEntityIdentifier
}
