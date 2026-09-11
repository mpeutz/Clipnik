// Radial (pie) menu exploration for the paste-mode format menu and Action Mode.
// Four structural answers to "a ring holds 8, the menus hold 16-17", all clickable.
// Run: node design/phase7/build.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

// ---------- shell ----------
const CSS = `
    body { margin: 0; font-family: "Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif; font-size: 13.33px; line-height: 1.35; }
    a { color: #76B84E; } a:hover { color: #8ECB68; }
    .stage { box-sizing: border-box; display: flex; flex-direction: column; gap: 12px; padding: 20px; background: var(--bg); color: var(--text); }
    .hd { display: flex; align-items: baseline; gap: 10px; flex: 0 0 auto; }
    .hd .t { font-size: 15px; font-weight: 600; }
    .hd .s { font-size: 12px; color: var(--muted); }
    .desk { position: relative; flex: 1 1 auto; min-height: 0; border-radius: 8px; overflow: hidden; background: #161920; background-image: radial-gradient(circle at 28% 18%, #262d3a 0, transparent 58%), radial-gradient(circle at 80% 90%, #1d2430 0, transparent 50%); }
    .ring { position: absolute; user-select: none; }
    .ring svg { display: block; }
    .wl { position: absolute; text-align: center; pointer-events: none; font-size: 10px; line-height: 1.2; font-weight: 600; letter-spacing: .01em; display: flex; flex-direction: column; align-items: center; gap: 2px; white-space: nowrap; }
    .wl .lt { max-width: 100%; overflow: hidden; text-overflow: ellipsis; }
    .wl .k { display: inline-flex; align-items: center; justify-content: center; min-width: 14px; height: 13px; padding: 0 4px; border-radius: 4px; font-size: 9px; font-weight: 600; letter-spacing: .02em; }
    .hub { position: absolute; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; pointer-events: none; }
    .hub .ht { font-size: 12px; font-weight: 600; line-height: 1.2; }
    .hub .hs { font-size: 10px; color: var(--muted); line-height: 1.25; margin-top: 3px; }
    .hub .hk { font-size: 9px; color: var(--muted); margin-top: 6px; letter-spacing: .02em; }
    .card { position: absolute; border-radius: 8px; border: 1px solid rgba(255,255,255,.10); background: var(--surface); box-shadow: 0 14px 34px rgba(0,0,0,.5); overflow: hidden; }
    .card .row { display: flex; align-items: center; gap: 8px; padding: 10px 12px 6px 12px; }
    .card .body { margin: 0 12px 10px 12px; padding: 8px 10px; border-radius: 2px; background: rgba(240,240,240,.05); font-family: Consolas, "Cascadia Mono", monospace; font-size: 11.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .pill { display: inline-flex; align-items: center; height: 19px; padding: 0 8px; border-radius: 10px; font-size: 10px; font-weight: 600; letter-spacing: .03em; }
    .notes { flex: 0 0 auto; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px 18px; }
    .note { font-size: 11px; color: var(--muted); line-height: 1.45; }
    .note b { color: var(--text); font-weight: 600; display: block; }
    .tiles { position: absolute; user-select: none; }
    .tile { position: absolute; box-sizing: border-box; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; border-radius: 6px; border: 1px solid rgba(255,255,255,.08); font-size: 11px; font-weight: 600; text-align: center; pointer-events: none; }
    .tile .k { font-size: 9.5px; font-weight: 600; opacity: .75; }
`;

