# Help: design

Date: 2026-09-11. Branch: main.

## Goal

Replace Clipjump's help with one in-app window: task-shaped guides in front, a generated reference behind,
and a single obvious way in. The 2016 `Clipjump.chm` and every path that opens it go away.

## Decisions (from the design session)

- Help lives in a WebView2 window built on the existing `WebHost`, like Clipboard History and the Channel
  Organizer. Themed, offline, searchable.
- Content is tasks first ("how do I paste something older"), with the full reference one click behind it.
- The reference tables are generated from the running app, so they show the user's configured keys and
  installed plugins and cannot drift from the code. The prose around them is hand written.
- Ways in: Action Mode F1 (and the ring's Help wedge), one Help entry on the tray card and the classic tray
  menu, and a Help button in Settings. Paste mode's F1 keeps today's instant key card and nothing more.
- `Clipjump.chm` is deleted along with `openFaq`, `openShortcutsHelp`, `hlp` and the first-run "see help"
  prompt. Anything in the CHM worth keeping is carried into the new pages first.
- Prose is English only. The existing language files keep serving the UI chrome.

## Components

### 1. `src/ui/web/HelpWin.ahk`

Mirrors `HistoryWin.ahk` in shape:

- `HelpWin.Open(topic := "")`, `HelpWin.Close()`, `HelpWin.Instance()`.
- `WebHost(PROGNAME " " TXT.TRY_help, "help/index.html", "Help")`, created on demand. No prewarm: help is
  opened rarely and the two existing hosts already cost memory.
- Geometry in `settings.ini` section `Help_window` (`w`, `h`, `x`, `y`), defaults 900 x 640, minimum 520 x 360,
  saved on close exactly as `HistoryWin_SaveGeometry` does.
- `Open(topic)` shows the window, focuses it and posts `opened {topic}`; when the window is already visible it
  activates it and posts `opened` again so the caller's topic wins.

**Page to host:** `reference` (request the generated data), `open {url}` (external link, goes through
`BrowserRun`), `close`.
**Host to page:** `i18n {strings}` (window chrome only), `reference {...}` (below), `opened {topic}`.

### 2. Generated reference data

`Help_Reference()` in `Clipjump.ahk` builds one Map, posted as `reference`:

- `pasteMode`: rows of `{key, caption}` from `Hud.HelpItems()`, the same source the F1 card uses, so the two
  never disagree and stay translated.
- `hotkeys`: the configured global keys read from their globals, each with a label: copy, cut, paste,
  Action Mode (`actionmode_k`), Channel Organizer (`chOrg_K`), Plugin Manager (`pluginManager_k`), History
  (`history_k`), pit swap, one-time stop, and the paste-mode identifier and paste key.
- `formats`: from `Formatting_Items("")` so the letters are the ones the ring assigns, each with `key`,
  `label`, `short`, `desc` and the kinds it applies to.
- `actions`: from `ActionRing_Items()`, each with `key`, `label`, `desc`, in ring order, plus the keyboard-only
  entries (digits, D, Esc).
- `rules`: `Rules.Actions` and the clip kinds with their labels from `ClipType.Kinds` / `ClipType_Labels()`.
- `version`: `VERSION`.

The page renders each into a table where a topic fragment carries `<div data-ref="pasteMode">`. A missing or
empty section renders as a short "not available" line rather than an empty table.

### 3. `ui/help/`

- `index.html`: the shell. Left topic list, content pane, filter box at the top of the list.
- `app.js`: loads every topic fragment at open (they are small), renders the list, handles selection, the
  filter, deep links from `opened {topic}`, and fills the `data-ref` tables from `reference`.
- `help.css`: layout on top of `ui/common/theme.css`.
- `topics/*.html`: one fragment per topic, each starting with `<h1>` and carrying `data-title` and
  `data-keywords` on its root element.

The filter searches the text of every topic, not just titles, shows the matching topics with a match count,
and highlights matches in the open topic with the CSS Custom Highlight API, as the history preview does.
`ui/common/mock-bridge.js` gains a `reference` fixture so the page opens in Chrome for layout work.

### 4. Topics

- **Start here**: the clip stack, channels, paste mode, and why Ctrl+V behaves differently from other
  clipboard managers.
- **How do I**: paste something older, keep a clip at the top, put a clip on the system clipboard, paste as
  plain text or another format, clean tracking parameters off a link, paste several clips in a row, find a
  clip by typing, move clips between channels, tag a clip, make a rule fire automatically, get something back
  from history, work with images.
- **Reference**: paste-mode keys, Action Mode and the ring, formats, rules, settings by page, plugins, global
  shortcuts.
- **When something goes wrong**: Ctrl+V does nothing in a particular app (ignored windows), clips from a
  password manager are skipped on purpose, images are not stored, the browser component is missing, resetting
  to defaults.
- **About**: version, the fork's origin, where to report a problem.

Each "How do I" entry is a few lines and names the keys involved; keys are marked up as `<kbd>` so they pick
up the chip styling.

The ring gets one inline SVG diagram (wedges, hub, the release-or-click gesture). No screenshots: they rot.

## Call sites

- `ACTIONMODE["F1"]` becomes `"help"`, dispatched to `HelpWin.Open("reference-actionmode")`; `RNG_act_F1`
  keeps its description. `ACTIONMODE["F2"]` (Paste-mode keys) becomes
  `HelpWin.Open("reference-pastemode")`.
- `TrayCard.SubSpec("help")` collapses: the tray card's Help item opens the window directly instead of
  expanding a submenu, and `lib/aboutGUI.ahk`'s `Help_Tray` becomes a single `A_TrayMenu` Help entry.
- `SettingsWin` gains a Help button in its button row, opening `HelpWin.Open("reference-settings")`.
- The first-run `ABT_seehelp` MsgBox is removed; the existing "Clipjump is ready" tray tip stays.

## Removals

`Clipjump.chm`; `openFaq`, `openShortcutsHelp` and `hlp` in `lib/aboutGUI.ahk` plus their `ACTIONS` entries;
the `Help_Tray` submenu; the string `ABT_seehelp` (English file only; other languages keep their now unused
key). `TRY_pstmdshorts` stays: it is still the Action Mode F2 caption.

## Testing

- `tests/help_flow.ahk`, in the style of `tests/history_flow.ahk`: Action Mode F1 opens the window; the topic
  list has every topic; selecting a topic shows its heading; the filter narrows the list and reports matches;
  a generated table has rows and contains a known format letter; closing saves geometry and reopening restores
  it. Added to `tests/run-all.sh`.
- `ui/help/index.html` opens in Chrome against `mock-bridge.js` for layout work, dark and light.
- Validate exits 0 with only the known noise.
- Manual: every entry point opens the window at the right topic; external links open in the browser, not in
  the WebView2 page.

## Out of scope

Screenshots, translated prose, a search index library, an in-app tour, and context help on individual settings
controls (the Settings Help button lands on the settings topic, not on the focused control).

## Order of work

1. `HelpWin.ahk`, an empty themed page, the entry points, and the removals.
2. `Help_Reference()` and the generated tables.
3. The topic content.
4. Filter and highlighting.
5. `tests/help_flow.ahk` and the run-all entry.
