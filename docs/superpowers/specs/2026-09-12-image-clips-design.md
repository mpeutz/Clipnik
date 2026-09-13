# Image clips: kinds, tags, rules and actions

Date: 2026-09-12. Branch: image-clips (from main).

## Goal

Clip intelligence shipped for text only. An image is modeled as "the clip whose text is empty", so it has no
kind, no actions, never reaches the rules engine, and carries no metadata. Vector markup arrives as text and
is classified as code. This makes images and SVG first-class.

## Decisions (from the design session)

- Two new kinds: `image` (pixels on the clipboard) and `svg` (vector markup, which arrives as text). A copied
  image file stays a file clip.
- Bitmap actions: open in the configured image editor, copy as a data URI. Width and height are recorded
  metadata, shown wherever a clip is shown, not an action.
- Vector actions: send to SVGOMG, open in a configured vector editor (new setting), copy as a data URI.
- Rules and tags cover images: route to a channel, tag, or ignore.
- Out of scope: save-as dialogs, OCR, SVG minification, thumbnails for copied image files, changing the
  thumbnail format.

## Components

### Kinds (`src/core/cliptype.ahk`)

`ClipType.Kinds` becomes `url, email, path, color, json, svg, number, phone, code, text, image`; that order
drives the history filter and the rule dialog. `ClipType.IsSvg(text)` matches trimmed text that starts with
`<svg` (or an XML declaration whose first element is `<svg`) and ends with `</svg>`; it runs in `Detect` after
the JSON test and before `IsCode`. `image` is never produced by `Detect`: the copy path assigns it.

### Copy path (`Clipjump.ahk`, image arm)

Sets `LASTKIND := "image"`, stores the kind on the clip, records the dimensions, evaluates rules, and passes
the kind to history.

### Metadata

`thumbGenerator()` returns the width and height of the bitmap it already creates. Stored per clip as the `Dim`
pref (a new key in `ClipPref_makeKeys`) and per history row as new `width` / `height` columns, added with the
same cheap migration `historyAddKindColumn` uses. Shown on the paste card footer, the History preview header
and the Organizer details pane.

### Actions

`ClipType.Run(id, text)` becomes `ClipType.Run(id, text, ref := "")`, where `ref` is the image file path for
image clips. New table entries: `openImage` and `imageDataUri` for `image`; `svgomg`, `openVector` and
`svgDataUri` for `svg`.

A new `src/core/imageclip.ahk` owns the pixel plumbing: resolving a clip to a source (history `fileid`, the
channel thumbnail, or the live clipboard), producing a PNG, and producing a data URI with a 2 MB cap.

History, the Organizer and the copy toast already build menus from the shared table; their image guards open
up and they pass a path instead of the clip text.

### Rules for images

The rule step is mirrored into the image arm. `channel` and `tag` behave as for text. `ignore` must delete the
already-saved clip and thumbnail and roll the clip counter back, reusing the cleanup `imageIsRepeat` performs.
`transform` is skipped for images. A rule-applied tag now flushes to `prefs.ini`, which it never did.

### Settings and strings

New `[System] default_vector_editor` with a row beside the image editor in Settings, Advanced, Editors;
default empty, and the action says so when unset. New `KIND_*`, `ACT_*` and `SET_*` strings in English only,
plus the two new kinds added to the Organizer's explicit i18n key list.

## Testing

Unit: SVG detection cases in `tests/cliptype.ahk`; an image-kind rule in `tests/rules.ahk`. Flow: kind, `Dim`
pref and history dimensions in `tests/image.ahk`; the data URI action from the History window; an image routed
by a rule in `tests/rules_flow.ahk`. Manual: the copy toast chip, opening in Affinity Photo, and SVGOMG.

## Known issue outside this work

`tests/rules_flow.ahk` currently fails on main (the channel-routing checks) and fails differently run to run.
Characterize it before trusting that suite's result here.