const shell = (w, h, body, props, logic) => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>${CSS}  </style>
</helmet>
<div class="stage" style="width: ${w}px; height: ${h}px; {{vars}}">
${body}
</div>
</x-dc>
<script data-dc-script data-props='${props}'>
class Component extends DCLogic {
${HELPERS}
${logic}
}
</script>
</body>
</html>
`;

// ---------- logic helpers shared by every artboard (copied into each file) ----------
const HELPERS = `  hex(s) { return parseInt(String(s).replace('#', ''), 16); }
  mix(a, b, t) {
    var A = this.hex(a), B = this.hex(b);
    var ch = function (s, e) { return Math.round(s + (e - s) * t); };
    var r = ch((A >> 16) & 255, (B >> 16) & 255), g = ch((A >> 8) & 255, (B >> 8) & 255), bl = ch(A & 255, B & 255);
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + bl).toString(16).slice(1).toUpperCase();
  }
  lum(a) { var v = this.hex(a); return 0.2126 * (((v >> 16) & 255) / 255) + 0.7152 * (((v >> 8) & 255) / 255) + 0.0722 * ((v & 255) / 255); }
  pal() {
    var dark = this.props.dark === undefined ? true : this.props.dark;
    var accent = this.props.accent || '#76B84E';
    var p = dark
      ? { bg: '#202020', surface: '#2B2B2B', surfaceAlt: '#363636', border: '#3F3F3F', text: '#F0F0F0', muted: '#9A9A9A', danger: '#E5484D' }
      : { bg: '#F3F3F3', surface: '#FFFFFF', surfaceAlt: '#EDEDED', border: '#D9D9D9', text: '#1B1B1B', muted: '#6B6B6B', danger: '#C42B1C' };
    p.accent = accent;
    p.accentText = this.lum(accent) > 0.45 ? '#101010' : '#FFFFFF';
    p.accentSoft = this.mix(accent, p.surface, 0.82);
    p.dim = this.mix(p.surfaceAlt, p.bg, 0.5);
    var keys = ['bg', 'surface', 'surfaceAlt', 'border', 'text', 'muted', 'danger', 'accent', 'accentText', 'accentSoft'];
    p.vars = keys.map(function (k) { return '--' + k + ':' + p[k]; }).join(';');
    return p;
  }
  pt(cx, cy, r, deg) {
    var a = (deg - 90) * Math.PI / 180;
    return [Math.round((cx + r * Math.cos(a)) * 100) / 100, Math.round((cy + r * Math.sin(a)) * 100) / 100];
  }
  sector(cx, cy, r0, r1, a0, a1) {
    var o0 = this.pt(cx, cy, r1, a0), o1 = this.pt(cx, cy, r1, a1), i1 = this.pt(cx, cy, r0, a1), i0 = this.pt(cx, cy, r0, a0);
    var big = (a1 - a0) > 180 ? 1 : 0;
    return 'M ' + o0[0] + ' ' + o0[1] + ' A ' + r1 + ' ' + r1 + ' 0 ' + big + ' 1 ' + o1[0] + ' ' + o1[1]
      + ' L ' + i1[0] + ' ' + i1[1] + ' A ' + r0 + ' ' + r0 + ' 0 ' + big + ' 0 ' + i0[0] + ' ' + i0[1] + ' Z';
  }
  aim(e, cx, cy, n) {
    var r = e.currentTarget.getBoundingClientRect();
    var dx = e.clientX - r.left - cx, dy = e.clientY - r.top - cy;
    var dist = Math.sqrt(dx * dx + dy * dy);
    var deg = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;
    return { dist: dist, deg: deg, idx: Math.round(deg / (360 / n)) % n };
  }
  look(n, r0, r1) {
    var gap = this.props.gap === undefined ? 8 : Number(this.props.gap);
    var corner = this.props.corner === undefined ? 8 : Number(this.props.corner);
    var step = 2 * Math.PI / n;
    return { gap: gap, corner: Math.max(0, Math.min(corner, 0.3 * r0 * step, (r1 - r0) / 2 - 2)) };
  }
  roundSector(cx, cy, r0, r1, a0, a1, gap, rad) {
    if (a1 - a0 >= 359.9) {
      return 'M ' + (cx - r1) + ' ' + cy + ' A ' + r1 + ' ' + r1 + ' 0 1 1 ' + (cx + r1) + ' ' + cy + ' A ' + r1 + ' ' + r1 + ' 0 1 1 ' + (cx - r1) + ' ' + cy + ' Z'
        + ' M ' + (cx - r0) + ' ' + cy + ' A ' + r0 + ' ' + r0 + ' 0 1 0 ' + (cx + r0) + ' ' + cy + ' A ' + r0 + ' ' + r0 + ' 0 1 0 ' + (cx - r0) + ' ' + cy + ' Z';
    }
    var d = gap / 2, k = Math.PI / 180;
    var corner = function (a, sign, R, outer) {
      var e = [Math.sin(a * k), -Math.cos(a * k)], nn = [sign * Math.cos(a * k), sign * Math.sin(a * k)];
      var cr = outer ? R - rad : R + rad, off = d + rad;
      var t = Math.sqrt(Math.max(cr * cr - off * off, 0));
      var c = [e[0] * t + nn[0] * off, e[1] * t + nn[1] * off];
      var len = Math.sqrt(c[0] * c[0] + c[1] * c[1]) || 1;
      return { line: [e[0] * t + nn[0] * d, e[1] * t + nn[1] * d], arc: [c[0] / len * R, c[1] / len * R] };
    };
    var P = function (q) { return (Math.round((cx + q[0]) * 100) / 100) + ' ' + (Math.round((cy + q[1]) * 100) / 100); };
    var AO = corner(a0, 1, r1, true), BO = corner(a1, -1, r1, true), BI = corner(a1, -1, r0, false), AI = corner(a0, 1, r0, false);
    var big = (a1 - a0) > 180 ? 1 : 0, f = ' A ' + rad + ' ' + rad + ' 0 0 1 ';
    return 'M ' + P(AO.arc) + ' A ' + r1 + ' ' + r1 + ' 0 ' + big + ' 1 ' + P(BO.arc) + f + P(BO.line)
      + ' L ' + P(BI.line) + f + P(BI.arc) + ' A ' + r0 + ' ' + r0 + ' 0 ' + big + ' 0 ' + P(AI.arc) + f + P(AI.line)
      + ' L ' + P(AO.line) + f + P(AO.arc) + ' Z';
  }`;

const PROPS_RING_EXTRA = `"gap":{"editor":"range","min":2,"max":10,"step":1,"unit":"px","default":8,"section":"Ring"},"corner":{"editor":"range","min":0,"max":14,"step":1,"unit":"px","default":8,"section":"Ring"}`;
const PROPS_BASE = `"dark":{"editor":"boolean","default":true,"section":"Theme"},"accent":{"editor":"color","default":"#76B84E","options":["#76B84E","#C42B1C","#0078D4","#8764B8"],"section":"Theme"}`;

// ---------- pieces of markup ----------
const ringMarkup = (size, hubR) => `      <div class="ring" style="{{ringStyle}}" onMouseMove="{{move}}" onMouseLeave="{{leave}}" onClick="{{pick}}">
        <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
          <circle cx="${size / 2}" cy="${size / 2}" r="{{shadowR}}" style="{{shadowStyle}}"></circle>
          <sc-for list="{{wedges}}" as="w" hint-placeholder-count="8">
            <path d="{{w.d}}" style="{{w.style}}"></path>
          </sc-for>
          <sc-for list="{{wedges}}" as="w" hint-placeholder-count="8">
            <g transform="{{w.itf}}" style="{{w.istyle}}"><path d="{{w.icon}}"></path></g>
          </sc-for>
          <circle cx="${size / 2}" cy="${size / 2}" r="{{hubR}}" style="{{hubStyle}}"></circle>
        </svg>
        <sc-for list="{{wedges}}" as="w" hint-placeholder-count="8">
          <div class="wl" style="{{w.lstyle}}"><div class="lt">{{w.label}}</div><div class="k" style="{{w.kstyle}}">{{w.key}}</div></div>
        </sc-for>
        <div class="hub" style="{{hubBox}}">
          <div class="ht" style="{{hubTitleStyle}}">{{hubTitle}}</div>
          <div class="hs">{{hubSub}}</div>
          <div class="hk">{{hubKeys}}</div>
        </div>
      </div>`;

const notes = (rows) => `      <div class="notes">
${rows.map(([h, t]) => `        <div class="note"><b>${h}</b>${t}</div>`).join("\n")}
      </div>`;

const head = (t, s) => `      <div class="hd"><span class="t">${t}</span><span class="s">${s}</span></div>`;

// the dimmed paste card behind the ring
const cardMarkup = `        <div class="card" style="{{cardStyle}}">
          <div class="row">
            <span class="pill" style="{{cardPill}}">Default</span>
            <span style="font-size: 14px; font-weight: 600;">3<span style="font-weight: 400; font-size: 11px; color: var(--muted);"> / 40</span></span>
            <span class="pill" style="{{cardKind}}">{{kindLabel}}</span>
            <span class="pill" style="{{cardFmt}}">{{activeLabel}}</span>
          </div>
          <div class="body">{{sample}}</div>
        </div>`;

// ---------- format data ----------
const D = {
  orig: ["Original", "Original", "O", "Paste the clip exactly as copied"],
  trim: ["Trim Formatting", "Trim", "T", "Strip off formatting"],
  strip: ["Strip URL tracking", "Untrack", "S", "Remove utm_*, fbclid, gclid"],
  md: ["Markdown link", "Markdown", "M", "[host](url)"],
  pretty: ["Pretty JSON", "Pretty", "P", "Indent two spaces"],
  mini: ["Minified JSON", "Minify", "J", "Strip whitespace outside strings"],
  sent: ["SentenceCase", "Sentence", "E", "Paste text in sentence case"],
  title: ["Title case", "Title", "I", "First Letter Of Each Word"],
  upper: ["Upper case", "UPPER", "U", "THE WHOLE CLIP"],
  lower: ["Lower case", "lower", "W", "the whole clip"],
  one: ["One line", "Flatten", "L", "Collapse every run of whitespace"],
  slug: ["Slugify", "Slug", "G", "lower-case-with-dashes"],
  b64: ["Decode base64", "Base64", "B", "Decode when the clip is valid base64"],
  common: ["Common Formats", "Common", "N", "Pick from many predefined formats"],
};
const f = (k, dim) => ({ label: D[k][0], short: D[k][1], key: D[k][2], desc: D[k][3], dim: !!dim });
const more = { label: "More…", short: "More", key: "→", desc: "seven more formats", more: true };
const back = { label: "Back", short: "Back", key: "←", desc: "back to the first ring", more: true };

// applicable formats first, in a fixed priority: Original, Trim, the kind's own formats, the rest
const SETS = {
  URL: {
    on: "Trim Formatting",
    sample: "https://github.com/aviaryan/Clipjump/issues/143?utm_source=news",
    pages: [
      [f("orig"), f("trim"), f("strip"), f("md"), f("sent"), f("common"), f("pretty", 1), more],
      [f("mini", 1), f("title", 1), f("upper", 1), f("lower", 1), f("one", 1), f("slug", 1), f("b64", 1), back],
    ],
  },
  JSON: {
    on: "Pretty JSON",
    sample: '{"id": 143, "title": "Paste mode ignores Ctrl release"}',
    pages: [
      [f("orig"), f("trim"), f("pretty"), f("mini"), f("sent"), f("common"), f("strip", 1), more],
      [f("md", 1), f("title", 1), f("upper", 1), f("lower", 1), f("one", 1), f("slug", 1), f("b64", 1), back],
    ],
  },
  "Plain text": {
    on: "Original",
    sample: "Brings the Latest Resources widget in line with the Figma mockup",
    pages: [
      [f("orig"), f("trim"), f("sent"), f("title"), f("upper"), f("lower"), f("one"), more],
      [f("slug"), f("b64"), f("common"), f("strip", 1), f("md", 1), f("pretty", 1), f("mini", 1), back],
    ],
  },
};

// ---------- icons (24 grid, stroke; stand-ins for the Lucide font glyphs the app draws) ----------
const I = {
  history: "M3 12a9 9 0 1 0 2.5-6.2M3 4v4h4M12 7v5l3.5 2",
  grid: "M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z",
  sliders: "M4 6h9M17 6h3M4 12h3M11 12h9M4 18h13M21 18h0M15 4v4M9 10v4M19 16v4",
  pin: "M12 17v5M9 10.8a2 2 0 0 1-1.1 1.8l-1.8.9A2 2 0 0 0 5 15.2V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.8a2 2 0 0 0-1.1-1.8l-1.8-.9A2 2 0 0 1 15 10.8V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z",
  swap: "M8 3 4 7l4 4M4 7h15M16 21l4-4-4-4M20 17H5",
  stop: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM10 9v6M14 9v6",
  file: "M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5",
  folder: "M4 20a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2z",
  dots: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12h.01M12 12h.01M16 12h.01",
  arrowBack: "M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18zM13 9l-3 3 3 3",
  plug: "M9 2v6M15 2v6M6 8h12v3a6 6 0 0 1-12 0zM12 17v5",
  eyeOff: "M10.7 5.1A9 9 0 0 1 21 12a17 17 0 0 1-2.2 2.9M6.6 6.6A17 17 0 0 0 3 12a9 9 0 0 0 13 6.3M3 3l18 18M9.9 9.9a3 3 0 0 0 4.2 4.2",
  help: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM9.5 9.5a2.6 2.6 0 0 1 5 1c0 1.8-2.5 2.2-2.5 3.5M12 17h.01",
  keyboard: "M3 6h18v12H3zM7 10h.01M11 10h.01M15 10h.01M7 14h10",
  sync: "M21 12a9 9 0 0 1-15.5 6.2M3 12A9 9 0 0 1 18.5 5.8M3 19v-4h4M21 5v4h-4",
  power: "M12 3v9M6.5 6.8a8 8 0 1 0 11 0",
  layers: "M12 3 3 8l9 5 9-5zM3 14l9 5 9-5",
  hash: "M4 9h16M4 15h16M10 3 8 21M16 3l-2 18",
};

const A = {
  history: ["Clipboard History", "History", "H", "history", "every clip ever copied"],
  org: ["Channel Organizer", "Organizer", "O", "grid", "channels and their clips"],
  settings: ["Settings", "Settings", "E", "sliders", "all of Clipjump's options"],
  hold: ["Hold clip", "Hold", "B", "pin", "keep the next copy at the top"],
  pit: ["PitSwap", "PitSwap", "P", "swap", "swap with the pit channel"],
  once: ["One-time stop", "Skip", "T", "stop", "skip recording the next copy"],
  fpath: ["Copy file path", "Path", "C", "file", "the selected file's full path"],
  more: ["More…", "More", "→", "dots", "seven more actions"],
  plugins: ["Plugin Manager", "Plugins", "M", "plug", "enable and edit plugins"],
  ignored: ["Ignored Windows", "Ignore", "L", "eyeOff", "apps Clipjump leaves alone"],
  folder: ["Copy folder path", "Folder", "X", "folder", "the open folder's path"],
  fdata: ["Copy file data", "File", "F", "layers", "the file itself, not its path"],
  sync: ["Sync clipboard", "Sync", "U", "sync", "push the active clip to Windows"],
  keys: ["Paste-mode keys", "Keys", "F2", "keyboard", "the shortcut sheet"],
  help: ["Help", "Help", "F1", "help", "what every key does"],
  off: ["Disable", "Disable", "D", "power", "stop monitoring the clipboard"],
  back: ["Back", "Back", "←", "arrowBack", "back to the first ring"],
};
const a = (k) => ({ label: A[k][0], short: A[k][1], key: A[k][2], icon: I[A[k][3]], desc: A[k][4], more: k === "more" || k === "back" });

// ---------- Main: Direction A, the format ring ----------
const mainLogic = `  wedgeSet(items, p, hover, onLabel, CX, CY, R0, R1, L) {
    var self = this, n = items.length, step = 360 / n;
    var labelR = R0 + (R1 - R0) * 0.5, lw = Math.floor(2 * labelR * Math.sin(Math.PI / n) - L.gap - 14);
    return items.map(function (it, i) {
      var isHover = i === hover, isOn = it.label === onLabel && !it.more;
      var fill = isHover ? p.accent : (isOn ? p.accentSoft : (it.more ? p.surface : (it.dim ? p.dim : p.surfaceAlt)));
      var stroke = (isOn && !isHover) ? p.accent : 'none';
      var c = self.pt(CX, CY, labelR, i * step);
      var color = isHover ? p.accentText : ((it.dim || it.more) ? p.muted : p.text);
      return {
        d: self.roundSector(CX, CY, R0, R1, i * step - step / 2, i * step + step / 2, L.gap, L.corner),
        style: 'fill:' + fill + ';stroke:' + stroke + ';stroke-width:1;fill-rule:evenodd',
        lstyle: 'left:' + (c[0] - lw / 2) + 'px; top:' + (c[1] - 14) + 'px; width:' + lw + 'px; color:' + color,
        kstyle: 'background:' + (isHover ? 'rgba(0,0,0,.16)' : p.surface) + ';color:' + (isHover ? p.accentText : p.muted),
        label: it.short || it.label, key: it.key, icon: '', itf: 'translate(-99,-99)', istyle: 'display:none'
      };
    });
  }
  renderVals() {
    var p = this.pal(), st = this.state || {};
    var kindKey = this.props.kind || 'URL';
    var set = ${JSON.stringify(SETS)}[kindKey];
    var page = st.page || 0, items = set.pages[page];
    var onLabel = st.on && st.onKind === kindKey ? st.on : set.on;
    var hover = st.hover === undefined ? -1 : st.hover;
    var CX = 160, CY = 160, R0 = 56, R1 = 148, n = items.length;
    var self = this;
    var h = hover >= 0 ? items[hover] : null;
    return {
      vars: p.vars,
      wedges: this.wedgeSet(items, p, hover, onLabel, CX, CY, R0, R1, this.look(n, R0, R1)),
      hubR: R0 - this.look(n, R0, R1).gap,
      ringStyle: 'left: 26px; top: 14px; width: 320px; height: 320px;',
      shadowR: 150, shadowStyle: 'fill:rgba(0,0,0,.34)',
      hubStyle: 'fill:' + p.surface + ';stroke:rgba(255,255,255,.10);stroke-width:1',
      hubBox: 'left: 110px; top: 110px; width: 100px; height: 100px;',
      hubTitle: h ? h.label : onLabel,
      hubTitleStyle: 'color:' + (h ? p.text : p.accent),
      hubSub: h ? h.desc : 'active format',
      hubKeys: 'release · click · Esc',
      kindLabel: kindKey === 'Plain text' ? 'TEXT' : kindKey,
      activeLabel: onLabel,
      sample: set.sample,
      cardStyle: 'left: 238px; top: 252px; width: 266px; opacity: .5;',
      cardPill: 'background:' + p.accent + ';color:' + p.accentText,
      cardKind: 'background:' + p.accentSoft + ';color:' + p.text,
      cardFmt: 'background:' + p.surfaceAlt + ';color:' + p.text,
      move: function (e) { var t = self.aim(e, CX, CY, n); self.setState({ hover: t.dist < R0 - 8 ? -1 : t.idx }); },
      leave: function () { self.setState({ hover: -1 }); },
      pick: function (e) {
        var t = self.aim(e, CX, CY, n);
        if (t.dist < R0 - 8) return self.setState({ hover: -1 });
        var it = items[t.idx];
        if (it.more) return self.setState({ page: 1 - page, hover: -1 });
        self.setState({ on: it.label, onKind: kindKey });
      }
    };
  }`;

writeFileSync(join(here, "Main.dc.html"), shell(560, 560,
  `${head("A · Favorites ring", "seven formats plus More, the ring at the pointer")}
      <div class="desk">
