; SQLiteDB for AutoHotkey v2
; Minimal port of the API surface Clipnik uses from just me's Class_SQLiteDB (v1):
;   OpenDB, CloseDB, Exec, GetTable, Query, ErrorMsg, ErrorCode, LastInsertRowID
; Result objects mirror the v1 shapes: Table has RowCount/ColumnCount/Rows and Next(&Row);
; RecordSet has Next(&Row), Reset(), Free(). Next() returns 1 for a row, -1 at end, 0 on error.
; Rows are 1-based Arrays of column values; NULL -> "", BLOB -> Buffer.

class SQLiteDB {
    static DLL := A_ScriptDir "\sqlite3.dll"
    static hModule := 0
    static SQLITE_OK := 0, SQLITE_ROW := 100, SQLITE_DONE := 101

    ErrorMsg := ""
    ErrorCode := 0
    Path := ""
    _Handle := 0
    _Queries := Map()

    __New() {
        if !SQLiteDB.hModule {
            SQLiteDB.hModule := DllCall("LoadLibrary", "Str", SQLiteDB.DLL, "Ptr")
            if !SQLiteDB.hModule
                throw OSError("Cannot load " SQLiteDB.DLL)
        }
    }

    __Delete() {
        if this._Handle
            this.CloseDB()
    }

    OpenDB(DBPath, Access := "W", Create := true) {
        static SQLITE_OPEN_READONLY := 0x01, SQLITE_OPEN_READWRITE := 0x02, SQLITE_OPEN_CREATE := 0x04
        this._Reset()
        if this._Handle {
            this.ErrorMsg := "You must first close DB " this.Path "!"
            return false
        }
        if !FileExist(DBPath) && !Create {
            this.ErrorMsg := "Database " DBPath " does not exist!"
            return false
        }
        flags := (Access = "R") ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | (Create ? SQLITE_OPEN_CREATE : 0)
        h := 0
        rc := DllCall("sqlite3.dll\sqlite3_open_v2", "Ptr", this._Utf8(DBPath), "Ptr*", &h, "Int", flags, "Ptr", 0, "Cdecl Int")
        if rc {
            this.ErrorMsg := h ? this._ErrMsg(h) : "Unable to open database"
            this.ErrorCode := rc
            if h
                DllCall("sqlite3.dll\sqlite3_close", "Ptr", h, "Cdecl Int")
            return false
        }
        this._Handle := h
        this.Path := DBPath
        return true
    }

    CloseDB() {
        this._Reset()
        if !this._Handle
            return true
        for stmt in this._Queries.Clone()
            DllCall("sqlite3.dll\sqlite3_finalize", "Ptr", stmt, "Cdecl Int")
        this._Queries.Clear()
        rc := DllCall("sqlite3.dll\sqlite3_close", "Ptr", this._Handle, "Cdecl Int")
        if rc {
            this.ErrorMsg := this._ErrMsg()
            this.ErrorCode := rc
            return false
        }
        this._Handle := 0
        this.Path := ""
        return true
    }

    Exec(SQL) {
        this._Reset()
        if !this._Handle
            return this._Fail("Invalid database handle!")
        err := 0
        rc := DllCall("sqlite3.dll\sqlite3_exec", "Ptr", this._Handle, "Ptr", this._Utf8(SQL), "Ptr", 0, "Ptr", 0, "Ptr*", &err, "Cdecl Int")
        if rc {
            this.ErrorMsg := err ? StrGet(err, "UTF-8") : this._ErrMsg()
            this.ErrorCode := rc
            if err
                DllCall("sqlite3.dll\sqlite3_free", "Ptr", err, "Cdecl")
            return false
        }
        return true
    }

    ; Runs a SELECT and materializes every row into a Table object.
    GetTable(SQL, &TB) {
        TB := ""
        if !this.Query(SQL, &rs)
            return false
        tb := SQLiteDB.Table()
        tb.ColumnCount := rs.ColumnCount
        tb.ColumnNames := rs.ColumnNames
        tb.HasNames := true
        while (rs.Next(&row) > 0)
            tb.Rows.Push(row)
        rs.Free()
        tb.RowCount := tb.Rows.Length
        tb.HasRows := tb.RowCount > 0
        TB := tb
        return true
    }

    ; Prepares a SELECT (or PRAGMA, which also returns rows, e.g. table_info) and returns a forward-only RecordSet.
    Query(SQL, &RS) {
        RS := ""
        this._Reset()
        if !this._Handle
            return this._Fail("Invalid database handle!")
        if !RegExMatch(SQL, "i)^\s*(SELECT|PRAGMA)\s")
            return this._Fail("Query requires a SELECT or PRAGMA statement!")
        stmt := 0
        rc := DllCall("sqlite3.dll\sqlite3_prepare_v2", "Ptr", this._Handle, "Ptr", this._Utf8(SQL), "Int", -1, "Ptr*", &stmt, "Ptr", 0, "Cdecl Int")
        if rc {
            this.ErrorMsg := this._ErrMsg()
            this.ErrorCode := rc
            return false
        }
        cols := DllCall("sqlite3.dll\sqlite3_column_count", "Ptr", stmt, "Cdecl Int")
        if (cols < 1) {
            DllCall("sqlite3.dll\sqlite3_finalize", "Ptr", stmt, "Cdecl Int")
            return this._Fail("Query result is empty!")
        }
        names := []
        loop cols
            names.Push(StrGet(DllCall("sqlite3.dll\sqlite3_column_name", "Ptr", stmt, "Int", A_Index - 1, "Cdecl Ptr"), "UTF-8"))
        rs := SQLiteDB.RecordSet()
        rs.ColumnCount := cols
        rs.ColumnNames := names
        rs.HasNames := true
        rs._Handle := stmt
        rs._DB := this
        this._Queries[stmt] := true
        RS := rs
        return true
    }

