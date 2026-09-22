/*
Lock the paste card open.

Paste mode normally dies the moment Ctrl comes up: ctrlCheck() polls every 50 ms and tears the card
down as soon as the modifier is released. The lock key pins it instead. LOCK.ACTIVE joins SPM.ACTIVE
in ctrlCheck's guard so the teardown waits, and the paste-mode keys are re-registered WITHOUT the Ctrl
prefix so they keep driving the card while the target application holds the focus.

Bare hotkeys, not an InputHook. An InputHook that suppresses a key kills every hotkey on that key,
modified ones included: suppressing "a" also killed Ctrl+Shift+A, and suppressing "c" and "x" would
have killed Clipnik's own Ctrl+C and Ctrl+X hooks for as long as the card stayed locked. In AHK "c"
and "^c" are separate hotkeys, so binding the bare letter leaves every Ctrl combination alone. The
cost is that a key we do NOT bind still reaches the application - the trade Ring.BindKeys makes too.

Every exit works the way search does: set ctrlRef, clear the flag, drop the keys, and let the timer
that is already running perform the whole teardown. There is deliberately no second teardown here.
*/

; Arms the lock. One-way: a second press cannot mean anything but "paste now", which would turn a
; mistyped key into an unintended paste, so it is ignored. Enter and Esc are the exits.
pasteLock_toggle(*) {
	global LOCK, SPM, MULTIPASTE, is_pstMode_active, temp_clipboard
	local px := 0, py := 0, pw := 0, ph := 0
	if (!is_pstMode_active || LOCK.ACTIVE || SPM.ACTIVE || Ring.isOpen)
		return
	MULTIPASTE := 0 		; only one mechanism may keep the card alive at a time
	LOCK.target := WinExist("A")
	LOCK.suspended := 0
	LOCK.ACTIVE := 1
	; the card is placed at the mouse on every render; the whole point of the lock is that the mouse
	; is free to wander, so pin it where it already is, exactly as searchpm() does
	Hud.GetPos(&px, &py, &pw, &ph)
	if pw
		Hud.Anchor(px, py)
	pasteLock_keys(1)
	PasteModeTooltip(temp_clipboard)
}

; Drops the keys and the flag. Does no HUD work, so it is safe to call from any thread, and it is
; idempotent - every teardown path calls it as a belt-and-braces measure.
pasteLock_clear(*) {
	global LOCK
	pasteLock_keys(0)
	LOCK.suspended := 0, LOCK.ACTIVE := 0
}

; Hands the keyboard to something that needs it (the search hook, either ring) without dropping the
; lock: LOCK.ACTIVE stays set so ctrlCheck's guard still holds and the card stays up. A ring binds the
; same bare letters we do and turns them Off when it closes, so resuming has to re-register them.
pasteLock_suspend(*) {
	global LOCK
	if (!LOCK.ACTIVE || LOCK.suspended)
		return
	LOCK.suspended := 1
	pasteLock_keys(0)
}

pasteLock_resume(*) {
	global LOCK
	if (!LOCK.ACTIVE || !LOCK.suspended)
		return
	LOCK.suspended := 0
	pasteLock_keys(1)
}

pasteLock_keys(on) {
	global LOCK
	local key, fn, bf
	if !on {
		if IsObject(LOCK.hk)
			for key, bf in LOCK.hk
				pasteLock_bindKey(key, bf, "Off T1")
		LOCK.hk := ""
		return
	}
	LOCK.hk := Map()
	for key, fn in pasteLock_keymap() {
		bf := pasteLock_fire.Bind(fn)
		LOCK.hk[key] := bf 		; keep the exact object: Hotkey() identifies a variant by its function
		pasteLock_bindKey(key, bf, "On T2")
	}
}

; Hotkey() with the vk fallback Ring.BindKey uses for letters a layout does not map by name
pasteLock_bindKey(key, fn, opt) {
	local t := ""
	try {
		Hotkey(key, fn, opt)
		return
	}
	loop parse key
		t .= IsAlpha(A_LoopField) ? "vk" GetVKList(A_LoopField)[1] : A_LoopField
	try Hotkey(t, fn, opt)
}

pasteLock_fire(fn, *) {
	global LOCK, SPM
	; a ring owns the keyboard while it is up; it also suspends us, but the Action Ring is reachable
	; from a global hotkey at any moment, so re-check here
	if (!LOCK.ACTIVE || LOCK.suspended || Ring.isOpen || SPM.ACTIVE)
		return
	fn()
}