${cardMarkup}
${ringMarkup(320, 46)}
      </div>
${notes([
    ["Why", "The seven formats that fit this clip are one flick away and never move, so the gesture becomes muscle memory. More… flips the ring to the other seven."],
    ["Cost", "A GDI+ layered window, roughly 300 lines: geometry, paint, angle hit test, input. The keyboard card stays for people who never reach for the mouse."],
  ])}`,
  `{${PROPS_BASE},${PROPS_RING_EXTRA},"kind":{"editor":"enum","options":["URL","JSON","Plain text"],"default":"URL","section":"Clip"},"$preview":{"width":560,"height":560}}`,
  mainLogic));

// ---------- ActionRing: Direction A applied to Action Mode ----------
const actionPages = [
  [a("history"), a("org"), a("settings"), a("hold"), a("pit"), a("once"), a("fpath"), a("more")],
  [a("plugins"), a("ignored"), a("folder"), a("fdata"), a("sync"), a("keys"), a("help"), a("back")],
];

const actionLogic = `  renderVals() {
    var p = this.pal(), st = this.state || {}, self = this;
    var pages = ${JSON.stringify(actionPages)};
    var page = st.page || 0, items = pages[page], n = items.length;
    var hover = st.hover === undefined ? -1 : st.hover;
    var CX = 160, CY = 160, R0 = 56, R1 = 148, step = 360 / n, L = this.look(n, R0, R1);
    var mr = R0 + (R1 - R0) * 0.5, lw = Math.floor(2 * mr * Math.sin(Math.PI / n) - L.gap - 14);
    var wedges = items.map(function (it, i) {
      var isHover = i === hover;
      var c = self.pt(CX, CY, mr, i * step);
      var color = isHover ? p.accentText : (it.more ? p.muted : p.text);
      return {
        d: self.roundSector(CX, CY, R0, R1, i * step - step / 2, i * step + step / 2, L.gap, L.corner),
        style: 'fill:' + (isHover ? p.accent : (it.more ? p.surface : p.surfaceAlt)) + ';stroke:none;fill-rule:evenodd',
        lstyle: 'left:' + (c[0] - lw / 2) + 'px; top:' + (c[1] - 5) + 'px; width:' + lw + 'px; color:' + color,
        kstyle: 'background:' + (isHover ? 'rgba(0,0,0,.16)' : p.surface) + ';color:' + (isHover ? p.accentText : p.muted),
        label: it.short || it.label, key: it.key,
        icon: it.icon,
        itf: 'translate(' + (c[0] - 8) + ',' + (c[1] - 24) + ') scale(0.6667)',
        istyle: 'fill:none;stroke:' + (isHover ? p.accentText : p.muted) + ';stroke-width:2;stroke-linecap:round;stroke-linejoin:round'
      };
    });
    var h = hover >= 0 ? items[hover] : null;
    return {
      vars: p.vars, wedges: wedges, hubR: R0 - L.gap,
      ringStyle: 'left: 50%; top: 50%; width: 320px; height: 320px; transform: translate(-50%, -50%);',
      shadowR: 150, shadowStyle: 'fill:rgba(0,0,0,.34)',
      hubStyle: 'fill:' + p.surface + ';stroke:rgba(255,255,255,.10);stroke-width:1',
      hubBox: 'left: 110px; top: 110px; width: 100px; height: 100px;',
      hubTitle: h ? h.label : 'Action mode',
      hubTitleStyle: 'color:' + (h ? p.text : p.accent),
      hubSub: h ? h.desc : (page ? 'page 2 of 2' : 'page 1 of 2'),
      hubKeys: 'release · click · Esc',
      move: function (e) { var t = self.aim(e, CX, CY, n); self.setState({ hover: t.dist < R0 - 8 ? -1 : t.idx }); },
      leave: function () { self.setState({ hover: -1 }); },
      pick: function (e) {
        var t = self.aim(e, CX, CY, n);
        if (t.dist < R0 - 8) return self.setState({ hover: -1 });
        if (items[t.idx].more) self.setState({ page: 1 - page, hover: -1 });
      }
    };
  }`;

writeFileSync(join(here, "ActionRing.dc.html"), shell(560, 560,
  `${head("A · Action mode as a ring", "the same structure, icons instead of long labels")}
      <div class="desk">
