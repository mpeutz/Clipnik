; vault.ahk - the Vault: clips the user saved on purpose. Nothing in Clipjump deletes from this table on its
; own: no age limit, no count limit, no compaction. Only an explicit delete removes an entry.
;
;   vaultCreateTable()   vaultAdd(data, type, fileid, kind, w, h, name)   vaultList(q, partial, kind)
;   vaultGet(id)   vaultSetText(id, text)   vaultSetName(id, name)   vaultMove(id, delta)
;   vaultDelete(id)   vaultToClipboard(id)   vaultCount()   vaultImageFile(srcPath)
;
; A row carries every field a history row does, so the Clipboard History page renders either list with one
; renderer, plus `name` (an optional label) and `pos` (the user's manual order).

vaultCreateTable() {
	global DB
	q := "
	(
		CREATE TABLE if not exists vault `(
		id      INTEGER PRIMARY KEY AUTOINCREMENT,
		name    TEXT,
		data    TEXT,
		type    INTEGER,
		fileid  TEXT,
		kind    TEXT,
		size    INTEGER,
		width   INTEGER,
		height  INTEGER,
		time    TEXT,
		pos     INTEGER
		`)
	)"
	if !DB.Exec(q)
		MsgBox("db create vault table")
}

; appends an entry: pos is one past the current maximum, so a new entry lands at the end of the order
vaultAdd(data, type, fileid := "", kind := "", w := 0, h := 0, name := "") {
	global DB
	if (kind = "" && type = 0)
		kind := ClipType.Detect(data)
	if (kind = "" && type = 1)
		kind := "image"
	top := getFromTable("vault", "max(pos)", "id>-1")
	pos := (top && top[1] != "") ? Integer(top[1]) + 1 : 1
	size := (type = 1) ? (FileExist(fileid) ? FileGetSize(fileid) : 0) : fileSizeFromStr(data)
	q := 'insert into vault (name, data, type, fileid, kind, size, width, height, time, pos) values ("'
		. escapeQuotesSql(Trim(name)) '", "' escapeQuotesSql(data) '", ' type ', "' escapeQuotesSql(fileid)
		. '", "' escapeQuotesSql(kind) '", ' size ', ' w ', ' h ', "' convertTimeSql(A_Now) '", ' pos ')'
	if !DB.Exec(q)
		return 0
	return DB.LastInsertRowID()   ; a method on SQLiteDB, not a property
}

; the whole vault in the user's order; q filters on the text and the name together
vaultList(q := "", partial := true, kind := "") {
	global DB
	crit := Trim(q)
	where := ""
	if (crit != "") {
		if partial {
			parts := []
			loop parse crit, " `t", " `t"
				if (A_LoopField != "")
					parts.Push('(data like "%' escapeQuotesSql(A_LoopField) '%" or name like "%' escapeQuotesSql(A_LoopField) '%")')
			where := " where " historyJoin(parts, " and ")
		} else
			where := ' where (data like "%' escapeQuotesSql(crit) '%" or name like "%' escapeQuotesSql(crit) '%")'
	}
	if ClipType.IsKind(kind)
		where .= (where = "" ? " where " : " and ") 'kind="' kind '"'
	out := Map("rows", [], "matched", 0, "total", 0, "bytes", 0)
	stats := getFromTable("vault", "count(*), sum(size)", "id>-1")
	out["total"] := stats ? stats[1] : 0, out["bytes"] := (stats && stats[2] != "") ? stats[2] : 0
	m := ""
	if !DB.GetTable("select count(*), sum(size) from vault" where, &m)
		return out
	if m.RowCount {
		r := ""
		m.Next(&r), out["matched"] := r[1]
	}
	sel := "select id, substr(data, 1, 300), type, time, size, fileid, kind, width, height, name, pos from vault"
		. where " order by pos asc, id asc"
	result := ""
	if !DB.GetTable(sel, &result)
		return out
	row := ""
	loop result.RowCount {
		result.Next(&row)
		out["rows"].Push(Map("id", row[1], "clip", row[2], "type", row[3], "time", row[4], "size", row[5]
			, "fileid", row[6], "kind", row[7], "width", row[8], "height", row[9], "name", row[10], "pos", row[11]))
	}
	return out
}

