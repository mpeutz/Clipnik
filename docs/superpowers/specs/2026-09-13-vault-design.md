# The Vault: design

Date: 2026-09-13. Branch: main.

## Goal

A permanent home for clips a user wants to keep. Everything else in Clipjump expires: channel clips are
compacted away when the stack fills, and history rows are pruned by age and by count. The Vault is the one
store nothing deletes on its own. Entries can carry a name, sit in an order the user chooses, be edited, and
be reached from paste mode without leaving the keyboard.

## Decisions (from the design session)

- The Vault is its own `vault` table in `cache/data.db`, not a flag on history rows and not a channel.
  Permanence is then structural: no pruning path and no compaction path touches it.
- It is browsed and managed as a second view inside the Clipboard History window, switched from the toolbar.
  The window is already addressed by row id, which matches a table with ids; the Organizer is addressed by
  channel index, which does not.
- Entries carry an optional name and a manual order. Walking unnamed raw text in the paste card is hard to
  read, and a manual order keeps the entries a user reaches for daily at the front.
- Paste mode reaches the Vault with one key that toggles the walker onto it. Same hold-and-tap flow as
  walking clips.
- Clips reach the Vault three ways: a Save to Vault action in Clipboard History, the same in the Channel
  Organizer, and an Add from clipboard button in the Vault view.
- Deletion is explicit only. No limit, no age, no automatic removal of any kind.

### The name

"Vault" describes permanence, not secrecy. Entries live in the same unencrypted SQLite database as history
and are readable by anything that can read the folder. The help text says so in those words. Encryption is
not in this design.

## Components

### 1. `src/core/vault.ahk`

Owns the table and every operation on it. Mirrors the shape of `src/core/history.ahk`.

```
CREATE TABLE if not exists vault (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT,      -- optional label; "" when unnamed
    data    TEXT,      -- the text, or "[IMAGE]" for an image entry
    type    INTEGER,   -- 0 text, 1 image
    fileid  TEXT,      -- cache\vault\<random>.<ext> for images, "" for text
    kind    TEXT,      -- a ClipType kind, re-detected whenever the text changes
    size    INTEGER,
    width   INTEGER,
    height  INTEGER,
    time    TEXT,      -- when it was saved, local, same format as history.time
    pos     INTEGER    -- manual order, ascending, gaps allowed
)
```

- `vaultCreateTable()` — called from the same startup path as `createHisTable()`.
- `vaultAdd(data, type, fileid, kind, w, h, name := "")` — returns the new id, `pos` one past the current
  maximum so new entries land at the end.
- `vaultList(q := "")` — every row ordered by `pos` ascending then `id`, filtered by `q` against `name` and
  `data` when `q` is not empty. Returns the same row shape the history list sends the page.
- `vaultGet(id)` — the full record, or `""`.
- `vaultSetText(id, text)` — rewrites `data`, recomputes `size`, re-detects `kind` through `ClipType.Detect`.
  Text entries only; an image entry is left alone.
- `vaultSetName(id, name)` — trimmed; an empty name is stored as `""` and the list falls back to the text.
- `vaultMove(id, delta)` — swaps `pos` with the neighbour in that direction, no-op at either end.
- `vaultDelete(id)` — deletes the row and, for an image entry, its file under `cache\vault`.
- `vaultToClipboard(id)` — text entries through `A_Clipboard`, image entries through
  `Gdip_SetImagetoClipboard`, mirroring `historyToClipboard`.
- `vaultCount()` — used by the paste-mode toggle to say the Vault is empty rather than entering it.

**Image bytes.** An image entry's file is copied verbatim into `cache\vault`, never re-encoded: re-encoding a
JPEG as PNG costs space and recovers nothing. That means the fidelity of a vaulted image is the fidelity of
where it came from. From the live clipboard or from the Channel Organizer it is the original pixels. From a
Clipboard History row it is that row's JPEG preview copy, which is lossy and has no transparency. The help
text states this.

### 2. The Vault view in the Clipboard History window

`ui/history/index.html` gains a two-state switch in the toolbar, beside the type filter: **History** and
**Vault**. The page keeps the active view in `state.view` and sends it with every request. `HistoryWin`
routes on it, so `list`, `get`, `copy`, `instaPaste`, `edit`, `delete` and `action` each reach either the
`history*` or the `vault*` function with no new message names.

In the Vault view:

- The row's first column shows the entry's name when it has one, and its clip text when it does not. The
  remaining columns are unchanged: kind badge, saved date, size. The full text is in the preview pane.
- The type filter and the partial-match toggle keep working; the sort control does not apply, because the
  Vault has one order and it is the user's. The sort header is disabled in this view.
- Three actions exist only here: **Rename**, **Move up**, **Move down**, on the row context menu and the
  Actions menu. Move up and down are also on Alt+Up and Alt+Down.
- **Edit** (Ctrl+H) already exists and points at `vaultSetText`.
- **Delete** (Del) removes the entry permanently and says so in the confirmation, because unlike a history
  row there is no other copy.
- An **Add from clipboard** button sits in the toolbar, enabled only in this view.

The kind badge, preview pane, search box, image preview and the per-kind Actions menu all work unchanged,
because a vault row carries the same `kind`, `type`, `fileid`, `width` and `height` fields a history row does.

### 3. Getting clips in

- `HistoryWin`: a **Save to Vault** entry on the row context menu and the Actions menu, in the History view
  only. Copies the row into the Vault, including its image file where it has one.