${ringMarkup(320, 46)}
      </div>
${notes([
    ["Why", "Action mode has seventeen entries and no context to rank them, so the ring carries the seven you reach for and More… holds the rest. Channels stay on the number keys."],
    ["Open", "A ring wants a mouse trigger. Ctrl+Shift+A still works, but a side button or middle click would suit it better."],
  ])}`,
  `{${PROPS_BASE},${PROPS_RING_EXTRA},"$preview":{"width":560,"height":560}}`,
  actionLogic));

// ---------- Direction B: two concentric tracks ----------
const bInner = [f("orig"), f("trim"), f("strip"), f("md"), f("pretty"), f("mini"), f("sent"), f("common")];
const bOuter = [f("title", 1), f("upper", 1), f("lower", 1), f("one", 1), f("slug", 1), f("b64", 1)];

const bLogic = `  renderVals() {
    var p = this.pal(), st = this.state || {}, self = this;
    var inner = ${JSON.stringify(bInner)}, outer = ${JSON.stringify(bOuter)};
    var CX = 230, CY = 230, HUB = 50;
    var G = this.look(8, HUB + 8, 146).gap;
    var tracks = [[inner, HUB + G, 146], [outer, 146 + G, 212]];
    var hv = st.hv || { t: -1, i: -1 };
    var onLabel = st.on || 'Trim Formatting';
    var wedges = [];
    tracks.forEach(function (tr, ti) {
      var m = tr[0].length, step = 360 / m, mid = (tr[1] + tr[2]) / 2, corner = self.look(m, tr[1], tr[2]).corner;
      var lw = Math.min(90, Math.floor(2 * mid * Math.sin(Math.PI / m) - G - 14));
      tr[0].forEach(function (it, i) {
        var isHover = hv.t === ti && hv.i === i, isOn = it.label === onLabel && ti === 0;
        var c = self.pt(CX, CY, mid, i * step);
        var fill = isHover ? p.accent : (isOn ? p.accentSoft : (ti ? p.dim : p.surfaceAlt));
        wedges.push({
          d: self.roundSector(CX, CY, tr[1], tr[2], i * step - step / 2, i * step + step / 2, G, corner),
          style: 'fill:' + fill + ';stroke:' + ((isOn && !isHover) ? p.accent : 'none') + ';stroke-width:1;fill-rule:evenodd',
          lstyle: 'left:' + (c[0] - lw / 2) + 'px; top:' + (c[1] - 14) + 'px; width:' + lw + 'px; color:' + (isHover ? p.accentText : (ti ? p.muted : p.text)),
          kstyle: 'background:' + (isHover ? 'rgba(0,0,0,.16)' : p.surface) + ';color:' + (isHover ? p.accentText : p.muted),
          label: it.short || it.label, key: it.key, icon: '', itf: 'translate(-99,-99)', istyle: 'display:none'
        });
      });
    });
    var h = hv.t >= 0 ? tracks[hv.t][0][hv.i] : null;
    var which = function (e) {
      var t = self.aim(e, CX, CY, 8);
      if (t.dist < HUB || t.dist > 214) return { t: -1, i: -1 };
      var tr = t.dist < 146 + G / 2 ? 0 : 1, m = tracks[tr][0].length;
      return { t: tr, i: Math.round(t.deg / (360 / m)) % m };
    };
    return {
      vars: p.vars, wedges: wedges, hubR: HUB,
      ringStyle: 'left: 50%; top: 50%; width: 460px; height: 460px; transform: translate(-50%, -50%);',
      shadowR: 210, shadowStyle: 'fill:rgba(0,0,0,.32)',
      hubStyle: 'fill:' + p.surface + ';stroke:rgba(255,255,255,.10);stroke-width:1',
      hubBox: 'left: 178px; top: 178px; width: 104px; height: 104px;',
      hubTitle: h ? h.label : onLabel,
      hubTitleStyle: 'color:' + (h ? p.text : p.accent),
      hubSub: h ? h.desc : 'inner ring fits this clip',
      hubKeys: 'release · click · Esc',
      move: function (e) { self.setState({ hv: which(e) }); },
      leave: function () { self.setState({ hv: { t: -1, i: -1 } }); },
      pick: function (e) { var w = which(e); if (w.t >= 0) self.setState({ on: tracks[w.t][0][w.i].label }); }
    };
  }`;

writeFileSync(join(here, "DirectionB.dc.html"), shell(580, 620,
  `${head("B · Two tracks", "all fourteen formats in one gesture")}
      <div class="desk">
