# Action ring: design

Date: 2026-09-11. Branch: main. Design canvas: https://claude.ai/code/artifact/ced716ea-17f4-41a9-8327-5a131316e248
(`design/phase7/build.mjs`; direction A on the "Chosen" page is the reference for every visual value below).

## Goal

Replace the two list menus, the paste-mode format menu (Z) and Action Mode (Ctrl+Shift+A), with a mouse-driven
radial ring that opens at the pointer, while every keyboard letter keeps working.

## Decisions (from the design session)

- Direction A: a ring of up to eight wedges. A menu with more than eight entries shows seven entries plus a
  **More** wedge per page; the last page's navigation wedge is **Back** (to page 1).
- The ring **replaces** both list menus. Z always opens the format ring; Ctrl+Shift+A always opens the action
  ring. The F1 help card and the confirm prompts stay on the paste card.
- Commit a pick either way: release the held trigger over a wedge, or click a wedge. The hub is a dead zone
  for both. Esc closes. The item letters pick while the ring is open. Enter picks the hovered wedge.
- The ring opens centred on the pointer, clamped so the whole disc stays inside the work area of the monitor
  under the pointer (the centre moves, the pointer does not).
- The paste card dims to half opacity while the format ring is open and returns to its previous opacity after.
- Action Mode keeps Ctrl+Shift+A as its only trigger.

## Components

### 1. `src/ui/native/RingGeom.ahk` (pure, unit-tested)

Angles are degrees, 0 = 12 o'clock, clockwise; wedge `i` (0-based) of `n` is centred on `i * 360 / n`.

- `RingGeom.Sizes(scale)` -> `{r1, r0, hub, shadow, travel}` in physical pixels: outer radius 148, inner radius 52,
  hub 46, shadow 10, flick travel threshold 30, all times the DPI scale.
- `RingGeom.Angle(dx, dy)` -> 0 <= a < 360 (dx, dy relative to the centre, screen y down).
- `RingGeom.Hit(dx, dy, n, sizes)` -> `{zone, index}`: zone `hub` inside the hub radius, `ring` out to
  `r1 + shadow`, else `outside`; index is the nearest wedge by angle (no dead gaps), -1 unless zone is `ring`.
- `RingGeom.Arc(i, n)` -> `[a0, a1]`, the wedge's start and end angle with a 2.2 degree gap split across its edges.
- `RingGeom.Point(i, n, radius)` -> `[x, y]` offset of the wedge's centre line at that radius.
- `RingGeom.Pages(items, cap := 8)` -> Array of pages. At most `cap` items: one page, no navigation. More: pages of
  `cap - 1` items plus a nav entry `{nav: "more"}`, the last page ending with `{nav: "back"}`.
- `RingGeom.Clamp(x, y, rad, l, t, r, b)` -> `[cx, cy]` keeping a disc of radius `rad` inside the rectangle.

### 2. `src/ui/native/Ring.ahk`

- **API.** `Ring.Pick(items, opts) -> key or ""`, blocking like `Hud.Menu`. `items`: Array of
  `{key, label, desc, icon?, active?, dim?}`. `opts`: `prefix` (hotkey prefix for the item letters, `"^"` in paste
  mode, `""` in Action Mode), `trigger` (key name whose held state commits on release, e.g. `"z"`),
  `triggerHotkey` (hotkey that re-closes the ring on a second tap, paste mode only), `dim` (hwnd to dim),
  `until` (Func: close as cancelled when it returns true), `idleTitle`, `idleSub`, `extraKeys` (Array of keys
  that close the ring returning themselves, e.g. digits for channels). The caller re-registers any hotkeys the
  ring replaced (paste mode already does this with `hkZ_pasteMode(1)`).
- **Window.** One reusable `Gui("-Caption +E0x80000 +E0x08000000 +AlwaysOnTop +ToolWindow -DPIScale +Owner"
  A_ScriptHwnd, "Clipjump_Ring")`: layered and never activated, so the target app keeps focus. Content is painted
  with GDI+ into a 32-bit DIB and shown with `UpdateLayeredWindow`; shown and hidden with
  `ShowWindow(SW_SHOWNOACTIVATE)` / `ShowWindow(SW_HIDE)`.
