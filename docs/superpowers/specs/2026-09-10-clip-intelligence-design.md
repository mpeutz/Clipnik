# Clip intelligence: design

Date: 2026-09-10. Branch: v2-port. First of two brainstormed sub-projects (the second is Snippets, not covered here).

## Goal

Clipjump learns what a text clip is (URL, email, path, color, JSON, number, phone, code or plain text), shows that
everywhere a clip appears, offers actions and transforms that fit the type, and lets the user define copy-time rules
that route, ignore, transform or tag clips automatically.

## Decisions

- Detect once at copy time and store the kind (history column, channel clip pref). Old data is classified lazily on
  first display and written back.
- Transforms use the existing paste-format table (the one the Z key and pformat plugins populate) but live in one
  core file, not one plugin file each.
- Z opens a format menu on the paste card instead of cycling.
- Type actions surface on the copy toast (one primary action chip) and in the History and Organizer preview panes
  and row context menus. Not in paste mode, not in Action Mode.
- Rules are edited on a Settings page and stored in settings.ini under [Rules].
- A design canvas for the visual pieces precedes implementation.

## 1. Detector and storage

New file `src/core/cliptype.ahk`, class `ClipType`.

`ClipType.Detect(text)` returns one of: `url`, `email`, `path`, `color`, `json`, `number`, `phone`, `code`, `text`.

- Input is trimmed. Anything longer than 64 KB returns `text` immediately (the detector runs inside the clipboard
  hook and must never stall it).
- Checks run in the order above, first match wins.
- `url`: a scheme (`https?://`, `ftp://`, `file://`, `mailto:` is excluded) or a bare `www.` domain, single line,
  no spaces.
