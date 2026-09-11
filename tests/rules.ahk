; Unit tests for the copy-time rules engine (src/core/rules.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\rules.ahk
#Requires AutoHotkey v2.0
#Warn All, Off   ; cliptype.ahk's ClipType.Of/Store reference clipPref/AddClipPref/CDS, which only Clipjump.ahk defines
#Include ..\lib\v2compat.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\src\core\rules.ahk

global TXT := CJMap(), CONFIGURATION_FILE := A_Temp "\cj_rules_test.ini"
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}

r := Rules.Parse("on=1;kinds=url,email;regex=;app=chrome.exe;action=channel:2")
check(IsObject(r) && r["on"] = 1 && r["kinds"].Length = 2 && r["kinds"][1] = "url", "parse kinds")
check(r["app"] = "chrome.exe" && r["action"] = "channel" && r["arg"] = "2", "parse app and action")
check(Rules.Serialize(r) = "on=1;kinds=url,email;regex=;app=chrome.exe;action=channel:2;name=", "serialize round trip")
check(Rules.Parse("garbage") = "", "unparseable line is rejected")
check(Rules.Parse("on=1;kinds=;regex=;app=;action=ignore") = "", "a rule needs at least one condition")

r2 := Rules.Parse("on=1;kinds=;regex=^\d{4} \d{4} \d{4} \d{4}$;app=;action=ignore;name=Card numbers")
check(IsObject(r2) && r2["name"] = "Card numbers", "regex-only rule with a name")
check(Rules.Serialize(Rules.Parse(Rules.Serialize(r2))) = Rules.Serialize(r2), "serialize is stable")
check(Rules.Validate(Rules.Parse("on=1;kinds=;regex=(unclosed;app=;action=ignore")) != "", "invalid regex reported")
check(Rules.Validate(r) = "", "valid rule passes")
check(Rules.Validate(Rules.Parse("on=1;kinds=url;regex=;app=;action=channel:-1")) != "", "a negative channel is rejected")
check(Rules.Validate(Rules.Parse("on=1;kinds=url;regex=;app=;action=channel:0")) = "", "channel 0 is valid")

; ';' separates the fields on a stored line, so values containing it must survive a round trip
rs := Rules.New()
rs["regex"] := "^a;b$", rs["app"] := "a;b.exe", rs["class"] := "A;B", rs["name"] := "semi;colon", rs["action"] := "tag", rs["arg"] := "a;b"
rp := Rules.Parse(Rules.Serialize(rs))
check(IsObject(rp) && rp["regex"] == "^a;b$" && rp["arg"] == "a;b", "';' in regex and arg survives serialize/parse")
check(IsObject(rp) && rp["app"] == "a;b.exe" && rp["class"] == "A;B" && rp["name"] == "semi;colon", "';' in app, class and name survives")
check(IsObject(rp) && Rules.Match(rp, "text", "a;b", "a;b.exe", "A;B"), "the round-tripped rule still matches a;b")
rpc := Rules.New()
rpc["regex"] := "100%;x", rpc["action"] := "tag", rpc["arg"] := "%3B"
rpc2 := Rules.Parse(Rules.Serialize(rpc))
check(IsObject(rpc2) && rpc2["regex"] == "100%;x" && rpc2["arg"] == "%3B", "'%' is escaped, not read back as an escape")

check(Rules.Match(r, "url", "https://x.com", "chrome.exe"), "match kind and app")
check(!Rules.Match(r, "url", "https://x.com", "firefox.exe"), "app mismatch")
check(!Rules.Match(r, "text", "hello", "chrome.exe"), "kind mismatch")
check(Rules.Match(r, "email", "a@b.co", "Chrome.EXE"), "app match is case-insensitive")
check(Rules.Match(r2, "number", "4111 1111 1111 1111", ""), "regex rule matches")
check(!Rules.Match(r2, "text", "4111 1111", ""), "regex rule does not match")
r3 := Rules.Parse("on=0;kinds=url;regex=;app=;action=ignore")
check(!Rules.Match(r3, "url", "https://x.com", ""), "disabled rule never matches")
r4 := Rules.Parse("on=1;kinds=path;regex=;app=explorer.exe,AutoHotkey64.exe;action=tag:files")
check(Rules.Match(r4, "path", "C:\x", "autohotkey64.exe"), "app list matches any entry")
r5 := Rules.Parse("on=1;kinds=;regex=;app=;action=ignore;class=Notepad")
check(r5 != "" && Rules.Match(r5, "text", "x", "notepad.exe", "Notepad") && !Rules.Match(r5, "text", "x", "notepad.exe", "Chrome_WidgetWin_1"), "window class condition")

list := [r3, r, r2]
hit := Rules.Evaluate(list, "url", "https://x.com", "chrome.exe")
check(IsObject(hit) && hit["action"] = "channel", "first enabled matching rule wins")
check(Rules.Evaluate(list, "code", "x;`ny;", "chrome.exe") = "", "no match returns empty")

w := Rules.Describe(r)
check(InStr(w[1], "URL") && InStr(w[1], "chrome.exe") && InStr(w[2], "2"), "describe: [" w[1] "] [" w[2] "]")

try FileDelete(CONFIGURATION_FILE)
Rules.Save([r, r2])
Rules.Load()
check(Rules.List.Length = 2 && Rules.List[2]["name"] = "Card numbers", "save and load through the ini")
Rules.Save([])
Rules.Load()
check(Rules.List.Length = 0, "saving an empty list clears the section")
try FileDelete(CONFIGURATION_FILE)

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
