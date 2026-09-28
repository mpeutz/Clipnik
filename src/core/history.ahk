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
historyAddKindColumn() {
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

; width and height of an image row, added after the kind column (2026-09)
historyAddImageSizeColumns() {
	global DB
	if !DB.GetTable("pragma table_info(history)", &tb)
		return
	hasW := false, hasH := false
	loop tb.RowCount {
		tb.Next(&r)
		if (r[2] = "width")
			hasW := true
		else if (r[2] = "height")
			hasH := true
	}
	if !hasW
		DB.Exec("alter table history add column width integer")
	if !hasH
		DB.Exec("alter table history add column height integer")
}

; the stored kind of one row, classifying and writing it back when missing; "image" for image rows
historyEnsureKind(id) {
	global DB
	row := getFromTable("history", "type, kind, data", "id=" id)
	if !row
		return ""
	if (row[2] != "")
		return row[2]
	kind := (row[1] = 1) ? "image" : ClipType.Detect(row[3])
	execSql('update history set kind="' kind '" where id=' id)
	return kind
}

; classifies the unclassified text rows of a historyQuery result in one transaction, filling in each row's "kind"
historyEnsureKinds(rows) {
	global DB
	todo := []
	for row in rows
		if (row["type"] = 0 && row["kind"] = "")
			todo.Push(row)
	if !todo.Length
		return 0
	began := DB.Exec("begin") ? true : false   ; false when a transaction is already open (the startup backfill)
	try {
		for row in todo
			row["kind"] := historyEnsureKind(row["id"])
	} finally {
		if began
			DB.Exec("commit")
	}
	return todo.Length
}

; classifies up to batch old rows; returns how many were updated (0 when done)
historyBackfillKinds(batch := 200) {
	global DB
	if !DB.GetTable("select id, data, type from history where kind is null or kind='' limit " batch, &tb)
		return 0
	n := 0
	DB.Exec("begin")
	loop tb.RowCount {
		tb.Next(&r)
		kind := (r[3] = 1) ? "image" : ClipType.Detect(r[2])
		execSql('update history set kind="' kind '" where id=' r[1])
		n++
	}
	DB.Exec("commit")
	return n
}

; one-time reclassification: old rows kept the "code"/"text" kind SVG detection couldn't yet produce.
; Walks such rows by id, in bounded batches, and promotes a match to "svg"; never touches any other
; kind. A [System] flag (written through Ini_write, once every matching row has been seen) makes it
; idempotent so a later launch does not rescan the table; a cursor lets it resume mid-scan.
historyReclassifySvg(batch := 200) {
	global DB
	if (Ini_read("System", "SvgReclassified") = "1")
		return 0
	cursor := Ini_read("System", "SvgReclassifyCursor")
	cursor := (cursor = "") ? 0 : Integer(cursor)
	if !DB.GetTable("select id, data from history where id > " cursor " and kind in ('code','text') order by id limit " batch, &tb)
		return 0
	if !tb.RowCount {
		Ini_write("System", "SvgReclassified", "1", 0)
		return 0
	}
	maxId := cursor
	DB.Exec("begin")
	loop tb.RowCount {
		tb.Next(&r)
		if (r[1] > maxId)
			maxId := r[1]
		if (StrLen(r[2]) * 2 <= ClipType.MaxBytes) && ClipType.IsSvg(r[2])
			execSql('update history set kind="svg" where id=' r[1])
	}
	DB.Exec("commit")
	Ini_write("System", "SvgReclassifyCursor", maxId, 0)
	if (tb.RowCount < batch)
		Ini_write("System", "SvgReclassified", "1", 0)
	return tb.RowCount
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

; test hook: "<kind> <width> <height>" of the newest image row
Image_LastHistoryDims() {
	row := getFromTable("history", "kind, width, height", "type=1 order by id desc limit 1")
	return row ? row[1] " " row[2] " " row[3] : ""
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

addHistoryImage(imgpath, timestamp, kind := "image", w := 0, h := 0){
; adds an image (by path) to history; timestamp is in A_Now format
	if !FileExist(imgpath)   ; the clipboard capture failed, so there is no thumbnail to record
		return
	timestamp := convertTimeSql(timestamp)
	fptr := FileOpen(imgpath, "r")
	size := fptr.Length
	fptr.Close()
	while (FileExist(rname := "cache\history\" getRandomStr(15) ".jpg")){
		; loop till new file name
	}

	FileCopy(imgpath, rname)
	q := "insert into history (data, type, time, size, fileid, kind, width, height) values ("
		. '"[IMAGE]", '
		. 1 ","
		. '"' timestamp '", '
		. size ", "
		. '"' rname '", '
		. '"' kind '", '
		. w ", "
		. h ")"

	if !DB.Exec(q)
		MsgBox("Msg:`t" . DB.ErrorMsg . "`nCode:`t" . DB.ErrorCode, "SQLite Error", 16)
}

deleteHistoryById(id){
; deletes a history element by its ID in the table
	; the row's own type decides whether there is a file to remove: HISTORYOBJ only knows rows the history
	; window has listed, so a prune at startup would otherwise leave every image file behind on disk
	row := getFromTable("history", "type, fileid", "id=" id)
	if (row && row[1] = 1 && row[2] != "")
		try FileDelete(row[2])
	execSql("delete from history where id=" id)
	try HISTORYOBJ.Delete(id)
}

; the ids a query returns, as a plain array: the delete loop must not walk a live result set while the
; rows under it are being removed
historyIdList(q) {
	global DB
	out := []
	if !DB.Query(q, &rs)
		return out
	row := ""
	while (rs.Next(&row) > 0)
		out.Push(row[1])
	rs.Free()
	return out
}

; applies the history retention limits and returns how many rows were deleted:
;   days       overall age in days; 0 means no age limit
;   imageDays  age for image rows only; 0 means images follow the overall limit
;   maxRows    how many clips to keep; 0 means no count limit
; The three sets are collected first and deleted as one transaction, so a row caught by more than one limit
; is deleted once. Times are compared in local time because that is how convertTimeSql writes them.
historyPrune(days, imageDays, maxRows) {
	global DB
	doomed := Map()
	if (days > 0)
		for id in historyIdList("select id from history where time < datetime('now', 'localtime', '-" days " days')")
			doomed[id] := 1
	if (imageDays > 0)
		for id in historyIdList("select id from history where type = 1 and time < datetime('now', 'localtime', '-" imageDays " days')")
			doomed[id] := 1
	; everything past the newest maxRows, so the count limit needs no arithmetic against the age passes
	if (maxRows > 0)
		for id in historyIdList("select id from history order by time desc, id desc limit -1 offset " maxRows)
			doomed[id] := 1
	if !doomed.Count
		return 0
	DB.Exec("BEGIN TRANSACTION")
	for id in doomed
		deleteHistoryById(id)
	DB.Exec("COMMIT TRANSACTION")
	return doomed.Count
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
	q := "select id, substr(data, 1, 300), type, time, size, fileid, kind, width, height from history" where " order by " col " " dir ", id desc limit " limit " offset " offset
	result := ""
	if !DB.GetTable(q, &result)
		return out
	loop result.RowCount {
		result.Next(&row)
		out["rows"].Push(Map("id", row[1], "clip", row[2], "type", row[3], "time", row[4], "size", row[5], "fileid", row[6], "kind", row[7], "width", row[8], "height", row[9]))
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

; full record: Map(id, data, type, time, size, fileid, kind, width, height) or ""
historyGet(id) {
	if !IsInteger(id)
		return ""
	data := getFromTable("history", "id, data, type, time, size, fileid, kind, width, height", "id=" id)
	if !data
		return ""
	return Map("id", Integer(data[1]), "data", data[2], "type", Integer(data[3]), "time", data[4], "size", Integer(data[5]), "fileid", data[6], "kind", data[7], "width", data[8] != "" ? Integer(data[8]) : "", "height", data[9] != "" ? Integer(data[9]) : "")
}

; rewrites a text row; the kind is re-detected so it cannot describe the old text
historySetText(id, text) {
	execSql('update history set data="' escapeQuotesSql(text) '", size=' fileSizeFromStr(text) ', kind="' ClipType.Detect(text) '" where id=' id, 1)
}

; puts a history record on the system clipboard; returns true when something was copied
historyToClipboard(id) {
	rec := historyGet(id)
	if !rec
		return false
	if (rec["type"] == 1)
		Gdip_SetImagetoClipboard(rec["fileid"])
	else
		try trySetClipboard(rec["data"])
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
