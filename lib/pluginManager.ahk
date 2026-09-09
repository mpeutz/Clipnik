/*
Plugin management Routines
*/

pluginManagerGui(*) {
	pluginManager_GUI()
}

pluginManager_GUI(){
	global CJGUI, TXT, PROGNAME, PLUGINS, ini_defEditor
	local wt, ht, g, sb, plMenu, pad, btnW, right, lvTop
	local searchTerm, pluginMLV, btnRun, btnEdit, btnProps
	local DidDelete, selected_row, valSelected, dirNum, plugin_displayname
	wt := 680, ht := 470, pad := 14, btnW := 84
	DidDelete := 0
	selected_row := 0, valSelected := 0, dirNum := "", plugin_displayname := ""

	GuiDestroy("pluginM")
	g := Gui("+Resize +MinSize560x360", PROGNAME " " TXT.PLG__name)
	CJGUI["pluginM"] := g
	g.MarginX := pad, g.MarginY := pad
	Theme.ApplyToGui(g)
	right := wt - pad
	searchTerm := Theme.Add(g, "Edit", "x" pad " y12 w" (right - pad - 3 * (btnW + 8)) " h26 vsearchTerm -E0x200 +Border")
	searchTerm.Opt("Background" Theme.Hex("surfaceAlt"))
	SendMessage(0x1501, 1, StrPtr(TXT.PLG_search), searchTerm.Hwnd)   ; EM_SETCUEBANNER
	searchTerm.OnEvent("Change", pluginMSearch)
	btnRun := Theme.Add(g, "Button", "x" (right - 3 * btnW - 16) " y12 w" btnW " h26 Default", TXT._run)
	btnRun.OnEvent("Click", plugin_Run)
	btnEdit := Theme.Add(g, "Button", "x+8 yp w" btnW " h26", TXT.PLG_edit)
	btnEdit.OnEvent("Click", plugin_edit)
	btnProps := Theme.Add(g, "Button", "x+8 yp w" btnW " h26", TXT._properties)
	btnProps.OnEvent("Click", plugin_showprops)
	lvTop := 48
	pluginMLV := Theme.Add(g, "ListView", "x" pad " y" lvTop " w" (wt - 2 * pad) " h" (ht - lvTop - 52) " -LV0X10 vpluginMLV -Multi -E0x200 +Border", [TXT._name, TXT._tags, TXT._author, "hidden"])
	pluginMLV.Opt("Background" Theme.Hex("surface"))
	pluginMLV.OnEvent("DoubleClick", pluginMLV_Event)
	pluginM_sizeCols(wt - 2 * pad)
	updatePluginList()
	; The menu
	plMenu := Menu()
	plMenu.Add(TXT._run, plugin_Run)
	plMenu.Add()
	plMenu.Add(TXT.plg_edit, plugin_edit)
	plMenu.Add(TXT.plg_properties, plugin_showprops)
	plMenu.Add(TXT.HST_m_del, plugin_delete)
	plMenu.Default := TXT._run

	g.SetFont("s9 c" Theme.Hex("muted"))
	sb := g.Add("Text", "x" pad " y" (ht - 40) " w" (wt - 2 * pad - 90) " h28 +0x200 vpluginM_status", "")
	g.SetFont("s10 c" Theme.Hex("text"))
	Theme.Add(g, "Button", "x" (right - 76) " y" (ht - 40) " w76 h28 vpluginM_close", TXT._close).OnEvent("Click", pluginMGuiClose)
	g.OnEvent("Size", pluginMGuiSize)
	g.OnEvent("ContextMenu", pluginMGuiContextMenu)
	g.OnEvent("Escape", pluginMGuiClose)
	g.OnEvent("Close", pluginMGuiClose)
	g.Show("w" wt " h" ht)
	; the Hotkeys
	HotIfWinActive(PROGNAME " " TXT.PLG__name)
	hkZ("^f", pluginSearchfocus)
	hkZ("!d", pluginSearchfocus)
	HotIf()
	HotIf(IsPlugListViewActive)
	hkZ("Enter", plugin_Run)
	hkZ("F2", plugin_edit)
	hkZ("!Enter", plugin_showprops)
	hkZ("Del", plugin_delete)
	HotIf()
	return

	pluginM_sizeCols(w) {
		pluginMLV.ModifyCol(1, Integer(4*w/12)) , pluginMLV.ModifyCol(2, Integer(5*w/12-4)) , pluginMLV.ModifyCol(3, Integer(3*w/12) - 24) , pluginMLV.ModifyCol(4, 0)
	}

	pluginMGuiSize(gui, minMax, w, h) {
		if (minMax = -1)
			return
		r := w - pad
		searchTerm.Move(, , r - pad - 3 * (btnW + 8))
		btnRun.Move(r - 3 * btnW - 16), btnEdit.Move(r - 2 * btnW - 8), btnProps.Move(r - btnW)
		pluginMLV.Move(, , w - 2 * pad, h - lvTop - 52)
		pluginM_sizeCols(w - 2 * pad)
		sb.Move(, h - 40, w - 2 * pad - 90)
		g["pluginM_close"].Move(r - 76, h - 40)
	}

	pluginMLV_Event(*) {		; only registered for DoubleClick
		plugin_Run()
	}

	pluginSearchfocus(*) {
		try searchTerm.Focus()
	}

	plugin_Run(*) {
		if !plugin_getSelected()
			return
		filepath := PLUGINS["<>"][dirNum]["plugin_path"]
		sb.Value := TXT.PLG_sb_running " - " plugin_displayname
		ret := API.runPlugin(filepath)
		if (ret != "") && !(InStr(filepath, "external.") == 1)
			guiMsgBox(plugin_displayname " Return", ret, "pluginM")
		try sb.Value := TXT.PLG_sb_exit " - " plugin_displayname 	; the gui may have been closed while the plugin ran
		EmptyMem()
	}

	plugin_edit(*) {
		if !plugin_getSelected()
			return
		Run(ini_defEditor ' "' "plugins\" PLUGINS["<>"][dirNum]["plugin_path"] '"')
	}

	plugin_showprops(*) {
		if !plugin_getSelected()
			return
		tempObj := CJMap()
		for key, value in PLUGINS["<>"][dirNum]
			if !InStr("|#|*|silent|previewable|", "|" key "|")
				tempObj[key] := value
		ObjectEditView( tempObj, [tempObj["Name"], "pluginM", TXT._properties, (A_ScreenWidth/2)>700 ? 620 : 500] , 1  )
		EmptyMem()
	}

	plugin_delete(*) {
		if !plugin_getSelected()
			return
		if (MsgBox(TXT.PLG_delmsg "`n" plugin_displayname, "Plugin Delete", 52) = "Yes")
		{
			plugPath := "plugins\" PLUGINS["<>"][dirNum]["Plugin_path"]
			try FileDelete(plugPath)
			try DirDelete(SubStr(plugPath,1,-4) ".lib", 1) 	;remove .ahk and put .lib
			pluginMLV.Delete(valSelected)
			sb.Value := TXT.PLG_sb_deleted " - " plugin_displayname
			DidDelete := 1
		}
	}

	; returns 0 when no row is selected (v1 silently continued with blank values)
	plugin_getSelected() {
		if pluginMLV.GetNext() = 0
			valSelected := selected_row
		else valSelected := pluginMLV.GetNext()
		if !valSelected
			return 0
		dirNum := pluginMLV.GetText(valSelected, 4) , plugin_displayname := PLUGINS["<>"][dirNum]["name"]
		return 1
	}

	pluginMSearch(*) {
		updatePluginList(searchTerm.Value)
	}

	pluginMGuiContextMenu(gui, ctrl, item, isRightClick, x, y) {
		if !(ctrl is Gui.Control) || (ctrl.Name != "pluginMLV") || (pluginMLV.GetNext() = 0)
			return
		selected_row := pluginMLV.GetNext()
		plMenu.Show(x, y)
	}

	pluginMGuiClose(*) {
		GuiDestroy("pluginM")
		plMenu.Delete()
		if DidDelete {
			if (MsgBox(TXT.PLG_restartmsg, "Warning", 52) = "Yes")
				reloadClipjump()
		}
		EmptyMem()
	}

}

updatePluginList(searchTerm := "") {
	if !CJGUI.Has("pluginM")
		return
	lv := CJGUI["pluginM"]["pluginMLV"]
	lv.Delete()

	for k,v in PLUGINS
	{
		if InStr("|external|pformat|<>|", "|" k "|")
			continue
		if !updatePluginList_validate(searchTerm,v)
			continue
		lv.Add("", v.name, v.tags, v.author, v["#"])
	}
	for k,v in PLUGINS.external
	{
		if !updatePluginList_validate(searchTerm,v)
			continue
		lv.Add("", v.name, v.tags, v.author, v["#"])
	}
	for k,v in PLUGINS.pformat
	{
		if !updatePluginList_validate(searchTerm,v)
			continue
		lv.Add("", v.name, v.tags, v.author, v["#"])
	}
}

updatePluginList_validate(searchTerm, v){
	return SuperInstr(v.name " " v.tags " " v.author , Trim(searchTerm), 1)
}

;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;------------------------------------------------------ END OF GUI FUNCTIONS --------------------------------

updatePluginIncludes() {
	try FileDelete("plugins\_registry.ahk")
	st := ""
	loop files "plugins\*.ahk"
	{
		if (A_LoopFileExt != "ahk") ; for .ahk~ bk files
			continue
		if (InStr(A_LoopFileName, "external.") = 1)
			continue
		st .= "#Include *i %A_ScriptDir%\plugins\" A_LoopFileName "`n"
	}
	FileAppend(st, "plugins\_registry.ahk")
}

migratePlugins(){
	loop files "plugins\*.ahk"
	{
		if (InStr(A_LoopFileName, "external.") = 1) || (InStr(A_LoopFileName, "pformat.") = 1)
		{
			clsname := SubStr(A_LoopFileName, 1, InStr(A_LoopFileName, ".")-1)
			try FileMove("plugins\" A_LoopFileName, "plugins\" clsname "\" RegExReplace(A_LoopFileName, "i)" clsname "."), 0)
			if FileExist(lpath := "plugins\" SubStr(A_LoopFileName, 1, -3) "lib")
				try DirMove(lpath, "plugins\" clsname "\" RegExReplace( SubStr(A_LoopFileName, 1, -3), "i)" clsname "." ) "lib")
		}
	}
}

;-------------------------------------------------------------------------------------------------------------
;Loads Plugins into the Obj
;-------------------------------------------------------------------------------------------------------------

loadPlugins() {
	global PLUGINS
	PLUGINS.pformat := CJMap() , PLUGINS.external := CJMap() , PLUGINS["<>"] := CJMap()	; init 2nd level objects
	loop files "plugins\*.ahk"
	{
		if (A_LoopFileExt != "ahk")
			continue
		if (A_LoopFileName = "_registry.ahk")
			continue
		; read plugin dets
		ov := FileRead(A_LoopFileFullPath)
		p:=1 , detobj := CJMap()
		while p2:=RegExMatch(ov, "im)^;@Plugin-.*$", &m, p) {
			o := m[0]
			ps := SubStr(o, InStr(o,"-")+1) , pname := SubStr(ps, 1, InStr(ps," ")-1) , ptext := SubStr(ps, InStr(ps, " ")+1)
			p := p2+StrLen(o) , detobj[pname] .= " " ptext , detobj[pname] := Trim(detobj[pname])
		}

		filename := SubStr(A_LoopFileName, 1, -4)
		parts := StrSplit(filename, ".") , c := parts.Length 	; v1: name%A_Index% := A_LoopField
		name1 := c >= 1 ? parts[1] : "" , name2 := c >= 2 ? parts[2] : ""
		detobj["#"] := A_Index		; add unique number of <> realtive directory
		detobj["name"] := detobj.name ? detobj.name : SubStr(A_LoopFileName,1,-4) 	; add the Name of plugin
		detobj["Plugin_path"] := A_LoopFileName
		; and * stores the path of plugin
		if c>1
		{
			if (name1 = "external")
				detobj["*"] := "plugins\external." name2 ".ahk" , PLUGINS["external"][name2] := detobj.Clone()
				, PLUGINS["<>"][A_Index] := detobj.Clone()
			else if (name1 = "pformat")
			{
				detobj["*"] := "plugin_pformat_" name2
				If HasFuncByName(detobj["*"]) 				; If function exists i.e. is included
					PLUGINS["pformat"][name2] := detobj.Clone() , PLUGINS["<>"][A_Index] := detobj.Clone()
			}
		}
		else {
			detobj["*"] := "plugin_" name1
			if HasFuncByName(detobj["*"])
				PLUGINS[name1] := detobj.Clone() , PLUGINS["<>"][A_Index] := detobj.Clone()
		}
	}
	; -- set def pformat
	set_pformat()
}

;///////////////////////// MORE LOW END GUI FUNCTIONS ///////////////////////////////////////////////////////////////////

IsPlugListViewActive(*){
	return IsActive("SysListView321", "classnn") && IsActive(PROGNAME " " TXT.PLG__name, "window") && ctrlRef==""
}
