// Generates the Phase 4 mockups (Clipboard History and Channel Organizer, both WebView2 pages) as .dc.html
// artboards plus canvas.json. Run: node design/phase4/build.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { helmet, props, logic, ddl, edit, btn, titlebar, wrap, check } from "../shared.mjs";
import { trayArtboard } from "./tray.mjs";

const here = dirname(fileURLToPath(import.meta.url));

// ---------- extra CSS for the web pages ----------
const webRules = `
    .toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 12px; }
    .search { flex-grow: 1; height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--muted); }
    .search svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.5; }
    .search .q { color: var(--text); flex-grow: 1; }
    .chip { font-size: 11px; padding: 2px 8px; border-radius: 10px; border: 1px solid var(--border); color: var(--muted); }
    .chip.on { background: var(--accent); border-color: var(--accent); color: var(--accentText); }
    .split { display: flex; flex-grow: 1; min-height: 0; border-top: 1px solid var(--border); }
    .pane { display: flex; flex-direction: column; min-width: 0; }
    .table { flex-grow: 1; overflow: hidden; }
    .table .hdr { display: grid; gap: 12px; height: 28px; align-items: center; padding: 0 12px; color: var(--muted); font-size: 12px; border-bottom: 1px solid var(--border); background: var(--surface); position: sticky; top: 0; }
    .table .tr { display: grid; gap: 12px; height: 30px; align-items: center; padding: 0 12px; border-bottom: 1px solid color-mix(in srgb, var(--border) 50%, transparent); white-space: nowrap; }
    .table .tr > span { overflow: hidden; text-overflow: ellipsis; }
    .table .tr.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .table .tr:hover { background: var(--hover); }
    .mono { font-family: Consolas, "Cascadia Mono", monospace; font-size: 12.5px; }
    .dim { color: var(--muted); }
    .preview { width: 380px; flex: 0 0 auto; border-left: 1px solid var(--border); background: var(--surface); display: flex; flex-direction: column; }
    .preview .ph { display: flex; align-items: center; gap: 8px; padding: 10px 14px; border-bottom: 1px solid var(--border); }
    .preview .body { flex-grow: 1; padding: 12px 14px; overflow: hidden; white-space: pre-wrap; word-break: break-word; }
    .preview .actions { display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 14px; border-top: 1px solid var(--border); background: var(--bg); }
    .abtn { height: 26px; padding: 0 10px; display: inline-flex; align-items: center; gap: 6px; border: 1px solid var(--border); border-radius: 4px; background: var(--surfaceAlt); color: var(--text); }
    .abtn.primary { background: var(--accent); border-color: var(--accent); color: var(--accentText); }
    .abtn kbd { font-family: inherit; font-size: 10.5px; color: var(--muted); background: var(--surface); border: 1px solid var(--border); border-radius: 3px; padding: 0 4px; }
    .abtn.primary kbd { color: var(--accentText); background: transparent; border-color: rgba(255,255,255,.4); }
    mark { background: color-mix(in srgb, var(--accent) 35%, transparent); color: inherit; border-radius: 2px; }
    .channels { width: 220px; flex: 0 0 auto; border-right: 1px solid var(--border); background: var(--surface); display: flex; flex-direction: column; }
    .channels .ch { display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; }
    .channels .ch.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .channels .ch .n { color: var(--muted); font-size: 12px; width: 18px; }
    .channels .ch .cnt { margin-left: auto; color: var(--muted); font-size: 11.5px; }
    .channels .head { display: flex; align-items: center; justify-content: space-between; height: 36px; padding: 0 12px; color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; border-bottom: 1px solid var(--border); }
    .iconbtn { width: 24px; height: 24px; display: inline-flex; align-items: center; justify-content: center; border-radius: 4px; color: var(--muted); }
    .iconbtn svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round; }
    .sheet { position: absolute; inset: 0; background: rgba(0,0,0,.35); display: flex; align-items: center; justify-content: center; }
    .card { width: 360px; color: var(--text); background: var(--surface); border: 1px solid var(--border); border-radius: 8px; box-shadow: 0 12px 32px rgba(0,0,0,.4); display: flex; flex-direction: column; }
    .card .ch { display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 14px; }
    .card .ch.sel { background: var(--hover); box-shadow: inset 3px 0 0 var(--accent); }
    .card .h { padding: 12px 16px 6px 16px; font-weight: 600; }
    .card .footer { border-radius: 0 0 8px 8px; }
`;
// one helmet only: the canvas editor applies a single <helmet> per artboard
const webHelmet = helmet.replace("</style>", webRules + "  </style>");

