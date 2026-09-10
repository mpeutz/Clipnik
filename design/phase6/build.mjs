// Clip intelligence mockups: the paste card with a kind pill and the Z format menu, History with a type filter
// and type actions, copy toasts with an action chip, and the Settings Rules page with its editor dialog.
// Run: node design/phase6/build.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { helmet, props, logic, ddl, edit, btn, check, row, section, icons, pages, titlebar, wrap } from "../shared.mjs";

const here = dirname(fileURLToPath(import.meta.url));

// ---------- glyphs (Lucide) ----------
const L = {
  check: `<path d="M20 6 9 17l-5-5"/>`,
  pin: `<path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>`,
  tag: `<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>`,
  wand: `<path d="M15 4V2"/><path d="M15 16v-2"/><path d="M8 9h2"/><path d="M20 9h2"/><path d="M17.8 11.8 19 13"/><path d="M15 9h.01"/><path d="M17.8 6.2 19 5"/><path d="m3 21 9-9"/><path d="M12.2 6.2 11 5"/>`,
  search: `<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>`,
  ban: `<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>`,
  zap: `<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>`,
  chevron: `<path d="m6 9 6 6 6-6"/>`,
  plus: `<path d="M5 12h14"/><path d="M12 5v14"/>`,
  rules: `<path d="M3 6h18"/><path d="M7 12h10"/><path d="M10 18h4"/>`,
};
const icon = (name, size = 16, extra = "") => `<svg viewBox="0 0 24 24" style="width: ${size}px; height: ${size}px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex: 0 0 auto; ${extra}">${L[name]}</svg>`;

