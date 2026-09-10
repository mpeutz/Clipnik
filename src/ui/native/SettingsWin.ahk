; SettingsWin.ahk - the Settings window: left navigation, one page per topic, OK / Cancel / Apply.
;
;   SettingsWin.Open()        show the window (creates it on first use)
;   SettingsWin.Close()
;
; Values live in the controls until OK or Apply collects them (SettingsWin.Collect) and hands the Map to
; save_Settings() in src/core/settings.ahk. Every control is created once; pages are shown by toggling
; visibility. Overlapping static controls do not repaint reliably, so the navigation column is tiled from
; non-overlapping Text controls instead of layering items over a panel.

class SettingsWin {
	static g := ""
	static c := Map()             ; value controls by key
	static pages := Map()         ; page id -> Array of controls
	static order := ["general", "history", "shortcuts", "channels", "appearance", "advanced"]
	static nav := Map()           ; page id -> {label, bar}
	static current := ""
	static dirty := false
	static anchored := []         ; [ctl, mode, arg]  mode: right | stretch | footer | navfill
	static building := ""
	static y := 0
	static hotkeyVals := Map()    ; key -> AHK hotkey string behind a recorder field
	static rec := ""              ; active InputHook
	static recKey := ""
	static recMods := Map()       ; modifier vk -> down, tracked from the hook events themselves
	static wasSuspended := 0
	static NavW := 184, Pad := 24, FooterH := 52, RowH := 32, CheckH := 28, ItemH := 36, W := 760, H := 588
	static suppress := false      ; true while controls are being filled programmatically
	static listening := false

	static Open() {
		if (SettingsWin.g && !GuiAlive(SettingsWin.g))
			SettingsWin.Close()                 ; the window went away without us (owner closed, external destroy)
		if SettingsWin.g {
			SettingsWin.g.Show()
			try WinActivate(SettingsWin.g.Hwnd)
			return
		}
		SettingsWin.Build()
	}

	static Close() {
		SettingsWin.StopRecording()
		if SettingsWin.g
			try SettingsWin.g.Destroy()
		SettingsWin.g := "", SettingsWin.c := Map(), SettingsWin.pages := Map(), SettingsWin.nav := Map()
		SettingsWin.anchored := [], SettingsWin.hotkeyVals := Map(), SettingsWin.dirty := false
		EmptyMem()
	}

	; ---------- window ----------

	static Build() {
		global PROGNAME, TXT
		g := Gui("+Resize +MinSize720x520", PROGNAME " " TXT.SET__name)
		SettingsWin.g := g
		g.MarginX := 0, g.MarginY := 0
		Theme.ApplyToGui(g)
		g.BackColor := Theme.Hex("surface")
		g.OnEvent("Close", (*) => SettingsWin.Cancel())
		g.OnEvent("Escape", (*) => SettingsWin.Cancel())
		g.OnEvent("Size", SettingsWin_OnSize)
		SettingsWin.BuildNav()
		SettingsWin.BuildFooter()
		SettingsWin.BuildGeneral()
		SettingsWin.BuildHistory()
		SettingsWin.BuildShortcuts()
		SettingsWin.BuildChannels()
		SettingsWin.BuildAppearance()
		SettingsWin.BuildAdvanced()
		for id in SettingsWin.order
			SettingsWin.SetPageVisible(id, false)
		SettingsWin.ShowPage(SettingsWin.current ? SettingsWin.current : "general")
		SettingsWin.SetDirty(false)
		g.Show("w" SettingsWin.W " h" SettingsWin.H)
		if !SettingsWin.listening {
			SettingsWin.listening := true
			Theme.OnChange(SettingsWin_OnTheme)
		}
	}

	; Edit with the field background of the mockups
	static Field(opts, text := "") {
		ctl := Theme.Add(SettingsWin.g, "Edit", opts " -E0x200 +Border", text)
		ctl.Opt("Background" Theme.Hex("surfaceAlt"))
		return ctl
	}

	static Tile(x, y, w, h, color := "") {
		ctl := SettingsWin.g.Add("Text", "x" x " y" y " w" w " h" h " Background" (color ? color : Theme.Hex("bg")), "")
		return ctl
	}

