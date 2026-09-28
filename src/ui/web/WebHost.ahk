; WebHost.ahk - a native window that hosts one WebView2 page from ui/ and talks to it with JSON messages.
;
;   WebHost.Available()                 true when the WebView2 runtime can be created
;   host := WebHost(title, page, name)  page: "history/index.html" under ui/; name: CJGUI key
;   host.OnMessage(fn)                  fn(cmd, data, host) for every message the page posts ({cmd, data})
;   host.Post(cmd, data)                queued until the page reports ready
;   host.Show(opts), host.Hide(), host.Visible, host.g (Gui), host.core (WebView2.Core)
;   host.OnClose(fn), host.OnResize(fn)
;   WebHost.CacheUrl(path, stamp)       the page's URL for a file under cache\
;
; Pages load from https://app.clipnik/<page>; cache/ is mapped to https://cache.clipnik/ for thumbnails.
; The palette is injected before every document as CSS variables plus a "cj-theme" class on <html>.

class WebHost {
	static avail := ""
	static Debug := true
	static hosts := Map()

	static Available() {
		if (WebHost.avail != "")
			return WebHost.avail
		dll := A_WorkingDir "\lib\vendor\WebView2\WebView2Loader.dll"
		ok := false
		try {
			h := DllCall("LoadLibrary", "Str", dll, "Ptr")
			if h {
				r := DllCall(dll "\GetAvailableCoreWebView2BrowserVersionString", "Ptr", 0, "Ptr*", &ver := 0, "Int")
				ok := (r = 0 && ver) ? true : false
				if ver
					DllCall("ole32\CoTaskMemFree", "Ptr", ver)
			}
		}
		return WebHost.avail := ok
	}