// ---------- board CSS (adds to the shared helmet) ----------
const css = `
    .stage { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 36px 44px; padding: 28px 32px 32px 32px; background: var(--bg); color: var(--text); box-sizing: border-box; align-content: start; align-items: start; }
    .lbl { font-size: 11.5px; color: var(--muted); margin-bottom: 8px; letter-spacing: .02em; }
    .desk { background: #1a1d24; background-image: radial-gradient(circle at 30% 20%, #2a3140 0, transparent 55%); padding: 24px; border-radius: 6px; display: flex; flex-direction: column; align-items: flex-start; gap: 14px; min-height: 100px; }
    .kbd { display: inline-flex; align-items: center; height: 18px; padding: 0 6px; border-radius: 5px; background: color-mix(in srgb, var(--text) 10%, transparent); color: var(--text); font-size: 11px; }
    .pill { display: inline-flex; align-items: center; gap: 5px; height: 20px; padding: 0 9px; border-radius: 10px; font-size: 10.5px; font-weight: 600; background: var(--surfaceAlt); color: var(--text); white-space: nowrap; }
    .pill.accent { background: var(--accent); color: var(--accentText); }
    .pill.kind { background: color-mix(in srgb, var(--accent) 18%, var(--surfaceAlt)); color: var(--text); letter-spacing: .04em; }
    .sw { width: 10px; height: 10px; border-radius: 3px; border: 1px solid rgba(255,255,255,.25); }
    .mono { font-family: Consolas, "Cascadia Mono", monospace; font-size: 12.5px; }
    .dim { color: var(--muted); }
    .note { font-size: 12px; color: var(--muted); line-height: 1.45; }
    .note b { color: var(--text); font-weight: 600; }
    .budget { grid-column: 1 / -1; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; border-top: 1px solid var(--border); padding-top: 16px; }
    .toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 12px; }
    .search { flex-grow: 1; height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--muted); }
    .search svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.5; }
    .chip { font-size: 11px; padding: 2px 8px; border-radius: 10px; border: 1px solid var(--border); color: var(--muted); }
    .chip.on { background: var(--accent); border-color: var(--accent); color: var(--accentText); }
    .split { display: flex; flex-grow: 1; min-height: 0; border-top: 1px solid var(--border); position: relative; }
    .pane { display: flex; flex-direction: column; min-width: 0; }
    .table { flex-grow: 1; overflow: hidden; }
    .table .hdr { display: grid; gap: 12px; height: 28px; align-items: center; padding: 0 12px; color: var(--muted); font-size: 12px; border-bottom: 1px solid var(--border); background: var(--surface); }
    .table .tr { display: grid; gap: 12px; height: 30px; align-items: center; padding: 0 12px; border-bottom: 1px solid color-mix(in srgb, var(--border) 50%, transparent); white-space: nowrap; }
    .table .tr > span { overflow: hidden; text-overflow: ellipsis; }
    .table .tr.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .preview { width: 380px; flex: 0 0 auto; border-left: 1px solid var(--border); background: var(--surface); display: flex; flex-direction: column; position: relative; }
    .preview .ph { display: flex; align-items: center; gap: 8px; padding: 10px 14px; border-bottom: 1px solid var(--border); }
    .preview .body { flex-grow: 1; padding: 12px 14px; overflow: hidden; white-space: pre-wrap; word-break: break-word; }
    .preview .actions { display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 14px; border-top: 1px solid var(--border); background: var(--bg); }
    .abtn { height: 26px; padding: 0 10px; display: inline-flex; align-items: center; gap: 6px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--text); }
    .abtn.primary { background: var(--accent); border-color: var(--accent); color: var(--accentText); }
    .abtn kbd { font-family: inherit; font-size: 10.5px; color: var(--muted); background: var(--surface); border: 1px solid var(--border); border-radius: 3px; padding: 0 4px; }
    .abtn.primary kbd { color: var(--accentText); background: transparent; border-color: rgba(255,255,255,.4); }
    .menu { position: absolute; background: var(--surface); border: 1px solid var(--border); border-radius: 6px; box-shadow: 0 10px 28px rgba(0,0,0,.45); padding: 4px; min-width: 200px; z-index: 2; }
    .menu .mi { display: flex; align-items: center; gap: 10px; height: 28px; padding: 0 10px; border-radius: 4px; }
    .menu .mi.hot { background: var(--hover); }
    .menu .mi .k { margin-left: auto; color: var(--muted); font-size: 11px; }
    .menu .sep { height: 1px; background: var(--border); margin: 4px 6px; }
    .menu .mh { font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; padding: 6px 10px 2px 10px; }
    .status { height: 24px; display: flex; align-items: center; padding: 0 12px; font-size: 12px; color: var(--muted); border-top: 1px solid var(--border); background: var(--bg); }
    .lv { border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); display: flex; flex-direction: column; overflow: hidden; flex-grow: 1; }
    .lv .hdr { display: grid; height: 26px; align-items: center; padding: 0 10px; color: var(--muted); font-size: 12px; border-bottom: 1px solid var(--border); }
    .lv .li { display: grid; height: 30px; align-items: center; padding: 0 10px; }
    .lv .li.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .lv .li.off { color: var(--muted); }
    .dlg { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 460px; background: var(--bg); color: var(--text); border: 1px solid var(--border); border-radius: 8px; box-shadow: 0 16px 40px rgba(0,0,0,.5); display: flex; flex-direction: column; overflow: hidden; }
    .dlg .b { padding: 8px 20px 12px 20px; display: flex; flex-direction: column; gap: 4px; }
    .shade { position: absolute; inset: 0; background: rgba(0,0,0,.35); }
`;
const boardHelmet = helmet.replace("</style>", css + "  </style>");

