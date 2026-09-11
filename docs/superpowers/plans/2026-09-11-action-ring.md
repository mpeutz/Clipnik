# Action Ring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the paste-mode format menu (Z) and Action Mode (Ctrl+Shift+A) with a radial ring at the pointer, picked by flick-and-release, click, or the existing letters.

**Architecture:** A pure geometry class (`RingGeom`) and a GDI+ layered-window renderer with input handling (`Ring`), exposing one blocking call, `Ring.Pick(items, opts) -> key`, shaped like the `Hud.Menu` it replaces. The two call sites (`Formatting()` and `actionmode_run()` in `Clipjump.ahk`) swap `Hud.Menu` for `Ring.Pick` and keep their existing dispatch on the returned key.

**Tech Stack:** AutoHotkey v2.0.27 (`runtime/AutoHotkey64.exe`), GDI+ through the vendored `lib/vendor/Gdip_All.ahk` plus direct `gdiplus` DllCalls, Lucide icons from `icons/lucide.ttf`. Tests are AHK scripts under `tests/` run with `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/<name>.ahk` from Git Bash.

**Spec:** `docs/superpowers/specs/2026-09-11-action-ring-design.md` (visual reference: `design/phase7/build.mjs`, direction A).

## Global Constraints

- AHK v2 only. A static field and a static method of one class must not share a name (case-insensitive). Functions that read globals declare them. `=` compares case-insensitively, `==` case-sensitively.
- The ring window never takes focus: `WS_EX_NOACTIVATE` (`+E0x08000000`), shown with `ShowWindow(hwnd, 4)` (SW_SHOWNOACTIVATE), hidden with `ShowWindow(hwnd, 0)`. Never `Gui.Show()` (it can move and activate the window).
- Sizes at 100% DPI (multiply by `Theme.Scale`): outer radius 148, inner radius 56, an even gap of 8 (between wedges and between the hub and the ring, so the hub radius is 48), corner fillet 8, shadow 10, flick travel 30, tap threshold 300 ms. Gaps are parallel-sided (constant width from hub to rim), not angular.
- Wedge text is one word: an item's `short` (else the first word of its `label`) in 10px bold on one line, trimmed with an ellipsis to the wedge's chord at mid-band minus the gap and 14px; its key chip below in 9px. The full `label` and the `desc` show in the hub on hover: title 12px bold, description 10px (at most two lines, ellipsis), the keys line 9px.
- Key states are read logically (`GetKeyState(key)` without `"P"`), so scripted tests drive the same code as a person.
- Hotkeys the ring registers use `"On T2"` and are released with `"Off T1"` (a key whose thread is parked in `Ring.Pick` must still accept a second press, and `T2` must not outlive the ring).
- `RunFunc` in `lib/customizer.ahk` misroutes dotted names to `API.*`; test hooks are plain file-level functions (`Ring_IsOpen`, `Ring_WedgePoint`, `Ring_LabelAt`).
- New user-visible strings go to `languages/english.txt` as `KEY = text`, read as `TXT.KEY`. Check the file's encoding first; if it is not UTF-8, write ASCII (`-` instead of `·`, `...` instead of `…`).
- File encodings and line endings stay as they are: `src/ui/native/*.ahk` are CRLF without a BOM; `Clipjump.ahk` is CRLF; new `src/ui/native` files follow suit. Verify with a byte check, not git-bash text tools (the Edit tool can flatten CRLF to LF; restore it if so).
- Validate (`MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut /validate Clipjump.ahk`) exits 0 with only the known noise: four WebView2 vendor warnings and one pre-existing SettingsWin warning.
- Interactive tests need an idle desktop and a running Clipjump restarted on the new code: `powershell -NoProfile -Command "Start-Process -FilePath '.\runtime\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut','Clipjump.ahk'"`, wait 8 s. A headless run that hangs more than 30 s is an error dialog: `tasklist /V | findstr AutoHotkey`, kill only the newest PID, never the user's live Clipjump. Never drive Notepad. Never edit or checkout `settings.ini`.
- Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

## File map

| File | Responsibility |
|---|---|
| `src/ui/native/RingGeom.ahk` (new) | Pure geometry: sizes, angles, hit zones, wedge arcs and points, pages, clamping |
| `src/ui/native/Ring.ahk` (new) | GDI+ fonts and painting, the layered window, input polling, `Ring.Pick`, test hooks |
| `Clipjump.ahk` | includes; `Formatting()` and `Formatting_Items()` use the ring; `actionmode_run()` and new `ActionRing_Items()` / `ActionRing_Trigger()` |
| `src/core/transforms.ahk` | each built-in format gets a `desc` and a `short` |
| `plugins/pformat.noformatting.ahk`, `pformat.commonformats.ahk`, `pformat.sentencecase.ahk` | a `;@Plugin-Short` header: the one-word wedge label |
| `languages/english.txt` | `RNG_*`, `TRF_desc_*` and `TRF_short_*` strings |
| `tests/ring_geom.ahk` (new, unit), `tests/ring_demo.ahk` (new, renders PNGs), `tests/ring_pick.ahk` (new, drives `Ring.Pick` in-process) | |
| `tests/pastemode.ahk`, `tests/hud_live.ahk`, `tests/run-all.sh` | switch the Z and Action Mode steps to the ring |

---

### Task 1: RingGeom

**Files:**
- Create: `src/ui/native/RingGeom.ahk`, `tests/ring_geom.ahk`
- Modify: `Clipjump.ahk` (include after the `Hud.ahk` include line), `tests/run-all.sh`

