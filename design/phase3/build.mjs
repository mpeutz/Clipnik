// Generates the Phase 3 window mockups (.dc.html artboards + canvas.json) from one shared shell.
// Run: node design/phase3/build.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

// ---------- shared theme (mirrors src/ui/native/Theme.ahk) ----------
const dark = { bg: "#202020", surface: "#2B2B2B", surfaceAlt: "#363636", border: "#3F3F3F", text: "#F0F0F0", muted: "#9A9A9A", hover: "#333333" };
const light = { bg: "#F3F3F3", surface: "#FFFFFF", surfaceAlt: "#EDEDED", border: "#D9D9D9", text: "#1B1B1B", muted: "#6B6B6B", hover: "#E9E9E9" };

const props = `{"dark":{"editor":"boolean","default":true,"section":"Theme"},"accent":{"editor":"color","default":"#C42B1C","options":["#C42B1C","#0078D4","#107C10","#8764B8"],"section":"Theme"}}`;

const logic = `
class Component extends DCLogic {
  renderVals() {
    const d = this.props.dark ?? true;
    const p = d ? ${JSON.stringify(dark)} : ${JSON.stringify(light)};
    const accent = this.props.accent ?? '#C42B1C';
    const vars = Object.entries(p).map(([k, v]) => '--' + k + ':' + v).join(';') + ';--accent:' + accent + ';--accentText:#FFFFFF';
    return { vars };
  }
}`;

const helmet = `
<helmet>
  <style>
    body { margin: 0; font-family: "Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif; font-size: 13.33px; line-height: 1.35; }
    a { color: var(--accent); } a:hover { color: var(--accent); text-decoration: underline; }
    .win { background: var(--bg); color: var(--text); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 8px 28px rgba(0,0,0,.35); }
    .title { display: flex; align-items: center; gap: 10px; height: 32px; padding: 0 0 0 12px; font-size: 12px; }
    .title .caption { flex-grow: 1; }
    .title .wc { width: 46px; height: 32px; display: flex; align-items: center; justify-content: center; color: var(--text); }
    .nav { width: 168px; flex: 0 0 auto; padding: 8px; display: flex; flex-direction: column; gap: 2px; }
    .nav .item { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: 4px; color: var(--text); position: relative; }
    .nav .item.sel { background: var(--hover); }
    .nav .item.sel::before { content: ""; position: absolute; left: 0; top: 10px; bottom: 10px; width: 3px; border-radius: 2px; background: var(--accent); }
    .nav svg { width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; }
    .content { flex: 1 1 0; min-width: 0; background: var(--surface); border-left: 1px solid var(--border); border-top: 1px solid var(--border); border-top-left-radius: 8px; padding: 20px 24px; display: flex; flex-direction: column; gap: 6px; overflow: hidden; }
    .h1 { font-size: 20px; font-weight: 600; margin: 0 0 8px 0; }
    .section { font-size: 11px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); margin: 10px 0 2px 0; padding-bottom: 5px; border-bottom: 1px solid var(--border); }
    .row { display: flex; align-items: center; justify-content: space-between; gap: 16px; min-height: 32px; } .row .lbl { flex: 1 1 0; min-width: 0; } .row > :not(.lbl) { flex: 0 0 auto; }
    .row .lbl { flex-grow: 1; }
    .row .hint { color: var(--muted); font-size: 12px; }
    .check { display: flex; align-items: center; gap: 10px; min-height: 28px; }
    .box { width: 16px; height: 16px; border: 1px solid var(--muted); border-radius: 3px; background: var(--surfaceAlt); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
    .box.on { background: var(--accent); border-color: var(--accent); }
    .box svg { width: 12px; height: 12px; stroke: #fff; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
    .edit { height: 24px; padding: 0 8px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--text); display: flex; align-items: center; box-sizing: border-box; }
    .edit.num { width: 80px; justify-content: space-between; }
    .edit.num .spin { display: flex; flex-direction: column; gap: 1px; margin-right: -4px; color: var(--muted); }
    .edit.num .spin svg { width: 10px; height: 8px; stroke: currentColor; fill: none; stroke-width: 1.5; }
    .edit.ddl { width: 180px; justify-content: space-between; }
    .edit.ddl svg { width: 12px; height: 12px; stroke: var(--muted); fill: none; stroke-width: 1.5; }
    .edit.hk { width: 180px; font-family: Consolas, "Cascadia Mono", monospace; font-size: 12.5px; }
    .edit.hk.empty { color: var(--muted); font-family: inherit; font-size: 13.33px; }
    .btn { height: 26px; min-width: 76px; padding: 0 14px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--text); display: inline-flex; align-items: center; justify-content: center; box-sizing: border-box; }
    .btn.primary { background: var(--accent); border-color: var(--accent); color: var(--accentText); }
    .btn.dis { opacity: .45; }
    .footer { height: 52px; display: flex; align-items: center; justify-content: flex-end; gap: 8px; padding: 0 24px; background: var(--bg); }
    .list { border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); display: flex; flex-direction: column; overflow: hidden; }
    .list .hdr { display: grid; height: 26px; align-items: center; padding: 0 10px; color: var(--muted); font-size: 12px; border-bottom: 1px solid var(--border); }
    .list .li { display: grid; height: 28px; align-items: center; padding: 0 10px; }
    .list .li.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .status { height: 24px; display: flex; align-items: center; padding: 0 12px; font-size: 12px; color: var(--muted); border-top: 1px solid var(--border); background: var(--bg); }
    .badge { font-size: 10.5px; padding: 2px 7px; border-radius: 4px; background: var(--surfaceAlt); }
    .badge.accent { background: var(--accent); color: var(--accentText); }
  </style>
</helmet>`;