const board = (w, h, inner) => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${boardHelmet}
<div class="stage" style="width: ${w}px; height: ${h}px; {{vars}}">
${inner}
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`;
const windowBoard = (w, h, inner) => wrap(w, h, inner).replace(helmet, boardHelmet);

const block = (label, body, span = false) => `<div${span ? ' style="grid-column: 1 / -1;"' : ""}><div class="lbl">${label}</div><div class="desk">${body}</div></div>`;
const kbd = (k, extra = "") => `<span class="kbd" style="${extra}">${k}</span>`;
const hint = (pairs) => `<span style="margin-left: auto; display: inline-flex; gap: 10px;">${pairs.map(([k, t]) => `<span style="display: inline-flex; align-items: center; gap: 4px;">${kbd(k)}${t}</span>`).join("")}</span>`;

// ---------- the paste card (as shipped in Phase 5) ----------
const shell = (inner, w = 480) => `<div style="width: ${w}px; background: color-mix(in srgb, var(--surface) 96%, transparent); border: 1px solid color-mix(in srgb, var(--text) 12%, transparent); border-radius: 8px; box-shadow: 0 12px 32px rgba(0,0,0,.45); box-sizing: border-box; overflow: hidden;">${inner}</div>`;
const head = (kind, format, extra = "") => `<div style="display: flex; align-items: center; gap: 8px; padding: 12px 14px 8px 14px;"><span class="pill accent" style="height: 22px; border-radius: 11px; font-size: 12px;">Default</span><span style="font-size: 16px; font-weight: 600;">3<span class="dim" style="font-weight: 400; font-size: 12px;"> / 40</span></span>${kind}${format ? `<span class="pill">${format}</span>` : ""}${extra}<span style="margin-left: auto; color: var(--accent); display: inline-flex; gap: 6px; align-items: center; font-size: 12px;">${icon("pin", 13)}pinned</span></div>`;
const body = (inner) => `<div style="margin: 0 14px; padding: 8px 12px; background: color-mix(in srgb, var(--text) 5%, transparent); line-height: 1.45;">${inner}</div>`;
const foot = (pairs, left = `${icon("tag", 12)}<span>work · urgent</span>`) => `<div style="display: flex; align-items: center; gap: 8px; padding: 10px 14px 12px 14px; font-size: 11.5px; color: var(--muted);">${left}${hint(pairs)}</div>`;
const kindPill = (k, swatch = "") => `<span class="pill kind">${swatch ? `<span class="sw" style="background: ${swatch};"></span>` : ""}${k}</span>`;
const normalKeys = [["V", "next"], ["C", "back"], ["X", "mode"], ["Z", "format"], ["F1", "help"]];

const cardUrl = shell(head(kindPill("URL"), "Trim Formatting") + body(`<span class="mono">https://github.com/aviaryan/Clipjump/issues/143?utm_source=newsletter&amp;utm_medium=email</span>`) + foot(normalKeys));
const cardColor = shell(head(kindPill("COLOR", "#1DBC55"), "") + body(`<span class="mono">#1DBC55</span>`) + foot(normalKeys, `<span class="dim">no tags</span>`));
const cardJson = shell(head(kindPill("JSON"), "Pretty JSON") + body(`<span class="mono" style="white-space: pre;">{\n  "id": 143,\n  "title": "Paste mode ignores Ctrl release",\n  "labels": ["bug", "paste-mode"]\n}</span>`) + foot(normalKeys, `<span class="dim">no tags</span>`));

const fmtRow = (k, t, opts = {}) => `<div style="display: flex; align-items: center; gap: 10px; height: 26px; padding: 0 8px; border-radius: 6px; ${opts.sel ? "background: color-mix(in srgb, var(--text) 8%, transparent);" : ""} ${opts.dim ? "color: var(--muted);" : ""}">${kbd(k, "width: 22px; justify-content: center; padding: 0;")}<span>${t}</span>${opts.active ? `<span style="margin-left: auto; color: var(--accent);">${icon("check", 13)}</span>` : ""}</div>`;
const zMenu = shell(
  head(kindPill("URL"), "Trim Formatting") +
  `<div style="display: flex; align-items: center; gap: 8px; padding: 4px 14px 4px 14px;">${icon("wand", 14, "color: var(--accent);")}<span style="font-weight: 600;">Paste format</span><span class="dim" style="margin-left: auto; font-size: 12px;">letter picks · Esc closes</span></div>
   <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0 12px; padding: 0 8px 4px 8px; font-size: 12.5px;">
     <div style="grid-column: 1 / -1; font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; padding: 4px 8px 2px 8px;">For this URL</div>
     ${fmtRow("O", "Original", {})}${fmtRow("T", "Trim Formatting", { active: true, sel: true })}${fmtRow("S", "Strip URL tracking")}${fmtRow("M", "Markdown link")}${fmtRow("N", "No formatting")}${fmtRow("L", "One line")}
     <div style="grid-column: 1 / -1; font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; padding: 8px 8px 2px 8px;">Other formats</div>
     ${fmtRow("U", "Upper case", { dim: true })}${fmtRow("W", "Lower case", { dim: true })}${fmtRow("I", "Title case", { dim: true })}${fmtRow("G", "Slugify", { dim: true })}${fmtRow("E", "Sentence case", { dim: true })}${fmtRow("P", "Pretty JSON", { dim: true })}${fmtRow("J", "Minified JSON", { dim: true })}${fmtRow("B", "Decode base64", { dim: true })}
   </div>` +
  foot([["Enter", "pick"], ["Z", "close"]], `<span class="dim">Ctrl stays held</span>`), 496);