	; The page's URL for a file under cache\ (a path relative to the working dir, "cache\history\x.jpg"). stamp adds
	; the file's size and time for files that are renamed in place: channel thumbnails are named by position, so after
	; a delete or a compaction the same name holds a different image, and the WebView must not serve the old one.
	static CacheUrl(path, stamp := false) {
		url := "https://cache.clipnik/" StrReplace(RegExReplace(path, "i)^cache[\\/]"), "\", "/")
		if stamp && FileExist(path)
			url .= "?v=" FileGetSize(path) "-" FileGetTime(path, "M")
		return url
	}

	; COREWEBVIEW2_COLOR is {A, R, G, B} bytes, little-endian in a UInt
	static Wv2Color(rgb) => 0xFF | (((rgb >> 16) & 0xFF) << 8) | (((rgb >> 8) & 0xFF) << 16) | ((rgb & 0xFF) << 24)

	__New(title, page, name := "") {
		this.title := title, this.page := page, this.name := name
		this.ready := false, this.queue := [], this.handlers := [], this.closeFns := [], this.resizeFns := []
		this.ctrl := "", this.core := "", this.token := "", this.Visible := false, this.creating := false, this.wantFocus := false
		g := Gui("+Resize +MinSize500x300", title)
		this.g := g
		g.MarginX := 0, g.MarginY := 0
		Theme.ApplyToGui(g)
		g.OnEvent("Size", this.OnSize.Bind(this))
		g.OnEvent("Close", this.OnCloseEvent.Bind(this))
		g.OnEvent("Escape", this.OnCloseEvent.Bind(this))
		if name {
			global CJGUI
			CJGUI[name] := g
		}
		Theme.OnChange(this.ApplyTheme.Bind(this))
		WebHost.hosts[g.Hwnd] := this
	}

	; creates the WebView2 controller; must run after the Gui has a client area (Show once, hidden is fine).
	; Each await lets other threads run - the startup prewarm, a second hotkey press, a close - so a call that
	; arrives meanwhile returns at once instead of starting a second browser on the same window. The browser
	; becomes this.ctrl only once no wait is left, then takes whatever visibility the window has by then, so a
	; close during the wait stays closed.
	Create() {
		if this.ctrl || this.creating
			return true
		if !WebHost.Available()
			return false
		this.creating := true
		try this.Build()
		finally this.creating := false
		this.ctrl.IsVisible := this.Visible
		this.ctrl.Fill()
		if this.wantFocus && this.Visible
			this.Focus()
		this.wantFocus := false
		return true
	}

	Build() {
		dataDir := A_Temp "\Clipnik\wv2"
		DirCreate(dataDir)
		env := WebView2.CreateEnvironmentAsync(0, dataDir, "", A_WorkingDir "\lib\vendor\WebView2\WebView2Loader.dll").await()
		ctrl := env.CreateCoreWebView2ControllerAsync(this.g.Hwnd).await()
		core := ctrl.CoreWebView2
		s := core.Settings
		s.AreDefaultContextMenusEnabled := false
		s.IsStatusBarEnabled := false
		s.IsZoomControlEnabled := false
		s.AreDevToolsEnabled := !A_IsCompiled
		s.AreHostObjectsAllowed := false
		ctrl.DefaultBackgroundColor := WebHost.Wv2Color(Theme.Palette["surface"])
		core.SetVirtualHostNameToFolderMapping("app.clipnik", A_WorkingDir "\ui", 1)       ; COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
		core.SetVirtualHostNameToFolderMapping("cache.clipnik", A_WorkingDir "\cache", 1)
		core.AddScriptToExecuteOnDocumentCreatedAsync(this.ThemeScript()).await()
		this.ctrl := ctrl, this.core := core
		this.token := core.WebMessageReceived(this.OnWebMessage.Bind(this))
		core.Navigate("https://app.clipnik/" this.page)
	}

	ThemeScript() {
		return "document.documentElement.style.cssText += '" Theme.CssVars() "';document.documentElement.classList.toggle('dark'," (Theme.IsDark ? "true" : "false") ");document.documentElement.classList.toggle('light'," (Theme.IsDark ? "false" : "true") ");"
	}

	ApplyTheme() {
		Theme.ApplyToGui(this.g)
		if !this.core
			return
		this.ctrl.DefaultBackgroundColor := WebHost.Wv2Color(Theme.Palette["surface"])
		this.Post("theme", Map("vars", Theme.CssVars(), "dark", Theme.IsDark ? 1 : 0))
	}

	; ---------- messaging ----------

	OnMessage(fn) {
		this.handlers.Push(fn)
	}

	OnWebMessage(sender, args) {
		msg := ""
		raw := ""
		try raw := args.WebMessageAsJson
		try msg := JSON.parse(raw)
		if WebHost.Debug
			WebHost.Log("recv " SubStr(raw, 1, 200))
		if !(msg is Map)
			return
		cmd := msg.Has("cmd") ? msg["cmd"] : ""
		data := msg.Has("data") ? msg["data"] : ""
		if (cmd = "ready") {
			this.ready := true
			this.ApplyTheme()
			for m in this.queue
				this.core.PostWebMessageAsJson(m)
			this.queue := []
		}
		for fn in this.handlers {
			try fn(cmd, data, this)
			catch as e
				WebHost.Log(this.page " " cmd ": " e.Message " (" e.File ":" e.Line ")" (e.Extra ? " " e.Extra : ""))
		}
	}

	static Log(text) {
		try FileAppend(A_Now " " text "`n", A_Temp "\Clipnik\webhost.log")
	}

	Post(cmd, data := "") {
		m := Map("cmd", cmd, "data", data)
		s := JSON.stringify(m, 0)
		if (!this.ready || !this.core) {
			this.queue.Push(s)
			return
		}
		if WebHost.Debug
			WebHost.Log("post " SubStr(s, 1, 200))
		this.core.PostWebMessageAsJson(s)
	}

	; ---------- window ----------

	Show(opts := "") {
		this.g.Show(opts)
		this.Visible := true
		if !this.Create() {
			this.g.Hide(), this.Visible := false
			WebHost_MissingRuntime()
			return false
		}
		; no browser yet while another thread creates it (that thread shows it when done), and none to show when
		; the window was closed while this Show waited
		if this.ctrl && this.Visible {
			this.ctrl.IsVisible := true
			this.ctrl.Fill()
		}
		return true
	}

	; creates the browser while the window stays hidden, so the first Show is quick
	Prewarm() {
		if (this.ctrl || !WebHost.Available())
			return
		this.Create()
	}

	Hide() {
		if this.ctrl
			this.ctrl.IsVisible := false
		this.g.Hide()
		this.Visible := false
	}

	OnClose(fn) {
		this.closeFns.Push(fn)
	}

	OnResize(fn) {
		this.resizeFns.Push(fn)
	}

	OnSize(g, minMax, w, h) {
		if (minMax = -1)
			return
		if this.ctrl
			this.ctrl.Fill()
		for fn in this.resizeFns
			try fn(w, h, minMax)
	}

	OnCloseEvent(*) {
		for fn in this.closeFns
			try fn()
		this.Hide()
	}

	; before the browser exists (its Show returned while another thread creates it) the focus is kept for Create()
	Focus() {
		this.wantFocus := !this.ctrl
		try this.ctrl.MoveFocus(0)   ; COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC
	}
}

; [Advanced] PrewarmWebViews=1: both pages are created hidden a few seconds after startup
WebHost_Prewarm() {
	if !WebHost.Available()
		return
	try HistoryWin.Prewarm()
	try OrganizerWin.Prewarm()
}

; Shown once per run when the runtime is missing; the tray app keeps working.
WebHost_MissingRuntime() {
	global PROGNAME, TXT
	static shown := false
	if shown
		return
	shown := true
	g := Gui("-MaximizeBox -MinimizeBox +AlwaysOnTop", PROGNAME)
	Theme.ApplyToGui(g)
	g.MarginX := 24, g.MarginY := 16
	g.SetFont("bold")
	g.Add("Text", "x24 y16 w392", TXT.WV2_missingTitle)
	g.SetFont("norm c" Theme.Hex("muted"))
	g.Add("Text", "x24 y+8 w392", TXT.WV2_missingText)
	g.SetFont("norm c" Theme.Hex("text"))
	Theme.AddLink(g, "x24 y+10 w392", TXT.WV2_download, (*) => BrowserRun("https://go.microsoft.com/fwlink/p/?LinkId=2124703"))
	Theme.Add(g, "Button", "x340 y+16 w76 h28 Default", "OK").OnEvent("Click", (*) => g.Destroy())
	g.OnEvent("Close", (*) => g.Destroy())
	g.OnEvent("Escape", (*) => g.Destroy())
	g.Show("w440")
}
