; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
; Customizer
/*
What is supported?
	k = %func()%
	a.b = %func()%
	a.b = some_string is supported (Obviously)
	a.b = %c.d%
*/


/**
 * loads customs from the ClipjumpCustom.ini file
 * @return {void}
 */
loadCustomizations() {
	global CUSTOMS, startUpComplete
	if !FileExist("ClipjumpCustom.ini") {
		FileAppend(";Customizer File for Clipjump`n;Add your custom settings here`n`n[AutoRun]`n;auto-run items go here", "ClipjumpCustom.ini")
		return
	}
	f := "ClipjumpCustom.ini"

	o := IniRead(f) 	; load sections
	loop parse o, "`n", A_Space
	{
		if (A_LoopField = "")
			continue
		s := IniRead(f, A_LoopField) 	; read that section
		tobj := CJMap()

		loop parse s, "`n", A_Space
		{	; read each key
			if (A_LoopField = "")
				continue
			a := Format("{:03}", A_Index)
			k := Trim(SubStr(A_LoopField, 1, p := InStr(A_LoopField, "=") - 1)), v := Trim(SubStr(A_LoopField, p + 2))
			if (k = "bind")
				tobj.bind := v
			else if (k = "noautorun")
				tobj.noautorun := v
			else
				tobj[a k] := v
		}
		if !(tobj.noautorun) && (tobj.bind = "") && !startUpComplete
			customization_Run(tobj)
		else if (tobj.bind != "") && (tobj.noautorun == 0) && !startUpComplete
			customization_Run(tobj)
		if Hparse(tobj.bind) { 	; if key is valid
			hkZ(tobj.bind := "$" Hparse(tobj.bind), CustomHotkey, 1) ; create hotkey
			CUSTOMS[tobj.bind] := tobj.Clone()
		}
		CUSTOMS["_" A_LoopField] := tobj.Clone() 	; store section object for use later
	}
}


/**
 * reset all customizations applied in Clipjump, including the hotkey bindings
 * @return {void}
 */
resetCustomizations() {
	global CUSTOMS
	for k, v in CUSTOMS
	{
		if InStr(k, "_") != 1
			hkZ(v.bind, CustomHotkey, 0) 	; unregister hk
	}
	CUSTOMS := CJMap()
}


; Resolves "name", "obj.key" or "obj.key.key2" to its current value.
resolveVarPath(path) {
	if !InStr(path, ".")
		return VarGet(Trim(path))
	parts := StrSplit(path, ".")
	val := VarGet(Trim(parts[1]))
	loop parts.Length - 1
		val := IsObject(val) ? val[Trim(parts[A_Index + 1])] : ""
	return val
}

; Assigns to "name", "obj.key" or "obj.key.key2".
assignVarPath(path, value) {
	if !InStr(path, ".") {
		VarSet(Trim(path), value)
		return
	}
	parts := StrSplit(path, ".")
	target := VarGet(Trim(parts[1]))
	if !IsObject(target)
		return
	loop parts.Length - 2
		target := target[Trim(parts[A_Index + 1])]
	target[Trim(parts[parts.Length])] := value
}


/**
 * runs a customization (the section)
 * @param  {array} obj customization object containing key-value pairs of commands in it
 * @return {void}
 */
customization_Run(obj) {
	if !IsObject(obj)
		return
	for k, v in obj
	{
		k := LTrim(k, "0123456789") 	; correct key
		isf := ((k == "run") && InStr(v, "("))
		loop { 			; change %..% vars to keys
			if !(op1 := InStr(v, "%", , 1, 1)) || !(op2 := InStr(v, "%", , 1, 2))
				break
			mtch := SubStr(v, op1, op2 - op1 + 1)
			vr := SubStr(mtch, 2, -1)

			if RegExMatch(vr, "iU)^[^ `t]+\(.*\)$")
				vr := RunFunc(vr)
			else
				vr := resolveVarPath(vr)
			v := StrReplace(v, mtch, (isf ? '"' vr '"' : vr), , , 1)
		}

		if (k = "run") {
			if !InStr(v, "(")
				actionFor(v)()
			else
				ans := RunFunc(v)
		}
		else if (k = "tip")
			autoTooltip(v, 1000, 8)
		else if (k = "send")
			SendInput(RegExMatch(g := HParse(v), "[#!\^\+]") = 1 ? g : v)				; parse keys like Ctrl+Alt+k
		else if (k = "sleep")
			Sleep(v)
		else if (k != "bind") && (k != "noautorun")
			assignVarPath(k, v)
	}
}


/**
 * runs a function in a string
 * @param {string} v function string
 * @Return output of function
 */
RunFunc(v) {
; runs dynamic functions
	static rk := "ª"
	static dq := "§"

	fn := SubStr(v, 1, InStr(v, "(") - 1)
	pms := SubStr(v, InStr(v, "(") + 1, -1), ps := []
	pms := StrReplace(pms, '""', dq)
	pmsbk := Trim(pms)

	while (Trim(pmsbk) != "") {
		if (InStr(pmsbk, '"') == 1) {
			endb := InStr(pmsbk, '"', , 1, 2)
			z1 := RegExReplace(SubStr(pmsbk, 2, endb - 2), rk, ",")
			ps.Push(RegExReplace(z1, dq, '"'))
			pmsbk := SubStr(pmsbk, endb + 1) ; skip quotes
			pmsbk := Trim(pmsbk) ; ---
			pmsbk := SubStr(pmsbk, 2) ; and then comma
		} else { ; comma separated params
			endb := !InStr(pmsbk, ",") ? 10000 : InStr(pmsbk, ",")
			z1 := RegExReplace(SubStr(pmsbk, 1, endb - 1), rk, ",")
			ps.Push(z1)
			pmsbk := SubStr(pmsbk, endb + 1)
		}
	}

	; API functions
	if InStr(fn, ".") {
		str := "API:" SubStr(fn, InStr(fn, ".") + 1)
		for temp in ps
		{
			temp := StrReplace(temp, "`r`n", "`n")
			temp := StrReplace(temp, "`r", "`n")
			str .= "`r" temp
		}
		return Act_API(str, "API:")
	}
	; else normal function
	f := FuncByName(Trim(fn))
	if !f {
		errMsgBox("Unknown function: " fn)
		return ""
	}
	return f(ps*)
}


/**
 * The hotkey callback for any hotkey created in Clipjump Custom
 */
CustomHotkey(ThisHotkey, *) {
	global CUSTOMS
	customization_Run(CUSTOMS[ThisHotkey])
}
