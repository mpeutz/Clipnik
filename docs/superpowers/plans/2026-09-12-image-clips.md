# Image Clips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make an image a first-class clip kind with its own actions and metadata, recognize SVG markup as its own kind, and bring both into tags and copy-time rules.

**Architecture:** Two kinds join `ClipType.Kinds`: `svg`, detected from text, and `image`, assigned by the copy path because an image clip has no text. A new `src/core/imageclip.ahk` owns the pixel plumbing (resolve a clip to an image source, write a PNG, build a data URI) so `ClipType.Run` stays a dispatcher. The existing action table already feeds the History window, the Organizer and the copy toast, so those surfaces gain image actions by opening their `type = 1` guards and passing a file path instead of clip text.

**Tech Stack:** AutoHotkey v2.0.27 (`runtime/AutoHotkey64.exe`), GDI+ through `lib/vendor/Gdip_All.ahk`, SQLite through `lib/vendor/SQLiteDB`, WebView2 pages in `ui/`. Tests are AHK scripts under `tests/` run with `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/<name>.ahk` from Git Bash.

**Spec:** `docs/superpowers/specs/2026-09-12-image-clips-design.md`

## Global Constraints

- AHK v2 only. A static field and a static method of one class must not share a name (case-insensitive). Functions that read globals declare them. `=` compares case-insensitively, `==` case-sensitively.
- New user-visible strings go to `languages/english.txt` as `KEY = text`, read as `TXT.KEY` (or `ClipType_T("KEY")` inside `src/core/*`). English only; other language files fall back through `ClipType_T`.
- File encodings and line endings stay as they are: `src/**/*.ahk`, `Clipjump.ahk`, `lib/*.ahk`, `languages/english.txt` and `tests/*.ahk` are CRLF; `ui/**` files are LF. Verify byte-accurately (grep misreports in this shell); use PowerShell or Python.
- Web pages are vanilla JS and CSS with no build step and no external requests; a page must still work in Chrome against `ui/common/mock-bridge.js`. Messages are `{cmd, data}` JSON both ways.
- Test hooks called through the public API must be plain file-level functions: `RunFunc` (`lib/customizer.ahk:173-181`) routes any dotted name to `API.*`.
- Validate (`MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate Clipjump.ahk`) exits 0 with only the known noise: four WebView2 vendor warnings and one pre-existing SettingsWin warning.
- Interactive tests need an idle desktop and Clipjump restarted on the new code: `powershell -NoProfile -Command "Start-Process -FilePath '.\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipjump.ahk'"`, wait 8 s. Wrap every AutoHotkey run in `timeout`. Kill only your own test process, never the one running `Clipjump.ahk`. Never drive Notepad. Never edit, stage or checkout `settings.ini`.
- `tests/rules_flow.ahk` already fails on main (its channel-routing checks, differently run to run). Treat a failure there as pre-existing unless your change plausibly caused it, and say so in the report.
- Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

## File map

| File | Responsibility |
|---|---|
| `src/core/cliptype.ahk` | `svg` and `image` kinds, `IsSvg`, the new action-table entries, `Run(id, text, ref)` |
| `src/core/imageclip.ahk` (new) | resolve a clip to an image source, PNG export, data URI with a size cap |
| `Clipjump.ahk` | image arm: kind, dimensions, rules; `showCopyToast` ref; `ClipPref_makeKeys` gains `Dim` |
| `src/core/history.ahk` | image rows carry a kind; `width`/`height` columns and their migration |
| `src/core/settings.ahk`, `src/ui/native/SettingsWin.ahk` | the vector-editor setting and its row |
| `src/ui/native/Hud.ahk` | dimensions on the paste card |
| `src/ui/web/HistoryWin.ahk`, `src/ui/web/OrganizerWin.ahk` | image actions and dimensions to the pages |
| `ui/history/app.js`, `ui/organizer/app.js` | the actions menu and dimensions for image rows |
| `languages/english.txt` | `KIND_*`, `ACT_*`, `SET_*` and toast strings |
| `ui/help/topics/*.html` | the images task entry and the kinds reference |
| `tests/cliptype.ahk`, `tests/rules.ahk`, `tests/image.ahk`, `tests/history_flow.ahk`, `tests/rules_flow.ahk` | coverage |