- `OrganizerWin`: a **Save to Vault** entry on the clip context menu. A text clip is copied from `CDS`; an
  image clip's `.avc` is read so the Vault gets the original pixels rather than the thumbnail.
- The Vault view's **Add from clipboard** button vaults whatever is on the clipboard right now: if
  `Gdip_CreateBitmapFromClipboard` returns a bitmap it is saved to `cache\vault` as PNG and the entry is an
  image, otherwise the clipboard text is saved as a text entry. An empty clipboard shows a toast and adds
  nothing.

All three land the entry at the end of the order, unnamed, with the kind detected from the text. Duplicates
are allowed and never merged: the Vault holds what the user put in it, and two entries with the same text may
be there for different reasons.

### 4. Paste mode

A new paste-mode key, **B**, toggles the walker onto the Vault.

- `pastemodekey` gains `b`, and `hkZ_pasteMode` registers it alongside the others.
- A `VAULT` state map holds `ACTIVE`, the id list captured when the Vault is entered, and the current index.
  Capturing the list on entry means an edit from another window mid-walk cannot shift what the keys do.
- Pressing B with an empty Vault shows a tooltip saying so and does not enter.
- While active, `paste()` and `moveBack()` step the vault index instead of `TEMPSAVE` and load the entry with
  `vaultToClipboard` instead of `try_ClipboardfromFile`. Releasing Ctrl pastes exactly as it does for a clip.
- The paste card's header names the Vault and shows position as `n of total`; the entry's name replaces the
  clip number line when it has one.
- B again leaves the Vault and returns the walker to the clip stack where it was. Esc leaves paste mode
  entirely, as it does now.
- While the Vault is active only these keys do anything: V and C to walk, B to leave, Z to change the paste
  format, S to put the entry on the system clipboard, F1 for help, and Esc to leave paste mode. Everything
  else is inert, including Space (fix), T (tag), Q (move to first), X (cancel, move, delete, copy), the digit
  jumps, Up and Down (change channel), Enter (multiple pasting), E (export), F (search) and H (edit). Each of
  those acts on a channel clip by position, which a vault entry does not have. Editing an entry and searching
  the Vault happen in the Vault view; both are candidates for a later version of this key set.
- `TIP_help` gains its line, so the F1 key card and the generated help reference both pick the key up with
  no further change.

### 5. Strings and help

New keys in `languages/english.txt`: `VLT__name`, `VLT_add`, `VLT_rename`, `VLT_moveUp`, `VLT_moveDown`,
`VLT_saveToVault`, `VLT_empty`, `VLT_deleteConfirm`, `VLT_namePrompt`, plus the `TIP_help` line. The
Clipboard History window's i18n list gains them.

`ui/help/topics/` gains a Vault entry under "How do I", covering what it is for, the three ways in, the paste
mode key, that the order is the user's, and the two honest caveats: it is not encrypted, and an image vaulted
from a history row is the lossy copy.

## Call sites

- `Clipjump.ahk`: `vaultCreateTable()` beside `createHisTable()` at startup; `pastemodekey` gains `b`;
  `hkZ_pasteMode` registers `vaultToggle`; `paste()` and `moveBack()` branch on `VAULT.ACTIVE`;
  `PasteModeTooltip` is given the Vault header and position.
- `src/ui/native/Hud.ahk`: the card renders the Vault header, the entry name, and `n of total`.
- `src/ui/web/HistoryWin.ahk`: view routing, `SaveToVault`, `Rename`, `Move`, `AddFromClipboard`.
- `src/ui/web/OrganizerWin.ahk`: `SaveToVault` on the clip menu.
- `ui/history/index.html`, `app.js`, `history.css`: the view switch, the Vault-only actions, the name column.
- `ui/organizer/app.js`: the menu entry.
- `src/core/history.ahk`: untouched. `historyPrune` never sees the vault table.

## Testing

- `tests/vault.ahk`, a unit suite against a temporary database in the style of `tests/history_prune.ahk`:
  add appends to the end of the order; list returns the manual order; move up and down swap and are no-ops at
  the ends; setText re-detects the kind; setName trims and accepts empty; delete removes an image entry's
  file; search matches name and text.
- `tests/vault_flow.ahk`, against a running Clipjump in the style of `tests/history_flow.ahk`: the switch
  shows the Vault, Add from clipboard creates an entry, editing rewrites it, move up reorders it, Save to
  Vault from a history row copies it, and delete removes it.
- `tests/pastemode.ahk` gains a Vault leg: B enters the Vault, V walks it, the card names the Vault, release
  pastes the entry, B returns to the clip stack.
- Both new suites join `tests/run-all.sh`.
- `/validate Clipjump.ahk` exits 0 with the five known warnings.
- Manual: an image vaulted from the Organizer pastes at full fidelity; the same image vaulted from a history
  row does not, and the help says why.

## Out of scope

Encryption or any access control; folders, tags or grouping inside the Vault; import and export; editing
image entries; saving to the Vault from inside paste mode; syncing between machines; a separate global
hotkey for the Vault window.

## Order of work

1. `src/core/vault.ahk` and its unit suite, with the table created at startup. Nothing else can be tested
   until the store exists.
2. The Vault view in the Clipboard History window: the switch, view routing, and the list.
3. The Vault-only actions: rename, move, delete confirmation, Add from clipboard, and editing.
4. Save to Vault in Clipboard History and the Channel Organizer.
5. Paste mode: the key, the walk, and the card.
6. Help topic, strings, and the flow suites.
