; Unit tests for historyPrune (src/core/history.ahk) against a temporary database.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\history_prune.ahk
#Requires AutoHotkey v2.0
#Warn All, Off   ; history.ahk references symbols only Clipnik.ahk defines (getRandomStr, clipPref, CDS)
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
; helpers history.ahk expects from lib/anticj_func_labels.ahk
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

; a local timestamp N days back, matching how convertTimeSql writes them
daysAgo(n) => FormatTime(DateAdd(A_Now, -n, "Days"), "yyyy-MM-dd HH:mm:ss")
ids() {
    global DB
    out := ""
    if DB.GetTable("select data from history order by time asc", &tb)
        loop tb.RowCount
            out .= (out != "" ? "," : "") tb.Rows[A_Index][1]
    return out
}
rowCount() {
    r := getFromTable("history", "count(*)", "id>-1")
    return r ? Integer(r[1]) : -1
}

tmp := A_Temp "\cj_prune.db"
imgDir := A_Temp "\cj_prune_imgs"
DirCreate(imgDir)

; rebuilt before each case so the cases cannot depend on each other's leftovers
seed() {
    global DB, tmp, imgDir
    try DB.CloseDB()
    try FileDelete(tmp)
    DB.OpenDB(tmp)
    DB.Exec("create table history (id integer primary key autoincrement, data text, type integer, fileid text, time text, size integer, kind text, width integer, height integer)")
    add(data, type, days, fileid := "") {
        global DB
        DB.Exec('insert into history (data, type, time, size, fileid) values ("' data '", ' type ', "' daysAgo(days) '", 10, "' StrReplace(fileid, "\", "\\") '")')
    }
    loop 3 {
        p := imgDir "\img" A_Index ".jpg"
        FileAppend("x", p)
    }
    add("old-text", 0, 40)
    add("mid-text", 0, 20)
    add("new-text", 0, 1)
    add("older-text", 0, 60)
    add("old-img", 1, 20, imgDir "\img1.jpg")
    add("mid-img", 1, 4, imgDir "\img2.jpg")
    add("new-img", 1, 1, imgDir "\img3.jpg")
}
cleanImgs() {
    global imgDir
    loop 3
        try FileDelete(imgDir "\img" A_Index ".jpg")
}

; ---- every limit off deletes nothing
seed()
check(historyPrune(0, 0, 0) = 0, "all limits off deletes nothing")
check(rowCount() = 7, "all seven rows survive: " rowCount())

; ---- overall age only
seed()
n := historyPrune(30, 0, 0)
check(n = 2, "30 day age deletes the two rows past it (deleted " n ")")
check(!InStr(ids(), "older-text") && !InStr(ids(), "old-text"), "the oldest text rows are gone: " ids())
check(InStr(ids(), "mid-text") && InStr(ids(), "old-img"), "rows inside the window stay: " ids())

; ---- image age only, and the file goes with the row
seed()
n := historyPrune(0, 7, 0)
check(n = 1, "a 7 day image age deletes only the one image past it (deleted " n ")")
check(!InStr(ids(), "old-img"), "the old image row is gone: " ids())
check(InStr(ids(), "old-text") && InStr(ids(), "older-text"), "text rows are untouched by the image limit: " ids())
check(!FileExist(imgDir "\img1.jpg"), "the pruned image's file is deleted too")
check(FileExist(imgDir "\img2.jpg") && FileExist(imgDir "\img3.jpg"), "the other image files stay")

; ---- count only, newest kept
seed()
n := historyPrune(0, 0, 3)
check(n = 4, "a cap of 3 deletes the other four (deleted " n ")")
check(rowCount() = 3, "three rows remain: " rowCount())
check(InStr(ids(), "new-text") && InStr(ids(), "new-img") && InStr(ids(), "mid-img"), "the newest three are the ones kept: " ids())

; ---- a row caught by two limits is deleted once, and the count is the union
seed()
n := historyPrune(30, 7, 5)
; older-text (60d) and old-text (40d) fail the age; old-img (20d) fails the image age; that is three, and
; the survivors are already under the cap of 5, so the count limit adds nothing
check(n = 3, "overlapping limits delete each row once (deleted " n ")")
check(rowCount() = 4, "four rows remain: " rowCount())

; ---- the count limit still applies when the age limits are off
seed()
n := historyPrune(0, 0, 1)
check(rowCount() = 1, "a cap of 1 leaves one row: " rowCount())
check(ids() = "new-text" || ids() = "new-img", "and it is a newest row: " ids())

try DB.CloseDB()
try FileDelete(tmp)
cleanImgs()
try DirDelete(imgDir)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