const svgCheck = `<svg viewBox="0 0 12 12"><path d="M2.5 6.5 5 9l4.5-6"></path></svg>`;
const svgChevron = `<svg viewBox="0 0 12 12"><path d="M3 4.5 6 7.5 9 4.5"></path></svg>`;
const spinner = (v) => `<div class="edit num" style="height: 24px; width: 80px;"><span>${v}</span><span class="spin"><svg viewBox="0 0 10 8"><path d="M2 6 5 3l3 3"></path></svg><svg viewBox="0 0 10 8"><path d="M2 2l3 3 3-3"></path></svg></span></div>`;
const ddl = (v, w = 180) => `<div class="edit ddl" style="height: 24px; width: ${w}px;"><span>${v}</span>${svgChevron}</div>`;
const edit = (v, w = 180) => `<div class="edit" style="height: 24px; width: ${w}px;"><span>${v}</span></div>`;
const hotkey = (v) => v ? `<div class="edit hk" style="height: 24px; width: 180px;"><span>${v}</span></div>` : `<div class="edit hk empty" style="height: 24px; width: 180px;"><span>Click to record</span></div>`;
const check = (label, on, hint = "") => `<div class="check" style="min-height: 28px;"><div class="box${on ? " on" : ""}">${on ? svgCheck : ""}</div><div>${label}${hint ? ` <span class="hint" style="color: var(--muted); font-size: 12px;">${hint}</span>` : ""}</div></div>`;
const row = (label, control, hint = "") => `<div class="row" style="min-height: 32px;"><div class="lbl">${label}${hint ? `<div class="hint">${hint}</div>` : ""}</div>${control}</div>`;
const section = (t) => `<div class="section">${t}</div>`;
const btn = (t, cls = "") => `<div class="btn${cls ? " " + cls : ""}" style="height: 26px;">${t}</div>`;

const icons = {
  general: `<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.5"></circle><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"></path></svg>`,
  history: `<svg viewBox="0 0 16 16"><path d="M2.5 8a5.5 5.5 0 1 0 1.6-3.9M2.5 2.5v3h3M8 5v3.5l2.5 1.5"></path></svg>`,
  shortcuts: `<svg viewBox="0 0 16 16"><rect x="1.5" y="4" width="13" height="8.5" rx="1.5"></rect><path d="M4 7h1M7 7h1M10 7h2M4.5 10h7"></path></svg>`,
  channels: `<svg viewBox="0 0 16 16"><rect x="2" y="2" width="5" height="5" rx="1"></rect><rect x="9" y="2" width="5" height="5" rx="1"></rect><rect x="2" y="9" width="5" height="5" rx="1"></rect><rect x="9" y="9" width="5" height="5" rx="1"></rect></svg>`,
  appearance: `<svg viewBox="0 0 16 16"><path d="M8 1.8a6.2 6.2 0 1 0 0 12.4c1.2 0 1.6-.9 1.1-1.7-.6-.9.1-2 1.2-2h1.4A2.5 2.5 0 0 0 14.2 8 6.2 6.2 0 0 0 8 1.8z"></path><circle cx="5" cy="7" r=".9"></circle><circle cx="8" cy="4.8" r=".9"></circle><circle cx="11" cy="6.5" r=".9"></circle></svg>`,
  advanced: `<svg viewBox="0 0 16 16"><path d="M3 4h10M3 8h10M3 12h10"></path><circle cx="6" cy="4" r="1.3" fill="var(--surface)"></circle><circle cx="11" cy="8" r="1.3" fill="var(--surface)"></circle><circle cx="7" cy="12" r="1.3" fill="var(--surface)"></circle></svg>`,
};
const pages = [["general", "General"], ["history", "Clipboard History"], ["shortcuts", "Shortcuts"], ["channels", "Channels"], ["appearance", "Appearance"], ["advanced", "Advanced"]];

const titlebar = (caption) => `
  <div class="title" style="height: 32px;">
    <svg viewBox="0 0 16 16" style="width: 16px; height: 16px;"><circle cx="8" cy="8" r="6.5" fill="none" stroke="var(--accent)" stroke-width="2"></circle><path d="M10.5 6.3A3 3 0 1 0 10.5 9.7" fill="none" stroke="var(--text)" stroke-width="1.6" stroke-linecap="round"></path></svg>
    <div class="caption">${caption}</div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><path d="M0 5h10" stroke="currentColor"></path></svg></div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><rect x=".5" y=".5" width="9" height="9" fill="none" stroke="currentColor"></rect></svg></div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><path d="M0 0l10 10M10 0 0 10" stroke="currentColor"></path></svg></div>
  </div>`;

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
const wrap = (w, h, inner) => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${helmet}
<div class="win" style="width: ${w}px; height: ${h}px; {{vars}}">
${inner}
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`;

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