- `email`: one address, single line, the whole trimmed text.
- `path`: drive (`C:\`) or UNC (`\\server\`) prefix, no line breaks, no characters illegal in Windows paths.
- `color`: `#` plus 3, 6 or 8 hex digits, `rgb()/rgba()`, `hsl()/hsla()`.
- `json`: starts with `{` or `[`, ends with the matching bracket, brackets balance outside of strings.
- `number`: integer or decimal with optional sign, thousands separators and currency symbol; the whole text.
- `phone`: 7 to 15 digits with optional `+`, spaces, dashes, dots, parentheses; the whole text.
- `code`: two or more lines and at least one strong signal: a shebang, lines ending in `;` or `{`, a line
  starting with `def `, `function `, `import `, `class `, `#include`, `using `, or consistent leading indentation
  with braces.
- Otherwise `text`.

Images and file clips keep their existing format labels and are never classified.

Storage:

- History: `ALTER TABLE history ADD COLUMN kind TEXT` at startup when the column is missing (checked with
  `PRAGMA table_info`). `addHistoryText` writes the kind. The History list handler classifies rows whose kind is
  NULL before sending them to the page and updates them.
- Channel clips: `Kind=` in the channel's `prefs.ini` through `clipPref`, next to `Tags` and `Fixed`. `clipSaver`
  writes it; the paste card classifies clips without a kind on display and writes it back.
- `ClipType.Of(channel, clip)` returns the stored kind or detects and stores it.

Tests: `tests/cliptype.ahk`, table-driven, at least 20 inputs per kind including false-positive traps (an email
inside a sentence stays text, a sentence containing a slash is not a path, `1.` is text), and a timing check that a
64 KB input classifies in under 5 ms.

## 2. Showing the type

- Paste card: the format pill shows the kind name (URL, EMAIL, PATH, COLOR, JSON, NUMBER, PHONE, CODE) instead of
  TEXT when known. A `color` clip adds a 10 px swatch inside the pill. Nothing else on the card changes.
- History page: a kind badge in the clip column; a type filter dropdown in the toolbar next to Partial/Exact with
  All plus the kinds present (from `SELECT DISTINCT kind`). The filter becomes `AND kind = ?` in the list query.
- Organizer page: the same badge in the clips table. No filter.
- Copy toast: a muted kind label after the channel pill when the kind is not `text`.
- Kind names are translation strings `KIND_url`, `KIND_email`, ... in `languages/english.txt`.

## 3. Transforms and the Z menu

New file `src/core/transforms.ahk`. Each transform is `(text) -> text`, registered into the paste-format table with a
name, the kinds it applies to (empty means all) and previewable = 1:

| Name | Applies to | Behavior |
|---|---|---|
| Upper case | text, code | `StrUpper` |
| Lower case | text, code | `StrLower` |
| Title case | text | first letter of each word upper, rest unchanged |
| One line | text, code | collapse all whitespace runs to one space, trim |
| Slugify | text | lower, ASCII letters and digits, dashes between words |
| Strip URL tracking | url | remove `utm_*`, `fbclid`, `gclid`, `mc_cid`, `mc_eid`, `igshid`, `ref` query keys |
| Markdown link | url | `[host](url)` |
| Pretty JSON | json | indent 2 spaces (own minimal formatter, no library) |
| Minified JSON | json | remove whitespace outside strings |
| Decode base64 | text | decode when the text is valid base64, else unchanged |

Existing pformat plugins (no formatting, trim and the commonformats set, sentence case) stay as they are and appear in
the same menu.

Z in paste mode opens a menu on the card (the existing menu mode used by Action Mode): applicable formats first,
then the rest dimmed, each with a letter key, the active one marked with a check. Letter or Enter picks and returns
to the normal card with the format pill updated; Esc or Z closes without change. Ctrl stays held throughout. The
"revert format to default after paste" setting is unchanged. Settings' default paste format dropdown lists the new
formats.

Tests: `tests/transforms.ahk` table-driven per transform; a step in `tests/pastemode.ahk`: Z opens the menu, a
letter picks Upper case, the pasted text is upper case.

## 4. Type actions

Action table in `src/core/cliptype.ahk`: per kind, an ordered list of `{id, label, fn(text)}`; the first entry is the
primary action.

| Kind | Actions (primary first) |
|---|---|
| url | Open in browser; Copy without tracking |
| email | Compose (mailto:) |
| path | Reveal in Explorer; Open; Copy folder path |
| color | Copy as hex; Copy as rgb |
| json | Pretty-print into clipboard; Minify into clipboard |
| number | Copy formatted (thousands separators) |
| code, phone, text | none |

"Copy" and "into clipboard" actions write to the system clipboard as a normal copy, so the result becomes a new clip.

- Copy toast: when the clip has a primary action, the toast shows a clickable pill with its label after the kind
  label and stays 2.5 s instead of 0.9 s. Clicking runs the action and hides the toast. The toast remains a
  no-activate window; the pill is a Button custom-drawn by the theme.
- History and Organizer: an Actions button in the preview pane header opens an in-page menu with the kind's actions;
  the same entries head the row context menu. The page sends `{cmd: "action", data: {id, action}}`; the host loads
  the clip text and runs the action. Menu code is shared in `ui/common/util.js`.

Tests: `tests/cliptype.ahk` covers the action functions that return text (strip tracking, folder path, hex/rgb,
pretty and minified JSON, number formatting). Open/reveal are exercised manually.

## 5. Auto rules and the Settings page

A rule: `{enabled, kinds[], regex, app, action, arg}`. Conditions given must all hold; empty conditions are not
allowed. `app` matches the process name or window class of the active window when the copy happened.

Actions: `channel:N` (store the clip in channel N without switching the active channel), `ignore` (drop the clip and
show a brief toast), `transform:Name` (store the transformed text), `tag:Text` (set the clip's tag).

Evaluation: in `cjClipboardChanged`, right after the exclusion check, text clips only, first enabled matching rule
wins. `ignore` returns before storage; the others adjust the target channel, the text or the tag before the existing
save path runs.

Storage: `[Rules]` in settings.ini, numbered keys, one rule per line:
`1=on=1;kinds=url,email;regex=;app=chrome.exe;action=channel:2`. Loaded at startup and on Apply. Regexes are
validated when loaded; an invalid rule is disabled and reported once with a toast.

Settings page "Rules": ListView with columns Enabled, When, Then; buttons Add, Edit, Remove, Up, Down. Add/Edit opens
a themed dialog: kind check boxes, regex Edit, source app Edit with a "Pick window" button reusing the Ignored
Windows picker, action DDL with a dependent second control (channel DDL, transform DDL, or tag Edit). Validation:
at least one condition, a valid regex, a channel that exists.

Tests: `tests/rules.ahk` unit tests for parsing, matching and precedence; a live step that writes a rule (kind url
to channel 1 with a tag), copies a URL, and checks the clip landed in channel 1 with the tag and the active channel
did not change.

## Out of scope

Snippets and templates (second sub-project). Type actions in paste mode or Action Mode. Rules on image or file
clips. A full JSON parser.

## Order of work

1. Detector, storage, tests (section 1).
2. Type display in card, History, Organizer, toast (section 2).
3. Transforms and the Z menu (section 3).
4. Type actions: toast pill, page menus (section 4).
5. Rules engine and Settings page (section 5).

Each step ends with the full test suite green on an idle desktop and a live check of the touched surfaces.
