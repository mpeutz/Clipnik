; Unit tests for the built-in paste formats (src/core/transforms.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\transforms.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\src\core\transforms.ahk

global TXT := CJMap(), PLUGINS := CJMap()
PLUGINS.pformat := CJMap()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
same(a, b, msg) => check(a == b, msg (a == b ? "" : "  -> [" StrReplace(a, "`n", "\n") "]"))

same(Transform_Upper("Hello wörld"), "HELLO WÖRLD", "upper")
same(Transform_Lower("Hello WÖRLD"), "hello wörld", "lower")
same(Transform_Title("the quick brown fox"), "The Quick Brown Fox", "title")
same(Transform_Title("already Mixed CASE"), "Already Mixed CASE", "title keeps inner case")
same(Transform_OneLine("  a`r`n b`n`n  c  "), "a b c", "one line")
same(Transform_Slugify("Hello, World! Clipnik 2.0"), "hello-world-clipnik-2-0", "slugify")
same(Transform_StripTracking("https://x.com/p?utm_source=a&q=1"), "https://x.com/p?q=1", "strip tracking")
same(Transform_MarkdownLink("https://github.com/a/b"), "[github.com](https://github.com/a/b)", "markdown link")
same(Transform_MarkdownLink("not a url"), "not a url", "markdown link leaves non-urls alone")
same(Transform_PrettyJson('{"a":[1,2,{"b":"x}y"}],"c":null}'), '{`n  "a": [`n    1,`n    2,`n    {`n      "b": "x}y"`n    }`n  ],`n  "c": null`n}', "pretty json")
same(Transform_MinifyJson('{ "a" : [ 1, 2 ],`n "b": "keep  spaces" }'), '{"a":[1,2],"b":"keep  spaces"}', "minify json")
same(Transform_PrettyJson("not json"), "not json", "pretty leaves non-json alone")
same(Transform_Base64("SGVsbG8gd29ybGQ="), "Hello world", "base64 decode")
same(Transform_Base64("Hello world"), "Hello world", "base64 leaves plain text alone")

Transforms.Register()
check(PLUGINS.pformat.HasKey("upper") && PLUGINS.pformat["upper"]["*"] = "Transform_Upper", "registered into PLUGINS.pformat")
check(PLUGINS.pformat["upper"]["Previewable"] = 1, "previewable")
check(Transforms.AppliesTo(PLUGINS.pformat["stripTracking"], "url") && !Transforms.AppliesTo(PLUGINS.pformat["stripTracking"], "text"), "AppliesTo by kind")
check(Transforms.AppliesTo(PLUGINS.pformat["upper"], "text"), "upper applies to text")
n := 0
for k, v in PLUGINS.pformat
    n++
check(n = 10, "ten built-in formats (" n ")")
Transforms.Register()
n := 0
for k, v in PLUGINS.pformat
    n++
check(n = 10, "Register is idempotent")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
