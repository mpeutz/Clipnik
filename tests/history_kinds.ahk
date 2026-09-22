; Unit tests for the kind column in src/core/history.ahk against a temporary database.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\history_kinds.ahk
#Requires AutoHotkey v2.0
#Warn All, Off   ; history.ahk's addHistoryImage/getRandomStr and cliptype.ahk's ClipType.Of/Store reference
                 ; symbols only Clipnik.ahk defines (getRandomStr, clipPref, AddClipPref, CDS)
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
; stand-ins for settings.ahk's ini helpers (not included here), same contract: Ini_write only writes
; when the key is blank unless ifblank is falsy; nothing touches the real settings.ini.
global SETTINGS := Map()
Ini_read(section, key) {
    global SETTINGS
    k := section "|" key
    return SETTINGS.Has(k) ? SETTINGS[k] : ""
}
Ini_write(section, key, value := "", ifblank := true) {
    global SETTINGS
    k := section "|" key
    if (ifblank && SETTINGS.Has(k))
        return
    SETTINGS[k] := value
}

tmp := A_Temp "\cj_kinds.db"
try FileDelete(tmp)
check(DB.OpenDB(tmp), "open temp db")
; an old-style table without the kind column
DB.Exec("create table history (id integer primary key autoincrement, data text, type integer, fileid text, time text, size integer)")
DB.Exec('insert into history (data, type, time, size) values ("https://example.com", 0, "2026-09-10 10:00:00", 22)')
DB.Exec('insert into history (data, type, time, size) values ("plain words here", 0, "2026-09-10 10:01:00", 19)')
DB.Exec('insert into history (data, type, time, size, fileid) values ("[IMAGE]", 1, "2026-09-10 10:02:00", 100, "cache\\history\\x.jpg")')

historyAddKindColumn()
historyAddImageSizeColumns()
check(DB.GetTable("pragma table_info(history)", &ti) && InStr(ti2str(ti), "kind"), "migration adds the kind column")
DB.GetTable("pragma table_info(history)", &ti), cols := ti2str(ti)
check(InStr(cols, "width") && InStr(cols, "height"), "migration adds the width and height columns")
ti2str(tb) {
    s := ""
    loop tb.RowCount {
        tb.Next(&r)
        s .= r[2] ","
    }
    return s
}
historyAddKindColumn()
historyAddImageSizeColumns()
check(true, "migration is idempotent (no error on second run)")

addHistoryText("mike@example.com", A_Now, "email")
rec := historyGet(4)
check(rec["kind"] = "email", "insert stores the kind")
addHistoryText("#1DBC55", A_Now)
check(historyGet(5)["kind"] = "color", "insert detects the kind when none is given")

check(historyEnsureKind(1) = "url", "lazy classification of an old row")
check(historyGet(1)["kind"] = "url", "lazy classification is written back")
check(historyEnsureKind(3) = "image", "image rows classify as image")

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
check(kinds.Length = 5, "historyKinds lists the distinct kinds present (" kinds.Length ")")

; rewriting a clip's text re-detects its kind (a url row that becomes plain text)
historySetText(1, "plain words now")
check(historyGet(1)["kind"] = "text", "historySetText re-detects the kind (" historyGet(1)["kind"] ")")

; the History window classifies a page of rows in one transaction
DB.Exec('insert into history (data, type, time, size) values ("https://batch.example.com", 0, "2026-09-10 10:03:00", 25)')
rows := historyQuery("batch.example", true, "time", false, 0, 50)["rows"]
check(rows.Length = 1 && rows[1]["kind"] = "", "the new row starts unclassified")
check(historyEnsureKinds(rows) = 1, "historyEnsureKinds classifies the one unclassified row")
check(rows[1]["kind"] = "url", "historyEnsureKinds fills the kind in the array")
check(historyGet(rows[1]["id"])["kind"] = "url", "historyEnsureKinds writes the kind back")
check(historyEnsureKinds(rows) = 0, "nothing to classify: no transaction")

; SVG reclassification: rows classified before SVG detection existed keep "code"/"text" forever;
; historyReclassifySvg walks them once and promotes only a genuine match.
svgMarkup := '<svg xmlns="http://www.w3.org/2000/svg"><rect width="4" height="4"/></svg>'
DB.Exec('insert into history (data, type, time, size, kind) values ("' escapeQuotesSql(svgMarkup) '", 0, "2026-09-12 09:00:00", 60, "code")')
svgId := DB.LastInsertRowID()
DB.Exec('insert into history (data, type, time, size, kind) values ("if (x) { return y }", 0, "2026-09-12 09:01:00", 20, "code")')
codeId := DB.LastInsertRowID()
n := historyReclassifySvg(10)
check(n > 0, "svg reclassification examines the old code/text rows (" n ")")
check(historyGet(svgId)["kind"] = "svg", "an old SVG row copied as code is reclassified as svg")
check(historyGet(codeId)["kind"] = "code", "a plain code row is left untouched")
check(Ini_read("System", "SvgReclassified") = "1", "completion is recorded")
check(historyReclassifySvg(10) = 0, "svg reclassification is idempotent once complete")
check(historyGet(codeId)["kind"] = "code", "re-running does not touch the plain code row")

DB.CloseDB()
try FileDelete(tmp)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