const svgSearch = `<svg viewBox="0 0 16 16"><circle cx="7" cy="7" r="4.5"></circle><path d="M10.5 10.5 14 14"></path></svg>`;
const svgPlus = `<svg viewBox="0 0 16 16"><path d="M8 3v10M3 8h10"></path></svg>`;
const svgUp = `<svg viewBox="0 0 16 16"><path d="M8 13V3M4 7l4-4 4 4"></path></svg>`;
const svgDown = `<svg viewBox="0 0 16 16"><path d="M8 3v10M4 9l4 4 4-4"></path></svg>`;
const sortDown = `<svg viewBox="0 0 12 12" style="width: 10px; height: 10px; stroke: currentColor; fill: none; stroke-width: 1.5; margin-left: 4px;"><path d="M3 4.5 6 7.5 9 4.5"></path></svg>`;

const page = (w, h, inner) => wrap(w, h, inner).replace(helmet, webHelmet);
const abtn = (t, key = "", cls = "") => `<div class="abtn${cls ? " " + cls : ""}">${t}${key ? `<kbd>${key}</kbd>` : ""}</div>`;

// ---------- Clipboard History ----------
const hcols = "grid-template-columns: 1fr 150px 70px;";
const hrows = [
  ["Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is r…", "Today 14:22", "1.2 KB", true],
  ["https://github.com/aviaryan/Clipjump/issues/143", "Today 13:58", "48 B"],
  ["[IMAGE] 1280 x 720", "Today 13:40", "214 KB"],
  ["SELECT id, clip, date FROM history WHERE clip LIKE '%figma%' ORDER BY date DESC", "Today 11:05", "82 B"],
  ["Mike Peutz &lt;mike@example.com&gt;", "Today 09:31", "29 B"],
  ["C:\\Users\\MikePeutz\\PortableApps\\Clipjump_new_x64\\design\\phase4", "Yesterday 18:12", "61 B"],
  ["Also fixes a regression where the fallback image was never shown.", "Yesterday 17:50", "66 B"],
  ["npm run build && node design/phase4/build.mjs", "Yesterday 16:02", "46 B"],
  ["[IMAGE] 640 x 480", "Yesterday 15:11", "96 KB"],
  ["The quick brown fox jumps over the lazy dog", "Mon 10:44", "43 B"],
  ["Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor", "Mon 09:02", "78 B"],
  ["4111 1111 1111 1111", "Sun 20:15", "19 B"],
  ["def render(state): return Card(state).draw()", "Sun 19:33", "44 B"],
];
const historyTable = (rows, q = "") => `
      <div class="table">
        <div class="hdr" style="${hcols}"><span>Clip</span><span style="display: flex; align-items: center;">Date${sortDown}</span><span>Size</span></div>
        ${rows.map(([c, d, s, sel]) => `<div class="tr${sel ? " sel" : ""}" style="${hcols}"><span class="mono${c.startsWith("[IMAGE]") ? " dim" : ""}">${q ? c.replace(new RegExp(q, "i"), (m) => `<mark>${m}</mark>`) : c}</span><span class="dim">${d}</span><span class="dim">${s}</span></div>`).join("\n        ")}
      </div>`;

const historyActions = `
      <div class="actions">
        ${abtn("Copy", "Ctrl+C", "primary")}${abtn("Insta-Paste", "Space")}${abtn("Hold", "Alt+C")}${abtn("Edit", "Ctrl+H")}${abtn("Export", "Ctrl+E")}${abtn("Delete", "Del")}
      </div>`;

writeFileSync(join(here, "Main.dc.html"), page(1040, 660, `
  ${titlebar("Clipjump Clipboard History")}
  <div class="toolbar" style="height: 48px;">
    <div class="search" style="height: 28px;">${svgSearch}<span class="q">figma</span><span class="chip on">Partial</span><span class="chip">Exact</span></div>
    ${btn("Refresh")}${btn("Clear history…")}
  </div>
  <div class="split">
    <div class="pane" style="flex-grow: 1;">${historyTable(hrows.filter(([c]) => /figma/i.test(c)), "figma")}</div>
    <div class="preview" style="width: 380px;">
      <div class="ph"><span class="badge">TEXT</span><span class="dim" style="font-size: 12px;">1.2 KB · Today 14:22</span></div>
      <div class="body mono">Brings the Latest Resources widget in line with the <mark>Figma</mark> mockup: the shared resource card is restyled, the section header is restructured with the carousel prev/next buttons moved into the header, and the grid now collapses to a single column below 720px.

Also fixes a regression where the fallback image was never shown.</div>
      ${historyActions}
    </div>
  </div>
  <div class="status" style="height: 24px;"><span>2 of 312 items match</span><span style="margin-left: auto;">4.8 MB on disk · sorted by date</span></div>`));

