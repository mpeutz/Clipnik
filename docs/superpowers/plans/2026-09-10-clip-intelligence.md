# Clip Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every text clip gets a detected kind (url, email, path, color, json, number, phone, code, text) that is stored, shown on the paste card, History, Organizer and copy toast, drives type actions and a Z format menu, and feeds copy-time rules edited in Settings.

**Architecture:** Three new core modules (`src/core/cliptype.ahk` detector and actions, `src/core/transforms.ahk` paste formats, `src/core/rules.ahk` rule engine) plug into the existing clipboard hook (`clipChange` in `Clipjump.ahk`), the paste-format table (`PLUGINS.pformat`), the history database and the two WebView2 pages. The kind is detected once at copy time and stored (history `kind` column, channel clip pref `Kind`); older data is classified lazily on display and by a startup backfill.

**Tech Stack:** AutoHotkey v2.0.27 (portable `runtime/AutoHotkey64.exe`), SQLite via `lib/SQLiteDB`, WebView2 pages in vanilla JS/CSS under `ui/`, native Gui windows themed by `src/ui/native/Theme.ahk`. Tests are AHK scripts under `tests/` run with `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/<name>.ahk` from Git Bash; `bash tests/run-all.sh` runs everything (interactive suites need a running Clipjump and an idle desktop).

**Spec:** `docs/superpowers/specs/2026-09-10-clip-intelligence-design.md`

## Global Constraints

- AHK v2 only. A static field and a static method of one class must not share a name (case-insensitive). Functions that read globals declare `global` (or list them). Never use `Send` with the hotkey's own key inside a hotkey.
- `Critical "On"` code paths (the clipboard hook, `paste()`) must not sleep, show dialogs or touch the clipboard beyond what they do today.
- The detector must return in under 5 ms for a 64 KB input; anything larger returns `text` at once.
- Kinds are exactly: `url`, `email`, `path`, `color`, `json`, `number`, `phone`, `code`, `text`. Stored lowercase. Images and file clips are never classified.
- All user-visible strings go to `languages/english.txt` as `KEY = text` lines and are read as `TXT.KEY`. Other languages fall back to English automatically.
- American English in code, comments and strings. Hyphens, not em dashes.
- Every task ends with `runtime\AutoHotkey64.exe /ErrorStdOut /validate Clipjump.ahk` exiting 0 (warnings from `lib/vendor/WebView2` are expected) and the named tests passing. Restart the running app with `powershell -NoProfile -Command "Start-Process -FilePath '.\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipjump.ahk'"` before live tests. Never `git checkout -- settings.ini`.
- Ask the user before every commit (project rule); the commit steps below are the proposed message.

---

## File map

| File | Responsibility |
|---|---|
| `src/core/cliptype.ahk` (new) | `ClipType`: kind detection, kind labels, per-kind actions and their text helpers |
| `src/core/transforms.ahk` (new) | `Transforms`: built-in paste formats registered into `PLUGINS.pformat`, applicability by kind, JSON pretty/minify |
| `src/core/rules.ahk` (new) | `Rules`: parse, serialize, match, evaluate, load/save `[Rules]` |
| `src/core/history.ahk` | `kind` column migration, insert with kind, query filter, lazy classify, backfill |
| `Clipjump.ahk` | includes, `clipChange` integration (kind, rules, toast), `Formatting` Z menu, `showCopyToast`, `reloadRules` |
| `src/ui/native/Hud.ahk` | kind pill with swatch, menu items with `dim` and `check` |
| `src/ui/native/Theme.ahk` | pill swatch in `DrawPill`/`SetPill` |
| `src/ui/native/Toast.ahk` | kind label, swatch and action chip on a toast |
| `src/ui/web/HistoryWin.ahk`, `ui/history/*` | type column, filter, Actions menu, `action` message |
| `src/ui/web/OrganizerWin.ahk`, `ui/organizer/*` | kind badge, Actions menu |
| `ui/common/util.js`, `ui/common/theme.css` | shared popup menu, kind badge style |
| `src/ui/native/SettingsWin.ahk` | Rules page |
| `src/ui/native/RuleDialog.ahk` (new) | rule editor dialog |
| `src/ui/native/IgnoredWindowsWin.ahk` | window picker factored into `IgnoredWindowsWin.Pick()` |
| `src/core/settings.ahk` | load/save rules with the other settings |
| `languages/english.txt` | new strings |
| `tests/cliptype.ahk`, `tests/transforms.ahk`, `tests/rules.ahk` (new unit) and `tests/rules_flow.ahk` (new live); edits to `tests/pastemode.ahk`, `tests/history_flow.ahk`, `tests/run-all.sh` |

---

### Task 1: ClipType.Detect

**Files:**
- Create: `src/core/cliptype.ahk`
- Create: `tests/cliptype.ahk`
- Modify: `Clipjump.ahk` (include line after `src\core\clipboard.ahk`), `tests/run-all.sh`, `languages/english.txt`

**Interfaces:**
- Produces: `ClipType.Kinds` (Array of the nine kind strings in detection order), `ClipType.Detect(text) -> String`, `ClipType.Label(kind) -> String` (upper-case translated label, e.g. "URL"), `ClipType.IsKind(s) -> Bool`.

- [ ] **Step 1: Write the failing test**

`tests/cliptype.ahk`:

```ahk
; Unit tests for ClipType.Detect (src/core/cliptype.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\cliptype.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk
#Include ..\src\core\cliptype.ahk

global TXT := CJMap()
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

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/cliptype.ahk`
Expected: load error naming `..\src\core\cliptype.ahk` (file missing), exit code 2.

- [ ] **Step 3: Write the detector**

`src/core/cliptype.ahk`:

```ahk
; cliptype.ahk - what a text clip is. ClipType.Detect classifies text once at copy time; the kind is stored with
; the clip (history column "kind", channel clip pref "Kind") and read back everywhere a clip is shown.
;
;   ClipType.Detect(text)   -> "url" | "email" | "path" | "color" | "json" | "number" | "phone" | "code" | "text"
;   ClipType.Label(kind)    -> translated upper-case label (TXT.KIND_<kind>, falls back to the kind itself)
;   ClipType.IsKind(s)      -> true for one of the nine kinds
;
; Detection is deliberately conservative: a clip is a URL only when the whole trimmed text is one URL, an email
; only when it is one address, and so on. Anything ambiguous is "text".

class ClipType {
	static Kinds := ["url", "email", "path", "color", "json", "number", "phone", "code", "text"]
	static MaxBytes := 65536

	static IsKind(s) {
		for k in ClipType.Kinds
			if (k = s)
				return true
		return false
	}

	static Label(kind) {
		global TXT
		key := "KIND_" kind
		try if (TXT[key] != "")
			return StrUpper(TXT[key])
		return StrUpper(kind)
	}

	static Detect(text) {
		if (StrLen(text) * 2 > ClipType.MaxBytes)
			return "text"
		t := Trim(text, " `t`r`n")
		if (t = "")
			return "text"
		oneLine := !InStr(t, "`n")
		if oneLine {
			if ClipType.IsUrl(t)
				return "url"
			if ClipType.IsEmail(t)
				return "email"
			if ClipType.IsPath(t)
				return "path"
			if ClipType.IsColor(t)
				return "color"
		}
		if ClipType.IsJson(t)
			return "json"
		if oneLine {
			if ClipType.IsNumber(t)
				return "number"
			if ClipType.IsPhone(t)
				return "phone"
		}
		if ClipType.IsCode(t)
			return "code"
		return "text"
	}

	static IsUrl(t) => !InStr(t, " ") && RegExMatch(t, "i)^(?:(?:https?|ftp|file)://[^\s]+|www\.[a-z0-9-]+(?:\.[a-z0-9-]+)+[^\s]*)$")

	static IsEmail(t) => RegExMatch(t, "i)^[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$")

	static IsPath(t) => RegExMatch(t, '^(?:[A-Za-z]:\\|\\\\[^\\/:*?"<>|]+\\)[^\x00-\x1f/:*?"<>|]*$')

	static IsColor(t) => RegExMatch(t, "i)^(?:#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})|rgba?\([^)]*\)|hsla?\([^)]*\))$")

	; starts with { or [, ends with the matching bracket, brackets balance outside strings, and there is at least
	; one : or , outside strings so "{word}" is not JSON
	static IsJson(t) {
		first := SubStr(t, 1, 1), last := SubStr(t, -1)
		if !((first = "{" && last = "}") || (first = "[" && last = "]"))
			return false
		depth := 0, inStr := false, esc := false, punct := false
		loop parse t {
			c := A_LoopField
			if inStr {
				if esc
					esc := false
				else if (c = "\")
					esc := true
				else if (c = '"')
					inStr := false
				continue
			}
			switch c {
				case '"': inStr := true
				case "{", "[": depth++
				case "}", "]":
					depth--
					if (depth < 0)
						return false
				case ":", ",": punct := true
			}
		}
		return depth = 0 && !inStr && punct
	}

	static IsNumber(t) => RegExMatch(t, "^[-+]?[$€£¥]?\s?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?%?$")

	static IsPhone(t) {
		if !RegExMatch(t, "^\+?[\d\s().-]+$")
			return false
		digits := RegExReplace(t, "\D")
		return StrLen(digits) >= 7 && StrLen(digits) <= 15
	}

	; two or more lines and a strong signal; checked on the first 40 lines only
	static IsCode(t) {
		if !InStr(t, "`n")
			return false
		lines := StrSplit(t, "`n", "`r")
		if (lines.Length < 2)
			return false
		if RegExMatch(lines[1], "^#!")
			return true
		ending := 0, keyword := 0, indented := 0, n := 0
		for line in lines {
			if (++n > 40)
				break
			s := RTrim(line)
			if (s = "")
				continue
			if RegExMatch(s, "[;{]$")
				ending++
			if RegExMatch(s, "^\s*(?:def |function |import |class |#include|using |from \w+ import |public |private |const |let |var |return |if \(|for \(|while \()")
				keyword++
			if RegExMatch(s, "^(?:\t| {2,})")
				indented++
		}
		return ending >= 2 || keyword >= 1 || (indented >= 1 && InStr(t, "{") && InStr(t, "}"))
	}
}
```

Add to `languages/english.txt` (after the `ABT_portable = portable` line):

```
KIND_url = URL
KIND_email = Email
KIND_path = Path
KIND_color = Color
KIND_json = JSON
KIND_number = Number
KIND_phone = Phone
KIND_code = Code
KIND_text = Text
```

Add the include to `Clipjump.ahk` right after the line `#Include %A_ScriptDir%\src\core\clipboard.ahk`:

```ahk
#Include %A_ScriptDir%\src\core\cliptype.ahk
```

In `tests/run-all.sh` change the unit test line to:

```bash
run cjmap.ahk; run hotkeyparser.ahk; run sqlitedb.ahk; run clipfile.ahk; run cliptype.ahk; run webhost_demo.ahk 60
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/cliptype.ahk`
Expected: every line `ok`, last line `ALL PASSED`. If a regex case fails, fix the regex, not the test, unless the test's expectation contradicts the spec. Then run `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate Clipjump.ahk` and expect exit 0.

- [ ] **Step 5: Commit (ask first)**

```bash
git add src/core/cliptype.ahk tests/cliptype.ahk tests/run-all.sh Clipjump.ahk languages/english.txt
git commit -m "Clip kinds: ClipType.Detect with unit tests"
```

---

### Task 2: Store the kind (history column, clip pref, copy hook, backfill)

**Files:**
- Modify: `src/core/history.ahk` (`createHisTable`, `addHistoryText`, `historyQuery`, `historyGet`, new `historyMigrate`, `historyEnsureKind`, `historyKinds`, `historyBackfillKinds`)
- Modify: `src/core/cliptype.ahk` (add `ClipType.Of`, `ClipType.Store`)
- Modify: `Clipjump.ahk` (`clipChange` text branch records the kind; `ClipPref_makeKeys` list; backfill timer at startup)
- Create: `tests/history_kinds.ahk` (unit, temp database)
- Modify: `tests/run-all.sh`

**Interfaces:**
- Consumes: `ClipType.Detect`.
- Produces: `addHistoryText(data, timestamp, kind := "")`; `historyQuery(crit, partial, sort, asc, offset, limit, kind := "")` rows gain `kind`; `historyGet(id)` gains `kind`; `historyEnsureKind(id) -> kind`; `historyKinds() -> Array of kind strings present`; `historyBackfillKinds(batch := 200) -> rows updated`; `ClipType.Of(ch, clip) -> kind` (channel clip, stored pref or detect-and-store); `ClipType.Store(ch, clip, kind)`; global `LASTKIND` set by `clipChange` for the toast.

- [ ] **Step 1: Write the failing test**

`tests/history_kinds.ahk`:

```ahk
; Unit tests for the kind column in src/core/history.ahk against a temporary database.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\history_kinds.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\v2compat.ahk
#Include ..\lib\SQLiteDB\SQLiteDB.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\src\core\history.ahk
SQLiteDB.DLL := A_ScriptDir "\..\sqlite3.dll"

global TXT := CJMap(), HISTORYOBJ := CJMap(), STORE := Map(), CJGUI := Map()
global DB := SQLiteDB()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
; helpers the history file expects from lib/anticj_func_labels.ahk
escapeQuotesSql(s) => StrReplace(s, '"', '""')
fileSizeFromStr(s) => StrLen(s) + 3
execSql(s, warn := 0) {
    global DB
    if !DB.Exec(s) && warn
        FileAppend("SQL error: " DB.ErrorMsg "`n", "*")
}
getFromTable(tbl, cols, condition) {
    global DB
    if !DB.Query("select " cols " from " tbl " where " condition, &rs)
        return ""
    row := ""
    if (rs.Next(&row) <= 0)
        row := ""
    rs.Free()
    return row
}
convertTimeSql(t) => FormatTime(t, "yyyy-MM-dd HH:mm:ss")

tmp := A_Temp "\cj_kinds.db"
try FileDelete(tmp)
check(DB.OpenDB(tmp), "open temp db")
; an old-style table without the kind column
DB.Exec("create table history (id integer primary key autoincrement, data text, type integer, fileid text, time text, size integer)")
DB.Exec('insert into history (data, type, time, size) values ("https://example.com", 0, "2026-09-10 10:00:00", 22)')
DB.Exec('insert into history (data, type, time, size) values ("plain words here", 0, "2026-09-10 10:01:00", 19)')
DB.Exec('insert into history (data, type, time, size, fileid) values ("[IMAGE]", 1, "2026-09-10 10:02:00", 100, "cache\\history\\x.jpg")')

historyMigrate()
check(DB.GetTable("pragma table_info(history)", &ti) && InStr(ti2str(ti), "kind"), "migration adds the kind column")
ti2str(tb) {
    s := ""
    loop tb.RowCount {
        tb.Next(&r)
        s .= r[2] ","
    }
    return s
}
historyMigrate()
check(true, "migration is idempotent (no error on second run)")

addHistoryText("mike@example.com", A_Now, "email")
rec := historyGet(4)
check(rec["kind"] = "email", "insert stores the kind")
addHistoryText("#1DBC55", A_Now)
check(historyGet(5)["kind"] = "color", "insert detects the kind when none is given")

check(historyEnsureKind(1) = "url", "lazy classification of an old row")
check(historyGet(1)["kind"] = "url", "lazy classification is written back")
check(historyEnsureKind(3) = "", "image rows are never classified")

n := historyBackfillKinds(10)
check(n = 1, "backfill classifies the remaining text row (" n ")")
check(historyGet(2)["kind"] = "text", "backfilled row is text")
check(historyBackfillKinds(10) = 0, "nothing left to backfill")

r := historyQuery("", true, "time", false, 0, 50, "url")
check(r["rows"].Length = 1 && r["rows"][1]["kind"] = "url", "query filtered by kind")
check(r["matched"] = 1, "matched count honors the kind filter")
r := historyQuery("", true, "time", false, 0, 50)
check(r["rows"].Length = 5, "no filter returns all rows")
kinds := historyKinds()
check(kinds.Length = 4, "historyKinds lists the distinct kinds present (" kinds.Length ")")

DB.CloseDB()
try FileDelete(tmp)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/history_kinds.ahk`
Expected: error "Call to nonexistent function historyMigrate" or the migration check failing.

- [ ] **Step 3: Implement the storage**

In `src/core/history.ahk`, after `createHisTable()` add:

```ahk
; adds the kind column to databases created before clip kinds existed (cheap: SQLite appends the column)
historyMigrate() {
	global DB
	has := false
	if DB.GetTable("pragma table_info(history)", &tb) {
		loop tb.RowCount {
			tb.Next(&r)
			if (r[2] = "kind")
				has := true
		}
	}
	if !has
		DB.Exec("alter table history add column kind text")
}

; the stored kind of one row, classifying and writing it back when missing; "" for images
historyEnsureKind(id) {
	global DB
	row := getFromTable("history", "type, kind, data", "id=" id)
	if !row || (row[1] = 1)
		return ""
	if (row[2] != "")
		return row[2]
	kind := ClipType.Detect(row[3])
	execSql('update history set kind="' kind '" where id=' id)
	return kind
}

; classifies up to batch old text rows; returns how many were updated (0 when done)
historyBackfillKinds(batch := 200) {
	global DB
	if !DB.GetTable("select id, data from history where type=0 and (kind is null or kind='') limit " batch, &tb)
		return 0
	n := 0
	DB.Exec("begin")
	loop tb.RowCount {
		tb.Next(&r)
		execSql('update history set kind="' ClipType.Detect(r[2]) '" where id=' r[1])
		n++
	}
	DB.Exec("commit")
	return n
}

; distinct kinds present, detection order
historyKinds() {
	global DB
	out := []
	if !DB.GetTable("select distinct kind from history where kind is not null and kind!=''", &tb)
		return out
	present := Map()
	loop tb.RowCount {
		tb.Next(&r)
		present[r[1]] := true
	}
	for k in ClipType.Kinds
		if present.Has(k)
			out.Push(k)
	return out
}
```

Change `addHistoryText`:

```ahk
addHistoryText(data, timestamp, kind := ""){
; adds some text data to history; the timestamp is in A_Now format; kind is detected when not given
	timestamp := convertTimeSql( timestamp )
	if (kind = "")
		kind := ClipType.Detect(data)
	q := 'insert into history (data, type, time, size, kind) values ("'
		. escapeQuotesSql(data)
		. '", 0, "'
		. timestamp '", '
		. fileSizeFromStr(data) ', "' kind '")'
	if (!DB.Exec(q))
		MsgBox(q)
}
```

In `historyQuery` change the signature to `historyQuery(crit := "", partial := true, sort := "time", asc := false, offset := 0, limit := 500, kind := "")` and, right after the `where` is built from `crit`, add:

```ahk
	if ClipType.IsKind(kind)
		where .= (where = "" ? " where " : " and ") 'kind="' kind '"'
```

Change the row query and the push to include the kind:

```ahk
	q := "select id, substr(data, 1, 300), type, time, size, fileid, kind from history" where " order by " col " " dir ", id desc limit " limit " offset " offset
	...
		out["rows"].Push(Map("id", row[1], "clip", row[2], "type", row[3], "time", row[4], "size", row[5], "fileid", row[6], "kind", row[7]))
```

Change `historyGet` to select and return `kind`:

```ahk
	data := getFromTable("history", "id, data, type, time, size, fileid, kind", "id=" id)
	if !data
		return ""
	return Map("id", data[1], "data", data[2], "type", data[3], "time", data[4], "size", data[5], "fileid", data[6], "kind", data[7])
```

In `Clipjump.ahk`, right after the line `migrateHistory()` (about line 300) add:

```ahk
historyMigrate()
SetTimer(historyBackfillTick, -4000)   ; classify old rows in small batches after startup
```

and add the function near `changeIcon()`:

```ahk
historyBackfillTick() {
	if historyBackfillKinds(200)
		SetTimer(historyBackfillTick, -250)
}
```

In `src/core/cliptype.ahk` add to the class:

```ahk
	; stored kind of a channel clip (prefs.ini Kind=), detecting and storing it on first use; "" for images
	static Of(ch, clip) {
		global CDS
		k := clipPref(ch, clip, "Kind")
		if ClipType.IsKind(k)
			return k
		text := ""
		try text := CDS[ch][clip]
		if (text = "")
			return ""
		k := ClipType.Detect(text)
		ClipType.Store(ch, clip, k)
		return k
	}

	static Store(ch, clip, kind) {
		AddClipPref(ch, clip, "Kind", kind)
	}
```

In `Clipjump.ahk` change `ClipPref_makeKeys`' static list to `static l := ["fixed", "Tags", "Kind"]`.

Add a global next to `LASTCLIP` (line 117): `LASTKIND := ""` (append `, LASTKIND := ""` to that `global` statement).

In `clipChange`, text branch, right after `LASTCLIP := clipboard_copy, temp := clipSaver()` and the `HASCOPYFAILED` guard, before the `if NOINCOGNITO ...` block, add:

```ahk
			LASTKIND := ClipType.Detect(LASTCLIP)
			ClipType.Store(CN.NG, CURSAVE, LASTKIND)
```

and change the history call to `addHistoryText(LASTCLIP, A_Now, LASTKIND)`.

In `tests/run-all.sh` add `run history_kinds.ahk;` after `run cliptype.ahk;`.

- [ ] **Step 4: Run the tests**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/history_kinds.ahk` then `tests/cliptype.ahk`, then `/validate Clipjump.ahk`.
Expected: ALL PASSED for both, validate exit 0. Restart Clipjump, copy a URL from any window, then run `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/history_flow.ahk` and expect ALL PASSED. Check `%TEMP%\Clipjump\webhost.log` shows `"kind":"url"` in the list rows.

- [ ] **Step 5: Commit (ask first)**

```bash
git add src/core/history.ahk src/core/cliptype.ahk Clipjump.ahk tests/history_kinds.ahk tests/run-all.sh
git commit -m "Store clip kinds: history column with migration and backfill, channel clip pref"
```

---

### Task 3: Show the kind on the paste card

**Files:**
- Modify: `src/ui/native/Theme.ahk` (`AddPill`, `SetPill`, `DrawPill` gain a swatch)
- Modify: `src/ui/native/Hud.ahk` (`NewState`, `FromPasteVars`, header render)
- Modify: `tests/hud_demo.ahk` (a kind state)

**Interfaces:**
- Consumes: `ClipType.Of`, `ClipType.Label`.
- Produces: `Theme.SetPill(ctl, fill, color, swatch := "")` where `swatch` is an RGB integer or `""`; state fields `kind` and `swatch` on the HUD state; `ClipType.ColorRgb(text) -> Integer` (RGB) used for the swatch (also by Task 6 actions).

- [ ] **Step 1: Add the demo state (the visual test)**

In `tests/hud_demo.ahk`, find where the "badges" state is rendered and add two captures after it, using the same capture helper the file uses for the other states (name them `kind-url` and `kind-color`):

```ahk
	s := Hud.NewState()
	s.channel := "Default", s.index := 3, s.total := 40, s.format := "TEXT", s.kind := "url", s.pformat := "Trim Formatting"
	s.text := "https://github.com/aviaryan/Clipjump/issues/143?utm_source=newsletter"
	Hud.Render(s), Sleep 250, snap("kind-url")
	s := Hud.NewState()
	s.channel := "Default", s.index := 3, s.total := 40, s.format := "TEXT", s.kind := "color", s.swatch := 0x1DBC55
	s.text := "#1DBC55"
	Hud.Render(s), Sleep 250, snap("kind-color")
```

(`snap` is the existing capture function name in that file; if it is named differently, use the file's name.) Add `#Include ..\src\core\cliptype.ahk` next to the other includes in the demo.

- [ ] **Step 2: Run the demo to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/hud_demo.ahk`
Expected: the new captures show a plain "TEXT" pill (kind ignored) or an error about `swatch`; either way the pill does not read "URL".

- [ ] **Step 3: Implement**

`src/ui/native/Theme.ahk`: in `AddPill` register the swatch, in `SetPill` accept it, in `DrawPill` paint it.

```ahk
	static AddPill(g, opts, text, fill := "surfaceAlt", color := "text", swatch := "") {
		ctl := g.Add("Button", opts " -TabStop", text)
		try DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", Theme.IsDark ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)
		Theme.RegisterDraw(ctl, "pill", {fill: fill, text: color, swatch: swatch})
		return ctl
	}

	static SetPill(ctl, fill, color, swatch := "") {
		if Theme.drawn.Has(ctl.Hwnd) {
			d := Theme.drawn[ctl.Hwnd]
			d.fill := fill, d.text := color, d.swatch := swatch
			ctl.Redraw()
		}
	}

	static DrawPill(d, hdc, rc, state) {
		p := Theme.Palette
		h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
		fill := p.Has(d.fill) ? p[d.fill] : p["surfaceAlt"], color := p.Has(d.text) ? p[d.text] : p["text"]
		Theme.PaintRoundRect(hdc, rc, fill, fill, Theme.RgbFromGui(d.ctl.Gui), h // 2)
		trc := rc
		if (d.HasProp("swatch") && d.swatch != "") {
			s := Round(10 * Theme.Scale), l := NumGet(rc, 0, "Int") + Round(8 * Theme.Scale), t := NumGet(rc, 4, "Int") + (h - s) // 2
			box := Buffer(16, 0), NumPut("Int", l, "Int", t, "Int", l + s, "Int", t + s, box)
			Theme.PaintRoundRect(hdc, box, d.swatch, Theme.Mix(d.swatch, 0xFFFFFF, 0.3), fill, Round(3 * Theme.Scale))
			trc := Buffer(16, 0), NumPut("Int", l + s, "Int", NumGet(rc, 4, "Int"), "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), trc)
		}
		Theme.PaintText(hdc, d.ctl, trc, color, 0x1 | 0x4 | 0x20 | 0x100000, 0)
	}
```

Add to the `ClipType` class in `src/core/cliptype.ahk`:

```ahk
	; RGB integer for a color clip (#hex, rgb(), hsl()); -1 when it cannot be read
	static ColorRgb(text) {
		t := Trim(text)
		if RegExMatch(t, "i)^#([0-9a-f]{3})$", &m)
			return Integer("0x" SubStr(m[1], 1, 1) SubStr(m[1], 1, 1) SubStr(m[1], 2, 1) SubStr(m[1], 2, 1) SubStr(m[1], 3, 1) SubStr(m[1], 3, 1))
		if RegExMatch(t, "i)^#([0-9a-f]{6})(?:[0-9a-f]{2})?$", &m)
			return Integer("0x" m[1])
		if RegExMatch(t, "i)^rgba?\(\s*(\d+)\s*[, ]\s*(\d+)\s*[, ]\s*(\d+)", &m)
			return (Min(255, m[1]) << 16) | (Min(255, m[2]) << 8) | Min(255, m[3])
		if RegExMatch(t, "i)^hsla?\(\s*([\d.]+)\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%", &m) {
			hh := Mod(m[1], 360) / 60, s := m[2] / 100, l := m[3] / 100
			c := (1 - Abs(2 * l - 1)) * s, x := c * (1 - Abs(Mod(hh, 2) - 1)), mm := l - c / 2
			r := 0, g := 0, b := 0
			if (hh < 1)
				r := c, g := x
			else if (hh < 2)
				r := x, g := c
			else if (hh < 3)
				g := c, b := x
			else if (hh < 4)
				g := x, b := c
			else if (hh < 5)
				r := x, b := c
			else
				r := c, b := x
			return (Round((r + mm) * 255) << 16) | (Round((g + mm) * 255) << 8) | Round((b + mm) * 255)
		}
		return -1
	}
```

`src/ui/native/Hud.ahk`:

In `NewState()` add `s.kind := "", s.swatch := ""` to the initialization line.

In `FromPasteVars()`, in the text branch after `s.text := halfClip`:

```ahk
			if (s.format = "TEXT") {
				s.kind := ClipType.Of(CN.NG, realActive)
				if (s.kind = "color")
					s.swatch := ClipType.ColorRgb(temp_clipboard)
			}
```

In the header render, replace the `if (state.format != "")` block with:

```ahk
			if (state.format != "") {
				label := (state.kind != "" && state.kind != "text") ? ClipType.Label(state.kind) : state.format
				sw := (state.kind = "color" && state.swatch != "" && state.swatch != -1) ? state.swatch : ""
				Theme.SetPill(c["format"], "surfaceAlt", "text", sw)
				Hud.Pill("format", label, x, y, rowH, sw != "" ? Hud.TextWidth(c["format"], label) + Round(34 * sc) : ""), x += c["format"].w + gap
			}
```

Check `Hud.Pill(name, text, x, y, h, w := "")`: it already accepts an explicit width; the swatch needs extra room, hence the computed width.

- [ ] **Step 4: Run the demo and live checks**

Run `tests/hud_demo.ahk`; open `tests/out/hud-dark-kind-url.png` and `hud-dark-kind-color.png` (names follow the demo's pattern) and confirm the pill reads URL, and COLOR with a green square. Validate, restart Clipjump, copy `#1DBC55` and a URL, hold Ctrl+V and cycle: the pill shows COLOR with the swatch and URL. Run `tests/pastemode.ahk` and `tests/hud_live.ahk`: ALL PASSED.

- [ ] **Step 5: Commit (ask first)**

```bash
git add src/ui/native/Theme.ahk src/ui/native/Hud.ahk src/core/cliptype.ahk tests/hud_demo.ahk
git commit -m "Paste card shows the clip kind, with a swatch for colors"
```

---

### Task 4: Kind badges and the type filter in History; badge in the Organizer

**Files:**
- Modify: `src/ui/web/HistoryWin.ahk` (`SendList`, `SendPreview`, new `kinds` message)
- Modify: `ui/history/index.html`, `ui/history/app.js`, `ui/common/theme.css`, `ui/common/mock-bridge.js`
- Modify: `src/ui/web/OrganizerWin.ahk` (`SendClips`, `SendClip`), `ui/organizer/app.js`
- Modify: `languages/english.txt`, `tests/history_flow.ahk`

**Interfaces:**
- Consumes: `historyQuery(..., kind)`, `historyKinds()`, `historyEnsureKind(id)`, `ClipType.Of`.
- Produces: page message `list` request gains `kind`; `list` response rows carry `kind`; new host→page message `kinds` `{kinds: [...], labels: {url: "URL", ...}}`; `preview` record carries `kind`; Organizer `clips` rows and `clip` record carry `kind`. JS: `cj.kindBadge(kind, labels, text)` in `util.js`.

- [ ] **Step 1: Extend the live test**

In `tests/history_flow.ahk`, after the existing `check("list sent to the page", ...)` line add:

```ahk
check(InStr(readLog(), '"cmd":"kinds"'), "kinds sent to the page")
check(InStr(readLog(), '"kind":"text"') || InStr(readLog(), '"kind":"'), "rows carry a kind")
```

- [ ] **Step 2: Run it to verify it fails**

Run `tests/history_flow.ahk` against the running app: the `kinds` check FAILS.

- [ ] **Step 3: Implement the host side**

`src/ui/web/HistoryWin.ahk` `SendList`:

```ahk
	static SendList(d) {
		global history_partial
		q := d is Map && d.Has("q") ? d["q"] : ""
		partial := d is Map && d.Has("partial") ? (d["partial"] ? true : false) : (history_partial ? true : false)
		sortBy := d is Map && d.Has("sort") ? d["sort"] : "time"
		asc := d is Map && d.Has("asc") ? (d["asc"] ? true : false) : false
		kind := d is Map && d.Has("kind") ? d["kind"] : ""
		r := historyQuery(q, partial, sortBy, asc, 0, 2000, kind)
		for row in r["rows"]
			if (row["type"] = 0 && row["kind"] = "")
				row["kind"] := historyEnsureKind(row["id"])
		r["partial"] := partial ? 1 : 0
		HistoryWin.host.Post("list", r)
		HistoryWin.SendKinds()
	}

	static SendKinds() {
		labels := Map()
		for k in ClipType.Kinds
			labels[k] := ClipType.Label(k)
		HistoryWin.host.Post("kinds", Map("kinds", historyKinds(), "labels", labels))
	}
```

In `SendPreview`, after `rec := historyGet(id)` / `if !rec return`, add `if (rec["type"] = 0 && rec["kind"] = "") rec["kind"] := historyEnsureKind(id)`.

`src/ui/web/OrganizerWin.ahk` `SendClips`: add `"kind", isImg ? "" : ClipType.Of(ch, real)` to the row Map. `SendClip`: add `"kind", isImg ? "" : ClipType.Of(ch, real)` to `m`, and after building `m` post the labels once per message: `m["labels"] := ClipType_Labels()` where you add to `cliptype.ahk`:

```ahk
; Map kind -> label, for the pages
ClipType_Labels() {
	labels := Map()
	for k in ClipType.Kinds
		labels[k] := ClipType.Label(k)
	return labels
}
```

and use `ClipType_Labels()` in `HistoryWin.SendKinds` too (replace the loop). In `OrganizerWin.SendClips` add `"labels", ClipType_Labels()` to the posted Map.

Strings in `languages/english.txt`:

```
HST_type = Type
HST_allTypes = All types
```

- [ ] **Step 4: Implement the pages**

`ui/common/util.js`: add inside `window.cj = {`:

```js
  // small badge for a clip kind; nothing for plain text or unknown
  kindBadge(kind, labels) {
    if (!kind || kind === "text") return "";
    const label = (labels && labels[kind]) || kind.toUpperCase();
    return `<span class="badge kind">${this.esc(label)}</span>`;
  },
```

`ui/common/theme.css`: after the `.badge.accent` rule:

```css
.badge.kind { background: color-mix(in srgb, var(--accent) 18%, var(--surfaceAlt)); letter-spacing: .04em; font-weight: 600; font-size: 10px; }
```

`ui/history/index.html`: toolbar, after the `</div>` that closes `.search`, before the Refresh button:

```html
    <select class="edit" id="kind" title="Type"><option value="" data-i18n="HST_allTypes">All types</option></select>
```

Header: change the `#hdr` grid to four columns and add a Type header. In the `<style>` block of `ui/history/index.html` find the `#hdr, #rows .tr { grid-template-columns: ... }` rule and change it to `grid-template-columns: minmax(0, 1fr) 84px 150px 70px;`. In `#hdr` add `<span data-i18n="HST_type">Type</span>` between the Clip and Date spans.

`ui/history/app.js`:

- state: add `kind: "", kinds: [], labels: {}` to the `state` object.
- `requestList()`: send `kind: state.kind` too.
- `render()`: change the row template to insert a type cell after the clip cell:

```js
      return `<div class="tr${state.sel.has(r.id) ? " sel" : ""}" data-id="${r.id}" tabindex="-1" draggable="false">` +
        `<span class="mono${isImg ? " dim" : ""}">${html}</span><span>${isImg ? "" : cj.kindBadge(r.kind, state.labels)}</span><span class="dim">${esc(fmtDate(r.time))}</span><span class="dim">${bytes(r.size)}</span></div>`;
```

- `showPreview(rec)`: replace the `<span class="badge">TEXT</span>` for text with `cj.kindBadge(rec.kind, state.labels) || '<span class="badge">TEXT</span>'`.
- events: add

```js
  bridge.on("kinds", (d) => {
    state.kinds = d.kinds || [], state.labels = d.labels || {};
    const sel = el("kind");
    const cur = state.kind;
    sel.innerHTML = `<option value="">${esc(T.HST_allTypes)}</option>` + state.kinds.map((k) => `<option value="${k}"${k === cur ? " selected" : ""}>${esc(state.labels[k] || k)}</option>`).join("");
    if (cur && !state.kinds.includes(cur)) { state.kind = ""; requestList(); }
  });
  el("kind").addEventListener("change", () => { state.kind = el("kind").value; requestList(); });
```

- the `opened` handler: also reset `state.kind = ""` and `el("kind").value = ""`.

`ui/common/mock-bridge.js`: when it answers `list`, also emit `kinds` with `{kinds: ["url", "email"], labels: {url: "URL", email: "Email"}}` and give mock rows a `kind`, so `ui/history/index.html` opened in Chrome shows the column.

`ui/organizer/app.js`: in the clips row template insert `${isImg ? "" : cj.kindBadge(r.kind, state.labels)} ` at the start of the tags cell, and in the `clips` handler store `state.labels = d.labels || {}`. In the preview header (where the fixed/tags props are shown for a selected clip) prepend `cj.kindBadge(rec.kind, state.labels)`.

- [ ] **Step 5: Run the tests**

Validate, restart Clipjump, run `tests/history_flow.ahk`, `tests/history_image.ahk`, `tests/organizer_flow.ahk`: ALL PASSED. Open History from the tray: rows show badges, the Type dropdown lists the kinds present, choosing URL filters the list and the status line count follows. Open `ui/history/index.html` in Chrome: the mock shows the column.

- [ ] **Step 6: Commit (ask first)**

```bash
git add src/ui/web src/core/cliptype.ahk ui languages/english.txt tests/history_flow.ahk
git commit -m "History and Organizer show clip kinds; History filters by type"
```

---

### Task 5: Kind label on the copy toast

**Files:**
- Modify: `src/ui/native/Toast.ahk` (`Show`, `Create` accept an `extra` object)
- Modify: `Clipjump.ahk` (`showCopyToast`, both copy toast call sites in `clipChange`)
- Modify: `tests/hud_demo.ahk` (toast with a kind)

**Interfaces:**
- Consumes: `LASTKIND`, `ClipType.Label`, `ClipType.ColorRgb`, `Theme.AddPill` with swatch.
- Produces: `Toast.Show(text, ms := 1500, kind := "info", slot := "", extra := "")` where `extra` is `""` or an object `{label: "URL", swatch: 0x1DBC55 or "", action: {label: "Open", fn: Func} or ""}`; `showCopyToast(channelName)` in `Clipjump.ahk`. The action chip is wired in Task 6; this task renders `label` and `swatch` and leaves `action` handling in place but unused.

- [ ] **Step 1: Demo capture**

In `tests/hud_demo.ahk` where toasts are shown, add:

```ahk
	Toast.Show("Transferred to Clipjump {Default}", 0, "info", "k1", {label: "URL", swatch: "", action: ""})
	Toast.Show("Transferred to Clipjump {Default}", 0, "info", "k2", {label: "COLOR", swatch: 0x1DBC55, action: ""})
	Sleep 300, snap("toast-kind")   ; capture the stack the way the other toast captures do
	Toast.Hide("k1"), Toast.Hide("k2")
```

- [ ] **Step 2: Run to verify it fails**

Run the demo: error "Too many parameters passed to function" from `Toast.Show`.

- [ ] **Step 3: Implement**

`src/ui/native/Toast.ahk`: change `Show` to `static Show(text, ms := 1500, kind := "info", slot := "", extra := "")` and pass `extra` to `Create(text, kind, slot, extra)`. In `Create(text, kind, slot, extra := "")`, after the pill block (`if (pill != "") { ... }`) and before the icon, add:

```ahk
		lw := 0, aw := 0
		x := padL + gw + gap + tw + (pw ? gap + pw : 0)
		if IsObject(extra) {
			if (extra.HasProp("label") && extra.label != "") {
				g.SetFont("s8 c" Theme.Hex("muted"), Theme.FontName)
				if (extra.HasProp("swatch") && extra.swatch != "" && extra.swatch != -1) {
					sw := Round(10 * s)
					g.Add("Text", "x" (x + gap) " y" ((h - sw) // 2) " w" sw " h" sw " Background" Format("{:06X}", extra.swatch))
					x += gap + sw
				}
				lbl := g.Add("Text", "x" (x + gap) " y0 h" h " +0x200", extra.label)
				lbl.GetPos(, , &lw)
				lw += gap
				x += lw
			}
			if (extra.HasProp("action") && IsObject(extra.action)) {
				g.SetFont("s8 bold c" Theme.Hex("text"), Theme.FontName)
				meter := g.Add("Text", "x0 y0 +Hidden", extra.action.label)
				meter.GetPos(, , &aw)
				Theme.Discard(meter)
				aw += Round(16 * s)
				ph := Round(20 * s)
				chip := Theme.AddPill(g, "x" (x + gap) " y" ((h - ph) // 2) " w" aw " h" ph, extra.action.label, "accentSoft", "text")
				chip.OnEvent("Click", Toast_ActionClick.Bind(extra.action.fn, slot))
				aw += gap
			}
		}
		w := x + aw + padR
```

and replace the old `w := padL + gw + gap + tw + (pw ? gap + pw : 0) + padR` line (it is now computed above). Add at the end of the file:

```ahk
Toast_ActionClick(fn, slot, *) {
	Toast.Hide(slot)
	try fn()
}
```

Add the palette color `accentSoft` in `Theme.Detect` (both palettes): after `p["accentText"] := ...` add `p["accentSoft"] := Theme.Mix(p["accent"], p["surface"], 0.82)`. The pill painter already looks names up in the palette.

`Clipjump.ahk`: add near `changeIcon()`:

```ahk
; copy toast: message, channel pill, and for a recognized kind its label (and swatch for colors)
showCopyToast(text) {
	global LASTKIND, LASTCLIP
	extra := ""
	if (LASTKIND != "" && LASTKIND != "text")
		extra := {label: ClipType.Label(LASTKIND), swatch: LASTKIND = "color" ? ClipType.ColorRgb(LASTCLIP) : "", action: ""}
	Toast.Show(text, extra != "" ? 2500 : 900, "info", "copy", extra)
}
```

In `clipChange` replace the text-branch `Toast.Show(copyMessage, 900, "info", "copy")` with `showCopyToast(copyMessage)`. Leave the image branch as it is, but set `LASTKIND := ""` at the top of the image branch (`CErrorlevel = 2`) so an image copy never carries the previous kind.

- [ ] **Step 4: Verify**

Run the demo and look at `toast-kind` capture: two toasts, the second with a green square before COLOR. Validate, restart, copy a URL: the toast reads "Transferred to Clipjump [Default] URL" and stays about 2.5 s; copy plain text: unchanged 0.9 s toast. Run `tests/hud_live.ahk`.

- [ ] **Step 5: Commit (ask first)**

```bash
git add src/ui/native/Toast.ahk src/ui/native/Theme.ahk Clipjump.ahk tests/hud_demo.ahk
git commit -m "Copy toast shows the clip kind"
```

---

### Task 6: Type actions (table, toast chip, page menus)

**Files:**
- Modify: `src/core/cliptype.ahk` (actions table, `Actions`, `Primary`, `Run`, text helpers)
- Modify: `Clipjump.ahk` (`showCopyToast` adds the action chip)
- Modify: `src/ui/web/HistoryWin.ahk`, `src/ui/web/OrganizerWin.ahk` (`action` message; preview carries actions)
- Modify: `ui/common/util.js` (`cj.menu`), `ui/common/theme.css` (`.menu`), `ui/history/index.html`, `ui/history/app.js`, `ui/organizer/index.html`, `ui/organizer/app.js`
- Modify: `tests/cliptype.ahk` (action helpers), `languages/english.txt`

**Interfaces:**
- Consumes: `Transforms.PrettyJson`, `Transforms.MinifyJson` (Task 7; until then those two actions return the text unchanged, see Step 3 note), `BrowserRun(url)` from `lib/anticj_func_labels.ahk`, `API.blockMonitoring`.
- Produces: `ClipType.Actions(kind) -> Array of {id, label, short}`; `ClipType.Primary(kind) -> action or ""`; `ClipType.Run(id, text)`; helpers `ClipType.StripTracking(url)`, `ClipType.FolderOf(path)`, `ClipType.ColorHex(text)`, `ClipType.ColorRgbText(text)`, `ClipType.FormatNumber(text)`, `ClipType.MarkdownLink(url)`; page message `action` `{id, action}` (History) and `{channel, n, action}` (Organizer); `cj.menu(anchor, items, onPick)` in `util.js`.

- [ ] **Step 1: Write the failing unit tests**

Append to `tests/cliptype.ahk` before the final summary lines:

```ahk
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
```

- [ ] **Step 2: Run to verify it fails**

Run `tests/cliptype.ahk`: "Unknown method" / nonexistent errors on `StripTracking`.

- [ ] **Step 3: Implement the action table and helpers**

Add to the `ClipType` class:

```ahk
	; ---------- actions ----------
	; per kind: ordered {id, label (TXT key), short (TXT key for the toast chip)}; the first entry is the primary one
	static ActionTable := Map(
		"url", [{id: "open", label: "ACT_open", short: "ACT_openShort"}, {id: "stripTracking", label: "ACT_stripTracking", short: ""}],
		"email", [{id: "compose", label: "ACT_compose", short: "ACT_compose"}],
		"path", [{id: "reveal", label: "ACT_reveal", short: "ACT_revealShort"}, {id: "openPath", label: "ACT_openPath", short: ""}, {id: "copyFolder", label: "ACT_copyFolder", short: ""}],
		"color", [{id: "copyHex", label: "ACT_copyHex", short: "ACT_copyHexShort"}, {id: "copyRgb", label: "ACT_copyRgb", short: "ACT_copyRgbShort"}],
		"json", [{id: "pretty", label: "ACT_pretty", short: "ACT_prettyShort"}, {id: "minify", label: "ACT_minify", short: ""}],
		"number", [{id: "formatNumber", label: "ACT_formatNumber", short: "ACT_formatNumberShort"}])

	static Actions(kind) {
		global TXT
		out := []
		if !ClipType.ActionTable.Has(kind)
			return out
		for a in ClipType.ActionTable[kind]
			out.Push({id: a.id, label: ClipType_T(a.label), short: a.short != "" ? ClipType_T(a.short) : ClipType_T(a.label)})
		return out
	}

	; primary action for a kind and clip text; "" when the kind has none
	static Primary(kind, text := "") {
		acts := ClipType.Actions(kind)
		if !acts.Length
			return ""
		if (kind = "color" && InStr(Trim(text), "#") = 1)
			return acts[2]   ; already hex: offer rgb
		return acts[1]
	}

	; runs an action on the clip text; "copy" style actions place the result on the clipboard as a normal copy
	static Run(id, text) {
		switch id {
			case "open": BrowserRun(Trim(text))
			case "stripTracking": ClipType.ToClipboard(ClipType.StripTracking(Trim(text)))
			case "compose": Run("mailto:" Trim(text))
			case "reveal": Run('explorer.exe /select,"' Trim(text) '"')
			case "openPath": Run(Trim(text))
			case "copyFolder": ClipType.ToClipboard(ClipType.FolderOf(Trim(text)))
			case "copyHex": ClipType.ToClipboard(ClipType.ColorHex(text))
			case "copyRgb": ClipType.ToClipboard(ClipType.ColorRgbText(text))
			case "pretty": ClipType.ToClipboard(Transforms.PrettyJson(text))
			case "minify": ClipType.ToClipboard(Transforms.MinifyJson(text))
			case "formatNumber": ClipType.ToClipboard(ClipType.FormatNumber(text))
		}
	}

	static ToClipboard(text) {
		if (text = "")
			return
		try A_Clipboard := text
	}

	static StripTracking(url) {
		if !RegExMatch(url, "^([^?#]*)\?([^#]*)(#.*)?$", &m)
			return url
		keep := []
		loop parse m[2], "&" {
			if (A_LoopField = "")
				continue
			key := StrSplit(A_LoopField, "=")[1]
			if RegExMatch(key, "i)^(?:utm_\w+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid|igshid|ref|ref_src|yclid|_hsenc|_hsmi)$")
				continue
			keep.Push(A_LoopField)
		}
		q := ""
		for i, p in keep
			q .= (i > 1 ? "&" : "") p
		return m[1] (q != "" ? "?" q : "") (m.Count >= 3 ? m[3] : "")
	}

	static FolderOf(path) {
		p := RTrim(path, "\")
		i := InStr(p, "\", , -1)
		return i ? SubStr(p, 1, i - 1) : p
	}

	static ColorHex(text) {
		rgb := ClipType.ColorRgb(text)
		return rgb < 0 ? "" : Format("#{:06X}", rgb)
	}

	static ColorRgbText(text) {
		rgb := ClipType.ColorRgb(text)
		return rgb < 0 ? "" : Format("rgb({}, {}, {})", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
	}

	static FormatNumber(text) {
		t := RegExReplace(Trim(text), "[,\s]")
		if !RegExMatch(t, "^([-+]?)([$€£¥]?)(\d+)(\.\d+)?(%?)$", &m)
			return Trim(text)
		int := m[3], out := ""
		while (StrLen(int) > 3)
			out := "," SubStr(int, -3) out, int := SubStr(int, 1, -3)
		return m[1] m[2] int out m[4] m[5]
	}

	static MarkdownLink(url) {
		host := RegExMatch(url, "i)^(?:https?|ftp)://([^/?#]+)", &m) ? m[1] : url
		return "[" host "](" url ")"
	}
```

Add the translation helper at file level (outside the class):

```ahk
ClipType_T(key) {
	global TXT
	try if (TXT[key] != "")
		return TXT[key]
	return key
}
```

Until Task 7 exists, add a temporary stub at the bottom of `cliptype.ahk` and remove it in Task 7:

```ahk
; removed in the transforms task
class Transforms {
	static PrettyJson(t) => t
	static MinifyJson(t) => t
}
```

Strings for `languages/english.txt`:

```
ACT_open = Open in browser
ACT_openShort = Open
ACT_stripTracking = Copy without tracking
ACT_compose = Compose
ACT_reveal = Reveal in Explorer
ACT_revealShort = Reveal
ACT_openPath = Open
ACT_copyFolder = Copy folder path
ACT_copyHex = Copy as hex
ACT_copyHexShort = Copy hex
ACT_copyRgb = Copy as rgb
ACT_copyRgbShort = Copy rgb
ACT_pretty = Pretty-print into clipboard
ACT_prettyShort = Pretty-print
ACT_minify = Minify into clipboard
ACT_formatNumber = Copy formatted
ACT_formatNumberShort = Format
HST_actions = Actions
```

- [ ] **Step 4: Run the unit tests**

Run `tests/cliptype.ahk`: ALL PASSED.

- [ ] **Step 5: Toast chip**

In `showCopyToast` (Clipjump.ahk) build the action:

```ahk
showCopyToast(text) {
	global LASTKIND, LASTCLIP
	extra := ""
	if (LASTKIND != "" && LASTKIND != "text") {
		act := ClipType.Primary(LASTKIND, LASTCLIP)
		clip := LASTCLIP
		extra := {label: ClipType.Label(LASTKIND), swatch: LASTKIND = "color" ? ClipType.ColorRgb(LASTCLIP) : ""
			, action: act != "" ? {label: act.short, fn: ClipType_RunLater.Bind(act.id, clip)} : ""}
	}
	Toast.Show(text, extra != "" ? 2500 : 900, "info", "copy", extra)
}
```

and in `cliptype.ahk`:

```ahk
; runs an action outside the click handler's thread so a clipboard write is a normal copy
ClipType_RunLater(id, text, *) {
	SetTimer(ClipType_RunNow.Bind(id, text), -10)
}
ClipType_RunNow(id, text) {
	ClipType.Run(id, text)
}
```

- [ ] **Step 6: Page menus**

`ui/common/util.js` add to `window.cj`:

```js
  // popup menu near an anchor element or at {x, y}; items: [{id, label, key, sep, head}]; onPick(id)
  menu(where, items, onPick) {
    this.closeMenu();
    const m = document.createElement("div");
    m.className = "menu";
    m.innerHTML = items.map((it) => it.sep ? `<div class="sep"></div>` : it.head ? `<div class="mh">${this.esc(it.head)}</div>` :
      `<div class="mi" data-id="${this.esc(it.id)}"><span>${this.esc(it.label)}</span>${it.key ? `<span class="k">${this.esc(it.key)}</span>` : ""}</div>`).join("");
    document.body.appendChild(m);
    const r = where instanceof Element ? where.getBoundingClientRect() : { left: where.x, right: where.x, bottom: where.y };
    let x = r.right - m.offsetWidth, y = r.bottom + 4;
    if (x < 4) x = r.left;
    if (y + m.offsetHeight > window.innerHeight - 4) y = Math.max(4, r.bottom - m.offsetHeight - 4 - (where instanceof Element ? r.height : 0));
    m.style.left = x + "px"; m.style.top = y + "px";
    m.addEventListener("click", (e) => { const mi = e.target.closest(".mi"); if (mi) { this.closeMenu(); onPick(mi.dataset.id); } });
    const away = (e) => { if (!m.contains(e.target)) this.closeMenu(); };
    const key = (e) => { if (e.key === "Escape") { this.closeMenu(); e.stopPropagation(); } };
    setTimeout(() => { document.addEventListener("mousedown", away, true); document.addEventListener("keydown", key, true); }, 0);
    m._off = () => { document.removeEventListener("mousedown", away, true); document.removeEventListener("keydown", key, true); };
    this._menu = m;
  },
  closeMenu() { if (this._menu) { this._menu._off(); this._menu.remove(); this._menu = null; } },
```

`ui/common/theme.css`:

```css
.menu { position: fixed; z-index: 20; background: var(--surface); border: 1px solid var(--border); border-radius: 6px; box-shadow: 0 10px 28px rgba(0,0,0,.45); padding: 4px; min-width: 200px; }
.menu .mi { display: flex; align-items: center; gap: 10px; height: 28px; padding: 0 10px; border-radius: 4px; cursor: default; }
.menu .mi:hover { background: var(--hover); }
.menu .mi .k { margin-left: auto; color: var(--muted); font-size: 11px; }
.menu .sep { height: 1px; background: var(--border); margin: 4px 6px; }
.menu .mh { font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; padding: 6px 10px 2px 10px; }
```

`ui/history/index.html`: in the `#ph` header the page rebuilds it in JS, so instead add a button after the `#ph` div is filled: in `showPreview(rec)` append to `ph.innerHTML` for text records with actions:

```js
    const acts = (rec.actions || []);
    ph.innerHTML = `${cj.kindBadge(rec.kind, state.labels) || '<span class="badge">TEXT</span>'}<span class="dim" style="font-size: 12px;">${bytes(rec.size)} · ${esc(fmtDate(rec.time))}</span>` +
      (acts.length ? `<button class="btn" id="actions" style="margin-left: auto; height: 24px;">${esc(T.HST_actions)} ▾</button>` : "");
    if (acts.length) el("actions").addEventListener("click", () => cj.menu(el("actions"), [{ head: state.labels[rec.kind] || rec.kind }, ...acts.map((a) => ({ id: a.id, label: a.label }))], (id) => bridge.send("action", { id: rec.id, action: id })));
```

Context menu on rows: add in `app.js`

```js
  rowsEl.addEventListener("contextmenu", (e) => {
    const tr = e.target.closest(".tr");
    if (!tr) return;
    e.preventDefault();
    const id = +tr.dataset.id;
    if (!state.sel.has(id)) select(id);
    const rec = state.preview && state.preview.id === id ? state.preview : null;
    const acts = rec ? (rec.actions || []).map((a) => ({ id: "act:" + a.id, label: a.label })) : [];
    const items = [...(acts.length ? [{ head: state.labels[rec.kind] || rec.kind }, ...acts, { sep: true }] : []),
      { id: "copy", label: T.HST_copy, key: "Ctrl+C" }, { id: "instaPaste", label: T.HST_insta, key: "Space" }, { id: "edit", label: T.HST_edit, key: "Ctrl+H" }, { id: "delete", label: T.HST_delete, key: "Del" }];
    cj.menu({ x: e.clientX, y: e.clientY }, items, (pick) => pick.startsWith("act:") ? bridge.send("action", { id, action: pick.slice(4) }) : act(pick));
  });
```

Host: `HistoryWin.SendPreview` adds `rec["actions"] := ClipType.Actions(rec["kind"])` for text records (an Array of objects; the JSON layer serializes objects with `id`, `label`, `short` fields; if the vendored JSON only serializes Maps, build `Map("id", a.id, "label", a.label)` per entry instead). Handler: `case "action": HistoryWin.Action(data)`:

```ahk
	static Action(d) {
		rec := historyGet(d["id"])
		if !rec || (rec["type"] = 1)
			return
		ClipType.Run(d["action"], rec["data"])
	}
```

Organizer: `SendClip` adds `m["actions"] := ClipType.Actions(m["kind"])`; handler `case "action": OrganizerWin.Action(data)`:

```ahk
	static Action(d) {
		global CDS
		ch := Integer(d["channel"]), n := Integer(d["n"])
		real := API.getChStrength(ch) - n + 1
		if (real < 1)
			return
		ClipType.Run(d["action"], CDS[ch][real])
	}
```

`ui/organizer/app.js`: in the preview header (`#ph`) add the same Actions button when `rec.actions` is non-empty, sending `bridge.send("action", {channel: rec.channel, n: rec.n, action: id})`, and the same context-menu block on `#rows` with the organizer's existing row actions (paste, edit, delete) after the separator.

- [ ] **Step 7: Verify**

Validate, restart. Copy a URL: the toast shows an `Open` chip; clicking it opens the browser and hides the toast; the target app keeps focus. Copy `#1DBC55`: chip reads `Copy rgb`; clicking it produces a new clip `rgb(29, 188, 85)` (History shows it). Open History, select a URL: the Actions button appears; Open in browser works; right-click shows the type actions first. Same in the Organizer. Run `history_flow`, `organizer_flow`, `hud_live`: ALL PASSED. Open `ui/history/index.html` in Chrome with the mock bridge: no console errors.

- [ ] **Step 8: Commit (ask first)**

```bash
git add src/core/cliptype.ahk Clipjump.ahk src/ui/web ui languages/english.txt tests/cliptype.ahk
git commit -m "Type actions: toast chip, History and Organizer action menus"
```

---

### Task 7: Built-in transforms

**Files:**
- Create: `src/core/transforms.ahk`
- Create: `tests/transforms.ahk`
- Modify: `src/core/cliptype.ahk` (remove the `Transforms` stub), `Clipjump.ahk` (include after `cliptype.ahk`; call `Transforms.Register()` after `loadPlugins()`), `lib/pluginManager.ahk` (nothing; formats live in `PLUGINS.pformat`), `tests/run-all.sh`

**Interfaces:**
- Consumes: `PLUGINS.pformat` (CJMap name -> CJMap with `name`, `*` function name, `Previewable`), `set_pformat`.
- Produces: `Transforms.Register()` adds entries with extra keys `kinds` (comma list or `""` for all) and `key` (menu letter); `Transforms.AppliesTo(entry, kind) -> Bool`; `Transforms.PrettyJson(text)`, `Transforms.MinifyJson(text)`; functions `Transform_Upper(t)`, `Transform_Lower(t)`, `Transform_Title(t)`, `Transform_OneLine(t)`, `Transform_Slugify(t)`, `Transform_StripTracking(t)`, `Transform_MarkdownLink(t)`, `Transform_PrettyJson(t)`, `Transform_MinifyJson(t)`, `Transform_Base64(t)`.

- [ ] **Step 1: Write the failing test**

`tests/transforms.ahk`:

```ahk
; Unit tests for the built-in paste formats (src/core/transforms.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\transforms.ahk
#Requires AutoHotkey v2.0
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
same(Transform_Slugify("Hello, World! Clipjump 2.0"), "hello-world-clipjump-2-0", "slugify")
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
```

- [ ] **Step 2: Run it to verify it fails**

Run `tests/transforms.ahk`: include error for the missing file.

- [ ] **Step 3: Implement**

`src/core/transforms.ahk`:

```ahk
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
			e["name"] := ClipType_T(t[2]), e["*"] := t[3], e["Previewable"] := 1, e["kinds"] := t[4], e["key"] := t[5], e["builtin"] := 1
			PLUGINS.pformat[t[1]] := e
		}
	}

	; a format with no kinds fits everything (plugins); "" and "text" kinds are the same thing
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
Transform_Title(t) => RegExReplace(t, "(?<=^|\s)(\p{Ll})", "$u1")
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
	out := "", depth := 0, inStr := false, esc := false
	loop parse src {
		c := A_LoopField
		if inStr {
			out .= c
			if esc
				esc := false
			else if (c = "\")
				esc := true
			else if (c = '"')
				inStr := false
			continue
		}
		switch c {
			case '"': inStr := true, out .= c
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
	out := "", inStr := false, esc := false
	loop parse Trim(t) {
		c := A_LoopField
		if inStr {
			out .= c
			if esc
				esc := false
			else if (c = "\")
				esc := true
			else if (c = '"')
				inStr := false
			continue
		}
		if (c = '"')
			inStr := true, out .= c
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
```

Remove the `Transforms` stub from `cliptype.ahk`. In `Clipjump.ahk` add `#Include %A_ScriptDir%\src\core\transforms.ahk` after the cliptype include, and right after the `loadPlugins()` call (about line 225) add:

```ahk
Transforms.Register()
set_pformat()   ; the default format may be a built-in transform
```

Strings:

```
TRF_upper = Upper case
TRF_lower = Lower case
TRF_title = Title case
TRF_oneLine = One line
TRF_slugify = Slugify
TRF_stripTracking = Strip URL tracking
TRF_markdownLink = Markdown link
TRF_prettyJson = Pretty JSON
TRF_minifyJson = Minified JSON
TRF_base64 = Decode base64
```

`tests/run-all.sh`: add `run transforms.ahk;` after `run cliptype.ahk;`.

- [ ] **Step 4: Verify**

Run `tests/transforms.ahk` and `tests/cliptype.ahk`: ALL PASSED. Validate, restart, open Settings > General: the default paste format list contains the ten new names. Hold Ctrl+V and press Z repeatedly: the cycle now includes them (the menu comes in Task 8). Run `tests/pastemode.ahk`: ALL PASSED (the Z step cycles formats and still resets).

- [ ] **Step 5: Commit (ask first)**

```bash
git add src/core/transforms.ahk src/core/cliptype.ahk Clipjump.ahk languages/english.txt tests/transforms.ahk tests/run-all.sh
git commit -m "Built-in paste transforms registered with the pformat plugins"
```

---

### Task 8: Z opens a format menu on the paste card

**Files:**
- Modify: `Clipjump.ahk` (`Formatting`, new `Formatting_Items`, `Formatting_Letter`)
- Modify: `src/ui/native/Hud.ahk` (`KeyRows` honors `dim` and `check` on items)
- Modify: `languages/english.txt`, `tests/pastemode.ahk`

**Interfaces:**
- Consumes: `Hud.Menu(items, keys, title)` returning the pressed hotkey string; `hkZ_pasteMode(1)`; `set_pformat(name)`; `Transforms.AppliesTo`; `ClipType.Of`.
- Produces: menu items `{key, caption, dim, check}`; `Formatting_Items(kind) -> {items, keys, byKey}`.

- [ ] **Step 1: Update the paste mode test**

In `tests/pastemode.ahk` replace the "Z cycles paste formats" step with:

```ahk
step("Z opens the format menu; a letter picks Upper case; Z again closes")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 700
check(WinExist("Clipjump_HUD ahk_class AutoHotkeyGUI"), "card still visible with the format menu")
SendEvent("u")
Sleep 700
check(cj["curPformat"] = "Upper case", "U picked Upper case: [" cj["curPformat"] "]")
SendEvent("z")
Sleep 500
SendEvent("z")
Sleep 500
check(cj["curPformat"] = "Upper case", "Z then Z leaves the format alone")
SendEvent("{Ctrl up}")
Sleep 900
check(ed.Value = StrUpper(ed.Value) && InStr(ed.Value, StrUpper(stamp)), "pasted upper case: [" ed.Value "]")
cj.runFunction("set_pformat()")
check(cj["curPformat"] = "", "set_pformat() resets the format")
```

Keep the existing `cj.runFunction("set_pformat()")` reset that follows in the file if it is there twice; remove the duplicate.

- [ ] **Step 2: Run to verify it fails**

Run `tests/pastemode.ahk`: "U picked Upper case" FAILS (Z still cycles).

- [ ] **Step 3: Implement**

`src/ui/native/Hud.ahk` `KeyRows`: after `r.text.Text := it.caption` add:

```ahk
			dim := it.HasProp("dim") && it.dim, chk := it.HasProp("check") && it.check
			r.text.Opt("c" Theme.Hex(dim ? "muted" : "text"))
			r.text.Text := (chk ? (Theme.HasIcons() ? Theme.Icon("check") " " : "* ") : "") it.caption
			Theme.SetPill(r.chip, chk ? "accent" : "surfaceAlt", chk ? "accentText" : (dim ? "muted" : "text"))
```

(`Theme.Icon("check")` renders only with the icon font, and the row text uses the UI font, so use the fallback: prefix a check mark character `✓ ` when checked instead of the glyph: `r.text.Text := (chk ? "✓ " : "") it.caption`. Use that line, drop the icon branch.)

`Clipjump.ahk` replace `Formatting(*)` with:

```ahk
; Z in paste mode: a menu of paste formats on the card. Formats that fit the clip's kind come first, the rest are
; dimmed; the active format is checked. A letter or Enter picks, Z or Esc closes. Ctrl stays held throughout.
Formatting(*) {
	global
	local kind, m, picked, letter
	if !is_pstMode_active
		return
	kind := (temp_clipboard != "") ? ClipType.Of(CN.NG, realActive) : ""
	m := Formatting_Items(kind)
	picked := Hud.Menu(m.items, m.keys, TXT.HUD_formatTitle)
	if !is_pstMode_active      ; Ctrl was released while the menu was open: the paste already happened
		return
	hkZ_pasteMode(1)           ; the menu turned the letters it used off; paste-mode keys come back
	letter := StrUpper(RegExReplace(picked, "^[~*$!^+#<>]*"))
	if (letter = "" || letter = "Z" || letter = "ESC")
		PasteModeTooltip(temp_clipboard)
	else if m.byKey.Has(letter) {
		set_pformat(m.byKey[letter])
		if (temp_clipboard != "") {
			halfClip := StrLen(temp_clipboard) > 200 ? SubStr(temp_clipboard, 1, 200) "`n`n" MSG_MORE_PREVIEW : temp_clipboard
			if curPisPreviewable
				halfClip := callPformat(curPfunction, halfClip)
		}
		PasteModeTooltip(temp_clipboard)
	} else
		PasteModeTooltip(temp_clipboard)
}

; items for the format menu; returns {items, keys, byKey}: byKey maps a letter to the format name ("" = original)
Formatting_Items(kind) {
	global PLUGINS, curPformat, pstIdentifier, TXT
	used := Map("V", 1, "C", 1, "Z", 1), byKey := Map(), fit := [], rest := []
	take(name, pref) {
		l := Formatting_Letter(name, pref, used)
		used[l] := 1, byKey[l] := name
		return l
	}
	oL := take("", "O")
	fit.Push({key: oL, caption: TXT.HUD_formatOriginal, check: curPformat = ""})
	for k, v in PLUGINS.pformat {
		pref := ""
		try pref := v["key"]
		l := take(v["name"], pref)
		it := {key: l, caption: v["name"], check: curPformat = v["name"], dim: !Transforms.AppliesTo(v, kind)}
		(it.dim ? rest : fit).Push(it)
	}
	items := []
	for it in fit
		items.Push(it)
	for it in rest
		items.Push(it)
	keys := pstIdentifier "Esc"
	for l in byKey
		keys .= " " pstIdentifier l
	keys .= " " pstIdentifier "Enter"
	byKey["ENTER"] := curPformat
	return {items: items, keys: keys, byKey: byKey}
}

; first free letter: the preferred one, then letters of the name, then the alphabet
Formatting_Letter(name, pref, used) {
	if (pref != "" && !used.Has(StrUpper(pref)))
		return StrUpper(pref)
	loop parse StrUpper(name)
		if RegExMatch(A_LoopField, "[A-Z]") && !used.Has(A_LoopField)
			return A_LoopField
	loop 26 {
		l := Chr(64 + A_Index)
		if !used.Has(l)
			return l
	}
	return "?"
}
```

Note: `Hud.Menu` returns the pressed hotkey string such as `^u`; the `RegExReplace` strips modifier symbols. `keys` uses `pstIdentifier` (`^`) because Ctrl is held; `Esc` and `Enter` are named keys, which `hkZ` accepts as `^Esc` / `^Enter`.

Strings:

```
HUD_formatTitle = Paste format
HUD_formatOriginal = Original
```

- [ ] **Step 4: Verify**

Validate, restart. Hold Ctrl+V, press Z: the card shows the format menu with letters; press U: pill reads "Upper case" and the preview is upper case; release Ctrl: upper-case paste. Z then Esc closes without change. Release Ctrl while the menu is open: the clip pastes with the previous format and paste mode ends cleanly (no stuck hotkeys: Ctrl+C in Notepad-like apps still copies afterwards). Run `tests/pastemode.ahk`, `tests/modes.ahk`, `tests/hud_live.ahk`: ALL PASSED.

- [ ] **Step 5: Commit (ask first)**

```bash
git add Clipjump.ahk src/ui/native/Hud.ahk languages/english.txt tests/pastemode.ahk
git commit -m "Z opens a paste format menu on the card"
```

---

### Task 9: Rules engine

**Files:**
- Create: `src/core/rules.ahk`, `tests/rules.ahk`
- Modify: `src/core/settings.ahk` (`load_Settings` calls `Rules.Load()`), `Clipjump.ahk` (include; `clipChange` integration; `reloadRules()`), `languages/english.txt`, `tests/run-all.sh`

**Interfaces:**
- Consumes: `ClipType.Detect`, `API.manageClip(new_channel, channel, clip, copy)`, `AddClipPref`, `callPformat`, `PLUGINS.pformat`, `Ini_read`, `CONFIGURATION_FILE`, `CN.Total`.
- Produces: `Rules.List` (Array of rule Maps), `Rules.Load()`, `Rules.Save(list)`, `Rules.Parse(line) -> Map or ""`, `Rules.Serialize(rule) -> String`, `Rules.Match(rule, kind, text, app) -> Bool`, `Rules.Evaluate(list, kind, text, app) -> rule or ""`, `Rules.Describe(rule) -> [when, then]`, `Rules.Validate(rule) -> "" or error string`, `Rules.New() -> rule`. Rule Map keys: `on` (1/0), `kinds` (Array), `regex`, `app`, `action` (`channel`|`ignore`|`transform`|`tag`), `arg`, `name` (optional display name). `reloadRules()` global function.

- [ ] **Step 1: Write the failing test**

`tests/rules.ahk`:

```ahk
; Unit tests for the copy-time rules engine (src/core/rules.ahk).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\rules.ahk
#Requires AutoHotkey v2.0
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
```

- [ ] **Step 2: Run it to verify it fails**

Run `tests/rules.ahk`: missing include error.

- [ ] **Step 3: Implement the engine**

`src/core/rules.ahk`:

```ahk
; rules.ahk - copy-time rules. A rule is conditions (kinds, regex, source app, window class; all given must hold)
; plus one action (channel:N, ignore, transform:Name, tag:Text). Stored in settings.ini under [Rules] as numbered
; lines: 1=on=1;kinds=url,email;regex=;app=chrome.exe;action=channel:2;name=Links
;
;   Rules.Load() / Rules.Save(list)      settings.ini <-> Rules.List
;   Rules.Parse(line) / Rules.Serialize(rule)
;   Rules.Match(rule, kind, text, app, cls := "")
;   Rules.Evaluate(list, kind, text, app, cls := "") -> first enabled matching rule or ""
;   Rules.Describe(rule) -> [when, then] for lists
;   Rules.Validate(rule) -> "" or a message

class Rules {
	static List := []
	static Actions := ["channel", "ignore", "transform", "tag"]

	static New() {
		r := Map()
		r["on"] := 1, r["kinds"] := [], r["regex"] := "", r["app"] := "", r["class"] := "", r["action"] := "ignore", r["arg"] := "", r["name"] := ""
		return r
	}

	static Parse(line) {
		r := Rules.New()
		seen := false
		loop parse line, ";" {
			p := InStr(A_LoopField, "=")
			if !p
				continue
			k := Trim(SubStr(A_LoopField, 1, p - 1)), v := SubStr(A_LoopField, p + 1)
			switch StrLower(k) {
				case "on": r["on"] := v ? 1 : 0, seen := true
				case "kinds":
					r["kinds"] := []
					loop parse v, ","
						if ClipType.IsKind(Trim(A_LoopField))
							r["kinds"].Push(Trim(A_LoopField))
				case "regex": r["regex"] := v
				case "app": r["app"] := Trim(v)
				case "class": r["class"] := Trim(v)
				case "name": r["name"] := Trim(v)
				case "action":
					q := InStr(v, ":")
					r["action"] := StrLower(q ? SubStr(v, 1, q - 1) : v), r["arg"] := q ? SubStr(v, q + 1) : ""
			}
		}
		if !seen || !Rules.HasCondition(r) || !Rules.IsAction(r["action"])
			return ""
		return r
	}

	static Serialize(r) {
		kinds := ""
		for i, k in r["kinds"]
			kinds .= (i > 1 ? "," : "") k
		s := "on=" (r["on"] ? 1 : 0) ";kinds=" kinds ";regex=" r["regex"] ";app=" r["app"] ";action=" r["action"] (r["arg"] != "" ? ":" r["arg"] : "") ";name=" r["name"]
		if (r["class"] != "")
			s .= ";class=" r["class"]
		return s
	}

	static HasCondition(r) => r["kinds"].Length || r["regex"] != "" || r["app"] != "" || r["class"] != ""

	static IsAction(a) {
		for x in Rules.Actions
			if (x = a)
				return true
		return false
	}

	; "" when valid, otherwise a TXT message
	static Validate(r) {
		if !Rules.HasCondition(r)
			return ClipType_T("RUL_noCondition")
		if (r["regex"] != "") {
			try RegExMatch("", r["regex"])
			catch
				return ClipType_T("RUL_badRegex")
		}
		if (r["action"] = "channel" && !IsInteger(r["arg"]))
			return ClipType_T("RUL_badChannel")
		return ""
	}

	static Match(r, kind, text, app, cls := "") {
		if !r["on"]
			return false
		if r["kinds"].Length {
			ok := false
			for k in r["kinds"]
				if (k = kind)
					ok := true
			if !ok
				return false
		}
		if (r["regex"] != "") {
			try {
				if !RegExMatch(text, r["regex"])
					return false
			} catch
				return false
		}
		if (r["app"] != "" && !Rules.InList(r["app"], app))
			return false
		if (r["class"] != "" && !Rules.InList(r["class"], cls))
			return false
		return true
	}

	static InList(list, value) {
		loop parse list, ","
			if (Trim(A_LoopField) != "" && Trim(A_LoopField) = value)
				return true
		return false
	}

	static Evaluate(list, kind, text, app, cls := "") {
		for r in list
			if Rules.Match(r, kind, text, app, cls)
				return r
		return ""
	}

	static Describe(r) {
		global TXT
		when := ""
		for i, k in r["kinds"]
			when .= (i > 1 ? ", " : "") ClipType.Label(k)
		if (r["regex"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_matching") " " r["regex"]
		if (r["app"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_from") " " r["app"]
		if (r["class"] != "")
			when .= (when != "" ? " " : "") ClipType_T("RUL_inClass") " " r["class"]
		switch r["action"] {
			case "channel": then := ClipType_T("RUL_act_channel") " " r["arg"] (Rules.ChannelName(r["arg"]) != "" ? " · " Rules.ChannelName(r["arg"]) : "")
			case "ignore": then := ClipType_T("RUL_act_ignore")
			case "transform": then := ClipType_T("RUL_act_transform") " " r["arg"]
			default: then := ClipType_T("RUL_act_tag") " " r["arg"]
		}
		return [when, then]
	}

	static ChannelName(n) {
		global CONFIGURATION_FILE
		if !IsInteger(n)
			return ""
		v := IniRead(CONFIGURATION_FILE, "Channels", n, "")
		return v != "" ? v : (n = 0 ? "Default" : "")
	}

	static Load() {
		global CONFIGURATION_FILE
		Rules.List := []
		sec := IniRead(CONFIGURATION_FILE, "Rules", , "")
		if (sec = "")
			return
		loop parse sec, "`n", "`r" {
			p := InStr(A_LoopField, "=")
			if !p
				continue
			r := Rules.Parse(SubStr(A_LoopField, p + 1))
			if (r = "")
				continue
			if (Rules.Validate(r) != "")
				r["on"] := 0
			Rules.List.Push(r)
		}
	}

	static Save(list) {
		global CONFIGURATION_FILE
		try IniDelete(CONFIGURATION_FILE, "Rules")
		for i, r in list
			IniWrite(Rules.Serialize(r), CONFIGURATION_FILE, "Rules", i)
		Rules.List := list
	}
}
```

Strings:

```
RUL_noCondition = Choose at least one condition
RUL_badRegex = The regular expression is invalid
RUL_badChannel = Choose a channel
RUL_matching = matching
RUL_from = from
RUL_inClass = in window class
RUL_act_channel = Send to channel
RUL_act_ignore = Ignore
RUL_act_transform = Apply
RUL_act_tag = Add tag
RUL_ignored = Not recorded: rule %rule%
```

`src/core/settings.ahk` `load_Settings`: after the `ini_prewarmWebViews := ...` line add `Rules.Load()`.

`Clipjump.ahk`: include `src\core\rules.ahk` after transforms. Add `reloadRules() { Rules.Load() }` near `changeIcon()`.

Integrate in `clipChange` (text branch). Change the start of the branch to evaluate rules before the clip is stored:

```ahk
	if (CErrorlevel = 1)
	{
		if (clipboard_copy != LASTCLIP) || (clipboard_copy == "")        ;dont let go if lastclip = clipboard_copy = <empty>
		{
			; copy-time rules: evaluated before anything is stored
			ruleKind := ClipType.Detect(clipboard_copy), ruleApp := "", ruleCls := ""
			try ruleApp := WinGetProcessName("A")
			try ruleCls := WinGetClass("A")
			rule := Rules.Evaluate(Rules.List, ruleKind, clipboard_copy, ruleApp, ruleCls)
			if IsObject(rule) && (rule["action"] = "ignore") {
				LASTCLIP := clipboard_copy
				Toast.Show(StrReplace(TXT.RUL_ignored, "%rule%", rule["name"] != "" ? rule["name"] : Rules.Describe(rule)[1]), 1500, "warn", "copy")
				return
			}
			CURSAVE += 1
			...
```

Declare `ruleKind, ruleApp, ruleCls, rule` in the function's `local` line. After the `HASCOPYFAILED` guard and the kind store lines from Task 2 (`LASTKIND := ...`, `ClipType.Store(...)`), apply the other actions before `addHistoryText`:

```ahk
			if IsObject(rule) {
				switch rule["action"] {
					case "transform": Rules_ApplyTransform(rule["arg"])
					case "tag": AddClipPref(CN.NG, CURSAVE, "Tags", rule["arg"])
				}
			}
```

and after `TEMPSAVE := CURSAVE` (before the `while (CURSAVE >= TOTALCLIPS)` loop) add:

```ahk
			if IsObject(rule) && (rule["action"] = "channel") && IsInteger(rule["arg"]) && (rule["arg"] != CN.NG) && (rule["arg"] < CN.Total) {
				API.manageClip(rule["arg"], CN.NG, 1, 0)   ; move the newest clip out of the active channel
				TEMPSAVE := CURSAVE
			}
```

Add near `showCopyToast`:

```ahk
; rewrites the just-saved clip (file, in-memory text, LASTCLIP) with a paste format applied
Rules_ApplyTransform(formatName) {
	global PLUGINS, LASTCLIP, CDS, CN, CURSAVE, CLIPS_dir
	fn := ""
	for k, v in PLUGINS.pformat
		if (v["name"] = formatName)
			fn := v["*"]
	if (fn = "")
		return
	t := callPformat(fn, LASTCLIP)
	if (t == LASTCLIP || t = "")
		return
	API.blockMonitoring(1)
	try {
		A_Clipboard := t
		ClipWait(1)
		FileDelete(CLIPS_dir "/" CURSAVE ".avc")
		FileAppend(ClipboardAll(), CLIPS_dir "/" CURSAVE ".avc")
		CDS[CN.NG][CURSAVE] := t, LASTCLIP := t
	}
	API.blockMonitoring(0, 5)
}
```

The toast for a routed clip: in `showCopyToast`, when `rule` routed the clip, the message should name the target channel. Simplest: keep `copyMessage` as is (it names the active channel); acceptable for this task, and the spec says "without switching". Do not change it.

`tests/run-all.sh`: add `run rules.ahk;` after `run transforms.ahk;`.

- [ ] **Step 4: Live test**

Create `tests/rules_flow.ahk`:

```ahk
; Copy-time rules against a RUNNING Clipjump: a URL rule routes to channel 1 with the active channel unchanged,
; an email rule tags the clip, an ignore rule drops a clip. Rules are restored afterwards.
#Requires AutoHotkey v2.0
#Include ..\publicAPI.ahk
SetTitleMatchMode 1
cj := Clipjump()
ini := A_ScriptDir "\..\settings.ini"
fails := 0
check(name, cond) {
	global fails
	FileAppend((cond ? "PASS " : "FAIL ") name "`n", "*")
	if !cond
		fails++
}
old := IniRead(ini, "Rules", , "")
stamp := A_TickCount
try IniDelete(ini, "Rules")
IniWrite("on=1;kinds=url;regex=;app=AutoHotkey64.exe;action=channel:1;name=links", ini, "Rules", 1)
IniWrite("on=1;kinds=email;regex=;app=;action=tag:contact", ini, "Rules", 2)
IniWrite("on=1;kinds=;regex=^secret-;app=;action=ignore;name=secrets", ini, "Rules", 3)
cj.runFunction("changeChannel(1)")   ; make sure channel 1 exists
Sleep 200
cj.runFunction("changeChannel(0)")
Sleep 200
cj.runFunction("reloadRules()")
g := Gui("+AlwaysOnTop", "cj-rules-target")
g.Add("Edit", "w300 h80")
g.Show()
WinWaitActive("cj-rules-target", , 5)
before1 := Integer(cj.runFunction("API.getChStrength(1)")), before0 := Integer(cj.runFunction("API.getChStrength(0)"))
A_Clipboard := "https://example.com/r" stamp
Sleep 900
check("url routed to channel 1", Integer(cj.runFunction("API.getChStrength(1)")) = before1 + 1 && InStr(cj.getClipAt(1, 1), "example.com/r" stamp))
check("active channel unchanged", cj["CN.NG"] = 0)
check("channel 0 did not keep it", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
A_Clipboard := "r" stamp "@example.com"
Sleep 900
check("email tagged", cj.runFunction("clipPref(0," cj["CURSAVE"] ",Tags)") = "contact")
before0 := Integer(cj.runFunction("API.getChStrength(0)"))
A_Clipboard := "secret-" stamp
Sleep 900
check("secret ignored", Integer(cj.runFunction("API.getChStrength(0)")) = before0)
try IniDelete(ini, "Rules")
if (old != "")
	loop parse old, "`n", "`r"
		if (p := InStr(A_LoopField, "="))
			IniWrite(SubStr(A_LoopField, p + 1), ini, "Rules", SubStr(A_LoopField, 1, p - 1))
cj.runFunction("reloadRules()")
g.Destroy()
FileAppend((fails ? "FAILED " fails : "ALL PASSED") "`n", "*")
ExitApp fails
```

Add `run rules_flow.ahk 90;` to the interactive line of `tests/run-all.sh` after `run organizer_flow.ahk 120;`.

- [ ] **Step 5: Verify**

Run `tests/rules.ahk`: ALL PASSED. Validate, restart, run `tests/rules_flow.ahk`: ALL PASSED. Run `tests/pastemode.ahk` and `tests/e2e.ahk` to confirm the hook still behaves.

- [ ] **Step 6: Commit (ask first)**

```bash
git add src/core/rules.ahk src/core/settings.ahk Clipjump.ahk languages/english.txt tests/rules.ahk tests/rules_flow.ahk tests/run-all.sh
git commit -m "Copy-time rules: route, ignore, transform or tag clips"
```

---

### Task 10: Settings Rules page and the rule editor

**Files:**
- Create: `src/ui/native/RuleDialog.ahk`
- Modify: `src/ui/native/SettingsWin.ahk` (order, nav titles and icons, `BuildRules`, `Collect`, `Save`), `src/ui/native/IgnoredWindowsWin.ahk` (`Pick()` factored out of `Add()`), `src/core/settings.ahk` (`save_Settings` writes rules), `Clipjump.ahk` (include), `languages/english.txt`, `tests/settings_flow.ahk`

**Interfaces:**
- Consumes: `Rules.*`, `Theme.Add`, `SettingsWin.PageStart/Reg/Section/SetDirty`, `PLUGINS.pformat`, `CN.Total`, `Hud.Message`.
- Produces: `RuleDialog.Open(owner, rule) -> rule Map or ""`; `IgnoredWindowsWin.Pick() -> Map("class", cls, "exe", exe)` (empty strings when cancelled); `SettingsWin.rules` (working copy Array); `save_Settings` accepts `v["Rules"]` (Array of rule Maps).

- [ ] **Step 1: Extend the settings test**

In `tests/settings_flow.ahk`, after the page-switching checks, add a Rules step (adapt the click helpers to the ones the file already uses for nav labels):

```ahk
step("Rules page: Add opens the editor, Cancel closes it")
navClick("Rules")
Sleep 400
check("rules list shown", ControlGetVisible("SysListView321", title))
ControlClick(cj["TXT.SET_ruleAdd"], title)
check("rule editor opens", WinWait(cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI", , 4) != 0)
Sleep 300
ControlClick(cj["TXT.SET_cancel"], cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI")
check("rule editor closed", WinWaitClose(cj["TXT.RUL_title"] " ahk_class AutoHotkeyGUI", , 3))
```

If the file has no `navClick` helper, use the same `ControlClick` on the nav label text it uses for other pages.

- [ ] **Step 2: Run to verify it fails**

Run `tests/settings_flow.ahk`: "rules list shown" FAILS (no page).

- [ ] **Step 3: Factor the window picker**

`src/ui/native/IgnoredWindowsWin.ahk`: replace the body of `Add()` up to `cls := IgnoredWindowsWin.picked` with a call to a new method, so it reads:

```ahk
	static Add() {
		if IgnoredWindowsWin.pickActive
			return
		r := IgnoredWindowsWin.Pick()
		if !IgnoredWindowsWin.g
			return
		try WinActivate(IgnoredWindowsWin.g.Hwnd)
		cls := r["class"]
		if (cls = "")
			return
		lv := IgnoredWindowsWin.lv
		loop lv.GetCount()
			if (lv.GetText(A_Index) = cls)
				return
		lv.Add("", cls)
		IgnoredWindowsWin.Save()
	}

	; lets the user point at a window (Space accepts, Esc cancels); returns Map("class", cls, "exe", exe)
	static Pick() {
		IgnoredWindowsWin.pickActive := true, IgnoredWindowsWin.picked := "", IgnoredWindowsWin.pickedExe := ""
		hkZ("Esc", IgnoredWindowsWin_PickEnd, 1)
		hkZ("Space", IgnoredWindowsWin_PickAccept, 1)
		SetTimer(IgnoredWindowsWin_PickTick, 200)
		while IgnoredWindowsWin.pickActive
			Sleep 20
		SetTimer(IgnoredWindowsWin_PickTick, 0)
		hkZ("Esc", IgnoredWindowsWin_PickEnd, 0)
		hkZ("Space", IgnoredWindowsWin_PickAccept, 0)
		Hud.Hide()
		return Map("class", IgnoredWindowsWin.picked, "exe", IgnoredWindowsWin.pickedExe)
	}
```

Add `pickedExe := ""` to the class's static field line. Change `IgnoredWindowsWin_PickAccept` to also record `IgnoredWindowsWin.pickedExe := WinGetProcessName("A")` inside its `try`, and `IgnoredWindowsWin_PickTick` to show `cls " · " exe` where `exe` is `WinGetProcessName("A")` in a `try`.

- [ ] **Step 4: The dialog**

`src/ui/native/RuleDialog.ahk`:

```ahk
; RuleDialog.ahk - the rule editor used by the Settings Rules page.
;   RuleDialog.Open(owner, rule) -> edited rule Map, or "" when cancelled

class RuleDialog {
	static g := "", c := Map(), done := false, result := ""

	static Open(owner, rule) {
		global TXT, PLUGINS, CN
		RuleDialog.done := false, RuleDialog.result := ""
		g := Gui("+ToolWindow -MaximizeBox +Owner" owner.Hwnd, TXT.RUL_title)
		RuleDialog.g := g, c := RuleDialog.c := Map()
		g.MarginX := 20, g.MarginY := 14
		Theme.ApplyToGui(g)
		w := 460, x := 20, y := 14
		Theme.Section(g, x, y, w - 40, TXT.RUL_when), y += 30
		col := 0
		for k in ClipType.Kinds {
			on := false
			for rk in rule["kinds"]
				if (rk = k)
					on := true
			c["k_" k] := Theme.Add(g, "CheckBox", "x" (x + col * 140) " y" y " w130 h24 " (on ? "Checked" : ""), ClipType.Label(k))
			col++
			if (col = 3)
				col := 0, y += 26
		}
		if col
			y += 26
		y += 6
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_regex)
		c["regex"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["regex"])
		y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_app)
		c["app"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w150 h24 -E0x200 +Border", rule["app"])
		Theme.Add(g, "Button", "x" (x + 318) " y" y " w102 h24", TXT.RUL_pick).OnEvent("Click", RuleDialog_Pick)
		y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_class)
		c["class"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["class"])
		y += 36
		Theme.Section(g, x, y, w - 40, TXT.RUL_then), y += 30
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_action)
		acts := [TXT.RUL_act_channel, TXT.RUL_act_ignore, TXT.RUL_act_transform, TXT.RUL_act_tag]
		sel := 2
		for i, a in Rules.Actions
			if (a = rule["action"])
				sel := i
		c["action"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" sel, acts)
		c["action"].OnEvent("Change", RuleDialog_ActionChanged)
		y += 30
		c["argLabel"] := g.Add("Text", "x" x " y" y " w150 h24 +0x200", "")
		chans := []
		loop CN.Total {
			n := A_Index - 1
			chans.Push(n " · " (Rules.ChannelName(n) != "" ? Rules.ChannelName(n) : n))
		}
		c["channel"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" (IsInteger(rule["arg"]) && rule["arg"] + 1 <= chans.Length ? rule["arg"] + 1 : 1), chans)
		fmts := [], fsel := 1
		for k, v in PLUGINS.pformat {
			fmts.Push(v["name"])
			if (v["name"] = rule["arg"])
				fsel := fmts.Length
		}
		c["transform"] := Theme.Add(g, "DDL", "x" (x + 160) " y" y " w260 Choose" fsel, fmts)
		c["tag"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["action"] = "tag" ? rule["arg"] : "")
		y += 36
		g.Add("Text", "x" x " y" y " w150 h24 +0x200", TXT.RUL_name)
		c["name"] := Theme.Add(g, "Edit", "x" (x + 160) " y" y " w260 h24 -E0x200 +Border", rule["name"])
		y += 40
		c["err"] := g.Add("Text", "x" x " y" y " w260 h24 +0x200 c" Theme.Hex("danger"), "")
		Theme.Add(g, "Button", "x" (w - 20 - 76 - 8 - 76) " y" y " w76 h28 Default", "OK").OnEvent("Click", RuleDialog_Ok)
		Theme.Add(g, "Button", "x" (w - 20 - 76) " y" y " w76 h28", TXT.SET_cancel).OnEvent("Click", RuleDialog_Cancel)
		g.OnEvent("Close", RuleDialog_Cancel), g.OnEvent("Escape", RuleDialog_Cancel)
		RuleDialog_ActionChanged()
		g.Show("w" w " h" (y + 44))
		while !RuleDialog.done
			Sleep 30
		try g.Destroy()
		RuleDialog.g := ""
		return RuleDialog.result
	}

	static Collect() {
		c := RuleDialog.c
		r := Rules.New()
		for k in ClipType.Kinds
			if c["k_" k].Value
				r["kinds"].Push(k)
		r["regex"] := c["regex"].Value, r["app"] := Trim(c["app"].Value), r["class"] := Trim(c["class"].Value), r["name"] := Trim(c["name"].Value)
		r["action"] := Rules.Actions[c["action"].Value]
		switch r["action"] {
			case "channel": r["arg"] := c["channel"].Value - 1
			case "transform": r["arg"] := c["transform"].Text
			case "tag": r["arg"] := Trim(c["tag"].Value)
			default: r["arg"] := ""
		}
		return r
	}
}

RuleDialog_ActionChanged(*) {
	global TXT
	c := RuleDialog.c
	a := Rules.Actions[c["action"].Value]
	c["channel"].Visible := (a = "channel"), c["transform"].Visible := (a = "transform"), c["tag"].Visible := (a = "tag")
	c["argLabel"].Text := a = "channel" ? TXT.RUL_channel : a = "transform" ? TXT.RUL_transform : a = "tag" ? TXT.RUL_tag : ""
}

RuleDialog_Pick(*) {
	r := IgnoredWindowsWin.Pick()
	if (r["exe"] != "")
		RuleDialog.c["app"].Value := r["exe"]
	try WinActivate(RuleDialog.g.Hwnd)
}

RuleDialog_Ok(*) {
	r := RuleDialog.Collect()
	msg := Rules.Validate(r)
	if (msg != "") {
		RuleDialog.c["err"].Text := msg
		return
	}
	RuleDialog.result := r, RuleDialog.done := true
}

RuleDialog_Cancel(*) {
	RuleDialog.done := true
}
```

Strings:

```
SET_rules = Rules
SET_rulesHint = Rules run when a text clip is copied, top to bottom; the first match wins.
SET_ruleAdd = Add…
SET_ruleEdit = Edit…
SET_ruleRemove = Remove
SET_ruleUp = Up
SET_ruleDown = Down
SET_ruleWhen = When
SET_ruleThen = Then
RUL_title = Edit rule
RUL_when = When the clip
RUL_then = Then
RUL_regex = Text matches
RUL_app = Copied from (process)
RUL_class = Window class
RUL_pick = Pick window…
RUL_action = Action
RUL_channel = Channel
RUL_transform = Format
RUL_tag = Tag
RUL_name = Name (optional)
```

- [ ] **Step 5: The Settings page**

`src/ui/native/SettingsWin.ahk`:

- `static order := ["general", "history", "shortcuts", "channels", "rules", "appearance", "advanced"]`.
- `static rules := []` and `static rulesLv := ""` fields.
- In `BuildNav`, add `"rules", TXT.SET_rules` to `titles` and `"rules", "zap"` to `icons`.
- In `Build()`, call `SettingsWin.BuildRules()` after `BuildChannels()`.
- Add:

```ahk
	static BuildRules() {
		global TXT
		g := SettingsWin.g
		SettingsWin.PageStart("rules", TXT.SET_rules)
		x := SettingsWin.ContentX(), w := SettingsWin.ContentW()
		g.SetFont("s9 c" Theme.Hex("muted"))
		SettingsWin.Reg(g.Add("Text", "x" x " y" SettingsWin.y " w" w " h18", TXT.SET_rulesHint), "stretch")
		g.SetFont("s10 c" Theme.Hex("text"))
		SettingsWin.y += 26
		lv := Theme.Add(g, "ListView", "x" x " y" SettingsWin.y " w" w " h280 -E0x200 +Border Checked -Multi", ["", TXT.SET_ruleWhen, TXT.SET_ruleThen])
		lv.ModifyCol(1, 28), lv.ModifyCol(2, 300), lv.ModifyCol(3, 200)
		lv.OnEvent("ItemCheck", SettingsWin_RuleCheck)
		lv.OnEvent("DoubleClick", (*) => SettingsWin.RuleEdit())
		SettingsWin.rulesLv := lv
		SettingsWin.Reg(lv, "stretch")
		SettingsWin.y += 290
		bx := x
		for spec in [[TXT.SET_ruleAdd, (*) => SettingsWin.RuleAdd()], [TXT.SET_ruleEdit, (*) => SettingsWin.RuleEdit()], [TXT.SET_ruleRemove, (*) => SettingsWin.RuleRemove()]] {
			b := Theme.Add(g, "Button", "x" bx " y" SettingsWin.y " w84 h28", spec[1])
			b.OnEvent("Click", spec[2]), SettingsWin.Reg(b), bx += 92
		}
		up := Theme.Add(g, "Button", "x" (SettingsWin.ContentRight() - 84 - 8 - 84) " y" SettingsWin.y " w84 h28", TXT.SET_ruleUp)
		up.OnEvent("Click", (*) => SettingsWin.RuleMove(-1)), SettingsWin.Reg(up, "right", 84 + 8 + 84)
		dn := Theme.Add(g, "Button", "x" (SettingsWin.ContentRight() - 84) " y" SettingsWin.y " w84 h28", TXT.SET_ruleDown)
		dn.OnEvent("Click", (*) => SettingsWin.RuleMove(1)), SettingsWin.Reg(dn, "right", 84)
		SettingsWin.y += 36
		SettingsWin.rules := []
		for r in Rules.List
			SettingsWin.rules.Push(r.Clone())
		SettingsWin.FillRules()
	}

	static FillRules(selectRow := 0) {
		lv := SettingsWin.rulesLv
		lv.Delete()
		for r in SettingsWin.rules {
			d := Rules.Describe(r)
			lv.Add(r["on"] ? "Check" : "", "", d[1], d[2])
		}
		if selectRow
			lv.Modify(selectRow, "Select Focus")
	}

	static RuleSelected() {
		lv := SettingsWin.rulesLv
		return lv ? lv.GetNext() : 0
	}

	static RuleAdd() {
		r := RuleDialog.Open(SettingsWin.g, Rules.New())
		if (r = "")
			return
		SettingsWin.rules.Push(r)
		SettingsWin.FillRules(SettingsWin.rules.Length), SettingsWin.SetDirty(true)
	}

	static RuleEdit() {
		i := SettingsWin.RuleSelected()
		if !i
			return
		r := RuleDialog.Open(SettingsWin.g, SettingsWin.rules[i])
		if (r = "")
			return
		SettingsWin.rules[i] := r
		SettingsWin.FillRules(i), SettingsWin.SetDirty(true)
	}

	static RuleRemove() {
		i := SettingsWin.RuleSelected()
		if !i
			return
		SettingsWin.rules.RemoveAt(i)
		SettingsWin.FillRules(Min(i, SettingsWin.rules.Length)), SettingsWin.SetDirty(true)
	}

	static RuleMove(delta) {
		i := SettingsWin.RuleSelected(), j := i + delta
		if (!i || j < 1 || j > SettingsWin.rules.Length)
			return
		t := SettingsWin.rules[i], SettingsWin.rules[i] := SettingsWin.rules[j], SettingsWin.rules[j] := t
		SettingsWin.FillRules(j), SettingsWin.SetDirty(true)
	}
```

and the file-level handler:

```ahk
SettingsWin_RuleCheck(lv, row, checked) {
	if (row >= 1 && row <= SettingsWin.rules.Length) {
		SettingsWin.rules[row]["on"] := checked ? 1 : 0
		SettingsWin.SetDirty(true)
	}
}
```

- In `Collect()` add `v["Rules"] := SettingsWin.rules`.
- `src/core/settings.ahk` `save_Settings(v)`: at the end add `if v.Has("Rules") Rules.Save(v["Rules"])`. Check that `load_Settings()` (called after save) reloads them (Task 9 added `Rules.Load()` there).
- `Clipjump.ahk`: include `src\ui\native\RuleDialog.ahk` after `IgnoredWindowsWin.ahk`.
- The ListView's header recolor: `Theme.Add(g, "ListView", ...)` already subclasses the header (see the Ignored Windows list), so no extra work.

- [ ] **Step 6: Verify**

Validate, restart. Open Settings > Rules: the list shows existing rules with check boxes; Add opens the editor; pick URL, action Send to channel, channel 1, OK: the row appears, Apply writes `[Rules]` to settings.ini and the rule works immediately (copy a URL: it lands in channel 1). Edit, Remove, Up/Down and unchecking all mark the window dirty and persist through Apply. An invalid regex shows the message and keeps the dialog open. Run `tests/settings_flow.ahk`, `tests/windowops.ahk`, `tests/rules_flow.ahk`, `tests/ignored_flow.ahk`: ALL PASSED. Then run `bash tests/run-all.sh` on an idle desktop: ALL SUITES PASSED.

- [ ] **Step 7: Commit (ask first)**

```bash
git add src/ui/native/RuleDialog.ahk src/ui/native/SettingsWin.ahk src/ui/native/IgnoredWindowsWin.ahk src/core/settings.ahk Clipjump.ahk languages/english.txt tests/settings_flow.ahk
git commit -m "Settings: Rules page with the rule editor"
```

---

## Self-review

- Spec coverage: section 1 (Tasks 1, 2), section 2 (Tasks 3, 4, 5), section 3 (Tasks 7, 8), section 4 (Task 6), section 5 (Tasks 9, 10). Backfill timer added beyond the spec so the History type filter converges; noted in Task 2.
- Type consistency: `ClipType.Of(ch, clip)`, `ClipType.Label(kind)`, `ClipType.Actions(kind)`, `ClipType.Primary(kind, text)`, `ClipType.Run(id, text)`, `Transforms.AppliesTo(entry, kind)`, `Rules.Evaluate(list, kind, text, app, cls)`, `Toast.Show(text, ms, kind, slot, extra)`, `Theme.SetPill(ctl, fill, color, swatch)`, `historyQuery(..., kind)` are used with the same shapes in every task. `Formatting_Items` returns `byKey` keyed by upper-case letters and `Hud.Menu` returns the hotkey string, stripped in `Formatting`.
- Known judgment calls for the implementer: the JSON layer's handling of plain objects vs Maps in `SendPreview` (Task 6 says what to do either way); `tests/settings_flow.ahk`'s nav helper name (Task 10 says to reuse whatever the file has).
