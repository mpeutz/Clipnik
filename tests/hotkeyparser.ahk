; Tests for lib/HotkeyParser.ahk, expected values from the examples in the file header.
#Requires AutoHotkey v2.0
#Include ..\lib\HotkeyParser.ahk

fails := 0
check(actual, expected, msg) {
    global fails
    ok := (actual == expected)
    FileAppend((ok ? "ok   " : "FAIL ") msg " -> [" actual "]" (ok ? "" : " expected [" expected "]") "`n", "*")
    if !ok
        fails++
}
check(HParse("Cntrol + ass + S", false), "", "invalid entry with RemoveInvalid=false")
check(HParse("Contrl + At + S"), "^!S", "fuzzy Ctrl Alt S")
check(HParse("^!s"), "^!s", "already ahk format")
check(HParse("LeftContrl + X"), "LControl & X", "LControl & X")
check(HParse("Contrl + Pageup + S"), "", "invalid: two non-modifiers")
check(HParse("PagUp + Ctrl", true), "^PgUp", "ManageOrder reorders")
check(HParse("PagUp + Ctrl", true, false), "", "ManageOrder off rejects unordered")
check(HParse("Ctrl + Alt + Ctrl + K"), "", "duplicate modifiers rejected")
check(HParse("Control + Alt"), "^Alt", "two modifiers only")
check(HParse("Ctrl + F1 + Nmpd1"), "", "invalid: two keys")
check(HParse("Prbitscreen + f1"), "PrintScreen & F1", "PrintScreen & F1")
check(HParse("Prbitscreen + yyy"), "PrintScreen", "invalid part removed")
check(HParse("f1+ browser_srch"), "F1 & Browser_Search", "F1 & Browser_Search")
check(HParse("Ctrl + joy1"), "Ctrl & Joy1", "Ctrl & Joy1")
check(HParse("pagup & paegdown"), "PgUp & PgDn", "PgUp & PgDn")
check(HParse("Ctrl + printskreen", 1, 1, 1), "^{PrintScreen}", "send mode braces")
check(HParse("Ctrl+Alt+k"), "^!k", "customizer style")
check(HParse_rev("^!s"), "Ctrl + Alt + S", "rev ^!s")
check(HParse_rev("Pgup & PgDn"), "Pgup + PgDn", "rev ampersand")
check(HParse_rev("^+a"), "Ctrl + Shift + A", "rev ^+a")
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
