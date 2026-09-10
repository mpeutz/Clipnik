; Unit tests for ClipType.Detect (src/core/cliptype.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\cliptype.ahk
#Requires AutoHotkey v2.0
#Warn All, Off   ; cliptype.ahk's ClipType.Of/Store reference clipPref/AddClipPref/CDS, which only Clipjump.ahk defines
#Include ..\lib\v2compat.ahk
#Include ..\src\core\cliptype.ahk

global STORE := Map(), CJGUI := Map(), TXT := CJMap()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
expect(kind, text, note := "") {
    got := ClipType.Detect(text)
    check(got = kind, "[" kind "] " (note != "" ? note : SubStr(StrReplace(text, "`n", "\n"), 1, 60)) (got = kind ? "" : "  -> got " got))
}

; url
expect("url", "https://github.com/aviaryan/Clipjump/issues/143")
expect("url", "http://example.com/a?b=1&c=2#frag")
expect("url", "www.autohotkey.com/docs/v2/lib/InputHook.htm")
expect("url", "ftp://files.example.org/pub/x.zip")
expect("url", "  https://example.com  ", "trimmed")
expect("text", "see https://example.com for details", "url inside prose")
expect("text", "https://example.com and https://example.org", "two urls")
expect("text", "mailto:mike@example.com", "mailto is not a url")
; email
expect("email", "mike@example.com")
expect("email", "first.last+tag@sub.example.co.uk")
expect("text", "Mike <mike@example.com>", "email with display name")
expect("text", "mail me at mike@example.com", "email inside prose")
; path
expect("path", "C:\Users\MikePeutz\PortableApps\Clipjump_new_x64")
expect("path", "D:\file with spaces.txt")
expect("path", "\\server\share\folder\file.docx")
expect("text", "C:\a`nD:\b", "two paths on two lines")
expect("text", "and/or", "slash in prose")
expect("text", "C:\bad|name.txt", "illegal path character")
; color
expect("color", "#1DBC55")
expect("color", "#fff")
expect("color", "#80FF000A")
expect("color", "rgb(29, 188, 85)")
expect("color", "rgba(29,188,85,.5)")
expect("color", "hsl(140 73% 43%)")
expect("text", "#12345", "five hex digits")
expect("text", "#hashtag", "hashtag")
; json
expect("json", '{"id": 143, "title": "x"}')
expect("json", '[1, 2, {"a": [3]}]')
expect("json", '{`n  "a": "b{",`n  "c": "}d"`n}', "braces inside strings")
expect("text", '{"a": 1', "unbalanced")
expect("text", "{not json}", "braces around words is still json-shaped: needs a colon or comma")
; number
expect("number", "1299")
expect("number", "-1,299.00")
expect("number", "$4,500")
expect("number", "3.14159")
expect("number", "€1,200", "euro prefix")
expect("text", "1.", "trailing dot")
expect("text", "1 2 3", "spaced digits")
; phone
expect("phone", "+1 (415) 555-0134")
expect("phone", "415-555-0134")
expect("phone", "+31 6 12345678")
expect("number", "12", "two digits is a number, not a phone")
; code
expect("code", "def render(state):`n    return Card(state).draw()")
expect("code", "function f() {`n  return 1;`n}")
expect("code", "#!/bin/bash`necho hi")
expect("code", "import os`nimport sys")
expect("code", "int x = 1;`nint y = 2;")
expect("text", "The quick brown fox`njumps over the lazy dog", "two prose lines")
expect("text", "Brings the Latest Resources widget in line with the Figma mockup.", "prose")
; text and guards
expect("text", "")
expect("text", "hello")
expect("text", "Line one`nLine two`nLine three")
big := ""
loop 70000
    big .= "x"
t0 := A_TickCount
expect("text", big, "70 KB input")
check(A_TickCount - t0 < 20, "big input classified in " (A_TickCount - t0) " ms")
code := ""
loop 1500
    code .= "int v" A_Index " = " A_Index ";`n"
t0 := A_TickCount
expect("code", code, "60 KB of code")
check(A_TickCount - t0 < 30, "60 KB code classified in " (A_TickCount - t0) " ms")

check(ClipType.Label("url") = "URL", "Label falls back to the upper-cased kind without TXT")
check(ClipType.IsKind("json") && !ClipType.IsKind("JSONX"), "IsKind")

check(ClipType.StripTracking("https://x.com/a?utm_source=n&id=5&fbclid=z#top") = "https://x.com/a?id=5#top", "StripTracking keeps other params and the fragment")
check(ClipType.StripTracking("https://x.com/a?utm_source=n") = "https://x.com/a", "StripTracking drops an empty query")
check(ClipType.FolderOf("C:\dir\sub\file.txt") = "C:\dir\sub", "FolderOf a file")
check(ClipType.FolderOf("C:\dir\sub") = "C:\dir", "FolderOf a folder path is its parent")
check(ClipType.ColorHex("rgb(29, 188, 85)") = "#1DBC55", "ColorHex from rgb()")
check(ClipType.ColorRgbText("#1DBC55") = "rgb(29, 188, 85)", "ColorRgbText from hex")
check(ClipType.FormatNumber("1299.5") = "1,299.5", "FormatNumber adds separators")
check(ClipType.FormatNumber("-4500") = "-4,500", "FormatNumber negative")
check(ClipType.MarkdownLink("https://github.com/aviaryan/Clipjump") = "[github.com](https://github.com/aviaryan/Clipjump)", "MarkdownLink uses the host")
check(ClipType.Actions("url").Length = 2 && ClipType.Primary("url").id = "open", "url actions")
check(ClipType.Actions("text").Length = 0 && ClipType.Primary("text") = "", "text has no actions")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