---

### Task 1: The svg kind

**Files:**
- Modify: `src/core/cliptype.ahk`, `languages/english.txt`, `src/ui/web/OrganizerWin.ahk`
- Test: `tests/cliptype.ahk`

**Interfaces:**
- Produces: `ClipType.IsSvg(t) -> true|false`; `"svg"` and `"image"` as members of `ClipType.Kinds`; the strings `KIND_svg`, `KIND_image`.

- [ ] **Step 1: Write the failing test**

Read the first 20 lines of `tests/cliptype.ahk` for its `check(...)` shape, then add beside the other detection cases:

```ahk
check(ClipType.Detect('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M4 4h16v16H4z"/></svg>') = "svg", "plain svg markup")
check(ClipType.Detect('<?xml version="1.0" encoding="UTF-8"?>' . "`n" . '<svg xmlns="http://www.w3.org/2000/svg"><circle cx="5" cy="5" r="4"/></svg>') = "svg", "svg behind an xml declaration")
check(ClipType.Detect('  <svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>  ') = "svg", "svg with surrounding whitespace")
check(ClipType.Detect('<div class="icon"><svg viewBox="0 0 10 10"></svg></div>') != "svg", "an html fragment containing svg is not svg")
check(ClipType.Detect('{"markup": "<svg></svg>"}') = "json", "json that mentions svg stays json")
check(ClipType.Detect('function f() { return "<svg>"; }') != "svg", "code that mentions svg is not svg")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `MSYS_NO_PATHCONV=1 timeout 60 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/cliptype.ahk`
Expected: the svg checks FAIL (`Detect` returns `code` or `text`).

- [ ] **Step 3: Implement**

`src/core/cliptype.ahk`, the kinds list (`:12`) becomes:

```ahk
	static Kinds := ["url", "email", "path", "color", "json", "svg", "number", "phone", "code", "text", "image"]
```

`image` is added now so the order is final; nothing produces it until Task 2.

Add the predicate beside the other `Is*` predicates:

```ahk
	; svg markup: an <svg> root, optionally behind an xml declaration or comments
	static IsSvg(t) {
		s := Trim(t, " `t`r`n")
		if (SubStr(s, -6) != "</svg>")
			return false
		if (SubStr(s, 1, 4) = "<svg")
			return true
		if (SubStr(s, 1, 5) != "<?xml")
			return false
		p := InStr(s, "?>")
		return p ? (RegExMatch(SubStr(s, p + 2), "s)^\s*(?:<!--.*?-->\s*)*<svg\b") > 0) : false
	}
```

In `Detect` (`:79-107`), put the svg test straight after the JSON test:

```ahk
		if ClipType.IsJson(t)
			return "json"
		if ClipType.IsSvg(t)
			return "svg"
```

`languages/english.txt`: add `KIND_svg = SVG` and `KIND_image = Image` beside the other `KIND_*` keys.

`src/ui/web/OrganizerWin.ahk`: add `"KIND_svg", "KIND_image"` to the explicit i18n key list (`:274`), the one place that does not read labels dynamically.

- [ ] **Step 4: Verify**

`tests/cliptype.ahk` ALL PASSED. Run `tests/rules.ahk` and `tests/transforms.ahk` too (the kinds list feeds both). Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/core/cliptype.ahk languages/english.txt src/ui/web/OrganizerWin.ahk tests/cliptype.ahk
git commit -m "Clip kinds: recognize SVG markup"
```

---

### Task 2: Image clips get a kind and their dimensions

**Files:**
- Modify: `Clipjump.ahk` (image arm, `thumbGenerator`, `ClipPref_makeKeys`, two test hooks), `lib/anticj_func_labels.ahk` (`Gdip_CaptureClipboard`), `src/core/history.ahk`
- Test: `tests/image.ahk`

