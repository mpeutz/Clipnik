; Tests for CJMap (lib/v2compat.ahk): v1 object semantics on top of Map.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\cjmap.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk

global STORE := Map(), CJGUI := Map()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}

m := CJMap()
check(m["missing"] = "", "missing key reads as empty string")
check(m.missing = "", "missing dot-property reads as empty string")
check(!m.HasKey("missing"), "HasKey false")

m[1] := "one", m["2"] := "two", m[3] := "three"
check(m["1"] = "one" && m[2] = "two", "integer and numeric-string keys unify")
check(m.Count = 3, "count 3")
check(m.MaxIndex() = 3 && m.MinIndex() = 1, "MaxIndex/MinIndex")

m.Insert("four")
check(m[4] = "four", "Insert appends at MaxIndex+1")
m.Insert("name", "Default")
check(m.name = "Default" && m["NAME"] = "Default", "Insert(key,value), case-insensitive")
m.NG := 0
check(m["ng"] = 0, "dot-set writes item")

order := ""
for k, v in m
    order .= k ","
check(order = "1,2,3,4,name,NG,", "enumeration order ints then strings: " order)

removed := m.Remove(2)
check(removed = "two" && m[2] = "three" && m[3] = "four" && !m.Has(4), "Remove(int) shifts higher keys down")
check(m.MaxIndex() = 3, "MaxIndex after shift")
m.Remove(9)
check(m.MaxIndex() = 3 && m[3] = "four", "Remove(absent int) above max is harmless")
m.Remove(1)
check(m[1] = "three" && m[2] = "four" && m.MaxIndex() = 2, "Remove(1) twice-style compaction")
m.Remove("name")
check(!m.Has("name"), "Remove(strKey)")
m[5] := "five"
m.Remove(5, "")
check(!m.Has(5) && m.MaxIndex() = 2, "Remove(key, '') no shift")
last := m.Remove()
check(last = "four" && m.MaxIndex() = 1, "Remove() pops highest int")

; nested
cps := CJMap()
cps[0] := CJMap()
cps[0][7] := CJMap("Tags", "work", "fixed", 1)
check(cps[0][7]["Tags"] = "work" && cps["0"]["7"].fixed = 1, "nested mixed access")
check(cps[0][8] = "", "missing nested leaf returns empty")
cps[0][7].Tags := "home"
check(cps[0][7]["tags"] = "home", "nested dot-set")
cps.CN := CJMap()
cps.CN.Total := 4
check(cps["CN"]["Total"] = 4, "dot chain set")

; constructor pairs and clone
a := CJMap("H", "history", "O", "organizer", 3, "three")
c := a.Clone()
c["H"] := "changed"
check(a.H = "history" && c.H = "changed" && c[3] = "three", "Clone is independent")
check(a.Length = 3, "Length is MaxIndex")

; Map's own members are not shadowed
check(a.Count = 3, "Count remains Map.Count")
a.cnt := 9
check(a["cnt"] = 9, "cnt item")

; keys like "007" stay strings, negative ints are ints
z := CJMap()
z["007"] := "s", z[-1] := "neg"
check(z.Has("007") && !z.Has(7) && z.Has("-1"), "non-canonical numeric strings stay strings")

; VarGet/VarSet fallbacks
global knownGlobal := "kg"
check(VarGet("knownGlobal") = "kg", "VarGet reads a global")
VarSet("knownGlobal", "kg2")
check(knownGlobal = "kg2", "VarSet writes a global")
VarSet("unknownName", 5)
check(VarGet("unknownName") = 5 && STORE["unknownName"] = 5, "unknown names fall back to STORE")
check(HasFuncByName("check") && !HasFuncByName("nope_" A_TickCount), "HasFuncByName")
check(FuncByName("check") is Func, "FuncByName returns Func")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
