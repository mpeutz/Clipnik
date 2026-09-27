; Menu style "list": the paste-mode format picker as the card list instead of the ring, built from the very items
; the ring shows. Standalone: stubs the Clipnik globals the modules touch, as hud_demo does; no running Clipnik,
; no clipboard. Shows a card on screen for a moment.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\menustyle.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\Toast.ahk
#Include ..\src\ui\native\Hud.ahk
#Include ..\src\core\cliptype.ahk
#Include ..\lib\translations.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"
global STORE := CJMap(), CJGUI := Map(), ACTIONS := CJMap()
global ini_pstMode_X := "", ini_pstMode_Y := "", ini_LANG := "english"
global CDS := Map()
AddClipPref(*) => 0
global CN := CJMap("Name", "Default", "NG", 0), realclipno := 3, CURSAVE := 40, curPformat := "", fixStatus := "", halfClip := ""
global temp_clipboard := "", THUMBS_dir := "cache/thumbs", TEMPSAVE := 1, realActive := 1, SPM := CJMap(), ctrlRef := ""
global VAULT := CJMap(), LOCK := CJMap()
global TXT := Translations_load("languages/english.txt")
global PROGNAME := "Clipnik"
hkZ(key, fn, status := 1) => Hotkey(key, fn, status ? "On" : "Off")
clipPref(ch, clip, name) => ""
GetClipboardFormat(type := 1) => "[Text]"
fillWithSpaces(text := "", limit := 35) {
	r := ""
	loop limit - StrLen(text)
		r .= A_Space
	return text r
}

OnError(fatal)
fatal(e, mode) {
	FileAppend("FAIL unhandled: " e.Message " (" e.What ", line " e.Line ")`n", "*")
	ExitApp 1
}

fails := 0
check(cond, msg) {
	global fails
	FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
	if !cond
		fails++
}

; the shape Formatting_Items gives the ring: the active format outlined, the ones that do not fit the clip dimmed
ring := [{key: "O", label: "Original", short: "Org", desc: "Paste as copied", active: true}
	, {key: "T", label: "Trim", short: "Trim", desc: "Trim whitespace", active: false, dim: false}
	, {key: "J", label: "Pretty JSON", short: "Pretty", desc: "Indent JSON", active: false, dim: true}]

m := Hud.MenuFromRing(ring, "^", ["Esc", "Z", "Enter"])
check(m.items.Length = 3, "one list row per ring item")
check(m.items[1].key = "O" && m.items[1].caption = "Original" && m.items[1].check && !m.items[1].dim, "the active format is the checked row")
check(!m.items[2].check && !m.items[2].dim, "a format that fits is plain")
check(m.items[3].caption = "Pretty JSON" && m.items[3].dim, "a format that does not fit the clip stays dimmed")
check(m.keys = "^O ^T ^J ^Esc ^Z ^Enter", "keys carry the paste-mode prefix, the extras last: " m.keys)
check(Hud.MenuFromRing(ring, "", ["Esc", "Z", "Enter"]).keys = "O T J Esc Z Enter", "locked (Ctrl up): the keys are bare")
bare := Hud.MenuFromRing([{key: "A", label: "Only a label"}], "", [])
check(bare.items[1].caption = "Only a label" && !bare.items[1].check && !bare.items[1].dim && bare.keys = "A",
	"an item without active or dim is a plain row")

; and the card actually lists them: key chips and captions, the active one ticked
Theme.Init("dark")
Hud.Init()
MouseMove(400, 300)
s := Hud.NewState()
s.mode := "menu", s.items := m.items, s.title := TXT.HUD_formatTitle
Hud.Render(s)
Sleep 100
check(Hud.visible, "the list menu shows on the card")
check(Hud.rows.Length >= 3 && Hud.rows[1].chip.Text = "O" && Hud.rows[1].text.Text = Chr(0x2713) " Original", "row 1: the O chip, ticked Original")
check(Hud.rows.Length >= 3 && Hud.rows[3].chip.Text = "J" && Hud.rows[3].text.Text = "Pretty JSON", "row 3: the J chip, Pretty JSON")
Hud.Hide()

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
