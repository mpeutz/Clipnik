; sandbox_guard.ahk - included right after #Requires by every test that drives a running Clipnik. Those tests copy,
; paste, delete and compact clips for real, so they may only ever meet a throwaway copy: tools/test-sandbox.sh
; builds one (marked by .clipnik-test-sandbox in its root), starts that copy's Clipnik and runs the copy's own tests.
; A test run from the real install, or with a second Clipnik running, stops here before it touches anything.
#Include %A_LineFile%\..\sandbox_guard_fns.ahk

SandboxGuard_Stop(SandboxGuard_Problem(RegExReplace(A_ScriptDir, "\\tests$"), SandboxGuard_Running()))

SandboxGuard_Stop(problem) {
	if (problem = "")
		return
	FileAppend("FAIL sandbox guard: " problem "`n", "*")
	ExitApp 2
}
