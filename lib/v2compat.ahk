; v2compat.ahk - helpers that preserve AutoHotkey v1 object and control-flow semantics
; that the Clipnik codebase relies on, so the port can stay close to the original code.

; CJMap: a Map that behaves like a v1 associative array.
;   - keys are case-insensitive; canonical integer strings ("12") and integers (12) are the same key
;   - reading a missing key returns "" instead of throwing
;   - obj.name reads/writes obj["name"] (v1 dot access), except for Map's own members
;   - v1 methods: HasKey, Insert, Remove (with integer-key shifting), MaxIndex, MinIndex
;   - enumeration order matches v1: integer keys ascending, then string keys sorted case-insensitively
class CJMap extends Map {
    Default => ""

    __New(params*) {
        this.CaseSense := "Off"
        loop params.Length // 2
            this[params[A_Index * 2 - 1]] := params[A_Index * 2]
    }

    static Key(k) {
        if (k is Integer)
            return k
        if (k is String && RegExMatch(k, "^-?(0|[1-9]\d*)$"))
            return Integer(k)
        return k
    }

    __Item[k] {
        get => super.__Item[CJMap.Key(k)]
        set => super.__Item[CJMap.Key(k)] := value
    }

    Has(k) => super.Has(CJMap.Key(k))
    HasKey(k) => super.Has(CJMap.Key(k))
    Get(k, default := "") => super.Has(CJMap.Key(k)) ? super.Get(CJMap.Key(k)) : default
    Set(k, v) => (super.Set(CJMap.Key(k), v), this)

    Delete(k) {
        k := CJMap.Key(k)
        return super.Has(k) ? super.Delete(k) : ""
    }

    ; obj.name -> obj["name"]; obj.name[i] -> obj["name"][i]
    __Get(name, params) {
        v := this[name]
        return params.Length ? v[params*] : v
    }

    __Set(name, params, value) {
        if !params.Length
            return this[name] := value
        target := this[name]
        target[params*] := value
        return value
    }

    ; Insert(value) appends after the highest integer key. Insert(key, value) sets key.
    Insert(params*) {
        if (params.Length = 1) {
            idx := this.MaxIndex()
            this[idx = "" ? 1 : idx + 1] := params[1]
            return true
        }
        this[params[1]] := params[2]
        return true
    }

    Push(v) => this.Insert(v)

    ; v1 Remove semantics:
    ;   Remove(intKey)      removes the key and shifts higher integer keys down by one, even when absent
    ;   Remove(key, "")     removes just that key
    ;   Remove(strKey)      removes just that key
    ;   Remove()            removes the highest integer key
    Remove(params*) {
        if !params.Length {
            idx := this.MaxIndex()
            return idx = "" ? "" : this.Delete(idx)
        }
        k := CJMap.Key(params[1])
        if (params.Length = 2 || !(k is Integer))
            return this.Delete(k)
        removed := this.Delete(k)
        keys := []
        for key in this.IntKeys()
            if (key > k)
                keys.Push(key)
        for key in keys {
            val := super.__Item[key]
            super.Delete(key)
            super.__Item[key - 1] := val
        }
        return removed
    }

    ; Drops integer keys 1..n and moves every higher one down by n, as compacter() does to the clip files.
    ; Remove(int) already shifts the rest down by one, so it is key 1 that goes each time: removing keys 1..n by
    ; index would take out every other entry instead, and leave the survivors holding their neighbors' values.
    RemoveFirst(n) {
        loop n
            this.Remove(1)
    }

    RawGet(k) => super.__Item[k]

    IntKeys() {
        keys := []
        for k in super.__Enum(1)
            if (k is Integer)
                keys.Push(k)
        return CJMap.SortInts(keys)
    }

    MaxIndex() {
        keys := this.IntKeys()
        return keys.Length ? keys[keys.Length] : ""
    }

    MinIndex() {
        keys := this.IntKeys()
        return keys.Length ? keys[1] : ""
    }

    Length => (m := this.MaxIndex()) = "" ? 0 : m

    Clone() {
        c := CJMap()
        for k, v in this
            c[k] := v
        return c
    }

    __Enum(n) {
        ints := this.IntKeys()
        strs := []
        for k in super.__Enum(1)
            if !(k is Integer)
                strs.Push(k)
        strs := CJMap.SortStrs(strs)
        keys := ints
        for s in strs
            keys.Push(s)
        i := 0
        self := this
        if (n = 1)
            return (&k) => (++i <= keys.Length) ? (k := keys[i], true) : false
        return (&k, &v) => (++i <= keys.Length) ? (k := keys[i], v := self.RawGet(k), true) : false
    }

    static SortInts(arr) {
        if arr.Length < 2
            return arr
        s := ""
        for v in arr
            s .= v "`n"
        out := []
        for v in StrSplit(Sort(RTrim(s, "`n"), "N"), "`n")
            out.Push(Integer(v))
        return out
    }

    static SortStrs(arr) {
        if arr.Length < 2
            return arr
        s := ""
        for v in arr
            s .= v "`n"
        return StrSplit(Sort(RTrim(s, "`n")), "`n")
    }
}

; Destroys a Gui stored in the CJGUI registry if it exists.
GuiDestroy(name) {
    global CJGUI
    if CJGUI.Has(name) {
        try CJGUI[name].Destroy()
        CJGUI.Delete(name)
    }
}

