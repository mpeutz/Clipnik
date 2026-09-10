// Direction sketches for the copy toast and the paste-mode card. Run: node design/phase5/build.mjs
// Each direction shows the same four moments: a copy toast, a warning toast, the card in paste mode, and the card
// in search mode. The rendering budget per direction is written on the board.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { helmet, props, logic } from "../shared.mjs";

const here = dirname(fileURLToPath(import.meta.url));

const L = {
  clipboard: `<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>`,
  check: `<path d="M20 6 9 17l-5-5"/>`,
  shield: `<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>`,
  search: `<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>`,
  pin: `<path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>`,
  image: `<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>`,
  tag: `<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>`,
};
const icon = (name, size = 16, extra = "") => `<svg viewBox="0 0 24 24" style="width: ${size}px; height: ${size}px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex: 0 0 auto; ${extra}">${L[name]}</svg>`;

const css = `
    .stage { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 40px 48px; padding: 28px 32px 32px 32px; background: var(--bg); color: var(--text); box-sizing: border-box; }
    .lbl { font-size: 11.5px; color: var(--muted); margin-bottom: 8px; letter-spacing: .02em; }
    .desk { background: #1a1d24; background-image: radial-gradient(circle at 30% 20%, #2a3140 0, transparent 55%); padding: 24px; border-radius: 6px; display: flex; flex-direction: column; align-items: flex-start; gap: 16px; min-height: 120px; }
    .kbd { display: inline-flex; align-items: center; height: 18px; padding: 0 6px; border-radius: 4px; background: var(--surfaceAlt); color: var(--text); font-size: 11px; }
    .badge { font-size: 10.5px; padding: 2px 7px; border-radius: 4px; background: var(--surfaceAlt); white-space: nowrap; }
    .badge.accent { background: var(--accent); color: var(--accentText); }
    .mono { font-family: Consolas, "Cascadia Mono", monospace; font-size: 12.5px; }
    .note { font-size: 12px; color: var(--muted); line-height: 1.45; }
    .note b { color: var(--text); font-weight: 600; }
    .budget { grid-column: 1 / -1; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; border-top: 1px solid var(--border); padding-top: 16px; }
`;