    LastInsertRowID() => DllCall("sqlite3.dll\sqlite3_last_insert_rowid", "Ptr", this._Handle, "Cdecl Int64")

    _Reset() {
        this.ErrorMsg := ""
        this.ErrorCode := 0
    }

    _Fail(msg) {
        this.ErrorMsg := msg
        return false
    }

    _ErrMsg(h := 0) {
        p := DllCall("sqlite3.dll\sqlite3_errmsg", "Ptr", h ? h : this._Handle, "Cdecl Ptr")
        return p ? StrGet(p, "UTF-8") : ""
    }

    _Utf8(str) {
        buf := Buffer(StrPut(str, "UTF-8"))
        StrPut(str, buf, "UTF-8")
        return buf
    }

    class Table {
        ColumnCount := 0
        RowCount := 0
        ColumnNames := []
        Rows := []
        HasNames := false
        HasRows := false
        _CurrentRow := 0

        GetRow(index, &Row) {
            Row := ""
            if (index < 1 || index > this.RowCount)
                return false
            Row := this.Rows[index]
            this._CurrentRow := index
            return true
        }

        Next(&Row) {
            Row := ""
            if (this._CurrentRow >= this.RowCount)
                return -1
            this._CurrentRow += 1
            Row := this.Rows[this._CurrentRow]
            return true
        }

        Reset() {
            this._CurrentRow := 0
            return true
        }
    }

    class RecordSet {
        static SQLITE_BLOB := 4, SQLITE_NULL := 5
        ColumnCount := 0
        ColumnNames := []
        HasNames := false
        CurrentRow := 0
        ErrorMsg := ""
        ErrorCode := 0
        _Handle := 0
        _DB := ""

        __Delete() {
            this.Free()
        }

        Next(&Row) {
            Row := ""
            this.ErrorMsg := "", this.ErrorCode := 0
            if !this._Handle {
                this.ErrorMsg := "Invalid query handle!"
                return false
            }
            rc := DllCall("sqlite3.dll\sqlite3_step", "Ptr", this._Handle, "Cdecl Int")
            if (rc = SQLiteDB.SQLITE_DONE) {
                this.ErrorMsg := "EOR", this.ErrorCode := rc
                return -1
            }
            if (rc != SQLiteDB.SQLITE_ROW) {
                this.ErrorMsg := this._DB._ErrMsg(), this.ErrorCode := rc
                return false
            }
            count := DllCall("sqlite3.dll\sqlite3_data_count", "Ptr", this._Handle, "Cdecl Int")
            Row := []
            loop count {
                col := A_Index - 1
                ctype := DllCall("sqlite3.dll\sqlite3_column_type", "Ptr", this._Handle, "Int", col, "Cdecl Int")
                if (ctype = SQLiteDB.RecordSet.SQLITE_NULL) {
                    Row.Push("")
                } else if (ctype = SQLiteDB.RecordSet.SQLITE_BLOB) {
                    ptr := DllCall("sqlite3.dll\sqlite3_column_blob", "Ptr", this._Handle, "Int", col, "Cdecl Ptr")
                    size := DllCall("sqlite3.dll\sqlite3_column_bytes", "Ptr", this._Handle, "Int", col, "Cdecl Int")
                    if (!ptr || !size) {
                        Row.Push("")
                    } else {
                        blob := Buffer(size)
                        DllCall("RtlMoveMemory", "Ptr", blob, "Ptr", ptr, "Ptr", size)
                        Row.Push(blob)
                    }
                } else {
                    Row.Push(StrGet(DllCall("sqlite3.dll\sqlite3_column_text", "Ptr", this._Handle, "Int", col, "Cdecl Ptr"), "UTF-8"))
                }
            }
            this.CurrentRow += 1
            return true
        }

        Reset() {
            this.ErrorMsg := "", this.ErrorCode := 0
            if !this._Handle {
                this.ErrorMsg := "Invalid query handle!"
                return false
            }
            rc := DllCall("sqlite3.dll\sqlite3_reset", "Ptr", this._Handle, "Cdecl Int")
            if rc {
                this.ErrorMsg := this._DB._ErrMsg(), this.ErrorCode := rc
                return false
            }
            this.CurrentRow := 0
            return true
        }

        Free() {
            this.ErrorMsg := "", this.ErrorCode := 0
            if !this._Handle
                return true
            rc := DllCall("sqlite3.dll\sqlite3_finalize", "Ptr", this._Handle, "Cdecl Int")
            if rc {
                this.ErrorMsg := this._DB._ErrMsg(), this.ErrorCode := rc
                return false
            }
            try this._DB._Queries.Delete(this._Handle)
            this._Handle := 0
            return true
        }
    }
}
