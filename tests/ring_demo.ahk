; Renders the action ring in every mode and page, dark and light, and saves screenshots to tests\out\ring-*.png.
; Standalone: stubs the few Clipnik globals the modules touch. Run with Clipnik NOT running (it uses hotkeys).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\lib\translations.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\RingGeom.ahk
#Include ..\src\ui\native\Ring.ahk
SetWorkingDir A_ScriptDir "\.."
FileEncoding "UTF-8"
global TXT := Translations_load("languages/english.txt")
DirExist("tests\out") || DirCreate("tests\out")

fmt := [{key: "O", label: "Original", short: "Original", desc: "Paste the clip exactly as copied"}
    , {key: "T", label: "Trim Formatting", short: "Trim", desc: "Strip off Formatting", active: true}
    , {key: "S", label: "Strip URL tracking", short: "Untrack", desc: "Remove utm_*, fbclid, gclid"}
    , {key: "M", label: "Markdown link", short: "Markdown", desc: "[host](url)"}
    , {key: "E", label: "SentenceCase", short: "Sentence", desc: "Paste Text in Sentence Case"}
    , {key: "N", label: "Common Formats", short: "Common", desc: "Shows a gui to paste with a format from many types of predefined formats."}
    , {key: "P", label: "Pretty JSON", short: "Pretty", desc: "Indent two spaces", dim: true}
    , {key: "J", label: "Minified JSON", short: "Minify", desc: "Strip whitespace outside strings", dim: true}
    , {key: "I", label: "Title case", short: "Title", desc: "First Letter Of Each Word", dim: true}
    , {key: "U", label: "Upper case", short: "UPPER", desc: "THE WHOLE CLIP", dim: true}
    , {key: "W", label: "Lower case", short: "lower", desc: "the whole clip", dim: true}
    , {key: "L", label: "One line", short: "Flatten", desc: "Collapse every run of whitespace", dim: true}
    , {key: "G", label: "Slugify", short: "Slug", desc: "lower-case-with-dashes", dim: true}
    , {key: "B", label: "Decode base64", short: "Base64", desc: "Decode when the clip is valid base64", dim: true}]
act := []
for row in [["H", "Clipboard History", "History", "history"], ["O", "Channel Organizer", "Organizer", "layout-grid"]
    , ["E", "Settings", "Settings", "settings"], ["B", "Hold clip", "Hold", "pin"], ["P", "PitSwap", "PitSwap", "zap"]
    , ["T", "One-time stop", "Skip", "ban"], ["C", "Copy file path", "Path", "file"], ["M", "Plugin Manager", "Plugins", "wrench"]
    , ["L", "Ignored Windows", "Ignore", "eye-off"], ["X", "Copy folder path", "Folder", "folder"], ["F", "Copy file data", "File", "copy"]
    , ["U", "Sync clipboard", "Sync", "clipboard-check"], ["F2", "Paste-mode keys", "Keys", "keyboard"], ["F1", "Help", "Help", "circle-help"]]
    act.Push({key: row[1], label: row[2], short: row[3], icon: Theme.Icon(row[4])})
fp := RingGeom.Pages(fmt), ap := RingGeom.Pages(act)
for mode in ["dark", "light"] {
    Theme.Init(mode, "76B84E")
    Ring.RenderToFile(Ring.State(fp[1], -1, "Trim Formatting", "active format", true), "tests\out\ring-" mode "-format.png")
    Ring.RenderToFile(Ring.State(fp[1], 2, "Strip URL tracking", "Remove utm_*, fbclid, gclid"), "tests\out\ring-" mode "-format-hover.png")
    Ring.RenderToFile(Ring.State(fp[1], 5, "Common Formats", fmt[6].desc), "tests\out\ring-" mode "-format-hover-long.png")
    Ring.RenderToFile(Ring.State(fp[2], 7, Ring.NavLabel("back"), TXT.RNG_backDesc), "tests\out\ring-" mode "-format-page2.png")
    Ring.RenderToFile(Ring.State(ap[1], 0, "Clipboard History", "every clip ever copied"), "tests\out\ring-" mode "-action.png")
    Ring.RenderToFile(Ring.State(ap[1], 1, "Channel Organizer", "channels and their clips"), "tests\out\ring-" mode "-action-organizer.png")
    Ring.RenderToFile(Ring.State(ap[1], 2, "Settings", "all of Clipnik's options"), "tests\out\ring-" mode "-action-settings.png")
}
FileAppend("done`n", "*")
ExitApp