writeFileSync(join(here, "PasteCard.dc.html"), board(1120, 900, `
  <div style="grid-column: 1 / -1; display: flex; align-items: baseline; gap: 14px;"><span style="font-size: 18px; font-weight: 600;">Paste card: kind pill and the Z format menu</span><span class="note">The format pill that reads TEXT today shows the detected kind. Z opens a menu on the card instead of cycling.</span></div>
  ${block("URL clip in paste mode", cardUrl)}
  ${block("Color clip: the pill carries a swatch", cardColor)}
  ${block("JSON clip with the Pretty JSON format active", cardJson)}
  ${block("Z pressed: format menu, formats that fit the kind first, active one checked", zMenu)}
  <div class="budget"><div class="note"><b>Kind pill</b><br>Tinted with 18% accent so it reads as information, not as a mode. The channel pill stays solid accent, paste formats stay on the neutral pill. Plain text shows TEXT as today; images and files keep IMAGE and FILE.</div><div class="note"><b>Z menu</b><br>Same card, same menu rows Action Mode uses. Applicable formats first, the rest dimmed but still pickable. Letter or Enter picks and returns to the normal card; Esc or Z closes without change. Ctrl stays held throughout.</div></div>`));

// ---------- History with type filter and actions ----------
const hcols = "grid-template-columns: 1fr 76px 150px 70px;";
const hrows = [
  ["https://github.com/aviaryan/Clipjump/issues/143?utm_source=newsletter", "URL", "Today 13:58", "72 B", true],
  ["Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is r…", "", "Today 14:22", "1.2 KB"],
  ["[IMAGE] 1280 x 720", "IMAGE", "Today 13:40", "214 KB"],
  ["{\"id\": 143, \"title\": \"Paste mode ignores Ctrl release\", \"labels\": [\"bug\"]}", "JSON", "Today 11:05", "82 B"],
  ["mike@example.com", "EMAIL", "Today 09:31", "16 B"],
  ["C:\\Users\\MikePeutz\\PortableApps\\Clipjump_new_x64\\design\\phase6", "PATH", "Yesterday 18:12", "61 B"],
  ["#1DBC55", "COLOR", "Yesterday 17:50", "7 B"],
  ["npm run build && node design/phase6/build.mjs", "", "Yesterday 16:02", "46 B"],
  ["def render(state):\n    return Card(state).draw()", "CODE", "Sun 19:33", "44 B"],
  ["1,299.00", "NUMBER", "Sun 20:15", "8 B"],
  ["+1 (415) 555-0134", "PHONE", "Sun 18:02", "17 B"],
  ["The quick brown fox jumps over the lazy dog", "", "Mon 10:44", "43 B"],
];
const kindBadge = (k) => `<span>${k ? `<span class="pill kind" style="height: 18px; font-size: 10px;">${k === "COLOR" ? `<span class="sw" style="background: #1DBC55;"></span>` : ""}${k}</span>` : ""}</span>`;
const historyTable = (rows) => `
      <div class="table">
        <div class="hdr" style="${hcols}"><span>Clip</span><span>Type</span><span>Date</span><span>Size</span></div>
        ${rows.map(([c, k, d, s, sel]) => `<div class="tr${sel ? " sel" : ""}" style="${hcols}"><span class="mono${c.startsWith("[IMAGE]") ? " dim" : ""}">${c.replace(/</g, "&lt;")}</span>${kindBadge(k)}<span class="dim">${d}</span><span class="dim">${s}</span></div>`).join("\n        ")}
      </div>`;