const wrap = (w, h, inner) => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${helmet.replace("</style>", css + "  </style>")}
<div class="stage" style="width: ${w}px; height: ${h}px; {{vars}}">
${inner}
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`;

const previewText = "Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is restyled and the grid now collapses to a single column below 720px.";
const hints = [["V", "next"], ["C", "back"], ["X", "mode"], ["Space", "pin"], ["F", "search"], ["F1", "help"]];

// ---------- Direction A: refined solid (today's toolkit) ----------
const A = {
  card: (inner, w = 480) => `<div style="width: ${w}px; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 10px 12px; box-sizing: border-box; display: flex; flex-direction: column; gap: 8px;">${inner}</div>`,
  toast: (kind, text) => `
    <div style="width: 300px; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; box-sizing: border-box; display: flex; overflow: hidden;">
      <div style="width: 4px; background: ${kind === "warn" ? "#E0A526" : "var(--accent)"}; flex: 0 0 auto;"></div>
      <div style="display: flex; align-items: center; gap: 10px; padding: 10px 12px; flex-grow: 1; color: var(--text);">${icon(kind === "warn" ? "shield" : "clipboard", 16, `color: ${kind === "warn" ? "#E0A526" : "var(--accent)"};`)}<span>${text}</span></div>
    </div>`,
  hud: (search = false) => A.card(`
    <div style="display: flex; align-items: center; gap: 6px;"><b>{Default}</b><span class="dim">3 / 40</span><span style="width: 6px;"></span><span class="badge">TEXT</span><span class="badge accent">Trim Formatting</span><span class="badge accent" style="display: inline-flex; align-items: center; gap: 4px;">${icon("pin", 11)}FIXED</span><span class="dim" style="font-size: 12px; margin-left: auto;">#work #urgent</span></div>
    ${search ? `<div style="display: flex; align-items: center; gap: 8px; height: 26px; padding: 0 8px; background: var(--surfaceAlt); border-radius: 4px; border-bottom: 2px solid var(--accent);">${icon("search", 14, "color: var(--muted);")}<span>figma<span style="border-left: 1px solid var(--text); margin-left: 1px;"></span></span><span class="dim" style="margin-left: auto; font-size: 12px;">2 / 7</span></div>` : ""}
    <div style="line-height: 1.4;">${search ? previewText.replace("Figma", "<mark style='background: color-mix(in srgb, var(--accent) 35%, transparent); color: inherit; border-radius: 2px;'>Figma</mark>") : previewText}</div>
    <div style="height: 1px; background: var(--border);"></div>
    <div style="display: flex; gap: 10px; align-items: center; font-size: 11.5px; color: var(--muted);">${(search ? [["Enter", "paste"], ["Up / Down", "match"], ["Home", "cancel"]] : hints).map(([k, t]) => `<span style="display: inline-flex; align-items: center; gap: 5px;"><span class="kbd">${k}</span>${t}</span>`).join("")}</div>`),
};

// ---------- Direction B: layered card (GDI+ drawn) ----------
const B = {
  shell: (inner, w) => `<div style="width: ${w}px; background: color-mix(in srgb, var(--surface) 88%, transparent); backdrop-filter: blur(14px); border: 1px solid color-mix(in srgb, var(--text) 12%, transparent); border-radius: 12px; box-shadow: 0 12px 32px rgba(0,0,0,.45), 0 1px 0 rgba(255,255,255,.05) inset; box-sizing: border-box; overflow: hidden;">${inner}</div>`,
  toast: (kind, text) => B.shell(`
      <div style="display: flex; align-items: center; gap: 12px; padding: 12px 14px;">
        <div style="width: 30px; height: 30px; border-radius: 8px; display: flex; align-items: center; justify-content: center; background: color-mix(in srgb, ${kind === "warn" ? "#E0A526" : "var(--accent)"} 22%, transparent); color: ${kind === "warn" ? "#E0A526" : "var(--accent)"};">${icon(kind === "warn" ? "shield" : "check", 16)}</div>
        <div style="display: flex; flex-direction: column; gap: 2px;"><span style="font-weight: 600;">${kind === "warn" ? "Not recorded" : "Copied"}</span><span class="dim" style="font-size: 12px;">${text}</span></div>
      </div>
      <div style="height: 2px; background: color-mix(in srgb, var(--text) 8%, transparent);"><div style="width: 62%; height: 2px; background: ${kind === "warn" ? "#E0A526" : "var(--accent)"};"></div></div>`, 320),
  hud: (search = false) => B.shell(`
      <div style="display: flex; align-items: center; gap: 8px; padding: 12px 14px 8px 14px;"><span style="display: inline-flex; align-items: center; gap: 6px; height: 22px; padding: 0 9px; border-radius: 11px; background: var(--accent); color: var(--accentText); font-weight: 600; font-size: 12px;">Default</span><span style="font-size: 16px; font-weight: 600;">3<span class="dim" style="font-weight: 400; font-size: 12px;"> / 40</span></span><span class="badge" style="border-radius: 10px;">TEXT</span><span class="badge" style="border-radius: 10px;">Trim Formatting</span><span style="margin-left: auto; color: var(--accent); display: inline-flex; gap: 6px; align-items: center; font-size: 12px;">${icon("pin", 13)}pinned</span></div>
      ${search ? `<div style="margin: 0 14px 8px 14px; display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px; border-radius: 8px; background: color-mix(in srgb, var(--text) 8%, transparent);">${icon("search", 14, "color: var(--muted);")}<span>figma</span><span class="dim" style="margin-left: auto; font-size: 12px;">2 of 7</span></div>` : ""}
      <div style="margin: 0 14px; padding: 10px 12px; border-radius: 8px; background: color-mix(in srgb, var(--text) 5%, transparent); line-height: 1.45;">${previewText}</div>
      <div style="display: flex; align-items: center; gap: 8px; padding: 10px 14px 12px 14px; font-size: 11.5px; color: var(--muted);">${icon("tag", 12)}<span>work · urgent</span><span style="margin-left: auto; display: inline-flex; gap: 8px;">${(search ? [["Enter", "paste"], ["Home", "cancel"]] : [["V", "next"], ["C", "back"], ["F1", "help"]]).map(([k, t]) => `<span style="display: inline-flex; align-items: center; gap: 4px;"><span class="kbd" style="border-radius: 5px; background: color-mix(in srgb, var(--text) 10%, transparent);">${k}</span>${t}</span>`).join("")}</span></div>`, 480),
};

