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
  // popup menu near an anchor element or at {x, y}; items: [{id, label, key, sep, head}]; onPick(id)
  menu(where, items, onPick) {
    this.closeMenu();
    const m = document.createElement("div");
    m.className = "menu";
    m.innerHTML = items.map((it) => it.sep ? `<div class="sep"></div>` : it.head ? `<div class="mh">${this.esc(it.head)}</div>` :
      `<div class="mi" data-id="${this.esc(it.id)}"><span>${this.esc(it.label)}</span>${it.key ? `<span class="k">${this.esc(it.key)}</span>` : ""}</div>`).join("");
    document.body.appendChild(m);
    const r = where instanceof Element ? where.getBoundingClientRect() : { left: where.x, right: where.x, bottom: where.y };
    let x = r.right - m.offsetWidth, y = r.bottom + 4;
    if (x < 4) x = r.left;
    if (y + m.offsetHeight > window.innerHeight - 4) y = Math.max(4, r.bottom - m.offsetHeight - 4 - (where instanceof Element ? r.height : 0));
    m.style.left = x + "px"; m.style.top = y + "px";
    m.addEventListener("click", (e) => { const mi = e.target.closest(".mi"); if (mi) { this.closeMenu(); onPick(mi.dataset.id); } });
    const away = (e) => { if (!m.contains(e.target)) this.closeMenu(); };
    const key = (e) => { if (e.key === "Escape") { this.closeMenu(); e.stopPropagation(); } };
    setTimeout(() => { document.addEventListener("mousedown", away, true); document.addEventListener("keydown", key, true); }, 0);
    m._off = () => { document.removeEventListener("mousedown", away, true); document.removeEventListener("keydown", key, true); };
    this._menu = m;
  },
  closeMenu() { if (this._menu) { this._menu._off(); this._menu.remove(); this._menu = null; } },
};
