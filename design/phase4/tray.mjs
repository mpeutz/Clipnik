// Tray menu artboard (Explorer-style popup card with an icon row). Imported by build.mjs.
import { helmet, props, logic } from "../shared.mjs";

const icon = (d) => `<svg viewBox="0 0 16 16" style="width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round;">${d}</svg>`;
const icons = {
  action: icon('<path d="M8 1.5 9.8 6l4.7.3-3.7 3 1.3 4.5L8 11.2 3.9 13.8l1.3-4.5-3.7-3L6.2 6z"></path>'),
  history: icon('<path d="M2.5 8a5.5 5.5 0 1 0 1.6-3.9M2.5 2.5v3h3M8 5v3.5l2.5 1.5"></path>'),
  organizer: icon('<rect x="2" y="2" width="5" height="5" rx="1"></rect><rect x="9" y="2" width="5" height="5" rx="1"></rect><rect x="2" y="9" width="5" height="5" rx="1"></rect><rect x="9" y="9" width="5" height="5" rx="1"></rect>'),
  settings: icon('<circle cx="8" cy="8" r="2.5"></circle><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"></path>'),
  incognito: icon('<path d="M2 9h12M4 9l1.5-5h5L12 9"></path><circle cx="5.5" cy="11.5" r="1.8"></circle><circle cx="10.5" cy="11.5" r="1.8"></circle>'),
  disable: icon('<circle cx="8" cy="8" r="6"></circle><path d="M3.8 3.8l8.4 8.4"></path>'),
  chevron: `<svg viewBox="0 0 12 12" style="width: 10px; height: 10px; stroke: var(--muted); fill: none; stroke-width: 1.5;"><path d="M4.5 3 7.5 6 4.5 9"></path></svg>`,
  check: `<svg viewBox="0 0 12 12" style="width: 12px; height: 12px; stroke: var(--accent); fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round;"><path d="M2.5 6.5 5 9l4.5-6"></path></svg>`,
};

const css = `
    .tray { width: 280px; background: var(--surface); color: var(--text); border: 1px solid var(--border); border-radius: 8px; box-shadow: 0 8px 28px rgba(0,0,0,.35); padding: 6px; box-sizing: border-box; }
    .icons { display: flex; justify-content: space-between; padding: 2px 2px 6px 2px; }
    .ib { width: 50px; height: 50px; border-radius: 6px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 5px; color: var(--text); position: relative; }
    .ib .lbl { font-size: 10.5px; line-height: 1; color: var(--muted); white-space: nowrap; }
    .ib.on .lbl { color: var(--accent); }
    .ib.hover { background: var(--hover); }
    .ib.on { color: var(--accent); }
    .hdr { display: flex; align-items: baseline; gap: 8px; padding: 6px 10px 8px 10px; border-top: 1px solid var(--border); }
    .hdr b { font-weight: 600; }
    .mi { display: flex; align-items: center; gap: 10px; height: 32px; padding: 0 10px; border-radius: 4px; }
    .mi.hover { background: var(--hover); }
    .mi .k { margin-left: auto; color: var(--muted); font-size: 11.5px; }
    .mi .chk { width: 12px; display: inline-flex; }
    .sep { height: 1px; background: var(--border); margin: 6px 4px; }
    .sub { position: absolute; width: 220px; }
`;

const mi = (label, key = "", { chevron = false, check = null, hover = false } = {}) =>
  `<div class="mi${hover ? " hover" : ""}" style="height: 32px;">${check !== null ? `<span class="chk">${check ? icons.check : ""}</span>` : ""}<span>${label}</span>${key ? `<span class="k">${key}</span>` : ""}${chevron ? `<span class="k">${icons.chevron}</span>` : ""}</div>`;

const iconRow = (hover = "", on = []) => `
    <div class="icons">
      ${[["history", "History"], ["organizer", "Channels"], ["settings", "Settings"], ["incognito", "Incognito"], ["disable", "Disable"]].map(([k, t]) => `<div class="ib${hover === k ? " hover" : ""}${on.includes(k) ? " on" : ""}" style="width: 50px; height: 50px;">${icons[k]}<span class="lbl">${t}</span></div>`).join("\n      ")}
    </div>`;

const card = (extra = {}) => `
  <div class="tray" style="width: 280px; position: relative;">
    ${iconRow(extra.hoverIcon, extra.on || [])}
    <div class="hdr"><b>Clipjump 13</b><span class="dim">channel Default</span></div>
    ${mi("Channels", "", { chevron: true, hover: extra.hoverItem === "channels" })}
    ${mi("Tools", "", { chevron: true })}
    ${mi("Options", "", { chevron: true })}
    ${mi("Help", "", { chevron: true })}
    <div class="sep"></div>
    ${mi("Reload ClipjumpCustom.ini")}
    ${mi("Restart")}
    ${mi("Exit")}
  </div>`;

export function trayArtboard() {
  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>${helmet.replace("</style>", css + "  </style>")}
<div style="display: flex; gap: 60px; align-items: flex-start; padding: 40px 32px 32px 32px; background: var(--bg); color: var(--text); width: 1000px; height: 460px; box-sizing: border-box; {{vars}}">
  <div>
    <div class="dim" style="margin-bottom: 10px; font-size: 12px;">Right-click on the tray icon, hovering History, Incognito on</div>
    ${card({ hoverIcon: "history", on: ["incognito"] })}
  </div>
  <div style="position: relative;">
    <div class="dim" style="margin-bottom: 10px; font-size: 12px;">Channels submenu open</div>
    ${card({ hoverItem: "channels", on: ["incognito"] })}
    <div class="tray sub" style="width: 220px; left: 286px; top: 110px;">
      ${mi("0  Default", "", { check: true })}
      ${mi("1  Work", "", { check: false })}
      ${mi("2  Snippets", "", { check: false, hover: true })}
      ${mi("3  Addresses", "", { check: false })}
      <div class="sep"></div>
      ${mi("Channel Organizer…", "Ctrl+Alt+O")}
    </div>
  </div>
</div>
</x-dc>
<script data-dc-script data-props='${props}'>${logic}
</script>
</body>
</html>
`;
}