${ringMarkup(460, 46)}
      </div>
${notes([
    ["Why", "Angle picks the format, distance picks the track: the inner ring is what fits this clip, the outer ring is everything else. Nothing is ever a page away."],
    ["Against", "420px across, and the outer track asks for a steadier hand. A flick that overshoots lands one ring out, which is a different format rather than nothing."],
  ])}`,
  `{${PROPS_BASE},${PROPS_RING_EXTRA},"$preview":{"width":580,"height":620}}`,
  bLogic));

// ---------- Direction C: two levels ----------
const cCats = [
  { label: "Windows", key: "1", icon: I.grid, desc: "history, organizer, settings", items: [a("history"), a("org"), a("settings"), a("plugins"), a("ignored")] },
  { label: "Clip", key: "2", icon: I.pin, desc: "hold, swap, skip, sync", items: [a("hold"), a("pit"), a("once"), a("sync")] },
  { label: "Copy", key: "3", icon: I.file, desc: "path, folder, file data", items: [a("fpath"), a("folder"), a("fdata")] },
  { label: "Channels", key: "4", icon: I.hash, desc: "switch to channel 0 to 9", items: "channels" },
  { label: "Help", key: "5", icon: I.help, desc: "keys and shortcuts", items: [a("help"), a("keys")] },
  { label: "Off", key: "6", icon: I.power, desc: "disable or exit", items: [a("off")] },
];

const cLogic = `  renderVals() {
    var p = this.pal(), st = this.state || {}, self = this;
    var cats = ${JSON.stringify(cCats)};
    var open = st.open === undefined ? -1 : st.open;
    var items = cats, level = 0;
    if (open >= 0) {
      level = 1;
      items = cats[open].items;
      if (items === 'channels') {
        items = [];
        for (var i = 0; i < 10; i++) items.push({ label: i === 0 ? 'Default' : 'Channel ' + i, short: i === 0 ? 'Default' : 'Ch ' + i, key: String(i), icon: '', desc: 'switch the active channel' });
      }
    }
    var n = items.length, step = 360 / n;
    var CX = 160, CY = 160, R0 = 56, R1 = 148, L = this.look(n, R0, R1);
    var hover = st.hover === undefined ? -1 : st.hover;
    var mr = R0 + (R1 - R0) * 0.5, wide = Math.min(90, Math.floor(2 * mr * Math.sin(Math.PI / n) - L.gap - 14));
    var wedges = items.map(function (it, i) {
      var isHover = i === hover;
      var hasIcon = !!it.icon;
      var c = self.pt(CX, CY, mr, i * step);
      return {
        d: self.roundSector(CX, CY, R0, R1, i * step - step / 2, i * step + step / 2, L.gap, L.corner),
        style: 'fill:' + (isHover ? p.accent : p.surfaceAlt) + ';stroke:none;fill-rule:evenodd',
        lstyle: 'left:' + (c[0] - wide / 2) + 'px; top:' + (c[1] - (hasIcon ? 5 : 14)) + 'px; width:' + wide + 'px; color:' + (isHover ? p.accentText : p.text),
        kstyle: 'background:' + (isHover ? 'rgba(0,0,0,.16)' : p.surface) + ';color:' + (isHover ? p.accentText : p.muted),
        label: it.short || it.label, key: it.key,
        icon: it.icon || '',
        itf: hasIcon ? ('translate(' + (c[0] - 8) + ',' + (c[1] - 24) + ') scale(0.6667)') : 'translate(-99,-99)',
        istyle: hasIcon ? ('fill:none;stroke:' + (isHover ? p.accentText : p.muted) + ';stroke-width:2;stroke-linecap:round;stroke-linejoin:round') : 'display:none'
      };
    });
    var h = hover >= 0 ? items[hover] : null;
    return {
      vars: p.vars, wedges: wedges, hubR: R0 - L.gap,
      ringStyle: 'left: 50%; top: 50%; width: 320px; height: 320px; transform: translate(-50%, -50%);',
      shadowR: 150, shadowStyle: 'fill:rgba(0,0,0,.34)',
      hubStyle: 'fill:' + p.surface + ';stroke:' + (level ? p.accent : 'rgba(255,255,255,.10)') + ';stroke-width:1',
      hubBox: 'left: 110px; top: 110px; width: 100px; height: 100px;',
      hubTitle: h ? h.label : (level ? cats[open].label : 'Action mode'),
      hubTitleStyle: 'color:' + (h ? p.text : p.accent),
      hubSub: h ? h.desc : (level ? 'click the centre to go back' : 'six groups, seventeen actions'),
      hubKeys: level ? 'centre · back' : 'release · click · Esc',
      move: function (e) { var t = self.aim(e, CX, CY, n); self.setState({ hover: t.dist < R0 - 8 ? -1 : t.idx }); },
      leave: function () { self.setState({ hover: -1 }); },
      pick: function (e) {
        var t = self.aim(e, CX, CY, n);
        if (t.dist < R0 - 8) return self.setState({ open: -1, hover: -1 });
        if (level === 0) self.setState({ open: t.idx, hover: -1 });
      }
    };
  }`;

writeFileSync(join(here, "DirectionC.dc.html"), shell(520, 560,
  `${head("C · Two levels", "six groups, then the group's actions")}
      <div class="desk">