GuiExists(name) {
    global CJGUI
    return CJGUI.Has(name)
}

; Copies every named control value from a Gui.Submit() result into same-named globals,
; reproducing v1 "Gui, Submit" behavior for code that reads those globals afterwards.
SubmitToGlobals(guiObj) {
    saved := guiObj.Submit(false)
    for name, val in saved.OwnProps()
        VarSet(name, val)
    return saved
}

; Dynamic variable access. v2 can only reference global variables that exist statically;
; unknown names fall back to STORE so customizer and API.setVar/getVar keep working.
VarGet(name) {
    global STORE
    try {
        if IsSet(%name%)
            return %name%
    }
    return STORE.Has(name) ? STORE[name] : ""
}

VarSet(name, value) {
    global
    try {
        %name% := value
        return value
    }
    STORE[name] := value
    return value
}

; True when a global function with this name exists.
HasFuncByName(name) {
    try
        return %name% is Func
    catch
        return false
}

; Returns the function object for a name, or "" when it does not exist.
FuncByName(name) {
    try {
        f := %name%
        return f is Func ? f : ""
    } catch
        return ""
}

; ToolTip that accepts blank coordinates (v1 allowed "" to mean "near the cursor").
ToolTipAt(text := "", x := "", y := "", which := 1) {
	if (x = "" || y = "")
		ToolTip(text, , , which)
	else
		ToolTip(text, x, y, which)
}

; Reads a clip file (.avc, or a .cj / .cnk export) and returns a ClipboardAll object.
; Clipjump v1 running on 64-bit AutoHotkey wrote each block as format(4) size(8) data; v2 expects format(4) size(4) data.
; Files are sniffed for the 8-byte layout and converted on the fly, so caches created by v1 keep working.
ClipFileRead(path) {
	data := FileRead(path, "RAW")
	if ClipFile_IsLayout(data, 4)
		return ClipboardAll(data)
	if ClipFile_IsLayout(data, 8)
		return ClipboardAll(ClipFile_Convert8to4(data))
	return ClipboardAll(data)
}

; True when the buffer parses cleanly as a chain of format/size/data blocks with the given size-field width,
; ending with a 4-byte zero terminator at the end of the buffer.
ClipFile_IsLayout(buf, sizeBytes) {
	total := buf.Size
	pos := 0
	if (total < 4)
		return false
	loop {
		if (pos + 4 > total)
			return false
		fmt := NumGet(buf, pos, "UInt")
		if (fmt = 0)
			return (pos + 4 = total)
		if (pos + 4 + sizeBytes > total)
			return false
		size := (sizeBytes = 8) ? NumGet(buf, pos + 4, "UInt64") : NumGet(buf, pos + 4, "UInt")
		pos += 4 + sizeBytes + size
		if (pos > total)
			return false
	}
}

ClipFile_Convert8to4(buf) {
	out := Buffer(buf.Size)
	src := 0, dst := 0
	loop {
		fmt := NumGet(buf, src, "UInt")
		NumPut("UInt", fmt, out, dst)
		dst += 4, src += 4
		if (fmt = 0)
			break
		size := NumGet(buf, src, "UInt64")
		NumPut("UInt", size, out, dst)
		dst += 4, src += 8
		DllCall("RtlMoveMemory", "Ptr", out.Ptr + dst, "Ptr", buf.Ptr + src, "Ptr", size)
		dst += size, src += size
	}
	out.Size := dst
	return out
}

; True when two clip dumps hold the same capture: every format that carries content matches byte for byte.
; OLE's bookkeeping is left out of the comparison - DataObject is a handle to the writer's COM object and Ole
; Private Data its private state, both new on every write - so an OLE writer that puts the same image on the
; clipboard twice (the Snipping Tool does) is recognized as a repeat. A dump that does not parse is compared
; whole, as raw bytes.
ClipFile_SameContent(a, b) {
	a := ClipFile_Content(a), b := ClipFile_Content(b)
	return a.Size = b.Size && DllCall("ntdll\RtlCompareMemory", "Ptr", a, "Ptr", b, "UPtr", a.Size, "UPtr") = a.Size
}

; the dump without OLE's bookkeeping formats; returned unchanged when it does not parse as a v2 dump
ClipFile_Content(buf) {
	static skip := Map(DllCall("RegisterClipboardFormat", "Str", "DataObject", "UInt"), true
		, DllCall("RegisterClipboardFormat", "Str", "Ole Private Data", "UInt"), true)
	if !ClipFile_IsLayout(buf, 4)
		return buf
	out := Buffer(buf.Size), pos := 0, n := 0
	loop {
		fmt := NumGet(buf, pos, "UInt")
		if !fmt
			break
		size := NumGet(buf, pos + 4, "UInt")
		if !skip.Has(fmt)
			DllCall("RtlMoveMemory", "Ptr", out.Ptr + n, "Ptr", buf.Ptr + pos, "UPtr", 8 + size), n += 8 + size
		pos += 8 + size
	}
	out.Size := n
	return out
}

; True while a Gui object still has its window (Destroy or an owner closing can take it away).
GuiAlive(g) {
	try return g.Hwnd ? true : false
	catch
		return false
}