**Interfaces:**
- Consumes: `ClipType.Store(ch, clip, kind)`, `AddClipPref(ch, clip, name, value)`, `clipPref(ch, clip, name)`, `Prefs2Ini()`.
- Produces: clip pref `Dim` as `"<w>x<h>"`; `addHistoryImage(imgpath, timestamp, kind := "image", w := 0, h := 0)`; history columns `width` and `height`; file-level hooks `ClipType_KindOf(ch, clip)`, `Image_DimOf(ch, clip)`, `Image_LastHistoryDims()`.

- [ ] **Step 1: Write the failing test**

`tests/image.ahk` already copies an image and waits for its thumbnail; read it first and reuse its clip number. Add after its existing checks:

```ahk
n := Integer(cj["CURSAVE"]), ch := Integer(cj["CN.NG"])
check("image clip kind is image", cj.runFunction("ClipType_KindOf(" ch "," n ")") = "image")
dim := cj.runFunction("Image_DimOf(" ch "," n ")")
check("image clip records its size: [" dim "]", RegExMatch(dim, "^\d+x\d+$"))
row := cj.runFunction("Image_LastHistoryDims()")
check("history row carries the kind and size: [" row "]", RegExMatch(row, "^image \d+ \d+$"))
```

Hooks in `Clipjump.ahk` beside the other file-level hooks:

```ahk
; test hooks: RunFunc misroutes dotted names to API.*
ClipType_KindOf(ch, clip) => ClipType.Of(ch, clip)
Image_DimOf(ch, clip) => clipPref(ch, clip, "Dim")
```

and in `src/core/history.ahk`:

```ahk
; test hook: "<kind> <width> <height>" of the newest image row
Image_LastHistoryDims() {
	row := getFromTable("history", "kind, width, height", "type=1 order by id desc limit 1")
	return row ? row[1] " " row[2] " " row[3] : ""
}
```

- [ ] **Step 2: Run it to verify it fails**

Restart Clipjump, run `tests/image.ahk`: the three new checks FAIL (no kind, no `Dim`, no columns).

- [ ] **Step 3: Implement**

`lib/anticj_func_labels.ahk`, `Gdip_CaptureClipboard` (`:565`) currently throws the bitmap's size away and passes a negative error code to the saver when the clipboard holds no bitmap:

```ahk
Gdip_CaptureClipboard(file, quality, &width := 0, &height := 0) {
	PToken := Gdip_Startup()
	pBitmap := Gdip_CreateBitmapFromClipboard()
	width := 0, height := 0
	if (pBitmap > 0) {
		width := Gdip_GetImageWidth(pBitmap), height := Gdip_GetImageHeight(pBitmap)
		Gdip_SaveBitmapToFile(pBitmap, file, quality)
		Gdip_DisposeImage(pBitmap)
	}
	Gdip_Shutdown(PToken)
}
```

`Clipjump.ahk`:

- `ClipPref_makeKeys` (`:1437`): `static l := ["fixed", "Tags", "Kind", "Dim"]`.
- Declare `IMGW` and `IMGH` beside `LASTIMAGETICK` in the globals block.
- `thumbGenerator()` (`:1419`) records the size:

```ahk
thumbGenerator() {
	global
	Critical "On"
	ClipWait(3, 1) 				;Dont need a Clipwait here , but just for special cases I put a wait of 3 secs
	local w := 0, h := 0
	Gdip_CaptureClipboard(A_WorkingDir "\" THUMBS_dir "\" CURSAVE ".jpg", ini_Quality, &w, &h)
	IMGW := w, IMGH := h
	if (w && h) {
		AddClipPref(CN.NG, CURSAVE, "Dim", w "x" h)
		Prefs2Ini()
	}
}
```

- The image arm (`:623-656`): `LASTKIND := "image"` instead of `""`, and after `thumbGenerator()`:

```ahk
			ClipType.Store(CN.NG, CURSAVE, "image")
			if NOINCOGNITO && ini_IsImageStored && (CN.Name != "pit") {
				addHistoryImage(THUMBS_dir "\" CURSAVE ".jpg", A_Now, "image", IMGW, IMGH)
			}
```

`src/core/history.ahk`:

- A migration beside `historyAddKindColumn` (`:22`); read that function and mirror its shape:

```ahk
; width and height of an image row, added after the kind column (2026-09)
historyAddImageSizeColumns() {
	global DB
	if !DB.GetTable("pragma table_info(history)", &tb)
		return
	hasW := false, hasH := false
	loop tb.RowCount {
		tb.Next(&r)
		if (r[2] = "width")
			hasW := true
		else if (r[2] = "height")
			hasH := true
	}
	if !hasW
		DB.Exec("alter table history add column width integer")
	if !hasH
		DB.Exec("alter table history add column height integer")
}
```

Call it wherever `historyAddKindColumn()` is called.

- `addHistoryImage(imgpath, timestamp, kind := "image", w := 0, h := 0)` (`:116`) writes `kind`, `width` and `height` in its insert.
- `historyEnsureKind` (`:37`): an image row answers `"image"` instead of `""`.
- `historyBackfillKinds` (`:70`): widen the query to all unclassified rows and write `image` for `type=1`, `ClipType.Detect(data)` otherwise.
- `historyQuery` (`:172-198`): select `width` and `height` so the page can show them.

- [ ] **Step 4: Verify**

Restart Clipjump. Run `tests/image.ahk` (ALL PASSED), `tests/image_repeat.ahk`, `tests/history_kinds.ahk`, `tests/history_flow.ahk`. Copy a screenshot by hand: the paste card still previews it, and the badge now reads IMAGE. Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add Clipjump.ahk lib/anticj_func_labels.ahk src/core/history.ahk tests/image.ahk
git commit -m "Image clips: a kind of their own and recorded dimensions"
```

---

### Task 3: Image and SVG actions

**Files:**
- Create: `src/core/imageclip.ahk`
- Modify: `src/core/cliptype.ahk`, `Clipjump.ahk` (include, `showCopyToast`), `src/core/settings.ahk`, `src/ui/native/SettingsWin.ahk`, `languages/english.txt`
- Test: `tests/cliptype.ahk`

**Interfaces:**
- Consumes: `Gdip_Startup`, `Gdip_Shutdown`, `Gdip_CreateBitmapFromFile`, `Gdip_CreateBitmapFromClipboard`, `Gdip_SaveBitmapToFile`, `Gdip_DisposeImage`, `BrowserRun(url)`, `Toast.Show(text, ms, kind)`, `ini_defImgEditor`.
- Produces: `ImageClip.Temp(ext)`, `ImageClip.PngFrom(ref, outPath) -> 1|0`, `ImageClip.DataUri(ref, maxBytes := 0) -> string`, `ImageClip.SvgDataUri(markup) -> string`; `ClipType.Run(id, text, ref := "")`; `ClipType.OpenWith(exe, file)`; action ids `openImage`, `imageDataUri`, `svgomg`, `openVector`, `svgDataUri`; setting `ini_defVectorEditor`.

- [ ] **Step 1: Write the failing test**

Add to `tests/cliptype.ahk` (unit, no windows; it will need the new include):

```ahk
check(ClipType.Actions("image").Length = 2, "image has two actions")
check(ClipType.Actions("svg").Length = 3, "svg has three actions")
check(ClipType.Primary("image").id = "openImage", "the image primary action opens the editor")
check(ClipType.Primary("svg").id = "svgomg", "the svg primary action is SVGOMG")
uri := ImageClip.SvgDataUri("<svg xmlns='http://www.w3.org/2000/svg'><rect width='4' height='4'/></svg>")
check(InStr(uri, "data:image/svg+xml,") = 1 && InStr(uri, "%3C") && !InStr(uri, "#"), "svg data uri is url-encoded")
check(ImageClip.DataUri("no-such-file.png", 10) = "", "a missing source yields no data uri")
```

- [ ] **Step 2: Run it to verify it fails**

Run `tests/cliptype.ahk`: the new checks FAIL (no image or svg actions, no `ImageClip`).

- [ ] **Step 3: Implement**

Before writing the base64 helper, check whether `src/core/transforms.ahk` already has one (the `base64` transform) and reuse it rather than adding a second encoder.

`src/core/imageclip.ahk` (new, CRLF, no BOM), pure: no clipboard writes, no UI.

```ahk
; imageclip.ahk - turning an image clip into something an action can use: a PNG on disk, or a data URI.
;
;   ImageClip.PngFrom(ref, outPath)   ref is a file path, or "" for the image on the clipboard right now
;   ImageClip.DataUri(ref, maxBytes)  "" when the source is missing or the PNG exceeds maxBytes
;   ImageClip.SvgDataUri(markup)      url-encoded data:image/svg+xml
;   ImageClip.Temp(ext)               a fresh path under A_Temp\Clipjump