- **Paint.** A soft shadow from five concentric low-alpha discs; a nearly invisible disc (alpha 2) under the wedges
  so the gaps catch the pointer instead of the app beneath; wedges as GDI+ paths (outer arc, inner arc reversed);
  labels and key chips with GDI+ `DrawString` (Segoe UI Variable Text, grayscale antialiasing, no ClearType);
  action icons from `icons/lucide.ttf` loaded through a GDI+ private font collection (the GDI private font
  registration Clipjump already does is invisible to GDI+); the hub disc with title, description and the
  "release · click · Esc" line. Visual values follow the canvas: wedge `surfaceAlt`; hovered `accent` with
  `accentText`; the active format `accentSoft` with a 1px `accent` outline; More/Back `surface` with muted text;
  formats that do not fit the clip's kind `Mix(surfaceAlt, bg, 0.5)` with muted text; label 10.5px semibold, key
  chip 9.5px on `surface`, hub title 12.5px semibold, description 10.5px and keys line 9.5px muted. Text-only rings
  centre the label at 54% of the band; icon rings put the icon at 27% and the label at 66%.
- **Input.** A 16 ms timer polls the pointer and repaints only when the hovered wedge or page changes.
  - Flick: when the trigger was down at open and is released (logical key state, so scripted tests work too),
    a hovered wedge is committed if the pointer travelled at least 30px from where the ring opened or the trigger
    was held longer than 300 ms; otherwise it was a tap and the ring stays open.
  - Click: acted on at release, for a press that happened while the ring was open. A click on a wedge commits,
    in the hub does nothing, outside the disc cancels (that click still reaches the app beneath).
  - Keys: every item letter on every page (`prefix` + key), Esc, Enter, the `extraKeys`, and in paste mode
    `triggerHotkey` (ignored while the trigger is still held, so key auto-repeat cannot close the ring).
    Registered with the `T2` thread option and released with `Off T1`, as `Hud.WaitKey` does.
  - More/Back flips the page and keeps the ring open; letters of items on other pages still pick.
- **Test hooks.** File-level functions `Ring_WedgePoint(i)` (screen `"x,y"` of wedge `i`'s label point on the
  current page) and `Ring_LabelAt(i)` (its label), because the public API's `runFunction` misroutes dotted names.
  `Ring.RenderToFile(state, path)` paints a ring onto an opaque background and saves a PNG for the demo.

### 3. Call sites

- **Format ring.** `Formatting()` passes `Formatting_Items(kind)` (applicable formats first, as today) to
  `Ring.Pick` with `prefix` `pstIdentifier`, `trigger` `pastemodekey.z`, `triggerHotkey` `pstIdentifier pastemodekey.z`,
  `dim` the paste card, `until` paste mode ended, idle hub = the active format and "active format". Items carry a
  description: built-in transforms get `TRF_desc_<id>` strings, plugin formats use their `;@Plugin-Description`,
  Original uses `RNG_origDesc`. The picked key goes through the existing `byKey` / `set_pformat` path.
- **Action ring.** `actionmode_run()` builds items from `ACTIONMODE` in this order: H, O, E, B, P, T, C (page 1),
  M, L, X, F, U, F2, F1 (page 2), then any customizer-added entries. D (Disable), Esc and the digits 0-9 stay on
  the keyboard only (`extraKeys` digits and D). Icons come from glyphs already in `Theme.Icons`; descriptions from
  `RNG_act_<key>` strings. `trigger` is the letter of the configured Action Mode hotkey. The returned key goes
  through the existing `ACTIONMODE[key]` dispatch.
- `Hud.Menu` stays (unused by the core after this change); `Hud.WaitKey` keeps serving Confirm.

## Testing

- `tests/ring_geom.ahk`: angles at the four compass points, nearest-wedge indices for 8, 6 and 10 wedges including
  the wrap at 0, hub/ring/outside zones, pages for 5, 8, 9, 14 and 17 items, clamping at every edge, sizes at 150%.
- `tests/ring_demo.ahk`: renders the format ring (idle, a hovered wedge, page 2) and the action ring in dark and
  light to `tests/out/ring-*.png` through `Ring.RenderToFile`.
- `tests/pastemode.ahk`: Z opens the ring; U picks Upper case; tap Z twice closes with no change; O picks Original;
  a click on wedge 2 picks that wedge's label; a flick (hold Z, move to wedge 3, release) picks that label;
  Ctrl released while the ring is open pastes with the previous format and leaves no ring behind.
- Action Mode: Ctrl+Shift+A opens the ring, Esc closes it, H opens Clipboard History (the existing action-mode steps
  in `tests/pastemode.ahk` and `tests/hud_live.ahk` switch from the HUD window to `Clipjump_Ring`).

## Out of scope

A mouse trigger for Action Mode; rings for the help card or confirm prompts; open/close animation; touch.

## Order of work

1. RingGeom and its unit test.
2. Ring rendering and the demo PNGs.
3. Ring input and `Ring.Pick`.
4. Format ring call site, descriptions, card dimming, paste-mode tests.
5. Action ring call site, icons, descriptions, action-mode tests.