${ringMarkup(320, 46)}
      </div>
${notes([
    ["Why", "Scales to any number of entries and gives channels their own ring of ten. Click a group, then its action; the centre goes back."],
    ["Against", "Two gestures for everything, including the action you use twenty times a day. Better for Action mode than for paste formats."],
  ])}`,
  `{${PROPS_BASE},${PROPS_RING_EXTRA},"$preview":{"width":520,"height":560}}`,
  cLogic));

// ---------- Direction D: tiles on a circle, no new renderer ----------
const dItems = [f("orig"), f("trim"), f("strip"), f("md"), f("sent"), f("common"), f("pretty", 1), more];

const dLogic = `  renderVals() {
    var p = this.pal(), st = this.state || {}, self = this;
    var items = ${JSON.stringify(dItems)};
    var CX = 170, CY = 170, RAD = 118, n = items.length, step = 360 / n;
    var hover = st.hover === undefined ? -1 : st.hover;
    var onLabel = st.on || 'Trim Formatting';
    var tiles = items.map(function (it, i) {
      var c = self.pt(CX, CY, RAD, i * step);
      var isHover = i === hover, isOn = it.label === onLabel && !it.more;
      return {
        label: it.short || it.label, key: it.key,
        style: 'left:' + (c[0] - 54) + 'px; top:' + (c[1] - 20) + 'px; width:108px; height:40px;'
          + 'background:' + (isHover ? p.accent : (isOn ? p.accentSoft : p.surface)) + ';'
          + 'color:' + (isHover ? p.accentText : p.text) + ';'
          + 'border-color:' + (isOn && !isHover ? p.accent : 'rgba(255,255,255,.08)') + ';'
          + 'box-shadow: 0 6px 16px rgba(0,0,0,.45);'
      };
    });
    var h = hover >= 0 ? items[hover] : null;
    return {
      vars: p.vars, tiles: tiles,
      wrapStyle: 'left: 50%; top: 50%; width: 340px; height: 340px; transform: translate(-50%, -50%);',
      hubStyle: 'left: 120px; top: 120px; width: 100px; height: 100px; border-radius: 50%; background:' + p.surface + '; border: 1px solid rgba(255,255,255,.10); box-shadow: 0 8px 22px rgba(0,0,0,.45);',
      hubTitle: h ? h.label : onLabel,
      hubTitleStyle: 'color:' + (h ? p.text : p.accent),
      hubSub: h ? h.desc : 'active format',
      hubKeys: 'release · click · Esc',
      move: function (e) { var t = self.aim(e, CX, CY, n); self.setState({ hover: t.dist < 54 ? -1 : t.idx }); },
      leave: function () { self.setState({ hover: -1 }); },
      pick: function (e) {
        var t = self.aim(e, CX, CY, n);
        if (t.dist < 54) return self.setState({ hover: -1 });
        var it = items[t.idx];
        if (!it.more) self.setState({ on: it.label });
      }
    };
  }`;

writeFileSync(join(here, "DirectionD.dc.html"), shell(520, 560,
  `${head("D · Tiles on a circle", "the same gesture with today's toolkit")}
      <div class="desk">
        <div class="tiles" style="{{wrapStyle}}" onMouseMove="{{move}}" onMouseLeave="{{leave}}" onClick="{{pick}}">
          <sc-for list="{{tiles}}" as="t" hint-placeholder-count="8">
            <div class="tile" style="{{t.style}}"><div>{{t.label}}</div><div class="k">{{t.key}}</div></div>
          </sc-for>
          <div class="hub" style="{{hubStyle}}">
            <div class="ht" style="{{hubTitleStyle}}">{{hubTitle}}</div>
            <div class="hs">{{hubSub}}</div>
            <div class="hk">{{hubKeys}}</div>
          </div>
        </div>
      </div>