class ImageClip {
	static MaxUriBytes := 2097152

	static Temp(ext) {
		DirCreate(A_Temp "\Clipjump")
		loop
			p := A_Temp "\Clipjump\clip-" A_TickCount "-" A_Index "." ext
		until !FileExist(p)
		return p
	}

	; writes the source as a PNG; 1 on success
	static PngFrom(ref, outPath) {
		t := Gdip_Startup()
		bm := (ref != "" && FileExist(ref)) ? Gdip_CreateBitmapFromFile(ref) : Gdip_CreateBitmapFromClipboard()
		ok := 0
		if (bm > 0) {
			ok := (Gdip_SaveBitmapToFile(bm, outPath) = 0) ? 1 : 0
			Gdip_DisposeImage(bm)
		}
		Gdip_Shutdown(t)
		return ok
	}

	static DataUri(ref, maxBytes := 0) {
		if !maxBytes
			maxBytes := ImageClip.MaxUriBytes
		png := ImageClip.Temp("png")
		if !ImageClip.PngFrom(ref, png)
			return ""
		big := FileGetSize(png) > maxBytes
		b64 := big ? "" : ImageClip.Base64(png)
		try FileDelete(png)
		return b64 = "" ? "" : "data:image/png;base64," b64
	}

	static Base64(path) {
		buf := FileRead(path, "RAW")
		size := 0
		if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &size)
			return ""
		out := Buffer(size * 2, 0)
		if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out, "UInt*", &size)
			return ""
		return StrGet(out, "UTF-16")
	}

	static SvgDataUri(markup) {
		s := Trim(markup, " `t`r`n")
		if (s = "")
			return ""
		s := StrReplace(s, "`r`n", " "), s := StrReplace(s, "`n", " "), s := StrReplace(s, "`t", " ")
		s := StrReplace(s, "%", "%25"), s := StrReplace(s, "#", "%23")
		s := StrReplace(s, "<", "%3C"), s := StrReplace(s, ">", "%3E")
		s := StrReplace(s, '"', "'")
		return "data:image/svg+xml," s
	}
}
```

`Clipjump.ahk`: `#Include %A_ScriptDir%\src\core\imageclip.ahk` beside the other core includes.

`src/core/cliptype.ahk`, two new rows in `ActionTable` (`:185`):

```ahk
		"image", [{id: "openImage", label: "ACT_openImage", short: "ACT_openImageShort"}, {id: "imageDataUri", label: "ACT_dataUri", short: "ACT_dataUriShort"}],
		"svg", [{id: "svgomg", label: "ACT_svgomg", short: "ACT_svgomgShort"}, {id: "openVector", label: "ACT_openVector", short: "ACT_openVectorShort"}, {id: "svgDataUri", label: "ACT_dataUri", short: "ACT_dataUriShort"}])
```

`Run` takes the ref and gains the cases (keep the existing cases untouched):

```ahk
	static Run(id, text, ref := "") {
		global ini_defImgEditor, ini_defVectorEditor
		switch id {
			; ...existing cases...
			case "openImage":
				png := ImageClip.Temp("png")
				if ImageClip.PngFrom(ref, png)
					ClipType.OpenWith(ini_defImgEditor, png)
				else
					Toast.Show(ClipType_T("ACT_imageUnavailable"), 1600, "warn")
			case "imageDataUri":
				uri := ImageClip.DataUri(ref)
				if (uri = "")
					Toast.Show(ClipType_T("ACT_imageTooBig"), 1800, "warn")
				else
					ClipType.ToClipboard(uri)
			case "svgomg":
				ClipType.ToClipboard(text)
				BrowserRun("https://jakearchibald.github.io/svgomg/")
			case "openVector":
				f := ImageClip.Temp("svg")
				try FileAppend(text, f, "UTF-8")
				ClipType.OpenWith(ini_defVectorEditor, f)
			case "svgDataUri": ClipType.ToClipboard(ImageClip.SvgDataUri(text))
		}
	}

	; runs a configured editor on a file, or says the editor is not set
	static OpenWith(exe, file) {
		if (Trim(exe) = "") {
			Toast.Show(ClipType_T("ACT_noEditor"), 2200, "warn")
			return
		}
		try Run('"' exe '" "' file '"')
	}
```