	static BuildNav() {
		global TXT
		g := SettingsWin.g
		navW := SettingsWin.NavW, itemH := SettingsWin.ItemH
		titles := Map("general", TXT.SET_general, "history", TXT.SET_cb, "shortcuts", TXT.SET_shortcuts, "channels", TXT.SET_channels, "appearance", TXT.SET_appearance, "advanced", TXT.SET_advancedPage)
		icons := Map("general", "settings", "history", "history", "shortcuts", "keyboard", "channels", "layout-grid", "appearance", "palette", "advanced", "sliders-horizontal")
		hasIcons := Theme.HasIcons()
		y := 0
		SettingsWin.Tile(0, 0, navW, 8)                                      ; top pad
		y := 8
		for id in SettingsWin.order {
			SettingsWin.Tile(0, y, 8, itemH)                                 ; left pad
			SettingsWin.Tile(8, y, 3, 10)
			bar := g.Add("Progress", "x8 y" (y + 10) " w3 h16 -Theme Background" Theme.Hex("bg") " c" Theme.Hex("bg"), 100)
			SettingsWin.Tile(8, y + 26, 3, 10)
			icon := ""
			if hasIcons {
				g.SetFont("s12 c" Theme.Hex("text"), Theme.IconFont)
				icon := g.Add("Text", "x11 y" y " w34 h" itemH " +0x200 +0x100 +Center Background" Theme.Hex("bg"), Theme.Icon(icons[id]))
				icon.OnEvent("Click", SettingsWin_NavClick.Bind(id))
				g.SetFont("s10 norm c" Theme.Hex("text"), Theme.FontName)
			}
			lx := hasIcons ? 45 : 11
			label := g.Add("Text", "x" lx " y" y " w" (navW - 8 - lx) " h" itemH " +0x200 +0x100 Background" Theme.Hex("bg"), (hasIcons ? "" : "   ") titles[id])
			label.OnEvent("Click", SettingsWin_NavClick.Bind(id))
			SettingsWin.Tile(navW - 8, y, 8, itemH)                          ; right pad
			SettingsWin.nav[id] := {label: label, bar: bar, icon: icon}
			y += itemH
			SettingsWin.Tile(0, y, navW, 2)                                  ; gap
			y += 2
		}
		fill := SettingsWin.Tile(0, y, navW, 100)
		SettingsWin.anchored.Push([fill, "navfill", y])
	}

	static BuildFooter() {
		global TXT
		g := SettingsWin.g
		fy := SettingsWin.H - SettingsWin.FooterH
		rule := g.Add("Progress", "x" SettingsWin.NavW " y" fy " w" (SettingsWin.W - SettingsWin.NavW) " h1 -Theme Background" Theme.Hex("border") " c" Theme.Hex("border"), 100)
		SettingsWin.anchored.Push([rule, "footer", {x: SettingsWin.NavW, stretch: true, dy: 0}])
		link := Theme.AddLink(g, "x" (SettingsWin.NavW + SettingsWin.Pad) " y" (fy + 16) " h20 +0x200", TXT.SET_openFolder, (*) => Run('explorer.exe "' A_WorkingDir '"'))
		SettingsWin.anchored.Push([link, "footer", {x: SettingsWin.NavW + SettingsWin.Pad, dy: 16}])
		ok := Theme.Add(g, "Button", "x0 y" (fy + 12) " w76 h28 Default", "OK")
		ok.OnEvent("Click", (*) => SettingsWin.Ok())
		btnCancel := Theme.Add(g, "Button", "x0 y" (fy + 12) " w76 h28", TXT.SET_cancel)
		btnCancel.OnEvent("Click", (*) => SettingsWin.Cancel())
		apply := Theme.Add(g, "Button", "x0 y" (fy + 12) " w76 h28", TXT.SET_apply)
		apply.OnEvent("Click", (*) => SettingsWin.Apply())
		SettingsWin.c["btnApply"] := apply, SettingsWin.c["btnOk"] := ok
		SettingsWin.anchored.Push([ok, "footer", {right: 3 * 76 + 2 * 8 + SettingsWin.Pad, dy: 12}])
		SettingsWin.anchored.Push([btnCancel, "footer", {right: 2 * 76 + 8 + SettingsWin.Pad, dy: 12}])
		SettingsWin.anchored.Push([apply, "footer", {right: 76 + SettingsWin.Pad, dy: 12}])
	}

	; ---------- page building helpers ----------

	static ContentX() => SettingsWin.NavW + SettingsWin.Pad
	static ContentRight() => SettingsWin.W - SettingsWin.Pad
	static ContentW() => SettingsWin.ContentRight() - SettingsWin.ContentX()

	static PageStart(id, title) {
		g := SettingsWin.g
		SettingsWin.building := id
		SettingsWin.pages[id] := []
		g.SetFont("s14 bold c" Theme.Hex("text"), Theme.FontName)
		SettingsWin.Reg(g.Add("Text", "x" SettingsWin.ContentX() " y20 w" SettingsWin.ContentW() " h28 +0x200", title), "stretch")
		g.SetFont("s10 norm c" Theme.Hex("text"), Theme.FontName)
		SettingsWin.y := 56
	}

	static Reg(ctl, mode := "", arg := "") {
		SettingsWin.pages[SettingsWin.building].Push(ctl)
		if mode
			SettingsWin.anchored.Push([ctl, mode, arg])
		return ctl
	}

	static Section(text) {
		SettingsWin.y += 6
		parts := Theme.Section(SettingsWin.g, SettingsWin.ContentX(), SettingsWin.y, SettingsWin.ContentW(), text)
		SettingsWin.Reg(parts[1], "stretch"), SettingsWin.Reg(parts[2], "stretch")
		SettingsWin.y += 28
	}

	; label (+ optional hint below it) on the left; returns the y of the row so a control can be placed on the right
	static Label(text, hint := "") {
		g := SettingsWin.g
		x := SettingsWin.ContentX(), y := SettingsWin.y
		if (hint = "") {
			SettingsWin.Reg(g.Add("Text", "x" x " y" y " w300 h" SettingsWin.RowH " +0x200", text))
			return y
		}
		SettingsWin.Reg(g.Add("Text", "x" x " y" (y + 2) " w300 h18", text))
		g.SetFont("s9 c" Theme.Hex("muted"))
		SettingsWin.Reg(g.Add("Text", "x" x " y" (y + 20) " w300 h16", hint))
		g.SetFont("s10 c" Theme.Hex("text"))
		return y
	}

