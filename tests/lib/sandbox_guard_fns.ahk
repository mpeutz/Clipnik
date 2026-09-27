; sandbox_guard_fns.ahk - the checks behind sandbox_guard.ahk, kept apart so tests/sandbox_guard.ahk can test them.

; "" when root is a sandbox copy and scriptPaths holds exactly that copy's Clipnik, else why not. scriptPaths are
; the scripts of every running Clipnik.ahk: publicAPI talks to the first one it finds, so a second one - the
; user's own, still running beside the copy - could be the one a test reaches.
SandboxGuard_Problem(root, scriptPaths) {
	if !FileExist(root "\.clipnik-test-sandbox")
		return "this test is not inside a sandbox copy (no .clipnik-test-sandbox in " root "). Run it through tools/test-sandbox.sh"
	if !scriptPaths.Length
		return "no Clipnik is running"
	if (scriptPaths.Length > 1)
		return scriptPaths.Length " copies of Clipnik are running, and the test could reach the wrong one"
	SplitPath(scriptPaths[1], &name, &dir)
	if (name != "Clipnik.ahk" || SandboxGuard_Long(dir) != SandboxGuard_Long(root))   ; != ignores case
		return "the running Clipnik is not this sandbox's: " scriptPaths[1]
	return ""
}

; the long form of an existing path (C:\Users\MIKEPE~1 -> C:\Users\MikePeutz), without a trailing backslash
SandboxGuard_Long(path) {
	buf := Buffer(65536)
	n := DllCall("GetLongPathNameW", "Str", path, "Ptr", buf, "UInt", 32768, "UInt")
	return RTrim(n ? StrGet(buf) : path, "\")
}

; the script path of every running Clipnik.ahk, read from its main window's title ("<path> - AutoHotkey v2...")
SandboxGuard_Running() {
	paths := []
	dhw := A_DetectHiddenWindows, tmm := A_TitleMatchMode
	DetectHiddenWindows true
	SetTitleMatchMode 2
	for hw in WinGetList("Clipnik.ahk ahk_class AutoHotkey")
		if RegExMatch(WinGetTitle(hw), "i)^(.*\\Clipnik\.ahk) - AutoHotkey", &m)
			paths.Push(m[1])
	DetectHiddenWindows dhw
	SetTitleMatchMode tmm
	return paths
}