writeFileSync(join(here, "HistoryImage.dc.html"), page(1040, 660, `
  ${titlebar("Clipjump Clipboard History")}
  <div class="toolbar" style="height: 48px;">
    <div class="search" style="height: 28px;">${svgSearch}<span>Search history</span><span class="chip on">Partial</span><span class="chip">Exact</span></div>
    ${btn("Refresh")}${btn("Clear history…")}
  </div>
  <div class="split">
    <div class="pane" style="flex-grow: 1;">${historyTable(hrows.map((r, i) => [r[0], r[1], r[2], i === 2]))}</div>
    <div class="preview" style="width: 380px;">
      <div class="ph"><span class="badge">IMAGE</span><span class="dim" style="font-size: 12px;">214 KB · 1280 x 720 · Today 13:40</span></div>
      <div class="body" style="display: flex; align-items: center; justify-content: center; background: var(--surfaceAlt);">
        <svg viewBox="0 0 320 180" style="width: 340px; height: 191px; border-radius: 4px;"><rect width="320" height="180" fill="#3a5f8a"></rect><circle cx="250" cy="45" r="22" fill="#f4d35e"></circle><path d="M0 180 60 110 120 150 190 80 260 130 320 100v80z" fill="#2f7d5b"></path><path d="M0 180 40 150 90 170 150 130 220 160 320 140v40z" fill="#245f46"></path></svg>
      </div>
      ${historyActions}
    </div>
  </div>
  <div class="status" style="height: 24px;"><span>312 items</span><span style="margin-left: auto;">4.8 MB on disk · sorted by date</span></div>`).replace(`data-props='${props}'`, `data-props='${props.replace('"default":true', '"default":false')}'`));

// ---------- Channel Organizer ----------
const ocols = "grid-template-columns: 34px 1fr 150px;";
const channels = [["0", "Default", 40, true], ["1", "Work", 12], ["2", "Snippets", 27], ["3", "Addresses", 5], ["4", "Pit", 3]];
const clips = [
  ["1", "Brings the Latest Resources widget in line with the Figma mockup", "<span class='badge'>work</span> <span class='badge accent'>fixed</span>", true],
  ["2", "https://github.com/aviaryan/Clipjump/issues/143", ""],
  ["3", "[IMAGE] 1280 x 720", ""],
  ["4", "SELECT id, clip, date FROM history WHERE clip LIKE '%figma%'", "<span class='badge'>sql</span>"],
  ["5", "Mike Peutz &lt;mike@example.com&gt;", ""],
  ["6", "C:\\Users\\MikePeutz\\PortableApps\\Clipjump_new_x64", "<span class='badge'>path</span>"],
  ["7", "Also fixes a regression where the fallback image was never shown.", ""],
  ["8", "npm run build && node design/phase4/build.mjs", "<span class='badge'>cmd</span>"],
  ["9", "The quick brown fox jumps over the lazy dog", ""],
  ["10", "Lorem ipsum dolor sit amet, consectetur adipiscing elit", ""],
  ["11", "def render(state): return Card(state).draw()", "<span class='badge'>py</span>"],
  ["12", "4111 1111 1111 1111", ""],
];
const channelList = (sel = "0") => `
    <div class="channels" style="width: 220px;">
      <div class="head" style="height: 36px;"><span>Channels</span><span class="iconbtn" style="width: 24px; height: 24px;">${svgPlus}</span></div>
      ${channels.map(([n, name, cnt]) => `<div class="ch${n === sel ? " sel" : ""}" style="height: 32px;"><span class="n">${n}</span><span>${name}</span><span class="cnt">${cnt}</span></div>`).join("\n      ")}
      <div style="flex-grow: 1;"></div>
      <div class="dim" style="padding: 8px 12px; font-size: 11.5px;">Double-click to use · F2 renames · Drag clips here to move</div>
    </div>`;