	static EndRow(extra := 0) {
		SettingsWin.y += SettingsWin.RowH + extra
	}

	static Check(key, text, checked, hint := "", tip := "") {
		g := SettingsWin.g
		x := SettingsWin.ContentX(), y := SettingsWin.y
		ctl := Theme.Add(g, "CheckBox", "x" x " y" y " h" SettingsWin.CheckH " Checked" (checked ? 1 : 0), text)
		ctl.OnEvent("Click", SettingsWin_Changed)
		SettingsWin.Reg(ctl)
		SettingsWin.c[key] := ctl
		if hint {
			ctl.GetPos(, , &cw)
			g.SetFont("s9 c" Theme.Hex("muted"))
			SettingsWin.Reg(g.Add("Text", "x" (x + cw + 6) " y" y " h" SettingsWin.CheckH " +0x200", hint))
			g.SetFont("s10 c" Theme.Hex("text"))
		}
		Theme.Tip(ctl, tip)
		SettingsWin.y += SettingsWin.CheckH
		return ctl
	}

	static Spinner(key, text, value, range, hint := "", tip := "") {
		g := SettingsWin.g
		y := SettingsWin.Label(text, hint)
		w := 60, udw := 20
		ctl := SettingsWin.Field("x" (SettingsWin.ContentRight() - w - udw) " y" (y + 4) " w" w " h24 Number", value)
		ud := Theme.Add(g, "UpDown", "x" (SettingsWin.ContentRight() - udw) " y" (y + 4) " w" udw " h24 -16 Range" range, value)
		ctl.OnEvent("Change", SettingsWin_SpinEdit.Bind(ud))
		ud.OnEvent("Change", SettingsWin_SpinButton.Bind(ctl))
		SettingsWin.Reg(ctl, "right", w + udw), SettingsWin.Reg(ud, "right", udw)
		SettingsWin.c[key] := ctl
		Theme.Tip(ctl, tip)
		SettingsWin.EndRow(hint ? 8 : 0)
		return ctl
	}

	static Ddl(key, text, items, choose, hint := "", tip := "", w := 180) {
		g := SettingsWin.g
		y := SettingsWin.Label(text, hint)
		ctl := Theme.Add(g, "DDL", "x" (SettingsWin.ContentRight() - w) " y" (y + 4) " w" w " Choose" choose, items)
		ctl.OnEvent("Change", SettingsWin_Changed)
		SettingsWin.Reg(ctl, "right", w)
		SettingsWin.c[key] := ctl
		Theme.Tip(ctl, tip)
		SettingsWin.EndRow(hint ? 8 : 0)
		return ctl
	}

	static EditRow(key, text, value, w := 220, hint := "", tip := "", opts := "") {
		g := SettingsWin.g
		y := SettingsWin.Label(text, hint)
		ctl := SettingsWin.Field("x" (SettingsWin.ContentRight() - w) " y" (y + 4) " w" w " h24 " opts, value)
		ctl.OnEvent("Change", SettingsWin_Changed)
		SettingsWin.Reg(ctl, "right", w)
		SettingsWin.c[key] := ctl
		Theme.Tip(ctl, tip)
		SettingsWin.EndRow(hint ? 8 : 0)
		return ctl
	}

	; read-only field that records a hotkey while it has the focus
	static HotkeyRow(key, text, value, hint := "", tip := "") {
		global TXT
		g := SettingsWin.g
		y := SettingsWin.Label(text, hint)
		w := 180
		ctl := SettingsWin.Field("x" (SettingsWin.ContentRight() - w) " y" (y + 4) " w" w " h24 +ReadOnly", "")
		SettingsWin.Reg(ctl, "right", w)
		SettingsWin.c[key] := ctl
		SettingsWin.hotkeyVals[key] := value
		SettingsWin.ShowHotkey(key)
		ctl.OnEvent("Focus", SettingsWin_RecFocus.Bind(key))
		ctl.OnEvent("LoseFocus", SettingsWin_RecBlur)
		Theme.Tip(ctl, tip ? tip : TXT.SET_T_record)
		SettingsWin.EndRow(hint ? 8 : 0)
		return ctl
	}

	static ShowHotkey(key, recording := false) {
		global TXT
		ctl := SettingsWin.c[key]
		v := SettingsWin.hotkeyVals[key]
		if recording
			ctl.SetFont("c" Theme.Hex("accent")), ctl.Value := TXT.SET_pressKeys
		else if (v = "")
			ctl.SetFont("c" Theme.Hex("muted")), ctl.Value := TXT.SET_clickToRecord
		else
			ctl.SetFont("c" Theme.Hex("text")), ctl.Value := HParse_Rev(v)
		ctl.Redraw()
	}

	static ButtonRow(text, btnText, fn, hint := "") {
		g := SettingsWin.g
		y := SettingsWin.Label(text, hint)
		btn := Theme.Add(g, "Button", "x0 y" (y + 2) " h28", btnText)
		btn.GetPos(, , &bw)
		bw += 16
		btn.Move(SettingsWin.ContentRight() - bw, , bw)
		btn.OnEvent("Click", fn)
		SettingsWin.Reg(btn, "right", bw)
		SettingsWin.EndRow(hint ? 8 : 0)
		return btn
	}