**Interfaces:**
- Produces: `RingGeom.Sizes(scale) -> {r1, r0, gap, corner, hub, shadow, travel}`; `RingGeom.Angle(dx, dy) -> Float`; `RingGeom.Hit(dx, dy, n, sizes) -> {zone, index}` (zone `"hub"|"ring"|"outside"`, index 0-based or -1); `RingGeom.WedgeArcs(i, n, r0, r1, gap, corner) -> Array of {cx, cy, r, start, sweep}` (relative to the centre, GDI+ degrees: 0 = 3 o'clock, clockwise); `RingGeom.Point(i, n, radius) -> [dx, dy]`; `RingGeom.Pages(items, cap := 8) -> Array of Arrays` (nav entries are `{nav: "more"}` / `{nav: "back"}`); `RingGeom.Clamp(x, y, rad, l, t, r, b) -> [cx, cy]`; constant `RingGeom.TapMs := 300`. All indices 0-based.

- [ ] **Step 1: Write the failing test**

`tests/ring_geom.ahk`:

```ahk
; Unit tests for src/ui/native/RingGeom.ahk (pure geometry of the action ring).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\ring_geom.ahk
#Requires AutoHotkey v2.0
#Include ..\src\ui\native\RingGeom.ahk

fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
near(a, b, tol := 0.01) => Abs(a - b) <= tol

check(near(RingGeom.Angle(0, -10), 0), "up is 0")
check(near(RingGeom.Angle(10, 0), 90), "right is 90")
check(near(RingGeom.Angle(0, 10), 180), "down is 180")
check(near(RingGeom.Angle(-10, 0), 270), "left is 270")
check(near(RingGeom.Angle(-1, -1000), 359.94, 0.01), "just left of up wraps below 360")

s := RingGeom.Sizes(1)
check(s.r1 = 148 && s.r0 = 56 && s.gap = 8 && s.corner = 8 && s.hub = 48 && s.shadow = 10 && s.travel = 30, "sizes at 100%")
s15 := RingGeom.Sizes(1.5)
check(s15.r1 = 222 && s15.r0 = 84 && s15.gap = 12 && s15.hub = 72 && s15.corner = 12 && s15.travel = 45, "sizes at 150%")

pol(deg, r) => [r * Sin(deg * 0.017453292519943295), -r * Cos(deg * 0.017453292519943295)]
idx(deg, n) {
    p := pol(deg, 100)
    return RingGeom.Hit(p[1], p[2], n, RingGeom.Sizes(1)).index
}
check(idx(0, 8) = 0 && idx(22, 8) = 0 && idx(23, 8) = 1 && idx(44, 8) = 1, "8 wedges: nearest by angle")
check(idx(338, 8) = 0 && idx(337, 8) = 7, "8 wedges: wrap at 0")
check(idx(89, 6) = 1 && idx(91, 6) = 2 && idx(359, 6) = 0, "6 wedges")
check(idx(17, 10) = 0 && idx(19, 10) = 1 && idx(342, 10) = 0, "10 wedges")

h := RingGeom.Hit(0, -20, 8, s)
check(h.zone = "hub" && h.index = -1, "inside the hub")
h := RingGeom.Hit(100, 0, 8, s)
check(h.zone = "ring" && h.index = 2, "on the ring, right is wedge 2 of 8")
h := RingGeom.Hit(0, -155, 8, s)
check(h.zone = "ring", "the shadow band still counts as the ring")
h := RingGeom.Hit(0, -300, 8, s)
check(h.zone = "outside" && h.index = -1, "outside")

arcs := RingGeom.WedgeArcs(0, 8, 52, 148, 5, 0)
check(arcs.Length = 2, "no corner radius: just the two main arcs")
check(near(arcs[1].start, 248.47, 0.05) && near(arcs[1].sweep, 43.06, 0.05), "outer arc of wedge 0 leaves an even 5px gap")
check(near(arcs[2].sweep, -39.49, 0.05), "inner arc runs back, shortened by the same 5px")
arcs := RingGeom.WedgeArcs(2, 8, 52, 148, 5, 7)
check(arcs.Length = 6, "rounded: six arcs")
rad(deg) => deg * 0.017453292519943295
endPt(a) => [a.cx + a.r * Cos(rad(a.start + a.sweep)), a.cy + a.r * Sin(rad(a.start + a.sweep))]
startPt(a) => [a.cx + a.r * Cos(rad(a.start)), a.cy + a.r * Sin(rad(a.start))]
ok := true
for j in [[1, 2], [3, 4], [4, 5], [6, 1]] {
    e := endPt(arcs[j[1]]), b := startPt(arcs[j[2]])
    if (Abs(e[1] - b[1]) > 0.01 || Abs(e[2] - b[2]) > 0.01)
        ok := false
}
check(ok, "fillets meet the main arcs without a step")
fil := true
for k in [2, 3, 5, 6]
    if !(arcs[k].r = 7 && arcs[k].sweep > 0 && arcs[k].sweep < 180)
        fil := false
check(fil, "four 7px fillets, each a short clockwise turn")
nb := [Cos(rad(112.5)), Sin(rad(112.5))]   ; normal of wedge 2's end ray (ring angle 112.5)
p1 := endPt(arcs[2]), p2 := startPt(arcs[3])   ; both ends of the straight side between them
check(near(Abs(p1[1] * nb[1] + p1[2] * nb[2]), 2.5) && near(Abs(p2[1] * nb[1] + p2[2] * nb[2]), 2.5), "the side runs parallel to its ray, half a gap in")
arcs := RingGeom.WedgeArcs(0, 10, 52, 148, 5, 14)
check(arcs[2].r < 14, "a corner too large for a narrow wedge is clamped")
pt := RingGeom.Point(2, 8, 100)
check(near(pt[1], 100) && near(pt[2], 0), "point of wedge 2 of 8 is to the right")

mk(n) {
    out := []
    loop n
        out.Push({key: Chr(64 + A_Index)})
    return out
}
pg := RingGeom.Pages(mk(5))
check(pg.Length = 1 && pg[1].Length = 5, "5 items: one page, no nav")
pg := RingGeom.Pages(mk(8))
check(pg.Length = 1 && pg[1].Length = 8, "8 items: one page, no nav")
pg := RingGeom.Pages(mk(9))
check(pg.Length = 2 && pg[1].Length = 8 && pg[1][8].nav = "more" && pg[2].Length = 3 && pg[2][3].nav = "back", "9 items: 7 + More, 2 + Back")
pg := RingGeom.Pages(mk(14))
check(pg.Length = 2 && pg[2].Length = 8 && pg[2][8].nav = "back" && pg[2][7].key = "N", "14 items: two full pages")
pg := RingGeom.Pages(mk(17))
check(pg.Length = 3 && pg[2][8].nav = "more" && pg[3].Length = 4 && pg[3][4].nav = "back", "17 items: three pages")

c := RingGeom.Clamp(500, 500, 160, 0, 0, 1920, 1040)
check(c[1] = 500 && c[2] = 500, "clamp leaves a centred ring alone")
c := RingGeom.Clamp(10, 1030, 160, 0, 0, 1920, 1040)
check(c[1] = 160 && c[2] = 880, "clamp at the bottom-left corner")
c := RingGeom.Clamp(1915, 5, 160, 0, 0, 1920, 1040)
check(c[1] = 1760 && c[2] = 160, "clamp at the top-right corner")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
```

- [ ] **Step 2: Run it to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/ring_geom.ahk`
Expected: load error for the missing include, exit code 2.

- [ ] **Step 3: Implement**

`src/ui/native/RingGeom.ahk` (CRLF, no BOM):

```ahk
; RingGeom.ahk - pure geometry for the action ring: sizes, angles, hit zones, wedge arcs, pages and clamping.
; Angles are degrees, 0 = 12 o'clock, clockwise, screen y down. Wedge i (0-based) of n is centred on i * 360 / n.

class RingGeom {
	static TapMs := 300

	; radii and distances in physical pixels for a DPI scale; the hub sits one gap inside the ring
	static Sizes(scale := 1) {
		r0 := Round(56 * scale), gap := Round(8 * scale)
		return {r1: Round(148 * scale), r0: r0, gap: gap, corner: Round(8 * scale), hub: r0 - gap
			, shadow: Round(10 * scale), travel: Round(30 * scale)}
	}

	static Angle(dx, dy) {
		a := RingGeom.Atan2(dx, -dy) * 57.29577951308232
		return a < 0 ? a + 360 : a
	}

	; atan2(y, x) in radians; AutoHotkey has no built-in
	static Atan2(y, x) {
		if (x > 0)
			return ATan(y / x)
		if (x < 0)
			return ATan(y / x) + (y >= 0 ? 3.141592653589793 : -3.141592653589793)
		return y > 0 ? 1.5707963267948966 : (y < 0 ? -1.5707963267948966 : 0)
	}

	; zone "hub" inside the hub, "ring" out to the edge of the shadow, else "outside"; index is the nearest
	; wedge by angle (no dead gaps between wedges), -1 unless the zone is "ring"
	static Hit(dx, dy, n, s) {
		dist := Sqrt(dx * dx + dy * dy)
		if (dist < s.hub)
			return {zone: "hub", index: -1}
		if (dist > s.r1 + s.shadow)
			return {zone: "outside", index: -1}
		return {zone: "ring", index: Mod(Round(RingGeom.Angle(dx, dy) / (360 / n)), n)}
	}

	; the arcs of wedge i in drawing order, relative to the centre, in GDI+ degrees (0 = 3 o'clock, clockwise):
	; outer arc, outer-end fillet, inner-end fillet, inner arc (reversed), inner-start fillet, outer-start fillet.
	; GDI+ joins consecutive arcs with straight lines, which become the two sides. The sides run parallel to the
	; wedge's boundary rays half a gap in, so neighbours are separated by an even gap from hub to rim. A corner
	; too large for a narrow wedge is clamped; a zero corner returns only the two main arcs.
	static WedgeArcs(i, n, r0, r1, gap, corner) {
		step := 360 / n, a0 := i * step - step / 2, a1 := i * step + step / 2
		rad := Max(0, Min(corner, 0.3 * r0 * (6.283185307179586 / n), (r1 - r0) / 2 - 2))
		d := gap / 2
		AO := RingGeom.Corner(a0, 1, r1, true, d, rad), BO := RingGeom.Corner(a1, -1, r1, true, d, rad)
		BI := RingGeom.Corner(a1, -1, r0, false, d, rad), AI := RingGeom.Corner(a0, 1, r0, false, d, rad)
		out := [RingGeom.ArcFrom(0, 0, r1, AO.onArc, BO.onArc, 1)]
		if (rad >= 0.5)
			out.Push(RingGeom.ArcFrom(BO.cx, BO.cy, rad, BO.onArc, BO.onLine, 1), RingGeom.ArcFrom(BI.cx, BI.cy, rad, BI.onLine, BI.onArc, 1))
		out.Push(RingGeom.ArcFrom(0, 0, r0, BI.onArc, AI.onArc, -1))
		if (rad >= 0.5)
			out.Push(RingGeom.ArcFrom(AI.cx, AI.cy, rad, AI.onArc, AI.onLine, 1), RingGeom.ArcFrom(AO.cx, AO.cy, rad, AO.onLine, AO.onArc, 1))
		return out
	}

	; fillet between the side parallel to ray a (offset d into the wedge; sign 1 = the wedge lies clockwise of
	; the ray) and the circle of radius R (outer: the fillet sits inside it, else outside). Returns the fillet's
	; centre and its tangent points on the side and on the circle; with rad 0 both points are the sharp corner.
	static Corner(a, sign, R, outer, d, rad) {
		t0 := a * 0.017453292519943295
		ex := Sin(t0), ey := -Cos(t0), nx := sign * Cos(t0), ny := sign * Sin(t0)
		cr := outer ? R - rad : R + rad, off := d + rad
		t := Sqrt(Max(cr * cr - off * off, 0))
		cx := ex * t + nx * off, cy := ey * t + ny * off
		len := Sqrt(cx * cx + cy * cy)
		return {cx: cx, cy: cy, onLine: [ex * t + nx * d, ey * t + ny * d], onArc: [cx / len * R, cy / len * R]}
	}

	; arc on the circle (cx, cy, r) from point p to point q; dir 1 = clockwise on screen, -1 = counter-clockwise
	static ArcFrom(cx, cy, r, p, q, dir) {
		s := RingGeom.Deg(p[1] - cx, p[2] - cy), e := RingGeom.Deg(q[1] - cx, q[2] - cy)
		return {cx: cx, cy: cy, r: r, start: s, sweep: dir * Mod(dir * (e - s) + 720, 360)}
	}

	; GDI+ angle of a vector: 0 = +x, clockwise on screen, 0 <= a < 360
	static Deg(x, y) {
		a := RingGeom.Atan2(y, x) * 57.29577951308232
		return a < 0 ? a + 360 : a
	}

	static Point(i, n, radius) {
		a := i * 360 / n * 0.017453292519943295
		return [radius * Sin(a), -radius * Cos(a)]
	}

	; one page when it fits, else pages of cap - 1 items each ending with a More or (last page) Back entry
	static Pages(items, cap := 8) {
		if (items.Length <= cap)
			return [items.Clone()]
		pages := [], i := 1
		while (i <= items.Length) {
			page := []
			loop cap - 1 {
				if (i > items.Length)
					break
				page.Push(items[i++])
			}
			page.Push({nav: i > items.Length ? "back" : "more"})
			pages.Push(page)
		}
		return pages
	}

	; centre that keeps a disc of radius rad inside the rectangle
	static Clamp(x, y, rad, l, t, r, b) => [Max(l + rad, Min(x, r - rad)), Max(t + rad, Min(y, b - rad))]
}
```

`Clipjump.ahk`: right after the line `#Include %A_ScriptDir%\src\ui\native\Hud.ahk` add

```ahk
#Include %A_ScriptDir%\src\ui\native\RingGeom.ahk
```

`tests/run-all.sh`: add `run ring_geom.ahk;` to the unit line after `run rules.ahk;`.

- [ ] **Step 4: Verify**

Run `tests/ring_geom.ahk`: ALL PASSED. Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/ui/native/RingGeom.ahk tests/ring_geom.ahk Clipjump.ahk tests/run-all.sh
git commit -m "Action ring: geometry with unit tests"
```

---

### Task 2: Ring rendering

**Files:**
- Create: `src/ui/native/Ring.ahk` (rendering part), `tests/ring_demo.ahk`
- Modify: `Clipjump.ahk` (include after RingGeom), `languages/english.txt` (the four strings the renderer reads)

**Interfaces:**
- Consumes: `RingGeom.*`, `Theme.Palette` (Map name -> RGB int: bg, surface, surfaceAlt, text, muted, accent, accentText, accentSoft), `Theme.Scale`, `Theme.FontName`, `Theme.IconFont`, `Theme.Mix(a, b, t)`, `Theme.Icon(name)`, Gdip_All functions (`Gdip_Startup`, `Gdip_CreatePath`, `Gdip_FillPath`, `Gdip_DeletePath`, `Gdip_BrushCreateSolid`, `Gdip_DeleteBrush`, `Gdip_CreatePen`, `Gdip_DeletePen`, `Gdip_FillEllipse`, `Gdip_SetSmoothingMode`, `Gdip_SetTextRenderingHint`, `Gdip_CreateBitmap`, `Gdip_GraphicsFromImage`, `Gdip_GraphicsClear`, `Gdip_SaveBitmapToFile`, `Gdip_DeleteGraphics`, `Gdip_DisposeImage`, `CreateDIBSection`, `CreateCompatibleDC`, `SelectObject`, `DeleteObject`, `DeleteDC`, `Gdip_GraphicsFromHDC`, `UpdateLayeredWindow`).
- Produces: `Ring.State(items, hover, hubTitle, hubSub, titleAccent := false) -> state`; `Ring.Paint(G, state, ox, oy)`; `Ring.RenderToFile(state, path)`; `Ring.NavLabel(nav)`. Items: `{key, label, short?, desc?, icon? (a glyph character), active?, dim?}` or nav `{nav: "more"|"back"}`; `Ring.Short(item)` -> the wedge word.

- [ ] **Step 1: Write the demo (the visual test)**

`tests/ring_demo.ahk` renders into `tests/out/`. Bootstrap it the way `tests/hud_demo.ahk` does (read that file's first 50 lines: includes, stubs, how it loads `TXT` from `languages/english.txt`, and `Theme.Init(mode, accent)`), including `..\src\ui\native\RingGeom.ahk` and `..\src\ui\native\Ring.ahk`. Then:

```ahk
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
}
FileAppend("done`n", "*")
ExitApp
```

- [ ] **Step 2: Run it to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/ring_demo.ahk`
Expected: load error for the missing `Ring.ahk`.

- [ ] **Step 3: Implement the renderer**

Add to `languages/english.txt` (next to the other recent blocks; mind the encoding constraint):

```
RNG_keys = release · click · Esc
RNG_more = More
RNG_back = Back
RNG_moreDesc = the next page
RNG_backDesc = back to the first page
```

`src/ui/native/Ring.ahk` (CRLF, no BOM). This task writes the class header and the rendering methods; Task 3 adds the window and input to the same class.

```ahk
; Ring.ahk - the action ring: a round, per-pixel-alpha popup at the pointer that replaces the list menus
; (the paste-mode format menu and Action Mode).
;
;   Ring.Pick(items, opts) -> the picked item's key, or "" when cancelled (blocking, like Hud.Menu)
;   Ring.RenderToFile(state, path)   paints one ring onto an opaque background (tests)
;
; Painted with GDI+ into a 32-bit DIB and shown with UpdateLayeredWindow, so wedges are true arcs with
; antialiased edges and the shadow is part of the bitmap. Hit testing is RingGeom arithmetic on the pointer.

class Ring {
	static token := 0, fonts := ""

	; GDI+ stays started for the life of the process once a ring has been drawn
	static Start() {
		if !Ring.token
			Ring.token := Gdip_Startup()
	}

	; {text, icon}: GDI+ font families. The icon family comes from a private collection because the GDI private
	; font Clipjump registers at startup is invisible to GDI+.
	static Fonts() {
		if IsObject(Ring.fonts)
			return Ring.fonts
		Ring.Start()
		f := {text: 0, icon: 0, coll: 0}
		fam := 0
		DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", Theme.FontName, "Ptr", 0, "Ptr*", &fam)
		if !fam
			DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
		f.text := fam
		path := A_WorkingDir "\icons\lucide.ttf"
		if FileExist(path) {
			coll := 0, ifam := 0
			DllCall("gdiplus\GdipNewPrivateFontCollection", "Ptr*", &coll)
			DllCall("gdiplus\GdipPrivateAddFontFile", "Ptr", coll, "WStr", path)
			DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", Theme.IconFont, "Ptr", coll, "Ptr*", &ifam)
			f.coll := coll, f.icon := ifam
		}
		return Ring.fonts := f
	}

	; everything Paint needs for one ring; hover is 0-based, -1 for none
	static State(items, hover, hubTitle, hubSub, titleAccent := false) {
		iconRing := false
		for it in items
			if (it.HasProp("icon") && it.icon != "")
				iconRing := true
		return {items: items, hover: hover, hubTitle: hubTitle, hubSub: hubSub, titleAccent: titleAccent
			, iconRing: iconRing, pal: Theme.Palette, s: RingGeom.Sizes(Theme.Scale), k: Theme.Scale}
	}

	static NavLabel(nav) {
		global TXT
		return nav = "more" ? TXT.RNG_more : TXT.RNG_back
	}

	; side of the square bitmap that holds one ring and its shadow
	static Side(s) => 2 * (s.r1 + s.shadow + 2)

	static RenderToFile(st, path) {
		D := Ring.Side(st.s)
		Ring.Start()
		bmp := Gdip_CreateBitmap(D, D), G := Gdip_GraphicsFromImage(bmp)
		Gdip_GraphicsClear(G, 0xFF000000 | st.pal["bg"])
		Ring.Paint(G, st, D / 2, D / 2)
		Gdip_SaveBitmapToFile(bmp, path)
		Gdip_DeleteGraphics(G), Gdip_DisposeImage(bmp)
	}

	; paints one ring centred on (ox, oy)
	static Paint(G, st, ox, oy) {
		p := st.pal, s := st.s, k := st.k, n := st.items.Length
		Gdip_SetSmoothingMode(G, 4)
		Gdip_SetTextRenderingHint(G, 4)       ; grayscale: ClearType fringes on a transparent bitmap
		loop 5                                 ; soft shadow
			Ring.Disc(G, ox, oy, s.r1 + s.shadow - (A_Index - 1) * Round(2 * k), (A_Index * 9) << 24)
		Ring.Disc(G, ox, oy, s.r1 + 1, 0x02000000)   ; nearly invisible: the gaps between wedges catch the pointer
		for i, it in st.items {
			idx := i - 1, hot := (idx = st.hover)
			stroke := (!hot && it.HasProp("active") && it.active) ? 0xFF000000 | p["accent"] : 0
			Ring.Wedge(G, ox, oy, idx, n, s, 0xFF000000 | Ring.Fill(it, hot, p), stroke)
			Ring.WedgeContent(G, st, it, idx, n, hot, ox, oy)
		}
		Ring.Disc(G, ox, oy, s.hub, 0xFF000000 | p["surface"])
		pen := Gdip_CreatePen(0x1A000000 | p["text"], 1)
		DllCall("gdiplus\GdipDrawEllipse", "Ptr", G, "Ptr", pen, "Float", ox - s.hub, "Float", oy - s.hub, "Float", 2 * s.hub, "Float", 2 * s.hub)
		Gdip_DeletePen(pen)
		Ring.Hub(G, st, ox, oy)
	}

	static Fill(it, hot, p) {
		if hot
			return p["accent"]
		if (it.HasProp("active") && it.active)
			return p["accentSoft"]
		if it.HasProp("nav")
			return p["surface"]
		if (it.HasProp("dim") && it.dim)
			return Theme.Mix(p["surfaceAlt"], p["bg"], 0.5)
		return p["surfaceAlt"]
	}

	; one word per wedge on one line, trimmed to the wedge's width, with its key chip below; icon rings stack a
	; 16px icon above the word. Everything sits on the middle of the band.
	static WedgeContent(G, st, it, idx, n, hot, ox, oy) {
		p := st.pal, s := st.s, k := st.k, f := Ring.Fonts()
		mid := s.r0 + (s.r1 - s.r0) / 2
		w := Floor(2 * mid * Sin(3.141592653589793 / n) - s.gap - 14 * k)
		isNav := it.HasProp("nav")
		muted := isNav || (it.HasProp("dim") && it.dim)
		fg := 0xFF000000 | (hot ? p["accentText"] : (muted ? p["muted"] : p["text"]))
		label := isNav ? Ring.NavLabel(it.nav) : Ring.Short(it)
		key := isNav ? (it.nav = "more" ? "→" : "←") : it.key
		c := RingGeom.Point(idx, n, mid), x := ox + c[1], y := oy + c[2]
		if st.iconRing {
			if (!isNav && it.HasProp("icon") && it.icon != "" && f.icon)
				Ring.Text(G, it.icon, f.icon, 16 * k, false, 0xFF000000 | (hot ? p["accentText"] : p["muted"])
					, x - 12 * k, y - 28 * k, 24 * k, 24 * k)
			Ring.Text(G, label, f.text, 10 * k, true, fg, x - w / 2, y - 7 * k, w, 16 * k, true)
			Ring.Chip(G, key, x, y + 9 * k, hot, p, k)
		} else {
			Ring.Text(G, label, f.text, 10 * k, true, fg, x - w / 2, y - 16 * k, w, 16 * k, true)
			Ring.Chip(G, key, x, y, hot, p, k)
		}
	}

	; the wedge word: the item's short label, else the first word of its label
	static Short(it) {
		if (it.HasProp("short") && it.short != "")
			return it.short
		return StrSplit(it.label, " ")[1]
	}

	; the hub: the full name, its description (two lines at most) and the keys line, one gap inside the hub's edge
	static Hub(G, st, ox, oy) {
		global TXT
		p := st.pal, k := st.k, f := Ring.Fonts(), w := 2 * st.s.hub - 8 * k
		Ring.Text(G, st.hubTitle, f.text, 12 * k, true, 0xFF000000 | (st.titleAccent ? p["accent"] : p["text"]), ox - w / 2, oy - 31 * k, w, 30 * k)
		Ring.Text(G, st.hubSub, f.text, 10 * k, false, 0xFF000000 | p["muted"], ox - w / 2, oy, w, 25 * k)
		Ring.Text(G, TXT.RNG_keys, f.text, 9 * k, false, 0xFF000000 | p["muted"], ox - w / 2, oy + 25 * k, w, 12 * k)
	}

	; key hint centred on cx, top edge at top
	static Chip(G, key, cx, top, hot, p, k) {
		if (key = "")
			return
		w := Max(14, 8 + 6 * StrLen(key)) * k, h := 13 * k
		Ring.RoundRect(G, cx - w / 2, top, w, h, 4 * k, hot ? 0x29000000 : 0xFF000000 | p["surface"])
		Ring.Text(G, key, Ring.Fonts().text, 9 * k, true, 0xFF000000 | (hot ? p["accentText"] : p["muted"]), cx - w / 2, top, w, h)
	}

	; wedge idx of n as a rounded ring sector with even gaps (RingGeom.WedgeArcs), centred on (ox, oy)
	static Wedge(G, ox, oy, idx, n, s, argb, strokeArgb := 0) {
		path := Gdip_CreatePath()
		for a in RingGeom.WedgeArcs(idx, n, s.r0, s.r1, s.gap, s.corner)
			DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", ox + a.cx - a.r, "Float", oy + a.cy - a.r, "Float", 2 * a.r, "Float", 2 * a.r, "Float", a.start, "Float", a.sweep)
		DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillPath(G, br, path)
		Gdip_DeleteBrush(br)
		if strokeArgb {
			pen := Gdip_CreatePen(strokeArgb, 1)
			DllCall("gdiplus\GdipDrawPath", "Ptr", G, "Ptr", pen, "Ptr", path)
			Gdip_DeletePen(pen)
		}
		Gdip_DeletePath(path)
	}

	static Disc(G, cx, cy, r, argb) {
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillEllipse(G, br, cx - r, cy - r, 2 * r, 2 * r)
		Gdip_DeleteBrush(br)
	}

	static RoundRect(G, x, y, w, h, r, argb) {
		path := Gdip_CreatePath(), d := 2 * r
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
		DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
		DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
		br := Gdip_BrushCreateSolid(argb)
		Gdip_FillPath(G, br, path)
		Gdip_DeleteBrush(br), Gdip_DeletePath(path)
	}

	; centred text in a box; size in pixels. Only whole lines that fit are drawn and the last one ends in an ellipsis
	; when the text runs over; oneLine keeps it to a single line cut with an ellipsis at the box's width.
	static Text(G, text, fam, size, bold, argb, x, y, w, h, oneLine := false) {
		if (text = "" || !fam)
			return
		font := 0, fmt := 0
		DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font)
		DllCall("gdiplus\GdipCreateStringFormat", "Int", oneLine ? 0x3000 : 0x2000, "Int", 0, "Ptr*", &fmt)   ; LineLimit, + NoWrap
		DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", fmt, "Int", oneLine ? 3 : 4)                   ; ellipsis: character / word
		DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
		DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
		br := Gdip_BrushCreateSolid(argb)
		rc := Buffer(16), NumPut("Float", x, "Float", y, "Float", w, "Float", h, rc)
		DllCall("gdiplus\GdipDrawString", "Ptr", G, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", br)
		Gdip_DeleteBrush(br)
		DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
		DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
	}
}
```

`Clipjump.ahk`: after the RingGeom include add `#Include %A_ScriptDir%\src\ui\native\Ring.ahk`.

Note for the implementer: GDI+ has no semibold for most families, so labels use bold. If the demo shows text that crowds, adjust only the box offsets in `WedgeContent` and `Hub`, keeping the radii and font sizes from the constraints.

- [ ] **Step 4: Verify**

Run the demo (prints `done`). Read `tests/out/ring-dark-format.png`, `ring-dark-format-hover.png`, `ring-dark-format-hover-long.png`, `ring-dark-format-page2.png`, `ring-dark-action.png` and the light ones, and compare against the canvas (direction A): eight rounded wedges separated by even 8px gaps (the same width at the hub as at the rim, and the same gap around the hub), one word and its key chip inside each wedge with nothing spilling past a wedge's edge, the full name and description inside the hub (the Common Formats description cut with an ellipsis), the active format outlined, the hovered wedge solid accent with black text, More/Back muted, icons above labels on the action ring, the hub text inside the hub, a soft shadow. Fix what does not match. Validate: exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/ui/native/Ring.ahk tests/ring_demo.ahk Clipjump.ahk languages/english.txt
git commit -m "Action ring: GDI+ renderer and demo"
```

---

### Task 3: Ring input and Ring.Pick

**Files:**
- Modify: `src/ui/native/Ring.ahk` (window, input, `Pick`, test hooks)
- Create: `tests/ring_pick.ahk`
- Modify: `tests/run-all.sh`

**Interfaces:**
- Consumes: Task 2's `Ring.State/Paint/Side/NavLabel`, `RingGeom.*`, `Theme.WorkAreaAt(x, y, &l, &t, &r, &b)`.
- Produces: `Ring.Pick(items, opts) -> key or ""` with `opts` fields `prefix`, `trigger`, `triggerHotkey`, `dim`, `until` (Func), `idleTitle`, `idleSub`, `extraKeys` (Array); file-level `Ring_IsOpen() -> 0|1`, `Ring_WedgePoint(i) -> "x,y"`, `Ring_LabelAt(i) -> label or nav`.

- [ ] **Step 1: Write the failing test**

`tests/ring_pick.ahk` drives `Ring.Pick` in-process: timers act while `Pick` blocks. It needs an idle desktop (it moves the mouse and types into its own window).

```ahk
; Drives Ring.Pick in-process: letters, Esc, Enter, clicks, a flick, paging, until. Needs an idle desktop.
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\ring_pick.ahk
#Requires AutoHotkey v2.0
#Warn All, Off
SetWorkingDir A_ScriptDir "\.."
CoordMode "Mouse", "Screen"
SendMode "Event"
SendLevel 1
#Include ..\lib\v2compat.ahk
#Include ..\lib\vendor\Gdip_All.ahk
#Include ..\lib\translations.ahk
#Include ..\src\ui\native\Theme.ahk
#Include ..\src\ui\native\RingGeom.ahk
#Include ..\src\ui\native\Ring.ahk
; load TXT and init the theme the way tests/hud_demo.ahk does, then register the icon font the same way
fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
g := Gui("+AlwaysOnTop", "ring-pick-target"), ed := g.Add("Edit", "w300 h80")
g.Show("x100 y100"), WinWaitActive("ring-pick-target", , 5), ed.Focus()
MouseMove(900, 500, 0), Sleep(200)
items := []
for kv in [["A", "Alpha"], ["B", "Beta"], ["D", "Delta"], ["E", "Echo"], ["G", "Golf"], ["H", "Hotel"], ["I", "India"], ["J", "Juliet"], ["K", "Kilo"], ["L", "Lima"]]
    items.Push({key: kv[1], label: kv[2], desc: "item " kv[2]})
at(i) {
    xy := StrSplit(Ring_WedgePoint(i), ",")
    MouseMove(xy[1], xy[2], 3), Sleep(120)
}
later(ms, fn) => SetTimer(fn, -ms)

later(400, () => SendEvent("b"))
check(Ring.Pick(items, {prefix: ""}) = "B", "a letter picks")
check(Ring_IsOpen() = 0 && !WinExist("Clipjump_Ring ahk_class AutoHotkeyGUI"), "the ring is hidden after a pick")

later(400, () => SendEvent("{Esc}"))
check(Ring.Pick(items, {prefix: ""}) = "", "Esc cancels")

later(400, () => (at(2), SendEvent("{Enter}")))
check(Ring.Pick(items, {prefix: ""}) = "D", "Enter picks the hovered wedge")

later(400, () => (at(1), Click()))
check(Ring.Pick(items, {prefix: ""}) = "B", "a click on wedge 1 picks it")

later(400, () => (MouseMove(200, 150, 3), Sleep(100), Click()))   ; on the test's own window, outside the disc
check(Ring.Pick(items, {prefix: ""}) = "", "a click outside cancels")
MouseMove(900, 500, 0), Sleep(200)

pg := ""
PageFlip() {
    global pg
    at(7), Click(), Sleep(300)
    pg := Ring_LabelAt(0)
    SendEvent("{Esc}")
}
later(400, PageFlip)
Ring.Pick(items, {prefix: ""})
check(pg = "Juliet", "More flips to page 2: " pg)

later(400, () => SendEvent("k"))
check(Ring.Pick(items, {prefix: ""}) = "K", "a letter from page 2 picks while page 1 shows")

SendEvent("{z down}")
later(300, () => (at(3), SendEvent("{z up}")))
check(Ring.Pick(items, {prefix: "", trigger: "z"}) = "E", "a flick picks the wedge under the release")

SendEvent("{z down}")
later(120, () => SendEvent("{z up}"))
later(700, () => SendEvent("{Esc}"))
check(Ring.Pick(items, {prefix: "", trigger: "z"}) = "", "a quick tap leaves the ring open")

t0 := A_TickCount
check(Ring.Pick(items, {prefix: "", until: () => A_TickCount - t0 > 500}) = "", "until closes the ring")

later(400, () => SendEvent("5"))
check(Ring.Pick(items, {prefix: "", extraKeys: ["5"]}) = "5", "an extra key returns itself")

g.Destroy()
FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
```

The outside click lands on the test's own window on purpose: an outside click passes through to whatever is beneath the ring, and it must never be the user's editor. `PageFlip` is a named function because a fat-arrow closure cannot assign a global.

- [ ] **Step 2: Run it to verify it fails**

Run: `MSYS_NO_PATHCONV=1 ./runtime/AutoHotkey64.exe /ErrorStdOut tests/ring_pick.ahk`
Expected: error "This value of type Class has no method named Pick" (or a missing-function error for `Ring_WedgePoint`).

- [ ] **Step 3: Implement**

Add to the `Ring` class:

```ahk
	static g := "", visible := false, isOpen := false, pages := [], page := 1, hover := -1
	static cx := 0, cy := 0, sx := 0, sy := 0, held := false, openedAt := 0, lDown := false, pressZone := ""
	static result := "", done := false, opts := "", prevAlpha := ""

	static Pick(items, opts := "") {
		if Ring.isOpen
			return ""
		o := IsObject(opts) ? opts : {}
		Ring.opts := o, Ring.pages := RingGeom.Pages(items), Ring.page := 1, Ring.hover := -1
		Ring.result := "", Ring.done := false, Ring.pressZone := ""
		Ring.Window()
		MouseGetPos(&mx, &my)
		Theme.WorkAreaAt(mx, my, &l, &t, &r, &b)
		s := RingGeom.Sizes(Theme.Scale)
		c := RingGeom.Clamp(mx, my, s.r1 + s.shadow + 2, l, t, r, b)
		Ring.cx := c[1], Ring.cy := c[2], Ring.sx := mx, Ring.sy := my
		Ring.held := o.HasProp("trigger") && o.trigger != "" && GetKeyState(o.trigger)
		Ring.openedAt := A_TickCount, Ring.lDown := GetKeyState("LButton")
		if o.HasProp("dim") && o.dim {
			Ring.prevAlpha := ""
			try Ring.prevAlpha := WinGetTransparent("ahk_id " o.dim)
			try WinSetTransparent(128, "ahk_id " o.dim)
		}
		Ring.isOpen := true
		Ring.BindKeys(true)
		Ring.Draw()
		SetTimer(Ring_Tick, 16)
		while !Ring.done {
			Sleep 15
			if o.HasProp("until") && o.until.Call()
				Ring.Close("")
		}
		SetTimer(Ring_Tick, 0)
		Ring.BindKeys(false)
		DllCall("ShowWindow", "Ptr", Ring.g.Hwnd, "Int", 0)
		Ring.visible := false
		if o.HasProp("dim") && o.dim
			try WinSetTransparent(Ring.prevAlpha = "" ? "Off" : Ring.prevAlpha, "ahk_id " o.dim)
		Ring.isOpen := false
		return Ring.result
	}

	; one reusable layered, never-activated window; UpdateLayeredWindow sizes and places it
	static Window() {
		if Ring.g
			return
		Ring.g := Gui("-Caption +E0x80000 +E0x08000000 +AlwaysOnTop +ToolWindow -DPIScale +Owner" A_ScriptHwnd, "Clipjump_Ring")
	}

	static Draw() {
		global TXT
		items := Ring.pages[Ring.page], o := Ring.opts
		h := Ring.hover >= 0 ? items[Ring.hover + 1] : ""
		if IsObject(h) {
			isNav := h.HasProp("nav")
			title := isNav ? Ring.NavLabel(h.nav) : h.label
			sub := isNav ? (h.nav = "more" ? TXT.RNG_moreDesc : TXT.RNG_backDesc) : (h.HasProp("desc") ? h.desc : "")
			st := Ring.State(items, Ring.hover, title, sub, false)
		} else {
			sub := o.HasProp("idleSub") ? o.idleSub : ""
			if (Ring.pages.Length > 1)
				sub := sub (sub != "" ? "  ·  " : "") Ring.page "/" Ring.pages.Length
			st := Ring.State(items, -1, o.HasProp("idleTitle") ? o.idleTitle : "", sub, true)
		}
		Ring.Present(st)
	}

	static Present(st) {
		D := Ring.Side(st.s)
		Ring.Start()
		hbm := CreateDIBSection(D, D), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
		G := Gdip_GraphicsFromHDC(hdc)
		Ring.Paint(G, st, D / 2, D / 2)
		UpdateLayeredWindow(Ring.g.Hwnd, hdc, Round(Ring.cx - D / 2), Round(Ring.cy - D / 2), D, D)
		Gdip_DeleteGraphics(G), SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
		if !Ring.visible {
			DllCall("ShowWindow", "Ptr", Ring.g.Hwnd, "Int", 4)   ; SW_SHOWNOACTIVATE
			Ring.visible := true
		}
	}

	static Choose(idx) {
		it := Ring.pages[Ring.page][idx + 1]
		if it.HasProp("nav") {
			Ring.page := it.nav = "more" ? Ring.page + 1 : 1
			Ring.hover := -1, Ring.Draw()
			return
		}
		Ring.Close(it.key)
	}

	static Close(result) {
		Ring.result := result, Ring.done := true
	}

	static BindKeys(on) {
		o := Ring.opts, pre := o.HasProp("prefix") ? o.prefix : ""
		opt := on ? "On T2" : "Off T1"
		for page in Ring.pages
			for it in page
				if (!it.HasProp("nav") && it.key != "")
					Ring.BindKey(pre it.key, Ring_Key.Bind(it.key), opt)
		Ring.BindKey(pre "Esc", Ring_Esc, opt)
		Ring.BindKey(pre "Enter", Ring_Enter, opt)
		if o.HasProp("extraKeys")
			for kk in o.extraKeys
				Ring.BindKey(pre kk, Ring_Key.Bind(kk), opt)
		if (o.HasProp("triggerHotkey") && o.triggerHotkey != "")
			Ring.BindKey(o.triggerHotkey, Ring_Trigger, opt)
	}

	; Hotkey() with the vk fallback Hud.BindKey uses for letters a layout does not map by name
	static BindKey(key, fn, opt) {
		try {
			Hotkey(key, fn, opt)
			return
		}
		t := ""
		loop parse key
			t .= IsAlpha(A_LoopField) ? "vk" GetVKList(A_LoopField)[1] : A_LoopField
		try Hotkey(t, fn, opt)
	}
```

`GetVKList` is defined in the main script's libraries; in the standalone test, add a stub `GetVKList(c) => [Format("{:X}", GetKeyVK(c))]` at the top of `tests/ring_pick.ahk` if the load complains (the try-path above normally never reaches it).

Add at file level (below the class):

```ahk
Ring_Tick() {
	if !Ring.isOpen
		return
	MouseGetPos(&mx, &my)
	s := RingGeom.Sizes(Theme.Scale)
	items := Ring.pages[Ring.page]
	h := RingGeom.Hit(mx - Ring.cx, my - Ring.cy, items.Length, s)
	hover := h.zone = "ring" ? h.index : -1
	if (hover != Ring.hover) {
		Ring.hover := hover
		Ring.Draw()
	}
	; releasing the held trigger commits a flick; a quick tap without travel keeps the ring open
	if (Ring.held && !GetKeyState(Ring.opts.trigger)) {
		Ring.held := false
		moved := Sqrt((mx - Ring.sx) ** 2 + (my - Ring.sy) ** 2) >= s.travel
		if (hover >= 0 && (moved || A_TickCount - Ring.openedAt > RingGeom.TapMs))
			return Ring.Choose(hover)
	}
	; a click acts on release, and only for a press made while the ring was open
	down := GetKeyState("LButton")
	if (down && !Ring.lDown)
		Ring.pressZone := h.zone
	if (!down && Ring.lDown && Ring.pressZone != "") {
		zone := Ring.pressZone, Ring.pressZone := ""
		Ring.lDown := down
		if (zone = "outside")
			return Ring.Close("")
		if (zone = "ring" && hover >= 0)
			return Ring.Choose(hover)
	}
	Ring.lDown := down
}

Ring_Key(key, *) => Ring.Close(key)
Ring_Esc(*) => Ring.Close("")

Ring_Enter(*) {
	if (Ring.hover >= 0)
		Ring.Choose(Ring.hover)
}

; a second tap of the trigger closes the ring; auto-repeat while it is still held is ignored
Ring_Trigger(*) {
	if !Ring.held
		Ring.Close("")
}

Ring_IsOpen() => Ring.isOpen ? 1 : 0

; screen position of wedge i's centre line (mid-band) on the current page, as "x,y"
Ring_WedgePoint(i) {
	if !Ring.isOpen
		return ""
	s := RingGeom.Sizes(Theme.Scale), n := Ring.pages[Ring.page].Length
	c := RingGeom.Point(i, n, (s.r0 + s.r1) / 2)
	return Round(Ring.cx + c[1]) "," Round(Ring.cy + c[2])
}

Ring_LabelAt(i) {
	if !Ring.isOpen
		return ""
	it := Ring.pages[Ring.page][i + 1]
	return it.HasProp("nav") ? it.nav : it.label
}
```

`tests/run-all.sh`: add `run ring_pick.ahk 60;` at the start of the interactive line (it does not need Clipjump, but it needs the idle desktop the interactive block assumes).

- [ ] **Step 4: Verify**

Run `tests/ring_pick.ahk` twice: ALL PASSED both times. Validate: exit 0. While it runs, confirm by eye that the ring appears where the mouse is and never steals focus from the test window (the Edit keeps the typed `z` characters).

- [ ] **Step 5: Commit**

```bash
git add src/ui/native/Ring.ahk tests/ring_pick.ahk tests/run-all.sh
git commit -m "Action ring: input, paging and Ring.Pick"
```

---

### Task 4: The format ring replaces the Z menu

**Files:**
- Modify: `Clipjump.ahk` (`Formatting`, `Formatting_Items`, new `Formatting_Ended`), `src/core/transforms.ahk` (`Register` adds `desc` and `short`), `plugins/pformat.noformatting.ahk`, `plugins/pformat.commonformats.ahk`, `plugins/pformat.sentencecase.ahk` (a `;@Plugin-Short` header each), `languages/english.txt`, `tests/pastemode.ahk`

**Interfaces:**
- Consumes: `Ring.Pick`, `Ring_IsOpen`, `Ring_WedgePoint`, `Ring_LabelAt`, `Transforms.AppliesTo`, `set_pformat`, `hkZ_pasteMode(1)`, `Hud.g`, globals `is_pstMode_active`, `pstIdentifier`, `pastemodekey`, `curPformat`, `temp_clipboard`, `halfClip`, `curPisPreviewable`, `curPfunction`, `MSG_MORE_PREVIEW`.
- Produces: `Formatting_Items(kind) -> {items, byKey}` where items are ring items `{key, label, short, desc, active, dim}` in the fixed priority order below (formats that fit the clip's kind first), and `byKey` maps an upper-case letter to a format name (`"-original-"` for Original); pformat entries gain `desc` and `short`.

- [ ] **Step 1: Rewrite the paste-mode test steps**

In `tests/pastemode.ahk`, replace the whole Z block (from the step that opens the format menu through the step that picks Original, including the "Z then Z" checks) with:

```ahk
step("Z opens the format ring; U picks Upper case")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 600
check(cj.runFunction("Ring_IsOpen()") = 1, "Z opens the ring")
check(cj.runFunction("Ring_LabelAt(0)") = "Original" && cj.runFunction("Ring_LabelAt(1)") = "Trim Formatting", "Original then Trim Formatting lead the ring")
SendEvent("u")
Sleep 500
check(cj["curPformat"] = "Upper case", "U picked Upper case: [" cj["curPformat"] "]")
check(cj.runFunction("Ring_IsOpen()") = 0, "picking closes the ring")
SendEvent("z")
Sleep 500
SendEvent("z")
Sleep 500
check(cj.runFunction("Ring_IsOpen()") = 0, "a second tap of Z closes the ring")
SendEvent("u")
Sleep 400
check(cj["curPformat"] = "Upper case", "U after the ring closed changes nothing")
SendEvent("{Ctrl up}")
Sleep 900
check(ed.Value == StrUpper(ed.Value) && InStr(ed.Value, StrUpper(stamp), true), "pasted upper case: [" ed.Value "]")

step("a click on a wedge picks it; a flick picks it")
ed.Value := ""
SendEvent("{Ctrl down}v")
Sleep 400
SendEvent("z")
Sleep 600
xy := StrSplit(cj.runFunction("Ring_WedgePoint(2)"), ","), lbl := cj.runFunction("Ring_LabelAt(2)")
MouseMove(xy[1], xy[2], 5)
Sleep 150
Click()
Sleep 500
check(lbl != "" && cj["curPformat"] = lbl, "a click picked [" lbl "]: [" cj["curPformat"] "]")
SendEvent("{z down}")
Sleep 500
xy := StrSplit(cj.runFunction("Ring_WedgePoint(3)"), ","), lbl := cj.runFunction("Ring_LabelAt(3)")
MouseMove(xy[1], xy[2], 10)
Sleep 200
SendEvent("{z up}")
Sleep 500
check(lbl != "" && cj["curPformat"] = lbl, "a flick picked [" lbl "]: [" cj["curPformat"] "]")

step("built-in letters win over plugin letters")
SendEvent("z")
Sleep 500
SendEvent("m")
Sleep 500
check(cj["curPformat"] = "Markdown link", "M picked Markdown link: [" cj["curPformat"] "]")
SendEvent("z")
Sleep 500
SendEvent("s")
Sleep 500
check(cj["curPformat"] = "Strip URL tracking", "S picked Strip URL tracking: [" cj["curPformat"] "]")

step("O picks Original; releasing Ctrl with the ring open leaves no ring")
SendEvent("z")
Sleep 500
SendEvent("o")
Sleep 500
check(cj["curPformat"] = "", "O picked Original")
SendEvent("z")
Sleep 500
SendEvent("{Ctrl up}")
Sleep 1200
check(cj.runFunction("Ring_IsOpen()") = 0, "the ring closed with paste mode")
check(InStr(ed.Value, stamp), "the clip was pasted: [" ed.Value "]")
cj.runFunction("set_pformat()")
check(cj["curPformat"] = "", "set_pformat() resets the format")
```

Keep the rest of the file as it is. Make sure only one `set_pformat()` reset + check remains after this block.

- [ ] **Step 2: Run it to verify it fails**

Restart Clipjump, run `tests/pastemode.ahk`: "Z opens the ring" FAILS (the old menu opens). "M picked Markdown link" and "S picked Strip URL tracking" also fail today: the plugins are enumerated alphabetically, so Common Formats takes M and SentenceCase takes S before the built-ins claim them.

- [ ] **Step 3: Implement**

`languages/english.txt` (mind the encoding constraint):

```
RNG_activeFormat = active format
RNG_origDesc = Paste the clip exactly as copied
RNG_origShort = Original
TRF_short_upper = UPPER
TRF_short_lower = lower
TRF_short_title = Title
TRF_short_oneLine = Flatten
TRF_short_slugify = Slug
TRF_short_stripTracking = Untrack
TRF_short_markdownLink = Markdown
TRF_short_prettyJson = Pretty
TRF_short_minifyJson = Minify
TRF_short_base64 = Base64
TRF_desc_upper = THE WHOLE CLIP
TRF_desc_lower = the whole clip
TRF_desc_title = First Letter Of Each Word
TRF_desc_oneLine = Collapse every run of whitespace
TRF_desc_slugify = lower-case-with-dashes
TRF_desc_stripTracking = Remove utm_*, fbclid, gclid
TRF_desc_markdownLink = [host](url)
TRF_desc_prettyJson = Indent two spaces
TRF_desc_minifyJson = Strip whitespace outside strings
TRF_desc_base64 = Decode when the clip is valid base64
```

`src/core/transforms.ahk`, in `Transforms.Register()`, after `e["builtin"] := 1` on the same statement line add `, e["desc"] := ClipType_T("TRF_desc_" t[1]), e["short"] := ClipType_T("TRF_short_" t[1])`.

Plugins: the loader in `lib/pluginManager.ahk` stores every `;@Plugin-<Key> <text>` header under `<Key>` (the map is case-insensitive), so a header is all a plugin needs. Add one line directly below the `;@Plugin-Name` line of each bundled pformat plugin, keeping each file's encoding and line endings:

- `plugins/pformat.noformatting.ahk`: `;@Plugin-Short Trim`
- `plugins/pformat.commonformats.ahk`: `;@Plugin-Short Common`
- `plugins/pformat.sentencecase.ahk`: `;@Plugin-Short Sentence`

`Clipjump.ahk`: replace `Formatting(*)` and `Formatting_Items(kind)` with the following (keep `Formatting_Letter` as it is):

```ahk
; Z in paste mode: the format ring at the pointer. Formats that fit the clip's kind come first, the rest are
; dimmed; the active format is outlined. Release Z over a wedge, click one, or press its letter; Z again or Esc
; closes. Ctrl stays held throughout; releasing it pastes with the current format and closes the ring.
Formatting(*) {
	global
	local kind, m, picked, letter
	if !is_pstMode_active
		return
	kind := (temp_clipboard != "") ? ClipType.Of(CN.NG, realActive) : ""
	m := Formatting_Items(kind)
	picked := Ring.Pick(m.items, {prefix: pstIdentifier, trigger: pastemodekey.z, triggerHotkey: pstIdentifier pastemodekey.z
		, dim: Hud.g.Hwnd, until: Formatting_Ended, idleTitle: curPformat != "" ? curPformat : TXT.HUD_formatOriginal
		, idleSub: TXT.RNG_activeFormat})
	if !is_pstMode_active      ; Ctrl was released while the ring was open: the paste already happened
		return
	hkZ_pasteMode(1)           ; the ring replaced ^z and the letters; paste-mode keys come back
	letter := StrUpper(picked)
	if (letter != "" && m.byKey.Has(letter)) {
		set_pformat(m.byKey[letter])
		if (temp_clipboard != "") {
			halfClip := StrLen(temp_clipboard) > 200 ? SubStr(temp_clipboard, 1, 200) "`n`n" MSG_MORE_PREVIEW : temp_clipboard
			if curPisPreviewable
				halfClip := callPformat(curPfunction, halfClip)
		}
	}
	PasteModeTooltip(temp_clipboard)
}

Formatting_Ended() {
	global is_pstMode_active
	return !is_pstMode_active
}

; ring items for the format ring; returns {items, byKey}: byKey maps an upper-case letter to a format name
; ("-original-" for Original, the sentinel set_pformat reads as "no format"). Formats are listed in a fixed
; priority order, those that fit the clip's kind first. Letters: formats with a preferred letter (the built-ins)
; claim theirs before the others pick from their names, so a plugin can never take a built-in's letter.
Formatting_Items(kind) {
	global PLUGINS, curPformat, TXT
	static priority := ["noformatting", "stripTracking", "markdownLink", "prettyJson", "minifyJson", "sentencecase"
		, "title", "upper", "lower", "oneLine", "slugify", "base64", "commonformats"]
	used := Map("V", 1, "C", 1, "Z", 1), byKey := Map(), letters := Map(), order := [], seen := Map(), fit := [], rest := []
	seen.CaseSense := "Off"
	for k in priority
		if PLUGINS.pformat.HasKey(k)
			order.Push(k), seen[k] := 1
	for k in PLUGINS.pformat
		if !seen.Has(k)
			order.Push(k)
	oL := Formatting_Letter("", "O", used)
	used[oL] := 1, byKey[oL] := "-original-"
	for pass in [1, 2]
		for k in order {
			v := PLUGINS.pformat[k], pref := ""
			try pref := v["key"]
			if ((pass = 1 && pref = "") || (pass = 2 && pref != ""))
				continue
			l := Formatting_Letter(v["name"], pref, used)
			used[l] := 1, byKey[l] := v["name"], letters[k] := l
		}
	fit.Push({key: oL, label: TXT.HUD_formatOriginal, short: TXT.RNG_origShort, desc: TXT.RNG_origDesc, active: curPformat = ""})
	for k in order {
		v := PLUGINS.pformat[k]
		desc := v["desc"] != "" ? v["desc"] : v["Description"]
		it := {key: letters[k], label: v["name"], short: v["short"], desc: desc, active: curPformat = v["name"]
			, dim: !Transforms.AppliesTo(v, kind)}
		(it.dim ? rest : fit).Push(it)
	}
	items := []
	for it in fit
		items.Push(it)
	for it in rest
		items.Push(it)
	return {items: items, byKey: byKey}
}
```

Before replacing, read the current `Formatting` / `Formatting_Items` and keep any behavior added by later fixes that this code does not cover (for example the `-original-` sentinel is already carried over above; the old `keys` string and the `ENTER` entry are intentionally gone because the ring binds its own keys and Enter picks the hovered wedge).

- [ ] **Step 4: Verify**

Validate; restart Clipjump; run `tests/pastemode.ahk` and `tests/modes.ahk` (ALL PASSED each; the action-mode step at the top of pastemode still uses the HUD until Task 5, so it must still pass as it is now). Run `tests/transforms.ahk`. Hold Ctrl+V, press Z by hand once: the ring opens at the pointer, the card behind dims, the hub shows the active format; every wedge shows one word (Original, Trim, Untrack, Markdown, ... for a URL clip) with letters T Trim Formatting, N Common Formats, E SentenceCase, M Markdown link, S Strip URL tracking; hover a wedge, the hub shows its description; release Z over a wedge after moving: that format is picked and the card updates.

- [ ] **Step 5: Commit**

```bash
git add Clipjump.ahk src/core/transforms.ahk languages/english.txt tests/pastemode.ahk plugins/pformat.noformatting.ahk plugins/pformat.commonformats.ahk plugins/pformat.sentencecase.ahk
git commit -m "Paste mode: Z opens the format ring"
```

---

### Task 5: The action ring replaces Action Mode's menu

**Files:**
- Modify: `Clipjump.ahk` (`actionmode_run`, new `ActionRing_Items`, `ActionRing_Trigger`), `languages/english.txt`, `tests/pastemode.ahk` (action-mode step), `tests/hud_live.ahk` (action-mode capture)

**Interfaces:**
- Consumes: `Ring.Pick`, `Ring_IsOpen`, `ACTIONMODE` (CJMap: key -> action; `<key>_caption` -> caption; `keys`, `text`, `items` bookkeeping entries), `update_actionmode()`, `Theme.Icon(name)`, `actionmode_K`.
- Produces: `ActionRing_Items() -> Array of ring items`; `ActionRing_Trigger() -> key name`.

- [ ] **Step 1: Update the tests**

`tests/pastemode.ahk`, replace the first step ("action mode: Ctrl+Shift+A shows the console, Esc closes it") with:

```ahk
step("action mode: Ctrl+Shift+A shows the ring, Esc closes it, H opens History")
SendEvent("^+a")
Sleep 700
check(cj.runFunction("Ring_IsOpen()") = 1, "action ring shown")
SendEvent("{Esc}")
Sleep 500
check(cj.runFunction("Ring_IsOpen()") = 0, "action ring closed by Esc")
SendEvent("^+a")
Sleep 700
SendEvent("h")
hist := cj["TXT.HST__name"] " ahk_class AutoHotkeyGUI"
check(WinWait(hist, , 5) != 0, "H opened Clipboard History")
try WinClose(hist)
Sleep 500
WinActivate("cj-pm-target")
ed.Focus()
Sleep 300
check(!errorDialog(), "no error after action mode")
```

`tests/hud_live.ahk`: in the action-mode section, replace the `Clipjump_HUD` checks with `cj.runFunction("Ring_IsOpen()") = 1` / `= 0`, and point the snapshot of the action-mode state at `Clipjump_Ring ahk_class AutoHotkeyGUI` (keep the file name `card-actionmode`).

- [ ] **Step 2: Run to verify it fails**

Restart Clipjump; run `tests/pastemode.ahk`: "action ring shown" FAILS.

- [ ] **Step 3: Implement**

`languages/english.txt`:

```
RNG_actionTitle = Action mode
RNG_act_H = every clip ever copied
RNG_act_O = channels and their clips
RNG_act_E = all of Clipjump's options
RNG_act_B = keep the next copy at the top
RNG_act_P = swap with the pit channel
RNG_act_T = skip recording the next copy
RNG_act_C = the selected file's full path
RNG_act_M = enable and edit plugins
RNG_act_L = apps Clipjump leaves alone
RNG_act_X = the open folder's path
RNG_act_F = the file itself, not its path
RNG_act_U = push the active clip to Windows
RNG_act_F2 = the shortcut sheet
RNG_act_F1 = what every key does
RNG_short_H = History
RNG_short_O = Organizer
RNG_short_E = Settings
RNG_short_B = Hold
RNG_short_P = PitSwap
RNG_short_T = Skip
RNG_short_C = Path
RNG_short_M = Plugins
RNG_short_L = Ignore
RNG_short_X = Folder
RNG_short_F = File
RNG_short_U = Sync
RNG_short_F2 = Keys
RNG_short_F1 = Help
```

`Clipjump.ahk`, in `actionmode_run(*)`, replace the line `temp_am := Hud.Menu(ACTIONMODE.items, ACTIONMODE.keys, PROGNAME " " TXT.ACT__name)` with:

```ahk
	temp_am := Ring.Pick(ActionRing_Items(), {prefix: "", trigger: ActionRing_Trigger(), idleTitle: TXT.RNG_actionTitle
		, extraKeys: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "D"]})
