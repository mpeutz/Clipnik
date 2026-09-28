; unHTML(): HTML to plain text for the Common Formats "UnHTML" paste format. Standalone.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\unhtml.ahk
#Requires AutoHotkey v2.0
#Include ..\plugins\pformat.commonformats.lib\unhtml.ahk
fails := 0
check(got, want, msg) {
	global fails
	ok := got == want
	FileAppend((ok ? "ok   " : "FAIL ") msg (ok ? "" : " [" got "] expected [" want "]") "`n", "*")
	if !ok
		fails++
}
check(unHTML("<p>Hello <b>world</b></p>"), "Hello world", "tags are removed")
check(unHTML("a &amp; b &lt;c&gt;"), "a & b <c>", "escaped markup stays as text")
check(unHTML("&amp;lt;"), "&lt;", "entities are decoded once")
check(unHTML("&#169; &#xA9; &#XA9; &copy;"), "© © © ©", "decimal, hex and named entities")
check(unHTML("&Eacute;t&eacute;"), "Été", "entity names are case-sensitive")
check(unHTML("&nbsp;|&hellip;|&euro;|&trade;"), Chr(160) "|…|€|™", "special characters and symbols")
check(unHTML("&bogus; and &#0; and &#xD800; stay"), "&bogus; and &#0; and &#xD800; stay", "unknown or invalid entities are left as they are")
check(unHTML("line<br>two<BR/>three<br />four"), "line`ntwo`nthree`nfour", "line breaks become new lines")
check(unHTML("5 < 6 and 7 > 3"), "5 < 6 and 7 > 3", "a bare < is not a tag")
check(unHTML("<!-- note -->kept"), "kept", "comments are removed")
check(unHTML("&#128512;"), "😀", "characters beyond the basic plane")
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