	; ---------- pages ----------

	static PformatList(&sel) {
		global PLUGINS, ini_def_pformat
		lst := ["-original-"]
		sel := 1
		for k, v in PLUGINS.pformat {
			lst.Push(v["Name"])
			if (ini_def_pformat == v["Name"])
				sel := lst.Length
		}
		return lst
	}

	static BuildGeneral() {
		global TXT, ini_limitMaxClips, ini_MaxClips, ini_Threshold, ini_startSearch, ini_PreserveClipPos, ini_revFormat2def
		global ini_KeepSession, ini_monitorClipboard, ini_respectExclusion
		SettingsWin.PageStart("general", TXT.SET_general)
		SettingsWin.Section(TXT.SET_sec_clipboards)
		chk := SettingsWin.Check("limitMaxClips", TXT.SET_limitmaxclips, ini_limitMaxClips, , TXT.SET_T_limitmaxclips)
		chk.OnEvent("Click", SettingsWin_LimitClick)
		SettingsWin.Spinner("MaxClips", TXT.SET_maxclips, ini_limitMaxClips ? ini_MaxClips : 20, "1-1000", , TXT.SET_T_maxclips)
		SettingsWin.Spinner("Threshold", TXT.SET_threshold, ini_Threshold, "1-1000", TXT.SET_thresholdHint, TXT.SET_T_threshold)
		SettingsWin.c["MaxClips"].Enabled := ini_limitMaxClips ? true : false
		SettingsWin.c["Threshold"].Enabled := ini_limitMaxClips ? true : false
		SettingsWin.Section(TXT.SET_sec_pastemode)
		SettingsWin.Check("startSearch", TXT.SET_startSearch, ini_startSearch, , TXT.SET_T_startSearch)
		SettingsWin.Check("PreserveClipPos", TXT.SET_keepactivepos, ini_PreserveClipPos, , TXT.SET_T_keepactivepos)
		SettingsWin.Check("revFormat2def", TXT.SET_revFormat2def, ini_revFormat2def, , TXT.SET_T_revFormat2def)
		lst := SettingsWin.PformatList(&sel)
		SettingsWin.Ddl("default_pformat", TXT.SET_pformat, lst, sel, , TXT.SET_T_pformat)
		SettingsWin.Section(TXT.SET_sec_capture)
		SettingsWin.Check("monitorClipboard", TXT.SET_monitorClipboard, ini_monitorClipboard, TXT.SET_monitorHint, TXT.SET_T_monitorClipboard)
		SettingsWin.Check("KeepSession", TXT.SET_keepsession, ini_KeepSession, , TXT.SET_T_keepsession)
		SettingsWin.Check("respectExclusion", TXT.SET_respectExclusion, ini_respectExclusion, TXT.SET_exclusionHint, TXT.SET_T_respectExclusion)
	}

	static BuildHistory() {
		global TXT, ini_DaysToStore, ini_IsImageStored, ini_Quality, history_partial, ini_HisCloseOnInstaPaste, ini_instapasteWritesClipboard
		SettingsWin.PageStart("history", TXT.SET_cb)
		SettingsWin.Spinner("DaysToStore", TXT.SET_daystostore, ini_DaysToStore, "0-100000", TXT.SET_daysHint, TXT.SET_T_daystostore)
		SettingsWin.Check("IsImageStored", TXT.SET_images, ini_IsImageStored, , TXT.SET_T_images)
		SettingsWin.Spinner("Quality", TXT.SET_quality, ini_Quality, "1-100", TXT.SET_qualityHint, TXT.SET_T_quality)
		SettingsWin.Section(TXT.SET_sec_historyWindow)
		SettingsWin.Check("history_partial", TXT.SET_partial, history_partial)
		SettingsWin.Check("HisCloseOnInstaPaste", TXT.SET_closeOnInstaPaste, ini_HisCloseOnInstaPaste)
		SettingsWin.Check("instapasteWritesClipboard", TXT.SET_instapasteWritesClipboard, ini_instapasteWritesClipboard)
	}