```

and add below `actionmode_run`:

```ahk
; Action Mode entries for the ring: the everyday ones first, customizer-added ones last. D, Esc and the channel
; digits stay on the keyboard (digits and D come back through extraKeys).
ActionRing_Items() {
	global ACTIONMODE, TXT
	static order := ["H", "O", "E", "B", "P", "T", "C", "M", "L", "X", "F", "U", "F2", "F1"]
	static icons := Map("H", "history", "O", "layout-grid", "E", "settings", "B", "pin", "P", "zap", "T", "ban"
		, "C", "file", "M", "wrench", "L", "eye-off", "X", "folder", "F", "copy", "U", "clipboard-check"
		, "F2", "keyboard", "F1", "circle-help")
	items := [], seen := Map()
	seen.CaseSense := "Off"
	add(k) {
		v := ACTIONMODE[k]
		if (v = "" || seen.Has(k))
			return
		seen[k] := 1
		cap := ACTIONMODE[k "_caption"]
		ik := StrUpper(k)
		items.Push({key: k, label: cap != "" ? cap : v, short: TXT["RNG_short_" ik], desc: TXT["RNG_act_" ik], icon: Theme.Icon(icons.Has(ik) ? icons[ik] : "chevron-right")})
	}
	for k in order
		add(k)
	for k, v in ACTIONMODE
		if (!InStr(k, "_") && k != "Esc" && k != "D" && k != "keys" && k != "text" && k != "items" && !IsInteger(k))
			add(k)
	return items
}