const abtn = (t, key = "", cls = "") => `<div class="abtn${cls ? " " + cls : ""}">${t}${key ? `<kbd>${key}</kbd>` : ""}</div>`;
const svgSearch = `<svg viewBox="0 0 16 16"><circle cx="7" cy="7" r="4.5"></circle><path d="M10.5 10.5 14 14"></path></svg>`;

const historyBoard = (withMenu) => windowBoard(1040, 660, `
  ${titlebar("Clipjump Clipboard History")}
  <div class="toolbar" style="height: 48px;">
    <div class="search" style="height: 28px;">${svgSearch}<span>Search history</span><span class="chip on">Partial</span><span class="chip">Exact</span></div>
    ${ddl(withMenu ? "All types" : "URL", 130)}
    ${btn("Refresh")}${btn("Clear history…")}
  </div>
  <div class="split">
    <div class="pane" style="flex-grow: 1;">${historyTable(withMenu ? hrows : hrows.filter((r) => r[1] === "URL").concat([["https://lucide.dev/icons/", "URL", "Mon 09:02", "24 B"], ["www.autohotkey.com/docs/v2/lib/InputHook.htm", "URL", "Sun 12:20", "45 B"]]))}</div>
    <div class="preview" style="width: 380px;">
      <div class="ph">${kindBadge("URL")}<span class="dim" style="font-size: 12px;">72 B · Today 13:58</span><div class="abtn" style="margin-left: auto; height: 24px; padding: 0 8px; gap: 4px;">${icon("zap", 13)}Actions${icon("chevron", 12)}</div></div>
      ${withMenu ? `<div class="menu" style="right: 14px; top: 44px;"><div class="mh">URL</div><div class="mi hot">${icon("zap", 13)}Open in browser<span class="k">Enter</span></div><div class="mi">Copy without tracking</div><div class="sep"></div><div class="mi">Copy<span class="k">Ctrl+C</span></div><div class="mi">Insta-Paste<span class="k">Space</span></div><div class="mi">Edit<span class="k">Ctrl+H</span></div><div class="mi">Delete<span class="k">Del</span></div></div>` : ""}
      <div class="body mono">https://github.com/aviaryan/Clipjump/issues/143?utm_source=newsletter&amp;utm_medium=email</div>
      <div class="actions">${abtn("Copy", "Ctrl+C", "primary")}${abtn("Insta-Paste", "Space")}${abtn("Hold", "Alt+C")}${abtn("Edit", "Ctrl+H")}${abtn("Export", "Ctrl+E")}${abtn("Delete", "Del")}</div>
    </div>
  </div>
  <div class="status" style="height: 24px;"><span>${withMenu ? "312 items" : "3 of 312 items match type URL"}</span><span style="margin-left: auto;">4.8 MB on disk · sorted by date</span></div>`);

writeFileSync(join(here, "History.dc.html"), historyBoard(true));
writeFileSync(join(here, "HistoryFiltered.dc.html"), historyBoard(false));

// ---------- copy toasts with kind and action chip ----------
const toast = (inner, tone = "var(--accent)", glyph = "check") => `<div style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px 0 11px; border-radius: 8px; background: color-mix(in srgb, var(--surface) 96%, transparent); border: 1px solid color-mix(in srgb, var(--text) 12%, transparent); box-shadow: 0 8px 22px rgba(0,0,0,.4); color: var(--text); font-size: 12.5px;">${icon(glyph, 14, `color: ${tone};`)}${inner}</div>`;
const chan = `<span class="pill accent">Default</span>`;
const act = (t) => `<span class="pill" style="border: 1px solid color-mix(in srgb, var(--accent) 60%, transparent); background: color-mix(in srgb, var(--accent) 14%, var(--surface)); color: var(--text); cursor: pointer;">${t}</span>`;
const kindLbl = (t) => `<span class="dim" style="font-size: 11.5px; letter-spacing: .04em;">${t}</span>`;