	static BuildShortcuts() {
		global TXT, paste_K, Actionmode_K, history_k, chOrg_K, Copyfilepath_K, Copyfolderpath_K, Copyfiledata_K, holdClip_K, pluginManager_K, onetime_K, pstKeyName
		g := SettingsWin.g
		SettingsWin.PageStart("shortcuts", TXT.SET_shortcuts)
		; paste mode: modifier badge + single character
		y := SettingsWin.Label(TXT.SET_pasteMode, TXT.SET_pasteModeHint)
		w := 48, bw := 56
		g.SetFont("s8 c" Theme.Hex("text"))
		badge := g.Add("Text", "x" (SettingsWin.ContentRight() - w - 8 - bw) " y" (y + 6) " w" bw " h20 +0x200 +Center Background" Theme.Hex("surfaceAlt"), pstKeyName " +")
		g.SetFont("s10 c" Theme.Hex("text"))
		SettingsWin.Reg(badge, "right", w + 8 + bw)
		SettingsWin.c["pasteBadge"] := badge
		pst := SettingsWin.Field("x" (SettingsWin.ContentRight() - w) " y" (y + 4) " w" w " h24 Limit1 Uppercase -WantReturn +Center", paste_K)
		pst.OnEvent("Change", SettingsWin_PasteKeyChange)
		SettingsWin.Reg(pst, "right", w)
		SettingsWin.c["pst_k"] := pst
		Theme.Tip(pst, TXT.SET_T_pst)
		SettingsWin.EndRow(8)
		SettingsWin.HotkeyRow("actmd_k", TXT.SET_actmd, Actionmode_K, , TXT.SET_T_actmd)
		SettingsWin.HotkeyRow("hst_k", TXT.HST__name, history_k, , TXT.SET_T_histshort)
		SettingsWin.HotkeyRow("org_k", TXT.SET_org, chOrg_K, , TXT.SET_org)
		SettingsWin.HotkeyRow("plugM_k", TXT.PLG__name, pluginManager_K, , TXT.SET_t_plugM)
		SettingsWin.Section(TXT.SET_sec_files)
		SettingsWin.HotkeyRow("Cfilep_K", TXT._cfilep, Copyfilepath_K, , TXT.SET_T_cfilep)
		SettingsWin.HotkeyRow("Cfolderp_K", TXT._cfolderp, Copyfolderpath_K, , TXT.SET_T_cfolderp)
		SettingsWin.HotkeyRow("Cfiled_K", TXT._cfiled, Copyfiledata_K, , TXT.SET_T_cfiled)
		SettingsWin.Section(TXT.SET_sec_capture)
		SettingsWin.HotkeyRow("hldClip_K", TXT.SET_holdclip, holdClip_K, , TXT.SET_T_holdclip)
		SettingsWin.HotkeyRow("onetime_k", TXT._ot, onetime_K, TXT.SET_onetimeHint)
	}

	static BuildChannels() {
		global TXT, pitswap_K
		SettingsWin.PageStart("channels", TXT.SET_channels)
		SettingsWin.HotkeyRow("pitswp_k", TXT._pitswp, pitswap_K, TXT.SET_pitswapHint, TXT.SET_T_pitswp)
		SettingsWin.Section(TXT.SET_sec_ignored)
		SettingsWin.ButtonRow(TXT.IGN__name, TXT.SET_manage, (*) => IgnoredWindowsWin.Open(SettingsWin.g), TXT.SET_ignoredHint)
	}

	static BuildAppearance() {
		global TXT, ini_theme, ini_accent, ini_IsMessage, ini_toastPosition, ini_CopyBeep, beepFrequency, ini_showPastingTip, ini_pstMode_X, ini_pstMode_Y
		g := SettingsWin.g
		SettingsWin.PageStart("appearance", TXT.SET_appearance)
		themes := Map("system", 1, "dark", 2, "light", 3)
		SettingsWin.Ddl("Theme", TXT.SET_theme, [TXT.SET_theme_system, TXT.SET_theme_dark, TXT.SET_theme_light], themes.Has(ini_theme) ? themes[ini_theme] : 1)
		; accent: mode DDL, swatch, hex, pick
		y := SettingsWin.Label(TXT.SET_accent, TXT.SET_accentHint)
		right := SettingsWin.ContentRight()
		pick := Theme.Add(g, "Button", "x" (right - 72) " y" (y + 2) " w72 h28", TXT.SET_pick)
		pick.OnEvent("Click", SettingsWin_PickAccent)
		SettingsWin.Reg(pick, "right", 72)
		hex := SettingsWin.Field("x" (right - 72 - 8 - 78) " y" (y + 4) " w78 h24 Limit6 Uppercase", ini_accent ? ini_accent : Format("{:06X}", Theme.WindowsAccent))
		hex.OnEvent("Change", SettingsWin_AccentHexChange)
		SettingsWin.Reg(hex, "right", 72 + 8 + 78)
		swatch := g.Add("Text", "x" (right - 72 - 8 - 78 - 8 - 24) " y" (y + 4) " w24 h24 Background" Theme.Hex("accent"), "")
		SettingsWin.Reg(swatch, "right", 72 + 8 + 78 + 8 + 24)
		mode := Theme.Add(g, "DDL", "x" (right - 72 - 8 - 78 - 8 - 24 - 8 - 130) " y" (y + 4) " w130 Choose" (ini_accent ? 2 : 1), [TXT.SET_accentWindows, TXT.SET_accentCustom])
		mode.OnEvent("Change", SettingsWin_AccentModeChange)
		SettingsWin.Reg(mode, "right", 72 + 8 + 78 + 8 + 24 + 8 + 130)
		SettingsWin.c["accentMode"] := mode, SettingsWin.c["accentHex"] := hex, SettingsWin.c["accentSwatch"] := swatch, SettingsWin.c["accentPick"] := pick
		SettingsWin.EndRow(8)
		SettingsWin.UpdateAccentControls()
		SettingsWin.Section(TXT.SET_sec_notifications)
		SettingsWin.Check("IsMessage", TXT.SET_ismessage, ini_IsMessage, , TXT.SET_T_ismessage)
		SettingsWin.Ddl("ToastPosition", TXT.SET_toastPosition, [TXT.SET_toastCursor, TXT.SET_toastBottomRight], ini_toastPosition = "bottomright" ? 2 : 1)
		SettingsWin.Check("copyBeep", TXT.SET_copybeep, ini_CopyBeep, , TXT.SET_T_copybeep)
		SettingsWin.Spinner("beepFrequency", TXT.SET_beepFrequency, beepFrequency, "37-32767")
		SettingsWin.Check("Show_pasting_tip", TXT.SET_showPastingTip, ini_showPastingTip)
		SettingsWin.Section(TXT.SET_sec_pasteCard)
		y := SettingsWin.Label(TXT.SET_pinnedPosition, TXT.SET_pinnedHint)
		btn := Theme.Add(g, "Button", "x" (right - 96) " y" (y + 2) " w96 h28", TXT.SET_useCursor)
		btn.OnEvent("Click", SettingsWin_UseCursor)
		SettingsWin.Reg(btn, "right", 96)
		py := SettingsWin.Field("x" (right - 96 - 8 - 70) " y" (y + 4) " w70 h24", ini_pstMode_Y)
		py.OnEvent("Change", SettingsWin_Changed)
		SettingsWin.Reg(py, "right", 96 + 8 + 70)
		px := SettingsWin.Field("x" (right - 96 - 8 - 70 - 8 - 70) " y" (y + 4) " w70 h24", ini_pstMode_X)
		px.OnEvent("Change", SettingsWin_Changed)
		SettingsWin.Reg(px, "right", 96 + 8 + 70 + 8 + 70)
		SettingsWin.c["pstMode_X"] := px, SettingsWin.c["pstMode_Y"] := py
		SettingsWin.EndRow(8)
	}