; the letter of the Action Mode hotkey, whose held state lets a flick commit on release
ActionRing_Trigger() {
	global actionmode_K
	return RegExReplace(actionmode_K, "[~*$!^+#<>]")
}
```

Check `Theme.Icons` has every glyph name used above (`history`, `layout-grid`, `settings`, `pin`, `zap`, `ban`, `file`, `wrench`, `eye-off`, `folder`, `copy`, `clipboard-check`, `keyboard`, `circle-help`, `chevron-right`); all were present when this plan was written.

- [ ] **Step 4: Verify**

Validate; restart; run `tests/pastemode.ahk`, `tests/hud_live.ahk`, `tests/modes.ahk`, `tests/ring_pick.ahk` (ALL PASSED each). By hand: Ctrl+Shift+A opens the ring at the pointer with icons and one word per wedge (History, Organizer, Settings, ...), the full name in the hub on hover; More shows page 2; pressing 1 switches to channel 1 (toast); D disables Clipjump (press D again from the tray to re-enable, or Ctrl+Shift+A then D). Then run `bash tests/run-all.sh` on an idle desktop: ALL SUITES PASSED.

- [ ] **Step 5: Commit**

```bash
git add Clipjump.ahk languages/english.txt tests/pastemode.ahk tests/hud_live.ahk
git commit -m "Action Mode: the action ring replaces the list"
```

---

## Self-review

- Spec coverage: RingGeom (Task 1), rendering and the demo (Task 2), window, input, paging, `Pick`, test hooks (Task 3), format ring with descriptions, dimming and paste-mode tests (Task 4), action ring with icons, descriptions and tests (Task 5). Out-of-scope items are not planned.
- Interface consistency: `Ring.Pick(items, opts) -> key`, `RingGeom.WedgeArcs` consumed only by `Ring.Wedge`, `RingGeom.Pages` nav entries `{nav}`, 0-based wedge indices in `RingGeom`, `Ring_WedgePoint(i)` and `Ring_LabelAt(i)` 0-based, `Formatting_Items -> {items, byKey}`, `ActionRing_Items -> items` are used the same way everywhere.
- Known judgment calls: text box offsets in `WedgeContent` and `Hub` may need tuning against the demo PNGs (radii and font sizes are fixed).