writeFileSync(join(here, "Toasts.dc.html"), board(1120, 700, `
  <div style="grid-column: 1 / -1; display: flex; align-items: baseline; gap: 14px;"><span style="font-size: 18px; font-weight: 600;">Copy toasts with a kind and one action</span><span class="note">Plain text looks as today. A recognized kind adds a muted label, and its primary action a clickable chip; those toasts stay 2.5 s.</span></div>
  ${block("Plain text (unchanged)", toast(`Transferred to Clipjump ${chan}`))}
  ${block("URL: Open in browser", toast(`Transferred to Clipjump ${chan}${kindLbl("URL")}${act("Open")}`))}
  ${block("Path: Reveal in Explorer", toast(`Transferred to Clipjump ${chan}${kindLbl("PATH")}${act("Reveal")}`))}
  ${block("Color: swatch in the label, copy as rgb", toast(`Transferred to Clipjump ${chan}<span class="sw" style="background: #1DBC55;"></span>${kindLbl("COLOR")}${act("Copy rgb")}`))}
  ${block("JSON: pretty-print into a new clip", toast(`Transferred to Clipjump ${chan}${kindLbl("JSON")}${act("Pretty-print")}`))}
  ${block("A rule ignored the clip (kind url from chrome.exe → ignore)", toast(`Not recorded: rule <b style="font-weight: 600;">Skip browser links</b>`, "#E0A526", "ban"))}
  <div class="budget"><div class="note"><b>Interaction</b><br>The toast stays a no-activate window: clicking the chip runs the action and hides the toast; the target app keeps focus. No keyboard access, by design. The chip is a Button drawn by the theme's pill painter.</div><div class="note"><b>Width</b><br>Toasts grow to fit up to 360 px; with a long channel name the message text truncates first, never the chip.</div></div>`));

// ---------- Settings: Rules page and the editor dialog ----------
const rulePages = [...pages.slice(0, 4), ["rules", "Rules"], ...pages.slice(4)];
icons.rules = `<svg viewBox="0 0 16 16"><path d="M2 4h12M4 8h8M6 12h4"></path></svg>`;
const nav = rulePages.map(([id, name]) => `<div class="item${id === "rules" ? " sel" : ""}" style="height: 36px;">${icons[id]}<span>${name}</span></div>`).join("\n      ");
const rcols = "grid-template-columns: 28px 1fr 190px;";
const rules = [
  [true, "URL from chrome.exe, msedge.exe", "Send to channel 2 · Links", true],
  [true, "EMAIL", "Add tag contact"],
  [true, "Text matching ^\\d{4} \\d{4} \\d{4} \\d{4}$", "Ignore"],
  [false, "JSON", "Apply Pretty JSON"],
  [true, "PATH from explorer.exe", "Send to channel 3 · Files"],
];
const box = (on) => `<div class="box${on ? " on" : ""}" style="width: 14px; height: 14px;">${on ? `<svg viewBox="0 0 12 12"><path d="M2.5 6.5 5 9l4.5-6"></path></svg>` : ""}</div>`;
const rulesList = `<div class="lv" style="min-height: 240px;"><div class="hdr" style="${rcols}"><span></span><span>When</span><span>Then</span></div>${rules.map(([on, w, t, sel]) => `<div class="li${sel ? " sel" : ""}${on ? "" : " off"}" style="${rcols}">${box(on)}<span>${w}</span><span>${t}</span></div>`).join("")}</div>`;
const settingsShell = (body, overlay = "") => windowBoard(760, 620, `
  ${titlebar("Clipjump Settings")}
  <div style="display: flex; flex-grow: 1; min-height: 0; position: relative;">
    <div class="nav" style="width: 168px;">
      ${nav}
    </div>
    <div class="content">
      <div class="h1">Rules</div>
      ${body}
    </div>
    ${overlay}
  </div>
  <div class="footer" style="height: 52px; justify-content: space-between;">
    <a href="#" style="font-size: 12.5px;">Open settings folder</a>
    <div style="display: flex; gap: 8px;">${btn("OK", "primary")}${btn("Cancel")}${btn("Apply")}</div>
  </div>`);