	static BuildAdvanced() {
		global TXT, ini_is_duplicate_copied, cut_is_delete_windows, ini_winClipjump, windows_copy_k, windows_cut_k, ini_winForPasteMode
		global ini_searchUsesWindow, ini_defEditor, ini_defImgEditor, ini_priority, ini_ram_flush
		SettingsWin.PageStart("advanced", TXT.SET_advancedPage)
		SettingsWin.Check("is_duplicate_copied", TXT.SET_duplicateCopies, ini_is_duplicate_copied)
		SettingsWin.EditRow("cut_equalto_delete", TXT.SET_cutIsDelete, cut_is_delete_windows, 220, TXT.SET_cutIsDeleteHint)
		SettingsWin.Check("winClipjump", TXT.SET_winClipjump, ini_winClipjump, , TXT.SET_T_winClipjump)
		SettingsWin.HotkeyRow("windows_copy_shortcut", TXT.SET_winCopyShortcut, windows_copy_k, TXT.SET_winShortcutHint)
		SettingsWin.HotkeyRow("windows_cut_shortcut", TXT.SET_winCutShortcut, windows_cut_k)
		SettingsWin.Check("WinForPasteMode", TXT.SET_winForPasteMode, ini_winForPasteMode)
		SettingsWin.Check("SearchUsesWindow", TXT.SET_searchUsesWindow, ini_searchUsesWindow, TXT.SET_searchUsesWindowHint)
		SettingsWin.Section(TXT.SET_sec_editors)
		SettingsWin.EditRow("default_editor", TXT.SET_textEditor, ini_defEditor)
		SettingsWin.EditRow("default_image_editor", TXT.SET_imageEditor, ini_defImgEditor)
		SettingsWin.Section(TXT.SET_sec_system)
		prios := ["L", "B", "N", "A", "H"]
		sel := 3
		for i, p in prios
			if (p = SubStr(ini_priority, 1, 1))
				sel := i
		SettingsWin.Ddl("Priority", TXT.SET_priority, [TXT.SET_prio_L, TXT.SET_prio_B, TXT.SET_prio_N, TXT.SET_prio_A, TXT.SET_prio_H], sel, , , 120)
		SettingsWin.Check("RAM_Flush", TXT.SET_ramFlush, ini_ram_flush)
	}

	; ---------- page switching and layout ----------

	static SetPageVisible(id, on) {
		for ctl in SettingsWin.pages[id]
			ctl.Visible := on
	}

	static ShowPage(id) {
		SettingsWin.StopRecording()
		if (SettingsWin.current && SettingsWin.pages.Has(SettingsWin.current))
			SettingsWin.SetPageVisible(SettingsWin.current, false)
		SettingsWin.current := id
		for pid, n in SettingsWin.nav {
			sel := (pid = id)
			n.label.Opt("Background" Theme.Hex(sel ? "surfaceAlt" : "bg"))
			n.bar.Opt("Background" Theme.Hex(sel ? "accent" : "bg") " c" Theme.Hex(sel ? "accent" : "bg"))
			if n.icon
				n.icon.Opt("Background" Theme.Hex(sel ? "surfaceAlt" : "bg"))
			n.label.Redraw(), n.bar.Redraw()
			if n.icon
				n.icon.Redraw()
		}
		SettingsWin.SetPageVisible(id, true)
	}