; key name -> action. Built from the live pastemodekey table rather than hardcoded keys, so a remap
; through the public API (cj["pastemodekey.z"] := "y") keeps working.
pasteLock_keymap() {
	global pastemodekey, pstIdentifier, paste_k
	local m := Map()
	pasteLock_bind(m, paste_k, paste) 		; steps forward, exactly as Ctrl+V does
	pasteLock_bind(m, pastemodekey.c, moveBack)
	pasteLock_bind(m, pastemodekey.x, pasteLock_modeStep)
	pasteLock_bind(m, pastemodekey.z, Formatting)
	pasteLock_bind(m, pastemodekey.space, fixate)
	pasteLock_bind(m, pastemodekey.a, navigate_to_first)
	pasteLock_bind(m, pastemodekey.q, move_to_first)
	pasteLock_bind(m, pastemodekey.f, pasteLock_search)
	pasteLock_bind(m, pastemodekey.b, vaultToggle)
	pasteLock_bind(m, pastemodekey.h, editclip_pm)
	pasteLock_bind(m, pastemodekey.t, setClipTag)
	pasteLock_bind(m, pastemodekey.s, Ssuspnd)
	pasteLock_bind(m, pastemodekey.e, export)
	pasteLock_bind(m, pastemodekey.up, channel_up)
	pasteLock_bind(m, pastemodekey.down, channel_down)
	pasteLock_bind(m, pastemodekey.F1, pstMode_Help)
	pasteLock_bind(m, pastemodekey.enter, pasteLock_paste)
	pasteLock_bind(m, pastemodekey.l, pasteLock_ignore) 	; claim it so a second press cannot type a letter
	pasteLock_bind(m, "Esc", pasteLock_cancel)
	; AddjumpClip reads the digit with SubStr(ThisHotkey, 2), so it wants the prefixed form
	loop 9
		pasteLock_bind(m, "" A_Index, AddjumpClip.Bind(pstIdentifier A_Index))
	pasteLock_bind(m, "-", TogglejumpClip)
	pasteLock_bind(m, "NumpadSub", TogglejumpClip)
	return m
}

pasteLock_bind(m, key, fn) {
	if (key = "")
		return
	m[key] := fn
}

pasteLock_ignore(*) {
}

pasteLock_search(*) {
	pasteLock_suspend() 	; SPM starts an InputHook; let it have the keyboard to itself
	searchpm()
}

; Commits whatever release mode is current. ctrlRef is already "pastemode" unless X cycled it, so this
; never overwrites a chosen mode - it only records the Shift-pop and lets ctrlCheck run.
pasteLock_paste(*) {
	global LOCK, ctrlRef, MULTIPASTE, dopop
	Critical "On"
	if (ctrlRef = "pastemode")
		dopop := GetKeyState("Shift", "P") ? 1 : 0
	MULTIPASTE := 0
	pasteLock_clear()
}

pasteLock_cancel(*) {
	global LOCK, ctrlRef, MULTIPASTE
	Critical "On"
	ctrlRef := "cancel"
	MULTIPASTE := 0
	pasteLock_clear()
}

; The locked X cycle. It deliberately does not reuse cancel()/delete_mode()/cutclip()/copyclip()/
; deleteall(): those juggle ^x hotkey registrations, and cancel() in particular calls
; hkZ_pasteMode(0, 0), which kills every paste-mode key but X - so the user would find dead hotkeys
; the moment they grabbed Ctrl again. While locked the bare keys route everything, so none of that
; applies. It also wraps deleteAll -> pastemode rather than -> cancel: unlocked you escape a wrong
; mode by releasing Ctrl, but locked there is no release, so the cycle has to come back to "just paste".
pasteLock_modeStep(*) {
	global ctrlRef, VAULT
	if VAULT.ACTIVE
		return
	switch ctrlRef {
		case "pastemode": ctrlRef := "cancel"
		case "cancel":    ctrlRef := "delete"
		case "delete":    ctrlRef := "cut"
		case "cut":       ctrlRef := "copy"
		case "copy":      ctrlRef := "deleteAll"
		default:          ctrlRef := "pastemode"
	}
	Hud.SetMode(ctrlRef = "pastemode" ? "normal" : StrLower(ctrlRef))
}

; Polled from ctrlCheck's idle branch. The card has no claim on the keyboard once the user moves to
; another application, and the bare keys are registered globally, so treat that as a cancel.
pasteLock_watch() {
	global LOCK
	local a
	if (!LOCK.ACTIVE || LOCK.suspended)
		return
	a := WinExist("A")
	if (!a || a = LOCK.target)
		return
	; our own windows do not count: the delete-all confirm, the legacy search box and the tag InputBox
	; all steal activation legitimately
	try {
		if (WinGetPID("ahk_id " a) = DllCall("GetCurrentProcessId", "UInt"))
			return
	} catch
		return
	pasteLock_cancel()
}

; test hook: 1 while the card is locked open, else 0
PasteLock_IsActive() => LOCK.ACTIVE ? 1 : 0