const organizerToolbar = (q = "") => `
  <div class="toolbar" style="height: 48px;">
    ${btn("New clip", "primary")}${btn("New channel")}
    <div style="display: flex; align-items: center; gap: 8px; margin-left: 12px;"><span class="dim">Active channel</span>${ddl("0 - Default", 150)}</div>
    <div class="search" style="height: 28px; max-width: 280px; margin-left: auto;">${svgSearch}<span${q ? ' class="q"' : ""}>${q || "Search clips"}</span></div>
  </div>`;

const clipTable = (rows) => `
      <div class="table">
        <div class="hdr" style="${ocols}"><span>#</span><span>Clip</span><span>Tags</span></div>
        ${rows.map(([n, c, t, sel]) => `<div class="tr${sel ? " sel" : ""}" style="${ocols}"><span class="dim">${n}</span><span class="mono${c.startsWith("[IMAGE]") ? " dim" : ""}">${c}</span><span>${t}</span></div>`).join("\n        ")}
      </div>`;

const organizerPreview = `
    <div class="preview" style="width: 320px;">
      <div class="ph"><span class="badge">TEXT</span><span class="badge accent">fixed</span><span class="dim" style="font-size: 12px;">clip 1 of 40</span><span class="iconbtn" style="margin-left: auto; width: 24px; height: 24px;" title="Move up">${svgUp}</span><span class="iconbtn" style="width: 24px; height: 24px;" title="Move down">${svgDown}</span></div>
      <div class="body mono">Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is restyled, the section header is restructured with the carousel prev/next buttons moved into the header.</div>
      <div style="padding: 0 14px 10px 14px; display: flex; gap: 6px; align-items: center;"><span class="dim" style="font-size: 12px;">Tags</span>${edit("work", 180)}${check("Fixed", true)}</div>
      <div class="actions">
        ${abtn("Insta-Paste", "Space", "primary")}${abtn("Paste mode", "Ctrl+O")}${abtn("Edit", "F2")}${abtn("Move to…", "Alt+X")}${abtn("Copy to…", "Alt+C")}${abtn("Delete", "Del")}
      </div>
    </div>`;

writeFileSync(join(here, "Organizer.dc.html"), page(1100, 640, `
  ${titlebar("Clipjump Channel Organizer")}
  ${organizerToolbar()}
  <div class="split">
    ${channelList()}
    <div class="pane" style="flex-grow: 1;">${clipTable(clips)}</div>
    ${organizerPreview}
  </div>
  <div class="status" style="height: 24px;"><span>40 items listed</span><span style="margin-left: auto;">Channel 0 - Default</span></div>`));

// Organizer with the in-page channel picker (Move to…) open
writeFileSync(join(here, "OrganizerMove.dc.html"), page(1100, 640, `
  ${titlebar("Clipjump Channel Organizer")}
  ${organizerToolbar()}
  <div class="split" style="position: relative;">
    ${channelList()}
    <div class="pane" style="flex-grow: 1;">${clipTable(clips)}</div>
    ${organizerPreview}
    <div class="sheet">
      <div class="card" style="width: 360px;">
        <div class="h">Move 1 clip to</div>
        ${channels.slice(1).map(([n, name, cnt], i) => `<div class="ch${i === 0 ? " sel" : ""}" style="height: 32px;"><span class="dim" style="width: 18px;">${n}</span><span>${name}</span><span class="dim" style="margin-left: auto; font-size: 11.5px;">${cnt}</span></div>`).join("\n        ")}
        <div class="ch" style="height: 32px; color: var(--accent);">${svgPlus.replace("<svg", '<svg style="width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.6;"')}<span>New channel…</span></div>
        <div class="footer" style="height: 52px;">${btn("Move", "primary")}${btn("Cancel")}</div>
      </div>
    </div>
  </div>
  <div class="status" style="height: 24px;"><span>40 items listed</span><span style="margin-left: auto;">Channel 0 - Default</span></div>`).replace(`data-props='${props}'`, `data-props='${props.replace('"default":true', '"default":false')}'`));

