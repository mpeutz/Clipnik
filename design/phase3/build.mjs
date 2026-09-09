// Generates the Phase 3 window mockups (.dc.html artboards + canvas.json) from one shared shell.
// Run: node design/phase3/build.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

import { dark, light, props, logic, helmet, svgCheck, svgChevron, spinner, ddl, edit, hotkey, check, row, section, btn, icons, pages, titlebar, wrap } from "../shared.mjs";

function settingsWindow(pageId, body, applyEnabled = false) {
  const nav = pages.map(([id, name]) => `<div class="item${id === pageId ? " sel" : ""}" style="height: 36px;">${icons[id]}<span>${name}</span></div>`).join("\n      ");
  const title = pages.find(([id]) => id === pageId)[1];
  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${helmet}
<div class="win" style="width: 760px; height: 620px; {{vars}}">
  ${titlebar("Clipjump Settings")}
  <div style="display: flex; flex-grow: 1; min-height: 0;">
    <div class="nav" style="width: 168px;">
      ${nav}
    </div>
    <div class="content">
      <div class="h1">${title}</div>
      ${body}
    </div>
  </div>
  <div class="footer" style="height: 52px; justify-content: space-between;">
    <a href="#" style="font-size: 12.5px;">Open settings folder</a>
    <div style="display: flex; gap: 8px;">${btn("OK", "primary")}${btn("Cancel")}${btn("Apply", applyEnabled ? "" : "dis")}</div>
  </div>
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`;
}

const general = `
      ${section("Clipboards")}
      ${check("Limit the maximum number of active clipboards", true)}
      ${row("Minimum number of active clipboards", spinner("20"))}
      ${row("Clipboard threshold", spinner("10"), "Extra clipboards kept before the oldest are dropped")}
      ${section("Paste mode")}
      ${check("Start paste mode with search enabled", false)}
      ${check("Preserve the current active clip position", true)}
      ${check("Always start paste mode with the default formatting", false)}
      ${row("Default paste format", ddl("-original-"))}
      ${section("Capture")}
      ${check("Monitor the clipboard", true, "off: only Clipjump shortcuts record clips")}
      ${check("Retain clipboard data upon application restart", true)}
      ${check("Skip clips that apps mark as private", true, "KeePass, 1Password, Bitwarden")}`;

const history = `
      ${row("Number of days to keep items in history", spinner("30"), "0 keeps everything")}
      ${check("Store images in history", false)}
      ${row("Quality of preview thumbnail", spinner("90"), "JPEG quality for stored image previews")}
      ${section("History window")}
      ${check("Search matches partial text by default", true)}
      ${check("Close the History window after Insta-Paste", true)}
      ${check("Insta-Paste also writes the system clipboard", false)}`;

const shortcuts = `
      ${row("Paste mode", `<div style="display: flex; align-items: center; gap: 8px;"><span class="badge" style="font-size: 10.5px;">Ctrl +</span>${edit("V", 48)}</div>`, "Single key, used together with Ctrl")}
      ${row("Action mode", hotkey("Ctrl + Shift + A"))}
      ${row("Clipboard History", hotkey(""))}
      ${row("Channel Organizer", hotkey(""))}
      ${row("Plugin Manager", hotkey(""))}
      ${row("Hold clip", hotkey(""))}
      ${section("Files and folders")}
      ${row("Copy file path(s)", hotkey(""))}
      ${row("Copy active folder path", hotkey(""))}
      ${row("Copy file data", hotkey(""))}
      ${section("System")}
      ${row("One time stop", hotkey(""))}`;

const channels = `
      ${row("PitSwap hotkey", hotkey(""), "Jumps to the channel named “pit” and back")}
      ${section("Ignored windows")}
      ${row("Windows where Clipjump stays out of the way", btn("Manage ignored windows"), "3 window classes ignored")}`;

const appearance = `
      ${row("Theme", ddl("Follow Windows"))}
      ${row("Accent color", `<div style="display: flex; gap: 8px; align-items: center;">${ddl("Custom", 120)}<span style="width: 24px; height: 24px; border-radius: 4px; background: var(--accent); border: 1px solid var(--border);"></span>${edit("#E5484D", 78)}${btn("Pick…")}</div>`, "Windows accent follows your system setting")}
      ${section("Notifications")}
      ${check("Show a confirmation when copying", true)}
      ${row("Notification position", ddl("Near the cursor"))}
      ${check("Beep when copied", false)}
      ${row("Beep frequency", spinner("1500"))}
      ${check("Show “Pasting…” in the card", false)}
      ${section("Paste mode card")}
      ${row("Pinned position", `<div style="display: flex; gap: 8px; align-items: center;">${edit("", 70)}${edit("", 70)}${btn("Use cursor")}</div>`, "Leave empty to follow the cursor")}`;

const advanced = `
      ${check("Record duplicate copies", true)}
      ${row("Cut behaves like delete in", edit("XLMAIN QWidget", 220), "Window classes, space separated")}
      ${check("Use Win-based shortcuts for copy/cut to Clipjump", false)}
      ${row("Windows copy shortcut", hotkey(""), "Only when Win-based shortcuts are enabled")}
      ${row("Windows cut shortcut", hotkey(""))}
      ${check("Use the Windows key instead of Ctrl for paste mode", false)}
      ${check("Search box as a separate window", false, "for input methods that need composition")}
      ${section("Editors")}
      ${row("Text editor", edit("Notepad.exe", 220))}
      ${row("Image editor", edit("mspaint.exe", 220))}
      ${section("System")}
      ${row("Process priority", ddl("Normal", 120))}
      ${check("Flush memory after each operation", false)}
`;

const settingsPages = { Main: ["general", general], SettingsHistory: ["history", history], SettingsShortcuts: ["shortcuts", shortcuts], SettingsChannels: ["channels", channels], SettingsAppearance: ["appearance", appearance], SettingsAdvanced: ["advanced", advanced] };
for (const [file, [id, body]] of Object.entries(settingsPages))
  writeFileSync(join(here, `${file}.dc.html`), settingsWindow(id, body, file === "SettingsAppearance"));

// ---------- About ----------
writeFileSync(join(here, "About.dc.html"), wrap(440, 380, `
  ${titlebar("About Clipjump")}
  <div style="display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 20px 28px 8px 28px; text-align: center;">
    <svg viewBox="0 0 16 16" style="width: 56px; height: 56px;"><circle cx="8" cy="8" r="6.5" fill="none" stroke="var(--accent)" stroke-width="2"></circle><path d="M10.5 6.3A3 3 0 1 0 10.5 9.7" fill="none" stroke="var(--text)" stroke-width="1.6" stroke-linecap="round"></path></svg>
    <div style="font-size: 22px; font-weight: 600; margin-top: 6px;">Clipjump</div>
    <div style="color: var(--muted);">Version 13.0 · AutoHotkey v2 · portable</div>
    <div style="margin-top: 4px;"><a href="#">Avi Aryan</a> <span style="color: var(--muted);">© 2013-2026</span></div>
    <div style="margin-top: 14px; max-width: 340px; color: var(--text); text-wrap: pretty;">A multiple clipboard manager. Hold Ctrl and tap V to cycle through everything you have copied, then release to paste.</div>
  </div>
  <div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 28px 0 28px; flex-grow: 1;">
    <div style="display: flex; align-items: center; gap: 10px;"><span>Language</span>${ddl("english", 140)}</div>
  </div>
  <div class="footer" style="height: 52px; justify-content: space-between;">
    ${btn("Reset Clipjump…")}
    ${btn("OK", "primary")}
  </div>`));

// ---------- Plugin Manager ----------
const plugins = [["Common Formats", "pformat", "Avi"], ["Delete [File/Folder]", "clip management file folder", "Avi"], ["History file paths cleaner", "history cleaning", "Avi"], ["Hotstring-Paste", "instant pasting", "AutoHotkey, Avi"], ["Ignored Window Manager", "system", "fump2000"], ["NoFormatting Paste", "no-format paste", "Avi"], ["SentenceCase", "pformat", "Avi"], ["Sync Clipjump Clipboard", "system clipboard clipjump", "Avi"], ["Translation File Cleaner", "translation maintenance", "Avi"], ["Trim Formatting", "pformat", "Avi"]];
const cols = "grid-template-columns: 2fr 2.2fr 1fr;";
writeFileSync(join(here, "PluginManager.dc.html"), wrap(680, 470, `
  ${titlebar("Clipjump Plugin Manager")}
  <div style="display: flex; flex-direction: column; gap: 10px; padding: 12px 14px 0 14px; flex-grow: 1; min-height: 0;">
    <div style="display: flex; align-items: center; gap: 8px;">
      <div class="edit" style="height: 26px; flex-grow: 1; gap: 8px; color: var(--muted);"><svg viewBox="0 0 16 16" style="width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.5;"><circle cx="7" cy="7" r="4.5"></circle><path d="M10.5 10.5 14 14"></path></svg><span>Search plugins</span></div>
      ${btn("Run", "primary")}${btn("Edit")}${btn("Properties")}
    </div>
    <div class="list" style="flex-grow: 1;">
      <div class="hdr" style="${cols}"><span>Name</span><span>Tags</span><span>Author</span></div>
      ${plugins.map(([n, t, a], i) => `<div class="li${i === 0 ? " sel" : ""}" style="${cols}"><span>${n}</span><span style="color: var(--muted);">${t}</span><span>${a}</span></div>`).join("\n      ")}
    </div>
  </div>
  <div class="status" style="height: 24px;">10 plugins · Double-click runs a plugin</div>`));

// ---------- Ignored Windows ----------
writeFileSync(join(here, "IgnoredWindows.dc.html"), wrap(420, 400, `
  ${titlebar("Ignored Windows")}
  <div style="display: flex; flex-direction: column; gap: 10px; padding: 12px 14px 0 14px; flex-grow: 1; min-height: 0;">
    <div style="color: var(--muted); font-size: 12px; text-wrap: pretty;">Clipjump does not capture copies made in these windows and Ctrl+V pastes normally there.</div>
    <div class="list" style="flex-grow: 1;">
      <div class="hdr" style="grid-template-columns: 1fr;"><span>Window class</span></div>
      <div class="li sel" style="grid-template-columns: 1fr;"><span>KeePass2</span></div>
      <div class="li" style="grid-template-columns: 1fr;"><span>Chrome_WidgetWin_1</span></div>
      <div class="li" style="grid-template-columns: 1fr;"><span>PuTTY</span></div>
    </div>
    <div style="display: flex; gap: 8px; align-items: center;">
      ${btn("Pick a window…", "primary")}${btn("Remove")}
      <span class="hint" style="color: var(--muted); font-size: 12px; margin-left: auto;">Hover the window, press Space</span>
    </div>
  </div>
  <div class="footer" style="height: 52px;">${btn("Close")}</div>`));

// ---------- small dialogs (three in one artboard) ----------
const dlg = (w, h, caption, inner) => `<div class="win" style="width: ${w}px; height: ${h}px; box-shadow: 0 8px 28px rgba(0,0,0,.35);">${titlebar(caption)}${inner}</div>`;
writeFileSync(join(here, "Dialogs.dc.html"), `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${helmet}
<div style="display: flex; gap: 32px; align-items: flex-start; padding: 24px; background: var(--bg); width: 1380px; height: 340px; box-sizing: border-box; {{vars}}">
  ${dlg(520, 292, "New Clip", `
  <div style="display: flex; flex-direction: column; gap: 8px; padding: 12px 16px 0 16px; flex-grow: 1;">
    <div>New clip will be created in channel <b>0 - Default</b></div>
    <div class="edit" style="height: 150px; align-items: flex-start; padding: 8px; font-family: Consolas, 'Cascadia Mono', monospace; font-size: 12.5px; color: var(--muted);">Type or paste the clip text</div>
  </div>
  <div class="footer" style="height: 52px;">${btn("OK", "primary")}${btn("Cancel")}</div>`)}
  ${dlg(380, 292, "Clip Properties", `
  <div style="display: flex; flex-direction: column; gap: 4px; padding: 12px 16px 0 16px; flex-grow: 1;">
    <div style="color: var(--muted); font-size: 12px; margin-bottom: 6px;">Channel 0 · Clip 3 of 28</div>
    ${row("Fixed", `<div class="box on">${svgCheck}</div>`)}
    ${row("Tags", edit("work urgent", 200))}
  </div>
  <div class="footer" style="height: 52px;">${btn("Save", "primary")}${btn("Cancel")}</div>`)}
  ${dlg(360, 292, "Select Channel", `
  <div style="display: flex; flex-direction: column; gap: 8px; padding: 12px 16px 0 16px; flex-grow: 1; min-height: 0;">
    <div>Choose the destination channel</div>
    <div class="list" style="flex-grow: 1;">
      <div class="li sel" style="grid-template-columns: 32px 1fr;"><span style="color: var(--muted);">0</span><span>Default</span></div>
      <div class="li" style="grid-template-columns: 32px 1fr;"><span style="color: var(--muted);">1</span><span>work</span></div>
      <div class="li" style="grid-template-columns: 32px 1fr;"><span style="color: var(--muted);">2</span><span>pit</span></div>
    </div>
  </div>
  <div class="footer" style="height: 52px;">${btn("OK", "primary")}${btn("Cancel")}</div>`)}
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`);

// ---------- canvas layout ----------
const canvas = {
  artboards: [
    { file: "Main.dc.html", title: "Settings · General", x: 0, y: 0, w: 760, h: 620 },
    { file: "SettingsHistory.dc.html", title: "Settings · Clipboard History", x: 860, y: 0, w: 760, h: 620 },
    { file: "SettingsShortcuts.dc.html", title: "Settings · Shortcuts", x: 1720, y: 0, w: 760, h: 620 },
    { file: "SettingsChannels.dc.html", title: "Settings · Channels", x: 0, y: 780, w: 760, h: 620 },
    { file: "SettingsAppearance.dc.html", title: "Settings · Appearance", x: 860, y: 780, w: 760, h: 620 },
    { file: "SettingsAdvanced.dc.html", title: "Settings · Advanced", x: 1720, y: 780, w: 760, h: 620 },
    { file: "About.dc.html", title: "About", x: 0, y: 1560, w: 440, h: 380 },
    { file: "PluginManager.dc.html", title: "Plugin Manager", x: 540, y: 1560, w: 680, h: 470 },
    { file: "IgnoredWindows.dc.html", title: "Ignored Windows", x: 1320, y: 1560, w: 420, h: 400 },
    { file: "Dialogs.dc.html", title: "Small dialogs", x: 0, y: 2180, w: 1380, h: 340 },
  ],
  annotations: [
    { id: "brief", x: 0, y: -280, w: 520, text: "Phase 3 native windows. Palette and type from Theme.ahk (the paste-mode card). Every artboard has a Dark switch and an Accent swatch in its tweak row: flip them to see the light theme or another Windows accent.\nWin32 limits: GroupBoxes become section headers, the Hotkey control becomes a click-to-record field, spinners are Edit + two small buttons." },
    { id: "settings-note", x: 2600, y: 0, w: 300, text: "Settings: left nav, one page per topic, 8px grid, min 720×520 and resizable. Apply enables only after a change (shown enabled on the Appearance page).\nNew in 13.0: the Appearance page (theme, notification position, pinned card position) and the private-clips switch under General." },
    { id: "dialogs-note", x: 1480, y: 2180, w: 280, text: "Small dialogs keep their behavior; they only pick up the theme, Segoe UI and consistent button rows. Ignored Windows moves in-process so adding a class no longer restarts Clipjump." },
  ],
  launch: { view: "canvas" },
};
writeFileSync(join(here, "canvas.json"), JSON.stringify(canvas, null, 2) + "\n");
console.log("wrote", Object.keys(settingsPages).length + 4, "artboards + canvas.json");