// ---------- Direction C: compact strip ----------
const C = {
  toast: (kind, text) => `<div style="display: inline-flex; align-items: center; gap: 8px; height: 30px; padding: 0 12px 0 10px; border-radius: 15px; background: var(--surface); border: 1px solid var(--border); color: var(--text); font-size: 12.5px;">${icon(kind === "warn" ? "shield" : "check", 14, `color: ${kind === "warn" ? "#E0A526" : "var(--accent)"};`)}${text}</div>`,
  hud: (search = false) => `
    <div style="width: 560px; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; box-sizing: border-box; display: flex; align-items: stretch; overflow: hidden;">
      <div style="display: flex; flex-direction: column; justify-content: center; gap: 2px; padding: 8px 12px; background: var(--surfaceAlt); min-width: 84px;"><span style="font-weight: 600;">Default</span><span class="dim" style="font-size: 12px;">3 / 40</span></div>
      <div style="display: flex; flex-direction: column; justify-content: center; gap: 4px; padding: 8px 12px; min-width: 0; flex-grow: 1;">
        ${search ? `<div style="display: flex; align-items: center; gap: 6px; font-size: 12.5px;">${icon("search", 13, "color: var(--accent);")}<span>figma</span><span class="dim" style="font-size: 11.5px;">2 / 7</span></div>` : `<div style="display: flex; gap: 6px;"><span class="badge">TEXT</span><span class="badge accent">Trim</span><span class="dim" style="font-size: 11.5px;">#work #urgent</span></div>`}
        <div style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${previewText}</div>
      </div>
      <div style="display: flex; align-items: center; padding: 0 10px; color: var(--accent);">${icon("pin", 14)}</div>
    </div>`,
};

const block = (label, body) => `<div><div class="lbl">${label}</div><div class="desk">${body}</div></div>`;

function board(name, D, title, blurb, budget) {
  return wrap(1120, 800, `
  <div style="grid-column: 1 / -1; display: flex; align-items: baseline; gap: 14px;"><span style="font-size: 18px; font-weight: 600;">${title}</span><span class="note">${blurb}</span></div>
  ${block("Copy toast, near the cursor", D.toast("info", "Copied to Default"))}
  ${block("Warning toast, clip skipped", D.toast("warn", name === "B" ? "KeePass marked this clip private" : "Private clip skipped (KeePass)"))}
  ${block("Paste mode, holding Ctrl", D.hud(false))}
  ${block("Search inside paste mode (F)", D.hud(true))}
  <div class="budget">${budget.map(([h, t]) => `<div class="note"><b>${h}</b><br>${t}</div>`).join("")}</div>`);
}

writeFileSync(join(here, "DirectionA.dc.html"), board("A", A, "A · Refined solid", "Today's toolkit, tidied: window-level rounding and border from DWM, opaque fills, Lucide glyphs, key chips.", [
  ["What it can do", "Solid fills per element, 1px rules, one rounded outer corner radius and border via DWM, accent strips, glyph icons, Consolas or Segoe text, native scrolling in the preview."],
  ["What it cannot", "No shadow, no translucency, no per-element rounding (badges and chips stay square-cornered in the real thing), no anti-aliased shapes beyond text."],
  ["Cost", "Small: the current card already does most of this. Toast strip and icon are two extra controls; hint chips are a row of small Text controls."],
  ["Risk", "Low. Same render path as now, so paste mode stays fast."],
]));

writeFileSync(join(here, "DirectionB.dc.html"), board("B", B, "B · Layered card", "The whole card is painted with GDI+ into a per-pixel-alpha window: shadow, translucency, rounded elements, real icons.", [
  ["What it can do", "Everything on this board: soft shadow, 88% opacity over the desktop, per-element rounding, tinted icon wells, a countdown line on toasts, pills and chips with real corners."],
  ["What it cannot", "No blur behind the card (Windows only offers that to windows with a frame). Text is drawn by GDI+, so ClearType is off inside the card. No native Edit: long previews clip instead of scrolling."],
  ["Cost", "Large: a new renderer (measure, wrap and paint every element, cache the bitmap) plus the toast and HUD moving onto it. Several days of work and testing."],
  ["Risk", "Paste mode redraws on every keypress; the renderer must stay under a few milliseconds or Ctrl+V cycling will feel sluggish."],
]));

writeFileSync(join(here, "DirectionC.dc.html"), board("C", C, "C · Compact strip", "One-line strip and pill toasts. Same toolkit as A, different footprint: the card stays out of the way and shows one clip line.", [
  ["What it can do", "Everything A can, in a smaller window: pill toasts, a horizontal card with the channel block on the left and a single preview line."],
  ["What it cannot", "Multi-line preview and the image thumbnail lose their room; hints move behind F1. Long clips are judged from one line."],
  ["Cost", "Small to medium: a new layout pass in the existing card, the toast shrinks to a pill."],
  ["Risk", "Usability: less context per clip while cycling; the help and menu modes would need a taller variant anyway."],
]));

// ---------- chosen: C toasts (pills) on B's layered finish, B card ----------
L.x = `<path d="M18 6 6 18"/><path d="m6 6 12 12"/>`;
L.loader = `<path d="M12 2v4"/><path d="m16.2 7.8 2.9-2.9"/><path d="M18 12h4"/><path d="m16.2 16.2 2.9 2.9"/><path d="M12 18v4"/><path d="m4.9 19.1 2.9-2.9"/><path d="M2 12h4"/><path d="m4.9 4.9 2.9 2.9"/>`;
L.trash = `<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>`;
L.zap = `<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>`;
L.help = `<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>`;
const toneOf = (kind) => kind === "warn" ? "#E0A526" : kind === "error" ? "var(--danger)" : "var(--accent)";
const pill = (kind, text) => `<div style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 14px 0 11px; border-radius: 8px; background: color-mix(in srgb, var(--surface) 92%, transparent); border: 1px solid color-mix(in srgb, var(--text) 12%, transparent); box-shadow: 0 8px 22px rgba(0,0,0,.4); color: var(--text); font-size: 12.5px;">${icon(kind === "warn" ? "shield" : kind === "error" ? "x" : kind === "busy" ? "loader" : "check", 14, `color: ${toneOf(kind)};`)}${text}</div>`;
const kbd = (k, extra = "") => `<span class="kbd" style="border-radius: 5px; background: color-mix(in srgb, var(--text) 10%, transparent); ${extra}">${k}</span>`;
const hint = (pairs) => `<span style="margin-left: auto; display: inline-flex; gap: 10px;">${pairs.map(([k, t]) => `<span style="display: inline-flex; align-items: center; gap: 4px;">${kbd(k)}${t}</span>`).join("")}</span>`;
const head = (opts = {}) => `<div style="display: flex; align-items: center; gap: 8px; padding: 12px 14px 8px 14px;"><span style="display: inline-flex; align-items: center; gap: 6px; height: 22px; padding: 0 9px; border-radius: 11px; background: ${opts.modeColor || "var(--accent)"}; color: var(--accentText); font-weight: 600; font-size: 12px;">${opts.mode ? icon(opts.modeIcon, 12) + opts.mode : "Default"}</span><span style="font-size: 16px; font-weight: 600;">3<span class="dim" style="font-weight: 400; font-size: 12px;"> / 40</span></span><span class="badge" style="border-radius: 10px;">${opts.format || "TEXT"}</span>${opts.pformat === false ? "" : '<span class="badge" style="border-radius: 10px;">Trim Formatting</span>'}${opts.pinned === false ? "" : `<span style="margin-left: auto; color: var(--accent); display: inline-flex; gap: 6px; align-items: center; font-size: 12px;">${icon("pin", 13)}pinned</span>`}</div>`;
const body = (inner, extra = "") => `<div style="margin: 0 14px; padding: 10px 12px; border-radius: 0; background: color-mix(in srgb, var(--text) 5%, transparent); line-height: 1.45; ${extra}">${inner}</div>`;
const foot = (pairs, left = `${icon("tag", 12)}<span>work · urgent</span>`) => `<div style="display: flex; align-items: center; gap: 8px; padding: 10px 14px 12px 14px; font-size: 11.5px; color: var(--muted);">${left}${hint(pairs)}</div>`;
const card = (inner, w = 480) => B.shell(inner, w);
const marked = previewText.replace("Figma", "<mark style='background: color-mix(in srgb, var(--accent) 35%, transparent); color: inherit; border-radius: 2px;'>Figma</mark>");
const row = (k, t, sel) => `<div style="display: flex; align-items: center; gap: 10px; height: 28px; padding: 0 8px; border-radius: 6px; ${sel ? "background: color-mix(in srgb, var(--text) 8%, transparent);" : ""}">${kbd(k, "width: 22px; justify-content: center; padding: 0;")}<span>${t}</span></div>`;
const helpRow = (k, t) => `<div style="display: flex; align-items: center; gap: 8px; height: 26px;">${kbd(k, "min-width: 22px; justify-content: center;")}<span class="dim">${t}</span></div>`;

const state = {
  normal: card(head() + body(previewText) + foot([["V", "next"], ["C", "back"], ["X", "mode"], ["Space", "pin"], ["F1", "help"]])),
  search: card(head() + `<div style="margin: 0 14px 8px 14px; display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px; border-radius: 0; background: color-mix(in srgb, var(--text) 8%, transparent); border: 1px solid color-mix(in srgb, var(--accent) 60%, transparent);">${icon("search", 14, "color: var(--muted);")}<span>figma<span style="border-left: 1px solid var(--text); margin-left: 1px;"></span></span><span class="dim" style="margin-left: auto; font-size: 12px;">2 of 7</span></div>` + body(marked) + foot([["Enter", "paste"], ["Up / Down", "match"], ["Home", "cancel"]])),
  image: card(head({ format: "IMAGE", pformat: false }) + body(`<svg viewBox="0 0 320 180" style="width: 300px; height: 169px; border-radius: 4px; display: block;"><rect width="320" height="180" fill="#3a5f8a"></rect><circle cx="250" cy="45" r="22" fill="#f4d35e"></circle><path d="M0 180 60 110 120 150 190 80 260 130 320 100v80z" fill="#2f7d5b"></path><path d="M0 180 40 150 90 170 150 130 220 160 320 140v40z" fill="#245f46"></path></svg>`, "padding: 6px;") + foot([["V", "next"], ["C", "back"], ["H", "edit"]], `${icon("image", 12)}<span>1280 × 720 · 214 KB</span>`)),
  mode: card(head({ mode: "Delete", modeIcon: "trash", modeColor: "var(--danger)", pinned: false }) + body(previewText) + `<div style="margin: 8px 14px 0 14px; display: flex; gap: 6px; align-items: center; font-size: 11.5px; color: var(--muted);"><span>Release Ctrl to delete this clip</span><span style="margin-left: auto; display: inline-flex; align-items: center; gap: 4px;">${kbd("X")}cut, copy, delete all</span></div>` + foot([["V", "next"], ["C", "back"]])),
  message: card(`<div style="display: flex; align-items: center; gap: 12px; padding: 14px 16px;">${icon("loader", 18, "color: var(--accent);")}<span style="font-weight: 600;">Pasting 3 clips…</span><span class="dim" style="margin-left: auto; font-size: 12px;">Default</span></div>`, 360),
  confirm: card(`<div style="display: flex; flex-direction: column; gap: 10px; padding: 14px 16px;"><div style="display: flex; align-items: center; gap: 10px;">${icon("trash", 18, "color: var(--danger);")}<span style="font-weight: 600;">Delete all 40 clips in Default?</span></div><div style="display: flex; gap: 12px; align-items: center; font-size: 12px; color: var(--muted);"><span style="display: inline-flex; align-items: center; gap: 4px;">${kbd("Y", "background: var(--danger); color: #fff;")}delete</span><span style="display: inline-flex; align-items: center; gap: 4px;">${kbd("N")}keep</span><span style="display: inline-flex; align-items: center; gap: 4px;">${kbd("Esc")}cancel</span></div></div>`, 380),
  menu: card(`<div style="display: flex; align-items: center; gap: 8px; padding: 12px 14px 6px 14px;">${icon("zap", 14, "color: var(--accent);")}<span style="font-weight: 600;">Action mode</span><span class="dim" style="margin-left: auto; font-size: 12px;">Esc closes</span></div><div style="display: flex; flex-direction: column; padding: 0 8px 8px 8px;">${[["H", "Clipboard History", true], ["O", "Channel Organizer"], ["C", "Copy file path"], ["X", "Copy folder path"], ["F", "Copy file data"], ["P", "PitSwap"], ["T", "One time stop"], ["D", "Disable Clipjump"], ["E", "Settings"], ["L", "Ignored windows"]].map(([k, t, sel]) => row(k, t, sel)).join("")}</div>`, 320),
  help: card(`<div style="display: flex; align-items: center; gap: 8px; padding: 12px 14px 6px 14px;">${icon("help", 14, "color: var(--accent);")}<span style="font-weight: 600;">Paste mode keys</span><span class="dim" style="margin-left: auto; font-size: 12px;">V closes</span></div><div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 2px 18px; padding: 0 14px 12px 14px; font-size: 12px;">${[["Release Ctrl", "Paste"], ["V", "Next clip"], ["C", "Previous clip"], ["X", "Cancel, move, delete, copy"], ["Z", "Paste format"], ["Space", "Pin (fix) clip"], ["S", "To system clipboard"], ["E", "Export"], ["Up / Down", "Change channel"], ["A", "First clip"], ["1 … 9", "Jump ahead"], ["F", "Search"], ["H", "Edit"], ["Q", "Move to first"], ["Enter", "Multi-paste"], ["T", "Tag"], ["Hold Shift", "Delete after paste"], ["F1", "This help"]].map(([k, t]) => helpRow(k, t)).join("")}</div>`, 520),
};

writeFileSync(join(here, "Main.dc.html"), wrap(1120, 900, `
  <div style="grid-column: 1 / -1; display: flex; align-items: baseline; gap: 14px;"><span style="font-size: 18px; font-weight: 600;">B look on A rendering</span><span class="note">Native controls as today, plus a DWM shadow, 92% window translucency, and badges drawn as rounded pills. Verified on the real card.</span></div>
  ${block("Copy toasts, near the cursor", `<div style="display: flex; flex-direction: column; gap: 10px; align-items: flex-start;">${pill("info", "Copied to Default")}${pill("warn", "Private clip skipped · KeePass")}${pill("error", "Copy failed, try again")}${pill("busy", "Moving history to the database…")}</div>`)}
  ${block("Paste mode, holding Ctrl", state.normal)}
  ${block("Search inside paste mode (F)", state.search)}
  ${block("Image clip", state.image)}
  <div class="budget"><div class="note"><b>How it is drawn</b><br>Same native controls and render path as today, so paste mode stays as fast as it is. Added: a DWM drop shadow on the borderless card (verified), 92% window translucency (verified), window corners at 8px, and pills, badges and key chips drawn as rounded shapes through the custom-draw hook the buttons already use (verified). Icons are Lucide glyphs.</div><div class="note"><b>What stays square</b><br>The preview panel and the search field are Edit controls, so they keep square corners; the toast is a rounded rectangle at 8px rather than a full pill; there is no blur behind the card. Everything else on these boards is as it will render.</div></div>`));

writeFileSync(join(here, "CardStates.dc.html"), wrap(1120, 1180, `
  <div style="grid-column: 1 / -1; display: flex; align-items: baseline; gap: 14px;"><span style="font-size: 18px; font-weight: 600;">The other card states</span><span class="note">Same shell, different content. The mode ring recolors the channel pill; message and confirm are short cards; menu and help are lists of rows.</span></div>
  ${block("Mode ring: X pressed once (delete), X again cycles cut, copy, delete all", state.mode)}
  ${block("Pasting message (multi-paste, Enter)", state.message)}
  ${block("Confirm (delete all)", state.confirm)}
  ${block("Action mode (Ctrl+Shift+A)", state.menu)}
  <div style="grid-column: 1 / -1;">${block("Help (F1)", state.help)}</div>`));

const canvas = {
  pages: [{ id: "page-1", name: "Chosen" }, { id: "page-2", name: "Directions" }],
  artboards: [
    { file: "Main.dc.html", title: "Toasts and paste card", x: 0, y: 0, w: 1120, h: 900, page: "page-1" },
    { file: "CardStates.dc.html", title: "Card states", x: 1220, y: 0, w: 1120, h: 1180, page: "page-1" },
    { file: "DirectionA.dc.html", title: "A · Refined solid (today's toolkit)", x: 0, y: 0, w: 1120, h: 800, page: "page-2" },
    { file: "DirectionB.dc.html", title: "B · Layered card (GDI+ renderer)", x: 1220, y: 0, w: 1120, h: 800, page: "page-2" },
    { file: "DirectionC.dc.html", title: "C · Compact strip", x: 0, y: 940, w: 1120, h: 800, page: "page-2" },
  ],
  annotations: [
    { id: "brief", x: 0, y: -200, w: 620, page: "page-1", text: "Chosen: compact toasts from C and the look of B, on the native rendering of A. The card keeps its speed; shadow, translucency and rounded pills come from DWM and the custom-draw hook, both verified on the real window. Left board: the four toast kinds and the everyday states. Right board: the remaining states. The Directions page keeps the three sketches." },
    { id: "directions-note", x: 0, y: -200, w: 620, page: "page-2", text: "The three direction sketches. A and C share today's toolkit; B needs the GDI+ renderer that the chosen design is built on." },
  ],
  launch: { view: "canvas", page: "page-1" },
};
writeFileSync(join(here, "canvas.json"), JSON.stringify(canvas, null, 2) + "\n");
console.log("wrote 5 artboards + canvas.json");
