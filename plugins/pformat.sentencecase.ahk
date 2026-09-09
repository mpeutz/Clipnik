;@Plugin-Name SentenceCase
;@Plugin-Description Paste Text in Sentence Case
;@Plugin-Author Avi
;@Plugin-Tags pformat
;@Plugin-version 0.0.1
;@Plugin-Previewable 1

;@Plugin-param1 Text to convert in Sentence case

plugin_pformat_sentencecase(zin) {
	global STORE, TXT
	zCS := getClipboardFormat()
	if (zCS == "[" TXT.TIP_text "]")
	{
		zin_copy := zin, STORE.ClipboardChanged := 1
		loop parse zin, ".?!`n`r"
		{
			if (A_LoopField = "")
				continue
			zChanged := plugin_pformat_sentencecase_upper(A_LoopField)
			zin_copy := StrReplace(zin_copy, A_LoopField, zChanged, , , 1)
		}
		return zin_copy
	}
	else
		return zin
}

plugin_pformat_sentencecase_upper(zin) {
	zFout := ""
	zStart := RegExMatch(zin, "i)[a-z]", &m)
	if zStart
		zFout := StrUpper(m[0])
	zFst := SubStr(zin, 1, (zStart ? zStart : 1) - 1)
	zAll := SubStr(zin, (zStart ? zStart : 1) + StrLen(zFout))
	zAll := StrLower(zAll)
	return zFst zFout zAll
}