// Delete-channel choice and rename, side by side, as in-page cards
writeFileSync(join(here, "OrganizerDialogs.dc.html"), `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${webHelmet}
<div style="display: flex; gap: 32px; align-items: flex-start; padding: 24px; background: var(--bg); color: var(--text); width: 900px; height: 300px; box-sizing: border-box; {{vars}}">
  <div class="card" style="width: 420px;">
    <div class="h">Delete channel 2 - Snippets</div>
    <div style="padding: 0 16px 8px 16px;" class="dim">27 clips are in this channel. What should happen to them?</div>
    <div style="padding: 0 16px; display: flex; flex-direction: column; gap: 6px;">
      <div class="ch sel" style="height: 32px; border-radius: 4px;"><span>Move them to another channel</span></div>
      <div class="ch" style="height: 32px;"><span>Delete the clips too</span></div>
    </div>
    <div class="footer" style="height: 52px;">${btn("Continue", "primary")}${btn("Cancel")}</div>
  </div>
  <div class="card" style="width: 360px;">
    <div class="h">Rename channel 2</div>
    <div style="padding: 0 16px 12px 16px;">${edit("Snippets", 328)}</div>
    <div class="footer" style="height: 52px;">${btn("Rename", "primary")}${btn("Cancel")}</div>
  </div>
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`);

// Native fallback when the WebView2 runtime is missing
writeFileSync(join(here, "Fallback.dc.html"), wrap(440, 220, `
  ${titlebar("Clipjump")}
  <div style="padding: 16px 24px 0 24px; display: flex; flex-direction: column; gap: 8px; flex-grow: 1;">
    <div style="font-weight: 600;">The WebView2 runtime is not installed</div>
    <div class="dim">Clipboard History and the Channel Organizer need Microsoft Edge WebView2. Paste mode and everything else keep working without it.</div>
    <a href="#">Download the Evergreen runtime from Microsoft</a>
  </div>
  <div class="footer" style="height: 52px;">${btn("Install…", "primary")}${btn("Later")}</div>`));

// ---------- tray menu ----------
writeFileSync(join(here, "TrayMenu.dc.html"), trayArtboard());

// ---------- canvas layout ----------
const canvas = {
  artboards: [
    { file: "Main.dc.html", title: "Clipboard History · dark, search active", x: 0, y: 0, w: 1040, h: 660 },
    { file: "HistoryImage.dc.html", title: "Clipboard History · light, image preview", x: 1140, y: 0, w: 1040, h: 660 },
    { file: "Organizer.dc.html", title: "Channel Organizer · dark", x: 0, y: 820, w: 1100, h: 640 },
    { file: "OrganizerMove.dc.html", title: "Channel Organizer · light, Move to…", x: 1200, y: 820, w: 1100, h: 640 },
    { file: "OrganizerDialogs.dc.html", title: "Organizer in-page cards", x: 0, y: 1620, w: 900, h: 300 },
    { file: "Fallback.dc.html", title: "WebView2 missing (native dialog)", x: 1000, y: 1620, w: 440, h: 220 },
    { file: "TrayMenu.dc.html", title: "Tray menu, Explorer-style card", x: 0, y: 2040, w: 1000, h: 460 },
  ],
  annotations: [
    { id: "brief", x: 0, y: -260, w: 560, text: "Phase 4: the two data-heavy windows move to WebView2 pages hosted in native frames. Same palette and type as the native windows; the Dark switch and Accent swatch on each artboard preview the theme handoff.\nHistory: search with Partial/Exact, sortable columns, a preview pane that replaces the separate Preview window, keyboard shortcuts on the action buttons." },
    { id: "organizer-note", x: 2400, y: 820, w: 300, text: "Organizer: channels on the left, clips in the middle, preview and clip properties on the right. Move to… and Copy to… open an in-page picker instead of the old Select Channel window; drag and drop between channels does the same. Channel delete and rename are in-page cards." },
    { id: "fallback-note", x: 1520, y: 1620, w: 280, text: "If the WebView2 runtime is missing, a native dialog links to the installer; the tray app keeps running." },
    { id: "tray-note", x: 1100, y: 2040, w: 300, text: "Tray menu: a custom popup card like the Windows 11 Explorer context menu. Icon row with the everyday actions (toggles light up when on), a header with the active channel that opens About, then the text items; submenus open beside the card. Esc, click-outside and focus loss close it; arrows and Enter work. An ini switch brings the standard menu back." },
  ],
  launch: { view: "canvas" },
};
writeFileSync(join(here, "canvas.json"), JSON.stringify(canvas, null, 2) + "\n");
console.log("wrote 7 artboards + canvas.json");