Widen `ClipType_RunLater` and `ClipType_RunNow` (`:311-316`) to carry the third argument.

`src/core/settings.ahk`: read `ini_defVectorEditor` from `[System] default_vector_editor` (default `""`) beside `ini_defImgEditor` (`:62`), and write it in the save path beside the other editors.

`src/ui/native/SettingsWin.ahk`: a third editor row in Advanced, Editors (`:533-536`), labeled `SET_vectorEditor` with the tip `SET_T_vectorEditor`, collected under the key the settings save expects.

`Clipjump.ahk`, `showCopyToast` (`:1690-1701`): the freshly copied image is still on the clipboard, so the ref is `""`. Pass it: `ClipType_RunLater.Bind(act.id, clip, "")`.

`languages/english.txt`:

```
ACT_openImage = Open in image editor
ACT_openImageShort = Edit
ACT_dataUri = Copy as data URI
ACT_dataUriShort = Data URI
ACT_svgomg = Send to SVGOMG
ACT_svgomgShort = SVGOMG
ACT_openVector = Open in vector editor
ACT_openVectorShort = Edit
ACT_noEditor = Set the editor in Settings, Advanced, Editors
ACT_imageTooBig = That image is too large for a data URI
ACT_imageUnavailable = That image could not be read
SET_vectorEditor = Vector editor
SET_T_vectorEditor = Program that opens an SVG clip, for example Affinity Designer.
```

- [ ] **Step 4: Verify**

`tests/cliptype.ahk` ALL PASSED; `tests/settings_flow.ahk` ALL PASSED (the new row must not disturb the settings round trip). Validate: exit 0. By hand, with the image editor at its default: copy a screenshot, click the toast chip, confirm Paint opens the PNG.

- [ ] **Step 5: Commit**

```bash
git add src/core/imageclip.ahk src/core/cliptype.ahk Clipjump.ahk src/core/settings.ahk src/ui/native/SettingsWin.ahk languages/english.txt tests/cliptype.ahk
git commit -m "Clip actions: image and SVG actions with a vector editor setting"
```

---

### Task 4: The windows offer image actions and show dimensions

**Files:**
- Modify: `src/ui/web/HistoryWin.ahk`, `src/ui/web/OrganizerWin.ahk`, `ui/history/app.js`, `ui/organizer/app.js`, `ui/common/mock-bridge.js`, `src/ui/native/Hud.ahk`
- Test: `tests/history_flow.ahk`

**Interfaces:**
- Consumes: `ClipType.Actions(kind)`, `ClipType.Run(id, text, ref)`, the history `width`/`height` columns, the clip pref `Dim`.
- Produces: image rows carrying `actions` and their size to both pages.

- [ ] **Step 1: Write the failing test**

Read `tests/history_flow.ahk` first: it has a `check(name, cond)` helper, a `readLog()` over `%TEMP%\Clipjump\webhost.log`, and existing image steps. Reusing its own selection mechanism, add:

```ahk
check("image preview offers actions", InStr(readLog(), "openImage"))
check("image preview reports its size", RegExMatch(readLog(), '"width":\s*\d+'))
```

Do not invent a new selection mechanism; drive the page the way the file already does.

- [ ] **Step 2: Run it to verify it fails**

Restart Clipjump, run `tests/history_flow.ahk`: both new checks FAIL (the image branch sends neither actions nor dimensions).

- [ ] **Step 3: Implement**