${notes([
    ["Why", "No wedges, so no new renderer: eight opaque cards on a circle, drawn by the same code as the tray card, and selection is still by angle, so the flick feels identical."],
    ["Against", "The desktop shows between the tiles and the shape reads as a constellation rather than a ring. Hit areas are the tiles, so a short flick can fall short."],
  ])}`,
  `{${PROPS_BASE},"$preview":{"width":520,"height":560}}`,
  dLogic));

// ---------- Budget ----------
const row = (a, b) => `        <div class="note" style="color: var(--text);"><b>${a}</b><span style="color: var(--muted)">${b}</span></div>`;

writeFileSync(join(here, "Budget.dc.html"), shell(620, 560,
  `${head("Building A", "what the renderer can do, and what was decided")}
      <div style="flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; gap: 14px; overflow: hidden;">
        <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 20px;">
${row("A GDI+ layered window can", "Draw true arcs with antialiased edges and per-pixel alpha, so there is no rectangular window edge and the shadow is part of the bitmap. Hit testing is angle and radius arithmetic, so there are no dead gaps between wedges. Repainting the whole 320px bitmap on every pointer move costs well under a millisecond.")}
${row("It cannot", "Hold native controls, so no scrolling list and no text field inside the ring. Text is drawn by GDI+, which means grayscale antialiasing rather than the ClearType the card uses: fine at 11px and up, marginally softer. Every hover repaints the whole bitmap.")}
${row("Both gestures, one ring", "Hold the trigger and release over a wedge, or let go and click. The hub is the dead zone for both: release or click there and nothing happens. A minimum travel of about 30px stops a twitch from picking.")}
${row("Keyboard survives", "Every wedge keeps its letter, and the letters are the ones already assigned, so the list card and the ring stay interchangeable.")}
        </div>
        <div style="height: 1px; background: var(--border);"></div>
        <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 20px;">
