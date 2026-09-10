// util.js - small helpers shared by the pages
window.cj = {
  esc(s) { return String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); },
  // escapes and wraps every match of q in <mark>
  hl(s, q) {
    s = String(s ?? "");
    if (!q) return this.esc(s);
    const out = [];
    let i = 0;
    const lower = s.toLowerCase(), ql = q.toLowerCase();
    for (;;) {
      const j = lower.indexOf(ql, i);
      if (j < 0) { out.push(this.esc(s.slice(i))); break; }
      out.push(this.esc(s.slice(i, j)), "<mark>", this.esc(s.slice(j, j + q.length)), "</mark>");
      i = j + q.length;
    }
    return out.join("");
  },
  bytes(n) { n = +n || 0; return n < 1024 ? n + " B" : n < 1048576 ? (n / 1024).toFixed(1) + " KB" : (n / 1048576).toFixed(1) + " MB"; },
  oneLine(s, max = 200) { s = String(s ?? "").replace(/\s+/g, " ").trim(); return s.length > max ? s.slice(0, max) + "…" : s; },
  el(id) { return document.getElementById(id); },
  toast(text, ms = 1500) {
    let t = document.querySelector(".toast");
    if (!t) { t = document.createElement("div"); t.className = "toast"; document.body.appendChild(t); }
    t.textContent = text;
    t.hidden = false;
    clearTimeout(t._h);
    t._h = setTimeout(() => (t.hidden = true), ms);
  },
  debounce(fn, ms) { let h; return (...a) => { clearTimeout(h); h = setTimeout(() => fn(...a), ms); }; },
  // "Ctrl+Shift+F" style name for a keyboard event
  hotkey(e) {
    const p = [];
    if (e.ctrlKey) p.push("Ctrl");
    if (e.altKey) p.push("Alt");
    if (e.shiftKey) p.push("Shift");
    let k = e.key;
    if (k === " ") k = "Space";
    if (k.length === 1) k = k.toUpperCase();
    p.push(k);
    return p.join("+");
  },
  isTyping(e) { const t = e.target; return t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable); },
  // small badge for a clip kind; nothing for plain text or unknown
  kindBadge(kind, labels) {
    if (!kind || kind === "text") return "";
    const label = (labels && labels[kind]) || kind.toUpperCase();
    return `<span class="badge kind">${this.esc(label)}</span>`;
  },
};