vaultGet(id) {
	if !IsInteger(id)
		return ""
	d := getFromTable("vault", "id, name, data, type, time, size, fileid, kind, width, height, pos", "id=" id)
	if !d
		return ""
	return Map("id", Integer(d[1]), "name", d[2], "data", d[3], "type", Integer(d[4]), "time", d[5]
		, "size", Integer(d[6]), "fileid", d[7], "kind", d[8]
		, "width", d[9] != "" ? Integer(d[9]) : "", "height", d[10] != "" ? Integer(d[10]) : ""
		, "pos", d[11] != "" ? Integer(d[11]) : 0)
}

; text entries only: an image entry has no text to rewrite
vaultSetText(id, text) {
	rec := vaultGet(id)
	if (!rec || rec["type"] = 1)
		return false
	execSql('update vault set data="' escapeQuotesSql(text) '", size=' fileSizeFromStr(text)
		. ', kind="' ClipType.Detect(text) '" where id=' id, 1)
	return true
}

vaultSetName(id, name) {
	execSql('update vault set name="' escapeQuotesSql(Trim(name)) '" where id=' id, 1)
}

; swaps this entry's position with its neighbour: delta below zero moves it up the list, above zero moves it
; down. Returns false at either end, so a caller can leave the list alone.
vaultMove(id, delta) {
	global DB
	me := getFromTable("vault", "pos", "id=" id)
	if !me
		return false
	pos := Integer(me[1])
	cmp := (delta < 0) ? "<" : ">", dir := (delta < 0) ? "desc" : "asc"
	n := ""
	if !DB.GetTable("select id, pos from vault where pos " cmp " " pos " order by pos " dir " limit 1", &n)
		return false
	if !n.RowCount
		return false
	row := ""
	n.Next(&row)
	execSql("update vault set pos=" row[2] " where id=" id, 1)
	execSql("update vault set pos=" pos " where id=" row[1], 1)
	return true
}

vaultDelete(id) {
	row := getFromTable("vault", "type, fileid", "id=" id)
	if (row && row[1] = 1 && row[2] != "")
		try FileDelete(row[2])
	execSql("delete from vault where id=" id)
}

vaultToClipboard(id) {
	rec := vaultGet(id)
	if !rec
		return false
	if (rec["type"] = 1)
		Gdip_SetImagetoClipboard(rec["fileid"])
	else
		try A_Clipboard := rec["data"]
	return true
}

vaultCount() {
	r := getFromTable("vault", "count(*)", "id>-1")
	return r ? Integer(r[1]) : 0
}

; copies an image into cache\vault under a fresh name, keeping the source extension. The bytes are never
; re-encoded: turning a JPEG into a PNG costs space and recovers nothing that was already thrown away.
; Returns the new relative path, or "" when there was nothing to copy.
vaultImageFile(srcPath) {
	if (srcPath = "" || !FileExist(srcPath))
		return ""
	SplitPath(srcPath, , , &ext)
	if (ext = "")
		ext := "png"
	DirCreate("cache\vault")
	while (FileExist(rname := "cache\vault\" getRandomStr(15) "." ext)) {
		; loop till a free name
	}
	try FileCopy(srcPath, rname)
	catch
		return ""
	return rname
}

; test hooks: RunFunc cannot index into a returned Map, so the fields a flow test needs to read back get
; their own plain functions. Plain file-level functions, never class methods, or RunFunc routes them to API.*
Vault_TextOf(id) {
	r := vaultGet(id)
	return r ? r["data"] : ""
}
Vault_KindOf(id) {
	r := vaultGet(id)
	return r ? r["kind"] : ""
}