${row("Decided", "The ring replaces the list: Z always opens it, and the letters still pick while it is open. It opens at the pointer, clamped to the monitor. The paste card dims to half behind it. Action mode opens its ring from Ctrl+Shift+A only. Wedges are 8px apart with 8px corners and show one short word each; the full name and a description appear in the hub on hover.")}
${row("Rough cost", "One renderer of about 300 lines (geometry, paint, hit test, input), shared by both rings, plus the two call sites. The list menus go; the help card and confirm prompts stay on the card.")}
        </div>
      </div>`,
  `{${PROPS_BASE},"$preview":{"width":620,"height":560}}`,
  `  renderVals() { return { vars: this.pal().vars }; }`));

// ---------- canvas ----------
const canvas = {
  pages: [{ id: "page-1", name: "Chosen" }, { id: "page-2", name: "Directions" }],
  artboards: [
    { file: "Main.dc.html", title: "A · Format ring", x: 0, y: 0, w: 560, h: 560, is_interactive: true, page: "page-1" },
    { file: "ActionRing.dc.html", title: "A · Action mode ring", x: 640, y: 0, w: 560, h: 560, is_interactive: true, page: "page-1" },
    { file: "Budget.dc.html", title: "Building A", x: 1280, y: 0, w: 620, h: 560, page: "page-1" },
    { file: "DirectionB.dc.html", title: "B · Two tracks", x: 0, y: 0, w: 580, h: 620, is_interactive: true, page: "page-2" },
    { file: "DirectionC.dc.html", title: "C · Two levels", x: 660, y: 0, w: 520, h: 560, is_interactive: true, page: "page-2" },
    { file: "DirectionD.dc.html", title: "D · Tiles on a circle", x: 1260, y: 0, w: 520, h: 560, is_interactive: true, page: "page-2" },
  ],
  annotations: [
    {
      id: "brief", x: 0, y: -170, w: 820, page: "page-1",
      text: "Chosen: A, the favorites ring. Seven entries that fit the moment are one flick away and never move; More flips to the rest.\nBoth boards are live - move the pointer over a ring and it follows your angle the way the real hit test would, clicking picks, and More turns the page. The kind tweak on the format ring shows it repopulating for a URL, JSON or plain text; the gap and corner tweaks set the even spacing between segments and their rounding.",
    },
    {
      id: "directions-note", x: 0, y: -130, w: 820, page: "page-2",
      text: "The alternatives, kept for reference: B shows all fourteen formats on two tracks, C drills through six groups, D is the same gesture built from the tray card's toolkit.",
    },
  ],
  launch: { view: "canvas", page: "page-1" },
};
writeFileSync(join(here, "canvas.json"), JSON.stringify(canvas, null, 2) + "\n");
console.log("wrote 6 artboards + canvas.json");
