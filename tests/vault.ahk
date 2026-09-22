; Unit tests for src/core/vault.ahk against a temporary database.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\vault.ahk
#Requires AutoHotkey v2.0
#Warn All, Off   ; vault.ahk references symbols only Clipnik.ahk defines
#Include ..\lib\v2compat.ahk
#Include ..\lib\SQLiteDB\SQLiteDB.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\src\core\vault.ahk
SQLiteDB.DLL := A_ScriptDir "\..\sqlite3.dll"

global TXT := CJMap(), STORE := Map(), CJGUI := Map()
global DB := SQLiteDB()
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
; helpers vault.ahk expects from lib/anticj_func_labels.ahk
escapeQuotesSql(s) => StrReplace(s, '"', '""')
fileSizeFromStr(s) => StrLen(s) + 3
convertTimeSql(t) => FormatTime(t, "yyyy-MM-dd HH:mm:ss")
getRandomStr(len) {
    out := ""
    loop len
        out .= SubStr("abcdefghijklmnopqrstuvwxyz0123456789", Random(1, 36), 1)
    return out
}
historyJoin(parts, sep) {
    s := ""
    for i, p in parts
        s .= (i > 1 ? sep : "") p
    return s
}
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

names() {
    out := ""
    for r in vaultList()["rows"]
        out .= (out != "" ? "," : "") (r["name"] != "" ? r["name"] : r["clip"])
    return out
}

tmp := A_Temp "\cj_vault.db"
try FileDelete(tmp)
check(DB.OpenDB(tmp), "open temp db")
vaultCreateTable()

; ---- add appends to the end of the order
a := vaultAdd("first entry", 0)
b := vaultAdd("second entry", 0)
c := vaultAdd("https://example.com", 0)
check(a && b && c, "three entries added")
check(names() = "first entry,second entry,https://example.com", "added in order: " names())
check(vaultCount() = 3, "count is three: " vaultCount())

; ---- the kind is detected from the text
check(vaultGet(c)["kind"] = "url", "a url entry is detected as url: " vaultGet(c)["kind"])
check(vaultGet(a)["kind"] = "text", "plain text is detected as text: " vaultGet(a)["kind"])

; ---- names
vaultSetName(b, "  Signature  ")
check(vaultGet(b)["name"] = "Signature", "the name is trimmed: [" vaultGet(b)["name"] "]")
check(names() = "first entry,Signature,https://example.com", "the list shows the name: " names())
vaultSetName(b, "")
check(vaultGet(b)["name"] = "", "an empty name clears it")
vaultSetName(b, "Signature")

; ---- editing text re-detects the kind
vaultSetText(a, "mike@example.com")
check(vaultGet(a)["data"] = "mike@example.com", "the text is rewritten")
check(vaultGet(a)["kind"] = "email", "the kind is re-detected: " vaultGet(a)["kind"])
check(vaultGet(a)["size"] = fileSizeFromStr("mike@example.com"), "the size follows the new text")
check(Vault_TextOf(a) = "mike@example.com", "the text hook reads it back")
check(Vault_KindOf(a) = "email", "the kind hook reads it back")

; ---- move
check(vaultMove(b, -1), "moving the middle entry up succeeds")
check(names() = "Signature,mike@example.com,https://example.com", "it moved up: " names())
check(vaultMove(b, 1), "moving it back down succeeds")
check(names() = "mike@example.com,Signature,https://example.com", "it moved back: " names())
check(!vaultMove(vaultList()["rows"][1]["id"], -1), "moving the first entry up is a no-op")
check(!vaultMove(vaultList()["rows"][3]["id"], 1), "moving the last entry down is a no-op")

; ---- search matches both text and name
check(vaultList("example")["rows"].Length = 2, "search matches text: " vaultList("example")["rows"].Length)
check(vaultList("Signature")["rows"].Length = 1, "search matches the name")
check(vaultList("nothing-here")["rows"].Length = 0, "a search with no match returns nothing")

; ---- an image entry keeps its file, and delete takes the file with it
img := A_Temp "\cj_vault_src.png"
try FileDelete(img)
FileAppend("not really a png", img)
rel := vaultImageFile(img)
check(rel != "" && FileExist(rel), "the image is copied into the vault folder: " rel)
d := vaultAdd("[IMAGE]", 1, rel, "image", 120, 80)
check(vaultGet(d)["type"] = 1 && vaultGet(d)["width"] = 120, "the image entry records its size")
check(vaultGet(d)["kind"] = "image", "an image entry is kind image")
vaultDelete(d)
check(!vaultGet(d), "the image entry is gone")
check(!FileExist(rel), "and its file went with it")

; ---- a missing source is a failure, never a silent empty entry
check(vaultImageFile(A_Temp "\no-such-vault-image.png") = "", "a missing image source copies nothing")

; ---- delete leaves the rest of the order alone
vaultDelete(vaultList()["rows"][2]["id"])
check(names() = "mike@example.com,https://example.com", "the remaining order survives a delete: " names())

try DB.CloseDB()
try FileDelete(tmp)
try FileDelete(img)
try DirDelete("cache\vault", true)
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
