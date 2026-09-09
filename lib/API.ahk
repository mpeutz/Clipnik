; Plugin API for Clipjump

/**
 * run a api function in the string given
 * @param {string} D string with the function call
 * @param {string} k api prefix, here 'api:'
 */
Act_API(D, k) {
	static cbF := A_Temp "\cjcb.txt"
	static rFuncs := "|getClipAt|getClipLoc|getVar|runFunction|getClipDataByTag"
	static resChar := "`r"

	fname := SubStr(D, l := StrLen(k) + 1, (InStr(D, resChar) ? InStr(D, resChar) : StrLen(D) + 1) - l)
	p := Trim(SubStr(D, InStr(D, resChar) ? InStr(D, resChar) + 1 : 2000000))
	ps := []
	if (p != "")
		loop parse p, resChar
			ps.Push(A_LoopField)

	r := API.%fname%(ps*)

	if InStr(rFuncs, "|" fname "|")
		FileAppend(r, cbF)
	return r
}


/**
 * API Class
 * includes all methods accessible through the api (all static, called as API.method())
 */
class API
{
	; pastes clips from certain postion in certain channel
	; if both are blank, paste 1st clip from currently active channel
	static paste(channel := "", clipno := "") {
		global IsCurCBActive, CLIPS_dir, TEMPSAVE
		this.blockMonitoring(1)
		if (channel = "") && (clipno = "") {
			if !IsCurCBActive
				try A_Clipboard := ClipFileRead(A_WorkingDir "\" CLIPS_dir "\" TEMPSAVE ".avc")
		}
		else {
			r := this.getClipLoc(channel, clipno)
			try_ClipboardFromFile(r, 10)
		}

		Send("^{vk56}")
		this.blockMonitoring(0)
	}

	; get Clip content
	; toreturn = 1 < return Clipboard text data >
	; toreturn = 2 < return ClipboardAll binary data >
	static getClipAt(channel := 0, clipno := 1, toreturn := 1, &err := "") {
		global CDS
		if (toreturn = 1)
			ret := CDS[channel][this.getChStrength(channel) - clipno + 1]
		else {
			this.blockMonitoring(1)
			r := this.getClipLoc(channel, clipno)
			try A_Clipboard := ClipFileRead(r)
			err := GetClipboardFormat() = "" ? 0 : 1
			ret := ClipboardAll()
			this.blockMonitoring(0)
		}
		return ret
	}

	; 0 = cut , 1 = copy
	; if channel is empty, active channel is used
	; if clip is empty, active clip in paste mode (Clip x of y, "x") is used.
	static manageClip(new_channel := 0, channel := "", clip := "", flag := 0) {
		global CN, CDS, CPS, CURSAVE, TEMPSAVE, IsCurCBActive
		if (channel = "")
			channel := CN.NG
		c_info := this.getChInfo(channel)
		if (clip = "")
			clip := c_info.realTEMPSAVE
		else
			clip := c_info.realCURSAVE - clip + 1
		nc_info := this.getChInfo(new_channel)

		origClip := "cache\clips" c_info.p "\" clip ".avc", origThumb := "cache\thumbs" c_info.p "\" clip ".jpg"
		newClip := "cache\clips" nc_info.p "\" (nc_info.realCURSAVE + 1) ".avc"
		newThumb := "cache\thumbs" nc_info.p "\" (nc_info.realCURSAVE + 1) ".jpg"

		; process
		if flag
		{
			FileTransfer(origClip, newClip), FileTransfer(origThumb, newThumb)
			CDS[new_channel][nc_info.realCURSAVE + 1] := CDS[channel][clip]
			CPS[new_channel][nc_info.realCURSAVE + 1] := CPS[channel][clip]
			manageFIXATE(nc_info.realCURSAVE + 1, new_channel, nc_info.p)
		}
		else
		{
			FileTransfer(origClip, newClip, 0), FileTransfer(origThumb, newThumb, 0)
			CPS[new_channel][nc_info.realCURSAVE + 1] := CPS[channel][clip], CPS[channel].Remove(clip) ; .remove() auto adjusts cavities in array
			CDS[new_channel][nc_info.realCURSAVE + 1] := CDS[channel][clip], CDS[channel].Remove(clip)
			c_Folder1 := "cache\clips" c_info.p "\", c_Folder2 := "cache\thumbs" c_info.p "\"
			loop c_info.realCURSAVE - clip
			{
				try FileMove(c_Folder1 (clip + A_Index) ".avc", c_Folder1 (clip + A_Index - 1) ".avc", 1)
				try FileMove(c_Folder2 (clip + A_Index) ".jpg", c_Folder2 (clip + A_Index - 1) ".jpg", 1)
			}

			if (new_channel == channel) {
				ClipTransfer(c_info.p, nc_info.realCURSAVE + 1, c_info.p, nc_info.realCURSAVE, 0)
				; no need for changing arr as .remove() handles it
				return
			}
			manageFIXATE(nc_info.realCURSAVE + 1, new_channel, nc_info.p)
			IsCurCBActive := 0
		}
		; fix vars
		CN["CURSAVE" nc_info.p] += 1
		if nc_info.isactive
			CURSAVE += 1 	; also cursave if it is active

		if !flag
		{
			CN["CURSAVE" c_info.p] -= 1
			CN["TEMPSAVE" c_info.p] -= (CN["TEMPSAVE" c_info.p] > CN["CURSAVE" c_info.p]) ? 1 : 0 	; if the 29th file of 29 files was deleted and 29 was active
			if c_info.isactive
				CURSAVE -= 1, TEMPSAVE -= (TEMPSAVE > CURSAVE) ? 1 : 0
		}
		return
	}

	; if channel no is empty, it DEFAULTS to current channel
	; you can also use name of a channel > like API.emptyChannel("web")
	static emptyChannel(chno := "") {
		global CN, CDS, CPS, CURSAVE, TEMPSAVE, LASTCLIP
		if (chno = "")
			chno := CN.NG
		if !IsInteger(chno)
			chno := channel_find(chno)
		CDS[chno] := CJMap(), CPS[chno] := CJMap()
		f := this.getChInfo(chno)
		try FileDelete("cache\clips" f.p "\*.avc")
		try FileDelete("cache\thumbs" f.p "\*.jpg")
		try FileDelete("cache\clips" f.p "\prefs.ini")
		CN["CURSAVE" f.p] := CN["TEMPSAVE" f.p] := 0
		if f.isactive
			CURSAVE := TEMPSAVE := 0, LASTCLIP := ""
	}

	;runs a plugin
	; filename - filename of plugin with .ahk . Example > pformat.noformatting.ahk
	; parameters - if no parameter is passed, function itself obtains them.
	static runPlugin(filename, parameters*) {
		global PLUGINS, TXT
		fpath := "", plugin_displayname := "", dirNum := "", Silent := ""
		for k, v in PLUGINS["<>"]
		{
			if (v["plugin_path"] == filename) {
				fpath := v["*"], plugin_displayname := v["name"], dirNum := v["#"], Silent := v["silent"]
				break
			}
		}
		; run
		if FileExist(fpath) {
			params := ""
			if !parameters.Length && !Silent {
				loop 3
					if PLUGINS["<>"][dirNum].HasKey("param" A_Index) {
						ib := InputBox(PLUGINS["<>"][dirNum]["param" A_Index], "Plugin " plugin_displayname, "w500")
						if (ib.Result = "OK")
							params .= ' "' ib.Value '"' 	;if OK
						else
							return
					}
					else
						break
			} else {
				for k, v in parameters
					params .= ' "' v '"'
			}

			try Run(A_AhkPath ' "' A_WorkingDir "\" fpath '"' params)
			catch
				MsgBox(TXT.API_extPlugMiss . "`n" fpath, "Error", 16)
		}
		else {
			if !HasFuncByName(fpath) {
				MsgBox(TXT.API_plugCorrupt "`n" plugin_displayname, "Error", 16)
				return
			}
			; else execute
			funcps := ""
			if !parameters.Length && !Silent {
				funcobj := FuncByName(fpath)
				loop funcobj.MaxParams
				{
					prompt := PLUGINS["<>"][dirNum]["param" A_Index]
					if (prompt = "")
						prompt := "#" A_Index " " TXT.PLG_fetchparam
					ib := InputBox(prompt, "Plugin " plugin_displayname, "w500")
					if (ib.Result = "OK")
						funcps .= RegExReplace(ib.Value, ",", "ª") ","
					else
						return
				}
			} else {
				for k, v in parameters
					funcps .= RegExReplace(v, ",", "ª") ","
			}
			ret := runfunc(fpath "(" RTrim(funcps, ",") ")")
			return ret
		}
	}

	; shows paste mode tooltip with search at the passed channel and clip posn
	static showPasteTipAt(ch, cl, x := "", y := "") {
		global CN, CURSAVE, TEMPSAVE, SPM
		_tmpsv := TEMPSAVE, _cnl := CN.NG, _cursv := CURSAVE
		CN["CURSAVE" CN.N] := CURSAVE, CN["TEMPSAVE" CN.N] := TEMPSAVE 	; load all values in CN obj
		v := API.getChStrength(ch) - cl + 1
		changeChannel(ch, 0)
		TEMPSAVE := v
		SPM.ACTIVE := 1
		SPM.X := x, SPM.Y := y
		paste()
		searchpm()
		SPM.TEMPSAVE := _tmpsv
		SPM.Channel := _cnl
	}

	; returns the contents of first element with tag
	static getClipDataByTag(tag) {
		robj := this.getClipByTag(tag)
		for k, v in robj
			return this.getClipAt(v[1], v[2])
	}

	; returns an array of clips which have the tag
	; RETURN
	; channel at index 0 and clip at 1
	; example - [ [0,1] , [0,2] ]
	static getClipByTag(tag) {
		global CPS
		robj := []
		for k, v in CPS
		{
			mindex := this.getChStrength(k)
			for k2, item in v
				if IsObject(item) && InStr(" " Trim(item["Tags"]) " ", " " tag " ")
					robj.Push([k, mindex - k2 + 1])
		}
		return robj
	}

	; runs any other function like choosechannelgui() , changeChannel()
	static runFunction(funcString) {
		return runFunc(funcString)
	}

	; runs the Label (v1 label names resolve through the ACTIONS map)
	static runLabel(label) {
		actionFor(label)()
	}

	; gets total no of clips in a channel
	static getChStrength(channel) {
		o := API.getChInfo(channel)
		return o.realCURSAVE
	}

	; deletes a clip
	static deleteClip(channel, clip) {
		global CN, CURSAVE, TEMPSAVE
		Critical "On"
		if (channel = "") || (clip = "")
			return 0
		zbkCh := CN.NG, zbkClip := TEMPSAVE	; create backup of current channel
		CN["CURSAVE" CN.N] := CURSAVE, CN["TEMPSAVE" CN.N] := TEMPSAVE
		changeChannel(channel)
		clearClip(API.getChStrength(channel) - clip + 1)
		changeChannel(zbkCh)
		;if (channel != zbkCh)  ; this was bcuz when clip from channel that was already active was deleted, tempsave can get invalid
			TEMPSAVE := zbkClip
		return 1
	}

	; adds clip to a chanel
	; input = the string that is created as a new clip
	; isbinary = 1 - makes the function take 'input' as binary (a ClipboardAll object)
	static addClip(channel, input, isbinary := 0) {
		global CN, CDS, CURSAVE
		cInfo := API.getChInfo(channel)
		if isbinary {
			ret := input
			input := this.Binary2Text(ret)
		}
		else
			API.Text2Binary(input, &ret)
		FileAppend(ret, "cache\clips" cInfo.p "\" (cInfo.realCURSAVE + 1) ".avc")
		CDS[channel][cInfo.realCURSAVE + 1] := input
		manageFIXATE(cInfo.realCURSAVE + 1, channel, cInfo.p)
		CN["CURSAVE" cInfo.p] += 1
		if cInfo.isactive
			CURSAVE += 1 	; also cursave if it is active
	}

	; sets a variable (supports obj.key and obj.key.key2 paths)
	static setVar(var, value) {
		value := valueOf(value)
		if InStr(var, ".") {
			parts := StrSplit(var, ".")
			target := VarGet(Trim(parts[1]))
			if !IsObject(target)
				return
			loop parts.Length - 2
				target := target[Trim(parts[A_Index + 1])]
			target[Trim(parts[parts.Length])] := value
		}
		else
			VarSet(var, value)
	}

	;gets a variable value
	static getVar(var) {
		return valueOf("%" var "%")
	}

	; EXecute a section in the ClipjumpCustom.ini
	static ExecuteSection(secName) {
		global CUSTOMS
		customization_Run(CUSTOMS["_" secName])
	}

	; p=1 enable incognito mode
	static IncognitoMode(p := 1) {
		global NOINCOGNITO
		NOINCOGNITO := p  		; make it the opp as incognito: will change the sign
		incognito()
	}

	; get Clips file location
	static getClipLoc(channel := "", clipno := "") {
		global CN, CURSAVE
		if (channel = "")
			channel := CN.NG
		if (clipno = "")
			clipno := 1
		p := !channel ? "" : channel
		z := (CN.NG == channel) ? CURSAVE : CN["CURSAVE" p] 		;chnl CURSAVE is not updated everytime but when channel is changed.
		f := A_WorkingDir "\cache\clips" p "\" (z - clipno + 1) ".avc"
		return FileExist(f) ? f : ""
	}

	;disable Clipjump - status=1 means disable , status=-1 means toggle
	static disable(status := 1) {
		global CLIPJUMP_STATUS
		status .= ""
		if (status == "-1")
			disable_clipjump()
		else if (status == "1" && CLIPJUMP_STATUS)
			disable_clipjump()
		else if (status == "0" && !CLIPJUMP_STATUS)
			disable_clipjump()
	}

	;blocks CB monitoring
	static blockMonitoring(yes := 1, sleeptime := 10) {
		global CALLER, ONCLIPBOARD, CALLER_STATUS
		Critical "Off" 		; necessary to let onclipboard break process if needed
		if yes
		{
			CALLER := 0, ONCLIPBOARD := ""
			while CALLER
				Sleep sleeptime
		} else {
			while !ONCLIPBOARD
			{
				Sleep sleeptime
				if (sleeptime * A_Index) > 1000
					break
			}
			CALLER := CALLER_STATUS
		}
	}

	;pastes the given text without copying it to clipjump
	static pasteText(Text) {
		this.blockMonitoring(1)
		oldclip := ""
		try oldclip := ClipboardAll()
		A_Clipboard := Text
		this.blockMonitoring(0), this.blockMonitoring(1) 	;2 times cb change, so reset onclipboard var
		Sleep 100
		Send("^{vk56}")
		Sleep 100
		try A_Clipboard := oldclip
		this.blockMonitoring(0)
	}

	;gets binary ClipboardAll data from simple text
	; Text = the string you want to convert to ClipboardAll
	; returnVar = byref variable to return ClipboardAll data
	static Text2Binary(Text, &returnVar) {
		this.blockMonitoring(1)
		try {
			oldclip := ClipboardAll()
			A_Clipboard := Text
			this.blockMonitoring(0), this.blockMonitoring(1)
			returnVar := ClipboardAll()
			A_Clipboard := oldclip
			err := 0
		}
		catch
			err := 1
		this.blockMonitoring(0)
		return err
	}

	;Tooltip for plugins
	static showTip(Text, forTime := "") {
		if forTime
			autoTooltip(Text, forTime, 7)
		else
			ToolTip(Text, , , 7)
	}

	; removes the above tip
	static removeTip() {
		ToolTip(, , , 7)
	}

	; get the text from a ClipboardAll binary
	static Binary2Text(binary) {
		this.blockMonitoring(1)
		try A_Clipboard := binary
		out := tryGetClipboard()
		this.blockMonitoring(0)
		return out
	}

	;------------------------
	;---- API HELPER FUNCS --
	;------------------------


	; returns obj full of channel information data
	; ret=0 returns string
	static getChInfo(c := "", ret := 1) {
		global CN, CURSAVE, TEMPSAVE
		if (c = "")
			c := CN.NG
		o := CJMap()
		if (CN.NG == c)
			o.isactive := 1
		o.p := p := !c ? "" : c
		o.realCURSAVE := o.isactive ? CURSAVE : CN["CURSAVE" p], o.channelCURSAVE := CN["CURSAVE" p]
		o.realTEMPSAVE := o.isactive ? TEMPSAVE : CN["TEMPSAVE" p], o.channelTEMPSAVE := CN["TEMPSAVE" p]
		if ret
			return o
		; make string
		str := ""
		for k, v in o
			str .= k "`t" v "`n"
		return str
	}
}