	static Layout(w, h) {
		SettingsWin.W := w, SettingsWin.H := h
		right := SettingsWin.ContentRight(), fy := h - SettingsWin.FooterH
		for a in SettingsWin.anchored {
			ctl := a[1], mode := a[2], arg := a[3]
			switch mode {
				case "right":
					ctl.GetPos(, &cy)
					ctl.Move(right - arg, cy)
				case "stretch":
					ctl.GetPos(&cx, &cy)
					ctl.Move(cx, cy, right - cx)
				case "navfill":
					ctl.Move(0, arg, SettingsWin.NavW, h - arg)
				case "footer":
					if arg.HasProp("stretch")
						ctl.Move(arg.x, fy + arg.dy, w - arg.x)
					else if arg.HasProp("right")
						ctl.Move(w - arg.right, fy + arg.dy)
					else
						ctl.Move(arg.x, fy + arg.dy)
			}
		}
	}

	; ---------- state ----------

	static SetDirty(on) {
		SettingsWin.dirty := on
		SettingsWin.c["btnApply"].Enabled := on ? true : false
	}

	static Collect() {
		global TXT
		c := SettingsWin.c, hv := SettingsWin.hotkeyVals
		v := Map()
		v.CaseSense := "Off"
		v["limitMaxClips"] := c["limitMaxClips"].Value
		v["MaxClips"] := c["MaxClips"].Value
		v["Threshold"] := c["Threshold"].Value
		v["IsMessage"] := c["IsMessage"].Value
		v["Quality"] := c["Quality"].Value
		v["copyBeep"] := c["copyBeep"].Value
		v["KeepSession"] := c["KeepSession"].Value
		v["DaysToStore"] := c["DaysToStore"].Value
		v["IsImageStored"] := c["IsImageStored"].Value
		v["startSearch"] := c["startSearch"].Value
		v["PreserveClipPos"] := c["PreserveClipPos"].Value
		v["revFormat2def"] := c["revFormat2def"].Value
		v["default_pformat"] := c["default_pformat"].Text
		v["monitorClipboard"] := c["monitorClipboard"].Value
		v["respectExclusion"] := c["respectExclusion"].Value
		v["history_partial"] := c["history_partial"].Value
		v["HisCloseOnInstaPaste"] := c["HisCloseOnInstaPaste"].Value
		v["instapasteWritesClipboard"] := c["instapasteWritesClipboard"].Value
		v["pst_k"] := SubStr(Trim(c["pst_k"].Value, "ESCXZAFH `t"), 1, 1)
		for k in ["actmd_k", "hst_k", "org_k", "plugM_k", "Cfilep_K", "Cfolderp_K", "Cfiled_K", "hldClip_K", "onetime_k", "pitswp_k", "windows_copy_shortcut", "windows_cut_shortcut"]
			v[k] := hv[k]
		v["Theme"] := ["system", "dark", "light"][c["Theme"].Value]
		v["Accent"] := (c["accentMode"].Value = 2 && Theme.ValidHex(c["accentHex"].Value)) ? StrUpper(c["accentHex"].Value) : ""
		v["ToastPosition"] := c["ToastPosition"].Value = 2 ? "bottomright" : "cursor"
		v["beepFrequency"] := c["beepFrequency"].Value
		v["Show_pasting_tip"] := c["Show_pasting_tip"].Value
		v["pstMode_X"] := c["pstMode_X"].Value
		v["pstMode_Y"] := c["pstMode_Y"].Value
		v["is_duplicate_copied"] := c["is_duplicate_copied"].Value
		v["cut_equalto_delete"] := c["cut_equalto_delete"].Value
		v["winClipjump"] := c["winClipjump"].Value
		v["WinForPasteMode"] := c["WinForPasteMode"].Value
		v["SearchUsesWindow"] := c["SearchUsesWindow"].Value
		v["default_editor"] := c["default_editor"].Value
		v["default_image_editor"] := c["default_image_editor"].Value
		v["Priority"] := ["L", "B", "N", "A", "H"][c["Priority"].Value]
		v["RAM_Flush"] := c["RAM_Flush"].Value
		return v
	}

	static Save() {
		SettingsWin.StopRecording()
		if !SettingsWin.dirty
			return
		save_Settings(SettingsWin.Collect())
		load_Settings(), validate_Settings()
		trayMenu(1)
		SettingsWin.SetDirty(false)
	}

	static Ok() {
		SettingsWin.Save()
		SettingsWin.Close()
	}

	static Apply() {
		SettingsWin.Save()
	}

	static Cancel() {
		SettingsWin.Close()
	}

	; rebuilt after a theme change so every control picks up the new palette; unsaved edits are kept only when clean
	static Rebuild() {
		if !SettingsWin.g
			return
		page := SettingsWin.current
		SettingsWin.g.GetPos(&x, &y)
		SettingsWin.Close()
		SettingsWin.current := page
		SettingsWin.Build()
		try SettingsWin.g.Move(x, y)
	}

	; ---------- accent helpers ----------

	static UpdateAccentControls() {
		c := SettingsWin.c
		custom := c["accentMode"].Value = 2
		c["accentHex"].Enabled := custom
		c["accentPick"].Enabled := custom
		if !custom
			c["accentHex"].Value := Format("{:06X}", Theme.WindowsAccent)
		hex := c["accentHex"].Value
		if Theme.ValidHex(hex) {
			c["accentSwatch"].Opt("Background" hex)
			c["accentSwatch"].Redraw()
		}
	}

	; ---------- hotkey recording ----------

