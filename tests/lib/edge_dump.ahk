; edge_dump.ahk - a page from ui\ rendered by headless Edge against the mock bridge, as its final DOM.

; The page's DOM once the mock bridge has answered and the images in view have loaded or failed; page is a path
; under ui\, a query string allowed. The command goes through a batch file: cmd /c's quote stripping does not
; survive "Program Files (x86)" plus a redirect, and reading Edge's stdout pipe to the end never returns, because
; its helper processes inherit the pipe and outlive it. cmd waits for Edge's main process only; the helpers are
; closed afterwards, found by this dump's own profile folder. Each dump gets a fresh profile, since a previous
; dump's helpers can still hold theirs and make the next Edge wait on them, and a dump that still hangs is ended
; after 30 s, so the page's checks fail instead of the whole test.
EdgeDump(page) {
	root := RegExReplace(A_LineFile, "\\tests\\lib\\[^\\]+$")
	edge := A_ProgramFiles " (x86)\Microsoft\Edge\Application\msedge.exe"
	if !FileExist(edge)
		edge := A_ProgramFiles "\Microsoft\Edge\Application\msedge.exe"
	tag := "cnk-edge-profile-" A_TickCount
	profile := A_Temp "\" tag, out := A_Temp "\cnk-dump.html", bat := A_Temp "\cnk-dump.cmd"
	url := "file:///" StrReplace(root "\ui\" page, "\", "/")
	try FileDelete(out)
	try FileDelete(bat)
	FileAppend('@"' edge '" --headless --disable-gpu --user-data-dir="' profile '" --virtual-time-budget=5000 --dump-dom "' url '" > "' out '" 2>nul', bat)
	Run(bat, , "Hide", &pid)
	if ProcessWaitClose(pid, 30)
		try ProcessClose(pid)
	for p in ComObjGet("winmgmts:").ExecQuery("select ProcessId, CommandLine from Win32_Process where Name='msedge.exe'")
		if InStr(p.CommandLine, tag)
			try ProcessClose(p.ProcessId)
	Sleep 300
	try DirDelete(profile, true)
	return FileExist(out) ? FileRead(out, "UTF-8") : ""
}
