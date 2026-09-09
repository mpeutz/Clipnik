// Shared mockup shell for the design canvases: palette (mirrors src/ui/native/Theme.ahk), tweak props,
// helmet CSS, control helpers, title bar and the artboard wrapper.
// ---------- shared theme (mirrors src/ui/native/Theme.ahk) ----------
export const dark = { bg: "#202020", surface: "#2B2B2B", surfaceAlt: "#363636", border: "#3F3F3F", text: "#F0F0F0", muted: "#9A9A9A", hover: "#333333" };
export const light = { bg: "#F3F3F3", surface: "#FFFFFF", surfaceAlt: "#EDEDED", border: "#D9D9D9", text: "#1B1B1B", muted: "#6B6B6B", hover: "#E9E9E9" };

export const props = `{"dark":{"editor":"boolean","default":true,"section":"Theme"},"accent":{"editor":"color","default":"#C42B1C","options":["#C42B1C","#0078D4","#107C10","#8764B8"],"section":"Theme"}}`;

export const logic = `
class Component extends DCLogic {
  renderVals() {
    const d = this.props.dark ?? true;
    const p = d ? ${JSON.stringify(dark)} : ${JSON.stringify(light)};
    const accent = this.props.accent ?? '#C42B1C';
    const vars = Object.entries(p).map(([k, v]) => '--' + k + ':' + v).join(';') + ';--accent:' + accent + ';--accentText:#FFFFFF';
    return { vars };
  }
}`;

export const helmet = `
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

export const svgCheck = `<svg viewBox="0 0 12 12"><path d="M2.5 6.5 5 9l4.5-6"></path></svg>`;
export const svgChevron = `<svg viewBox="0 0 12 12"><path d="M3 4.5 6 7.5 9 4.5"></path></svg>`;
export const spinner = (v) => `<div class="edit num" style="height: 24px; width: 80px;"><span>${v}</span><span class="spin"><svg viewBox="0 0 10 8"><path d="M2 6 5 3l3 3"></path></svg><svg viewBox="0 0 10 8"><path d="M2 2l3 3 3-3"></path></svg></span></div>`;
export const ddl = (v, w = 180) => `<div class="edit ddl" style="height: 24px; width: ${w}px;"><span>${v}</span>${svgChevron}</div>`;
export const edit = (v, w = 180) => `<div class="edit" style="height: 24px; width: ${w}px;"><span>${v}</span></div>`;
export const hotkey = (v) => v ? `<div class="edit hk" style="height: 24px; width: 180px;"><span>${v}</span></div>` : `<div class="edit hk empty" style="height: 24px; width: 180px;"><span>Click to record</span></div>`;
export const check = (label, on, hint = "") => `<div class="check" style="min-height: 28px;"><div class="box${on ? " on" : ""}">${on ? svgCheck : ""}</div><div>${label}${hint ? ` <span class="hint" style="color: var(--muted); font-size: 12px;">${hint}</span>` : ""}</div></div>`;
export const row = (label, control, hint = "") => `<div class="row" style="min-height: 32px;"><div class="lbl">${label}${hint ? `<div class="hint">${hint}</div>` : ""}</div>${control}</div>`;
export const section = (t) => `<div class="section">${t}</div>`;
export const btn = (t, cls = "") => `<div class="btn${cls ? " " + cls : ""}" style="height: 26px;">${t}</div>`;

export const icons = {
  general: `<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.5"></circle><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"></path></svg>`,
  history: `<svg viewBox="0 0 16 16"><path d="M2.5 8a5.5 5.5 0 1 0 1.6-3.9M2.5 2.5v3h3M8 5v3.5l2.5 1.5"></path></svg>`,
  shortcuts: `<svg viewBox="0 0 16 16"><rect x="1.5" y="4" width="13" height="8.5" rx="1.5"></rect><path d="M4 7h1M7 7h1M10 7h2M4.5 10h7"></path></svg>`,
  channels: `<svg viewBox="0 0 16 16"><rect x="2" y="2" width="5" height="5" rx="1"></rect><rect x="9" y="2" width="5" height="5" rx="1"></rect><rect x="2" y="9" width="5" height="5" rx="1"></rect><rect x="9" y="9" width="5" height="5" rx="1"></rect></svg>`,
  appearance: `<svg viewBox="0 0 16 16"><path d="M8 1.8a6.2 6.2 0 1 0 0 12.4c1.2 0 1.6-.9 1.1-1.7-.6-.9.1-2 1.2-2h1.4A2.5 2.5 0 0 0 14.2 8 6.2 6.2 0 0 0 8 1.8z"></path><circle cx="5" cy="7" r=".9"></circle><circle cx="8" cy="4.8" r=".9"></circle><circle cx="11" cy="6.5" r=".9"></circle></svg>`,
  advanced: `<svg viewBox="0 0 16 16"><path d="M3 4h10M3 8h10M3 12h10"></path><circle cx="6" cy="4" r="1.3" fill="var(--surface)"></circle><circle cx="11" cy="8" r="1.3" fill="var(--surface)"></circle><circle cx="7" cy="12" r="1.3" fill="var(--surface)"></circle></svg>`,
};
export const pages = [["general", "General"], ["history", "Clipboard History"], ["shortcuts", "Shortcuts"], ["channels", "Channels"], ["appearance", "Appearance"], ["advanced", "Advanced"]];

export const titlebar = (caption) => `
  <div class="title" style="height: 32px;">
    <svg viewBox="0 0 16 16" style="width: 16px; height: 16px;"><circle cx="8" cy="8" r="6.5" fill="none" stroke="var(--accent)" stroke-width="2"></circle><path d="M10.5 6.3A3 3 0 1 0 10.5 9.7" fill="none" stroke="var(--text)" stroke-width="1.6" stroke-linecap="round"></path></svg>
    <div class="caption">${caption}</div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><path d="M0 5h10" stroke="currentColor"></path></svg></div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><rect x=".5" y=".5" width="9" height="9" fill="none" stroke="currentColor"></rect></svg></div>
    <div class="wc"><svg viewBox="0 0 10 10" style="width: 10px; height: 10px;"><path d="M0 0l10 10M10 0 0 10" stroke="currentColor"></path></svg></div>
  </div>`;

export const wrap = (w, h, inner) => `<!doctype html>
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