	static StartRecording(key) {
		SettingsWin.StopRecording()
		SettingsWin.recKey := key
		SettingsWin.wasSuspended := A_IsSuspended
		Suspend(true)
		ih := InputHook("")
		ih.KeyOpt("{All}", "N S")
		ih.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-S")
		ih.OnKeyDown := SettingsWin_RecKey
		ih.OnKeyUp := SettingsWin_RecKeyUp
		SettingsWin.recMods := Map()
		ih.Start()
		SettingsWin.rec := ih
		SettingsWin.ShowHotkey(key, true)
	}

	static StopRecording() {
		if !SettingsWin.rec
			return
		try SettingsWin.rec.Stop()
		SettingsWin.rec := ""
		if !SettingsWin.wasSuspended
			Suspend(false)
		key := SettingsWin.recKey
		SettingsWin.recKey := ""
		if (key && SettingsWin.c.Has(key))
			SettingsWin.ShowHotkey(key)
	}

	; Modifier state comes from the hook's own down/up events: the callbacks run a little after the keystrokes,
	; so sampling GetKeyState here would miss modifiers that were already released.
	static IsModifier(vk) => (vk >= 16 && vk <= 18) || vk = 91 || vk = 92 || (vk >= 160 && vk <= 165)

	static ModDown(vk) => SettingsWin.recMods.Has(vk) && SettingsWin.recMods[vk]

	static RecordKey(vk, sc) {
		if SettingsWin.IsModifier(vk) {
			SettingsWin.recMods[vk] := true
			return
		}
		key := SettingsWin.recKey
		name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
		md := SettingsWin.ModDown.Bind(SettingsWin)
		m := ((md(17) || md(162) || md(163)) ? "^" : "") ((md(16) || md(160) || md(161)) ? "+" : "") ((md(18) || md(164) || md(165)) ? "!" : "") ((md(91) || md(92)) ? "#" : "")
		if (m = "" && (vk = 27)) {                 ; Esc: keep the old value
			SettingsWin.StopRecording()
			return
		}
		if (m = "" && (vk = 8 || vk = 46))         ; Backspace / Delete: clear
			SettingsWin.hotkeyVals[key] := ""
		else
			SettingsWin.hotkeyVals[key] := m (StrLen(name) = 1 ? StrLower(name) : name)
		SettingsWin.StopRecording()
		SettingsWin.SetDirty(true)
		try SettingsWin.c["btnOk"].Focus()
	}
}

; ---------- event handlers (plain functions so Bind() works everywhere) ----------

SettingsWin_OnSize(g, minMax, w, h) {
	if (minMax = -1)
		return
	SettingsWin.Layout(w, h)
}

SettingsWin_OnTheme() {
	SetTimer(SettingsWin_RebuildNow, -10)
}

SettingsWin_RebuildNow() {
	SettingsWin.Rebuild()
}

SettingsWin_NavClick(id, *) {
	SettingsWin.ShowPage(id)
}

SettingsWin_Changed(*) {
	if !SettingsWin.suppress
		SettingsWin.SetDirty(true)
}

SettingsWin_SpinEdit(ud, ctl, *) {
	if IsInteger(ctl.Value)
		ud.Value := ctl.Value
	SettingsWin_Changed()
}

SettingsWin_SpinButton(edit, ud, *) {
	edit.Value := ud.Value
	SettingsWin_Changed()
}

SettingsWin_LimitClick(ctl, *) {
	c := SettingsWin.c
	on := ctl.Value ? true : false
	c["MaxClips"].Enabled := on, c["Threshold"].Enabled := on
	if (on && !c["MaxClips"].Value)
		c["MaxClips"].Value := 20
	SettingsWin.SetDirty(true)
}

SettingsWin_PasteKeyChange(ctl, *) {
	v := Trim(ctl.Value, "ESCXZAFH `t")
	if (v = "" && ctl.Value != "")
		ctl.Value := ""
	SettingsWin.SetDirty(true)
}

SettingsWin_RecFocus(key, *) {
	SettingsWin.StartRecording(key)
}

SettingsWin_RecBlur(*) {
	SettingsWin.StopRecording()
}

SettingsWin_RecKey(ih, vk, sc) {
	SettingsWin.RecordKey(vk, sc)
}

SettingsWin_RecKeyUp(ih, vk, sc) {
	if SettingsWin.IsModifier(vk)
		SettingsWin.recMods[vk] := false
}

SettingsWin_AccentModeChange(*) {
	SettingsWin.UpdateAccentControls()
	SettingsWin.SetDirty(true)
}

SettingsWin_AccentHexChange(*) {
	SettingsWin.UpdateAccentControls()
	SettingsWin.SetDirty(true)
}

SettingsWin_PickAccent(*) {
	hex := SettingsWin.c["accentHex"].Value
	rgb := Theme.PickColor(Theme.ValidHex(hex) ? Integer("0x" hex) : Theme.WindowsAccent, SettingsWin.g.Hwnd)
	if (rgb = "")
		return
	SettingsWin.c["accentHex"].Value := Format("{:06X}", rgb)
	SettingsWin.UpdateAccentControls()
	SettingsWin.SetDirty(true)
}

SettingsWin_UseCursor(*) {
	SettingsWin.c["pstMode_X"].Value := "", SettingsWin.c["pstMode_Y"].Value := ""
	SettingsWin.SetDirty(true)
}