const rulesBody = `
      <div class="note" style="margin-bottom: 10px;">Rules run when a text clip is copied, top to bottom; the first match wins.</div>
      ${rulesList}
      <div style="display: flex; gap: 8px; margin-top: 10px;">${btn("Add…")}${btn("Edit…")}${btn("Remove")}<span style="flex-grow: 1;"></span>${btn("Up")}${btn("Down")}</div>`;

writeFileSync(join(here, "Rules.dc.html"), settingsShell(rulesBody));

const kinds = ["URL", "Email", "Path", "Color", "JSON", "Number", "Phone", "Code", "Text"];
const dialog = `<div class="shade"></div><div class="dlg">
  <div style="padding: 14px 20px 6px 20px; font-weight: 600; font-size: 14px;">Edit rule</div>
  <div class="b">
    ${section("When the clip")}
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 0 12px;">${kinds.map((k) => check(k, k === "URL")).join("")}</div>
    ${row("Text matches", edit("", 220), "regular expression, optional")}
    ${row("Copied from", `<div style="display: flex; gap: 6px;">${edit("chrome.exe, msedge.exe", 168)}${btn("Pick window…")}</div>`, "process or window class")}
    ${section("Then")}
    ${row("Action", ddl("Send to channel", 180))}
    ${row("Channel", ddl("2 · Links", 180))}
  </div>
  <div class="footer" style="height: 52px; padding: 0 20px;">${btn("OK", "primary")}${btn("Cancel")}</div>
</div>`;
writeFileSync(join(here, "RuleDialog.dc.html"), settingsShell(rulesBody, dialog));

const canvas = {
  pages: [{ id: "page-1", name: "Clip intelligence" }],
  artboards: [
    { file: "PasteCard.dc.html", title: "Paste card: kind pill and Z menu", x: 0, y: 0, w: 1120, h: 900, page: "page-1" },
    { file: "Toasts.dc.html", title: "Copy toasts with an action", x: 1220, y: 0, w: 1120, h: 700, page: "page-1" },
    { file: "History.dc.html", title: "History: type column, filter, Actions menu", x: 0, y: 1020, w: 1040, h: 660, page: "page-1" },
    { file: "HistoryFiltered.dc.html", title: "History filtered to URL", x: 1220, y: 1020, w: 1040, h: 660, page: "page-1" },
    { file: "Rules.dc.html", title: "Settings: Rules page", x: 0, y: 1800, w: 760, h: 620, page: "page-1" },
    { file: "RuleDialog.dc.html", title: "Settings: rule editor", x: 1220, y: 1800, w: 760, h: 620, page: "page-1" },
    { file: "Main.dc.html", title: "Overview", x: 2440, y: 0, w: 560, h: 420, page: "page-1" },
  ],
  annotations: [
    { id: "brief", x: 0, y: -170, w: 700, page: "page-1", text: "Clip intelligence, from the spec of 2026-09-10: every text clip gets a kind (URL, email, path, color, JSON, number, phone, code, text). Row 1: the paste card and the copy toast. Row 2: History with the type column, the type filter and the Actions menu. Row 3: the Settings Rules page and its editor. Tweak the accent and dark/light on any board." },
  ],
  launch: { view: "canvas", page: "page-1" },
};

writeFileSync(join(here, "Main.dc.html"), board(560, 420, `
  <div style="grid-column: 1 / -1; display: flex; flex-direction: column; gap: 10px;">
    <span style="font-size: 18px; font-weight: 600;">Clip intelligence</span>
    <div class="note">Five pieces, in build order:</div>
    <div class="note"><b>1 Detector</b> classifies text clips once at copy time; the kind is stored with the clip.</div>
    <div class="note"><b>2 Showing it</b> kind pill on the paste card, badge and filter in History, badge in the Organizer, label on the toast.</div>
    <div class="note"><b>3 Transforms</b> ten new paste formats; Z opens a menu on the card.</div>
    <div class="note"><b>4 Actions</b> one chip on the toast, an Actions menu in History and the Organizer.</div>
    <div class="note"><b>5 Rules</b> route, ignore, transform or tag clips at copy time, edited in Settings.</div>
  </div>`));
writeFileSync(join(here, "canvas.json"), JSON.stringify(canvas, null, 2) + "\n");
console.log("wrote 7 artboards + canvas.json");
