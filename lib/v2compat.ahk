; v2compat.ahk - helpers that preserve AutoHotkey v1 object and control-flow semantics
; that the Clipjump codebase relies on, so the port can stay close to the original code.

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
