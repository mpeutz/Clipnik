; history.ahk - the clipboard history table (SQLite): schema, inserts, deletes, queries and migration.
; The History window (src/ui/web/HistoryWin.ahk) only talks to this file.

createHisTable(){
; creates the History Table if it doesnt exist
	q := "
	(
		CREATE TABLE if not exists history `(
		id	INTEGER PRIMARY KEY AUTOINCREMENT,
		data 	TEXT,
		type	INTEGER,
		fileid 	TEXT,
		time	TEXT,
		size 	INTEGER
		`)
	)"
	if !DB.Exec(q)
		MsgBox("db create history table")
}

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

addHistoryImage(imgpath, timestamp){
; adds an image (by path) to history; timestamp is in A_Now format
	timestamp := convertTimeSql(timestamp)
	fptr := FileOpen(imgpath, "r")
	size := fptr.Length
	fptr.Close()
	while (FileExist(rname := "cache\history\" getRandomStr(15) ".jpg")){
		; loop till new file name
	}

	FileCopy(imgpath, rname)
	q := "insert into history (data, type, time, size, fileid) values ("
		. '"[IMAGE]", '
		. 1 ","
		. '"' timestamp '", '
		. size ", "
		. '"' rname '")'

	if !DB.Exec(q)
		MsgBox("Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode, "SQLite Error", 16)
}

deleteHistoryById(id){
; deletes a history element by its ID in the table
	if (HISTORYOBJ[id] == 1){
		imgpath := (data := getFromTable("history", "fileid", "id=" id)) ? data[1] : ""
		try FileDelete(imgpath)
	}
	execSql("delete from history where id=" id)
	try HISTORYOBJ.Delete(id)
}

clearHistory() {
	try FileDelete("cache\history\*")
	execSql("delete from history")
	global HISTORYOBJ := CJMap()
}

fillHISTORYOBJ(){
; HISTORYOBJ[ID] = type ( 0 text, 1 image )
	global HISTORYOBJ
	local result := "", Row := "", q
	q := "select id,type from history"
	if !DB.GetTable(q, &result) {
		MsgBox("error")
		return
	}
	loop result.RowCount
	{
		result.Next(&Row) 		; v1 never advanced the row (bug); without this HISTORYOBJ stayed empty
		HISTORYOBJ[Row[1]] := Row[2]
	}
}

; Rows matching a search, sorted and paged. Returns {rows: Array of Map(id, clip, type, time, size, fileid), matched, total, bytes}.
; clip is a one-line snippet (the page asks for the full text through historyGet).
historyQuery(crit := "", partial := true, sort := "time", asc := false, offset := 0, limit := 500, kind := "") {
	crit := Trim(crit)
	where := ""
	if (crit != "") {
		if partial {
			parts := []
			loop parse crit, " `t", " `t"
				if (A_LoopField != "")
					parts.Push('data like "%' escapeQuotesSql(A_LoopField) '%"')
			where := " where " historyJoin(parts, " and ")
		} else
			where := ' where data like "%' escapeQuotesSql(crit) '%"'
	}
	if ClipType.IsKind(kind)
		where .= (where = "" ? " where " : " and ") 'kind="' kind '"'
	col := (sort = "clip") ? "data" : (sort = "size") ? "size" : "time"
	dir := asc ? "asc" : "desc"
	out := Map("rows", [], "matched", 0, "total", 0, "bytes", 0)
	stats := getFromTable("history", "count(*), sum(size)", "id>-1")
	out["total"] := stats ? stats[1] : 0, out["bytes"] := (stats && stats[2] != "") ? stats[2] : 0
	m := ""
	if !DB.GetTable("select count(*), sum(size) from history" where, &m)
		return out
	if m.RowCount {
		m.Next(&r), out["matched"] := r[1]
	}
	q := "select id, substr(data, 1, 300), type, time, size, fileid, kind from history" where " order by " col " " dir ", id desc limit " limit " offset " offset
	result := ""
	if !DB.GetTable(q, &result)
		return out
	loop result.RowCount {
		result.Next(&row)
		out["rows"].Push(Map("id", row[1], "clip", row[2], "type", row[3], "time", row[4], "size", row[5], "fileid", row[6], "kind", row[7]))
		HISTORYOBJ[row[1]] := row[3]
	}
	return out
}

historyJoin(parts, sep) {
	s := ""
	for i, p in parts
		s .= (i > 1 ? sep : "") p
	return s
}

; full record: Map(id, data, type, time, size, fileid) or ""
historyGet(id) {
	if !IsInteger(id)
		return ""
	data := getFromTable("history", "id, data, type, time, size, fileid, kind", "id=" id)
	if !data
		return ""
	return Map("id", data[1], "data", data[2], "type", data[3], "time", data[4], "size", data[5], "fileid", data[6], "kind", data[7])
}

historySetText(id, text) {
	execSql('update history set data="' escapeQuotesSql(text) '", size=' fileSizeFromStr(text) ' where id=' id, 1)
}

; puts a history record on the system clipboard; returns true when something was copied
historyToClipboard(id) {
	rec := historyGet(id)
	if !rec
		return false
	if (rec["type"] == 1)
		Gdip_SetImagetoClipboard(rec["fileid"])
	else
		try A_Clipboard := rec["data"]
	return true
}

history_GetSize(option := ""){
; size of history in KB
	data := getFromTable("history", "sum(size)", "id>-1")
	R := (data && data[1] != "") ? data[1] : 0
	return R/1024
}

;------------------------------------ MIGRATE ----------------------------------------------

migrateHistory(){
; migrates History files to the database
	createHisTable()
	DB.Exec("BEGIN TRANSACTION")
	API.showTip("Moving history files to database. This process may take some time.")
	loop files "cache\history\*"
	{
		if (StrLen(A_LoopFileName) != 18) ; YYYYMMDDHHMMSS.ext
			continue
		if (A_LoopFileExt == "jpg"){
			addHistoryImage(A_LoopFileFullPath, SubStr(A_LoopFileName, 1, -4))
			FileDelete(A_LoopFileFullPath)
		} else if (A_LoopFileExt == "txt"){
			tdata := FileRead(A_LoopFileFullPath)
			addHistoryText(tdata, SubStr(A_LoopFileName, 1, -4))
			FileDelete(A_LoopFileFullPath)
		}
	}
	DB.Exec("COMMIT TRANSACTION")
	API.removeTip()
}