`src/ui/web/HistoryWin.ahk`:
- `SendPreview` (`:76-88`): on the `type = 1` branch attach `rec["actions"] := ClipType.Actions("image")` beside the existing `url`, and keep `width`/`height` on the record.
- `Action` (`:90-95`): drop the `type = 1` early return. For an image call `ClipType.Run(action, "", A_WorkingDir "\" rec["fileid"])`; for text keep `ClipType.Run(action, rec["data"])`.
- Post a `toast` after an action that writes the clipboard, the way `Copy` (`:97-101`) already does, so a page-triggered action is not silent.

`src/ui/web/OrganizerWin.ahk`: the same two changes in `SendClip` (`:95-110`) and `Action` (`:111-118`), with the thumbnail path as the ref, and an image row's `kind` now `"image"` rather than `""`.

`ui/history/app.js` (`:115-124`) and `ui/organizer/app.js` (`:109-113`): compute the actions list outside the text-only branch so the Actions button and the row context menu appear for images, and show `width x height` beside the size in the preview header when present.

`ui/common/mock-bridge.js`: give the image fixture `kind: "image"`, an `actions` array and `width`/`height`, so both pages lay out in Chrome.

`src/ui/native/Hud.ahk`: show the stored `Dim` for an image clip. `FromPasteVars` (`:159-178`) reads `clipPref(CN.NG, realActive, "Dim")` on the image branch; `Footer` (`:389-413`) renders it beside the tags.

- [ ] **Step 4: Verify**

Restart Clipjump. Run `tests/history_flow.ahk`, `tests/organizer_flow.ahk`, `tests/hud_live.ahk` (ALL PASSED each). Open both pages in Chrome against the mock bridge, dark and light, and check the image row's actions menu and the size. By hand: copy a screenshot, open History, run Copy as data URI, paste into an editor and confirm a `data:image/png;base64,` string. Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/ui/web/HistoryWin.ahk src/ui/web/OrganizerWin.ahk ui/history/app.js ui/organizer/app.js ui/common/mock-bridge.js src/ui/native/Hud.ahk tests/history_flow.ahk
git commit -m "History and Organizer: actions and dimensions for image clips"
```

---

### Task 5: Rules and tags for images

**Files:**
- Modify: `Clipjump.ahk` (image arm rules, the text arm's tag flush), `src/ui/native/RuleDialog.ahk`, `languages/english.txt`
- Test: `tests/rules.ahk`, `tests/rules_flow.ahk`

**Interfaces:**
- Consumes: `Rules.Evaluate(list, kind, text, app, cls)`, `Rules.List`, `API.manageClip`, `AddClipPref`, `Prefs2Ini`, `Toast.Show`.
- Produces: image clips honoring `channel`, `tag` and `ignore` rules.

- [ ] **Step 1: Write the failing test**

`tests/rules.ahk` (unit):

```ahk
r := Rules.New()
r["kinds"] := ["image"], r["action"] := "tag", r["arg"] := "shot"
check(Rules.Match(r, "image", "", "app.exe", "Cls"), "an image rule matches an image clip")
check(!Rules.Match(r, "text", "hello", "app.exe", "Cls"), "an image rule ignores a text clip")
r["regex"] := "screenshot"
check(!Rules.Match(r, "image", "", "app.exe", "Cls"), "a regex condition cannot match an image")
```

`tests/rules_flow.ahk`: a step that installs `on=1;kinds=image;action=channel:1;name=shots`, copies an image the way `tests/image.ahk` does, and checks the clip landed in channel 1 with the active channel unchanged. Restore the rules exactly as the file already does at the end.

- [ ] **Step 2: Run it to verify it fails**

Run `tests/rules.ahk`: the three checks may already pass, because `Match` is kind-agnostic; keep them as regression cover and say so in the report. Run `tests/rules_flow.ahk`: the new image step FAILS (rules never run for images).

- [ ] **Step 3: Implement**

`Clipjump.ahk`, image arm: an image has no text, so rules can only be evaluated once the clip is saved. Read the text arm (`:556-616`) and mirror its variable names, its toast and its `API.manageClip` call rather than inventing new ones:

```ahk
			; rules for images: kind "image" and no text, so a regex condition never matches
			imgRule := (!ISACTIVEEXCEL && NOINCOGNITO) ? Rules.Evaluate(Rules.List, "image", "", winProcess, winClass) : ""
			if (imgRule != "") {
				switch imgRule["action"] {
					case "ignore":
						try FileDelete(CLIPS_dir "/" CURSAVE ".avc")
						try FileDelete(THUMBS_dir "/" CURSAVE ".jpg")
						CURSAVE -= 1, TEMPSAVE := CURSAVE
						Toast.Show(TXT.RUL_ignored, 1200, "warn", "copy")
						return
					case "tag":
						AddClipPref(CN.NG, CURSAVE, "Tags", imgRule["arg"]), Prefs2Ini()
					case "channel":
						; the same call and toast the text arm makes
				}
			}
