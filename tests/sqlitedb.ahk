; Smoke test for lib/SQLiteDB/SQLiteDB.ahk. Run:
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\sqlitedb.ahk
#Requires AutoHotkey v2.0
#Include ..\lib\SQLiteDB\SQLiteDB.ahk
SQLiteDB.DLL := A_ScriptDir "\..\sqlite3.dll"

fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}

tmp := A_Temp "\cj_test.db"
try FileDelete(tmp)
db := SQLiteDB()
check(db.OpenDB(tmp), "open " db.ErrorMsg)
check(db.Exec("create table t(id integer primary key autoincrement, data text, n integer, b blob)"), "create " db.ErrorMsg)
check(db.Exec("insert into t(data,n) values('hello ''quoted''', 5)"), "insert1")
check(db.Exec("insert into t(data,n) values('unicode ☃ ü', null)"), "insert2")
check(db.LastInsertRowID() = 2, "last rowid")
check(!db.Exec("bogus sql"), "bad sql fails")
check(InStr(db.ErrorMsg, "syntax"), "error message populated: " db.ErrorMsg)

check(db.GetTable("select id,data,n from t order by id", &tb), "gettable")
check(tb.RowCount = 2 && tb.ColumnCount = 3, "rowcount/colcount " tb.RowCount "/" tb.ColumnCount)
check(tb.ColumnNames[2] = "data", "column names")
tb.Next(&row)
check(row[1] = 1 && row[2] = "hello 'quoted'" && row[3] = 5, "row1 values")
tb.Next(&row)
check(row[2] = "unicode ☃ ü" && row[3] = "", "row2 unicode + null")
check(tb.Next(&row) = -1, "table EOR")

check(db.Query("select id from t where n > 1", &rs), "query")
n := 0
while (rs.Next(&r) > 0)
    n++
check(n = 1, "query iterates 1 row")
check(rs.Reset() && rs.Next(&r) = 1 && r[1] = 1, "query reset")
rs.Free()

check(!db.Query("delete from t", &rs2), "query rejects non-select")
check(db.GetTable("select id from t where n > 999", &empty) && empty.RowCount = 0, "empty result")

; real database, read only
real := A_ScriptDir "\..\cache\data.db"
if FileExist(real) {
    db2 := SQLiteDB()
    check(db2.OpenDB(real, "R", false), "open real db " db2.ErrorMsg)
    ok := db2.GetTable("select count(*) from history", &c)
    check(ok, "count history " db2.ErrorMsg)
    if ok && c.Next(&r) = 1
        FileAppend("     history rows: " r[1] "`n", "*")
    db2.CloseDB()
}
check(db.CloseDB(), "close")
FileDelete(tmp)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