```

Place it after `thumbGenerator()` and the history insert, so an ignored image leaves nothing behind; `transform` is skipped for images.

Fix the pre-existing bug in the text arm while you are here: its `tag` case (`:589`) writes the pref without `Prefs2Ini()`, so a rule-applied tag is lost on restart.

`src/ui/native/RuleDialog.ahk`: when the action is `transform`, show a muted line saying it applies to text clips only, using a new `RUL_transformTextOnly` string.

- [ ] **Step 4: Verify**

Restart Clipjump. Run `tests/rules.ahk`, `tests/rules_flow.ahk`, `tests/image.ahk`. By hand: a rule that tags images `shot`, copy a screenshot, confirm the tag shows on the paste card and survives a restart; an ignore rule for images leaves no `.avc` and no thumbnail. Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add Clipjump.ahk src/ui/native/RuleDialog.ahk languages/english.txt tests/rules.ahk tests/rules_flow.ahk
git commit -m "Rules: images can be routed, tagged and ignored"
```

---

### Task 6: Help and the full suite

**Files:**
- Modify: `ui/help/topics/tasks.html`, `ui/help/topics/reference-rules.html`, `ui/help/topics/trouble.html`

**Interfaces:**
- Consumes: the generated kinds and actions tables, which pick up the new kinds automatically.

- [ ] **Step 1: Update the help content**

House style: short paragraphs, second person, keys as `<kbd>`, no screenshots, every claim checked against the code.

- "Work with images" gains what an image clip can now do: it has a kind, records its size, offers Open in image editor and Copy as data URI, and can be routed or tagged by a rule.
- A short SVG entry: copied SVG markup is recognized as its own kind and offers SVGOMG, the vector editor and a data URI.
- The rules topic says transform applies to text clips only.
- The troubleshooting topic gains the two failure cases: no editor configured, and an image too large for a data URI.

- [ ] **Step 2: Verify the help**

Open `ui/help/index.html` in Chrome against the mock bridge and read the changed topics; run `tests/help_flow.ahk`.

- [ ] **Step 3: Full suite**

`bash tests/run-all.sh` on an idle desktop. Everything must pass except the known `tests/rules_flow.ahk` weather; if that suite fails, say whether the failing checks are the pre-existing channel-routing ones or the new image step.

- [ ] **Step 4: Commit**

```bash
git add ui/help
git commit -m "Help: image and SVG clips"
```

---

## Self-review

- **Spec coverage:** kinds (Tasks 1 and 2), dimensions (Task 2), actions and the vector-editor setting (Task 3), the surfaces (Task 4), rules and tags (Task 5), help and the suite (Task 6).
- **Interface consistency:** `ClipType.Run(id, text, ref := "")` is called with three arguments from `ClipType_RunLater/RunNow`, `HistoryWin.Action`, `OrganizerWin.Action` and the toast binding; `ImageClip.Temp/PngFrom/DataUri/SvgDataUri/Base64` keep the names used in Task 3; `addHistoryImage(imgpath, timestamp, kind, w, h)` matches its only caller; the clip pref is `Dim` everywhere; the test hooks `ClipType_KindOf`, `Image_DimOf` and `Image_LastHistoryDims` are plain file-level functions.
- **Known judgment calls:** a data URI for a stored clip comes from the lossy thumbnail JPEG, because the lossless source exists only while the image is still on the clipboard; the 2 MB cap is a guess and may want tuning against real screenshots.
