// Clipboard History page. State lives here; the host owns the data (see src/ui/web/HistoryWin.ahk).
(function () {
  const { el, esc, bytes, oneLine, debounce, hotkey, isTyping } = cj;
  const T = {
    HST_partial: "Partial", HST_exact: "Exact", HST_refresh: "Refresh", HST_clear: "Clear history…", HST_search: "Search history",
    HST_clip: "Clip", HST_date: "Date", HST_size: "Size", HST_copy: "Copy", HST_insta: "Insta-Paste", HST_hold: "Hold", HST_edit: "Edit",
    HST_export: "Export", HST_delete: "Delete", HST_empty: "Nothing copied yet", HST_noMatch: "No clips match", HST_items: "items",
    HST_match: "of %2 items match", HST_onDisk: "on disk", HST_sortedBy: "sorted by", HST_selectHint: "Select a clip to preview it",
    HST_viewimage: "[IMAGE]", HST_today: "Today", HST_yesterday: "Yesterday",
  };
  const state = { q: "", partial: true, sort: "time", asc: false, rows: [], sel: new Set(), anchor: null, focusId: null, preview: null };
  const rowsEl = el("rows"), tableEl = el("table"), qEl = el("q");

  function applyI18n() {
    document.querySelectorAll("[data-i18n]").forEach((n) => { const k = n.dataset.i18n; if (T[k]) n.textContent = T[k]; });
    qEl.placeholder = T.HST_search;
  }

  function fmtDate(s) {
    // "YYYY-MM-DD HH:MM:SS" from SQLite
    const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/.exec(s || "");
    if (!m) return s || "";
    const d = new Date(+m[1], +m[2] - 1, +m[3]);
    const now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diff = Math.round((today - d) / 86400000);
    const hm = m[4] + ":" + m[5];
    if (diff === 0) return T.HST_today + " " + hm;
    if (diff === 1) return T.HST_yesterday + " " + hm;
    if (diff < 7) return d.toLocaleDateString(undefined, { weekday: "short" }) + " " + hm;
    return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }) + " " + hm;
  }

  const rx = (w) => new RegExp(w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "ig");
  // escapes text and marks every search word
  const hlWords = (text, words) => words.reduce((acc, w) => acc.replace(rx(esc(w)), (m) => `<mark>${m}</mark>`), esc(text));
  const searchWords = () => { const q = state.q.trim(); return state.partial ? q.split(/\s+/).filter(Boolean) : (q ? [q] : []); };

  function requestList() {
    bridge.send("list", { q: state.q, partial: state.partial ? 1 : 0, sort: state.sort, asc: state.asc ? 1 : 0 });
  }

  function render() {
    const q = state.q.trim();
    const words = searchWords();
    if (!state.rows.length) {
      rowsEl.innerHTML = `<div class="empty">${esc(q ? T.HST_noMatch : T.HST_empty)}</div>`;
      return;
    }
    rowsEl.innerHTML = state.rows.map((r) => {
      const isImg = +r.type === 1;
      const text = isImg ? T.HST_viewimage : oneLine(r.clip, 220);
      const html = hlWords(text, words);
      return `<div class="tr${state.sel.has(r.id) ? " sel" : ""}" data-id="${r.id}" tabindex="-1" draggable="false">` +
        `<span class="mono${isImg ? " dim" : ""}">${html}</span><span class="dim">${esc(fmtDate(r.time))}</span><span class="dim">${bytes(r.size)}</span></div>`;
    }).join("");
    document.querySelectorAll("#hdr span").forEach((s) => {
      s.classList.toggle("sorted", s.dataset.sort === state.sort);
      s.classList.toggle("asc", s.dataset.sort === state.sort && state.asc);
    });
  }

  function renderStatus(d) {
    const q = state.q.trim();
    el("count").textContent = q ? `${d.matched} ${T.HST_match.replace("%2", d.total)}` : `${d.total} ${T.HST_items}`;
    const sortName = { clip: T.HST_clip, time: T.HST_date, size: T.HST_size }[state.sort];
    el("disk").textContent = `${bytes(d.bytes)} ${T.HST_onDisk} · ${T.HST_sortedBy} ${sortName.toLowerCase()}`;
  }

  function select(id, { add = false, range = false, focus = true } = {}) {
    if (range && state.anchor != null) {
      const ids = state.rows.map((r) => r.id);
      const a = ids.indexOf(state.anchor), b = ids.indexOf(id);
      if (a >= 0 && b >= 0) {
        state.sel = new Set(ids.slice(Math.min(a, b), Math.max(a, b) + 1));
      }
    } else if (add) {
      if (state.sel.has(id)) state.sel.delete(id); else state.sel.add(id);
      state.anchor = id;
    } else {
      state.sel = new Set([id]);
      state.anchor = id;
    }
    state.focusId = id;
    document.querySelectorAll(".tr").forEach((n) => n.classList.toggle("sel", state.sel.has(+n.dataset.id)));
    const n = rowsEl.querySelector(`.tr[data-id="${id}"]`);
    if (n) n.scrollIntoView({ block: "nearest" });
    if (focus) tableEl.focus({ preventScroll: true });
    if (state.sel.size === 1) bridge.send("get", id);
    else showPreview(null);
    updateButtons();
  }

  function updateButtons() {
    const one = state.sel.size === 1, any = state.sel.size > 0;
    const isImg = state.preview && +state.preview.type === 1;
    el("copy").disabled = !one;
    el("insta").disabled = !any;
    el("hold").disabled = !one || isImg;
    el("edit").disabled = !one;
    el("export").disabled = !one;
    el("delete").disabled = !any;
  }

  function showPreview(rec) {
    state.preview = rec;
    const ph = el("ph"), body = el("body");
    if (!rec) {
      ph.innerHTML = `<span class="dim">${esc(state.sel.size > 1 ? `${state.sel.size} ${T.HST_items}` : T.HST_selectHint)}</span>`;
      body.className = "body mono";
      body.innerHTML = "";
      updateButtons();
      return;
    }
    const isImg = +rec.type === 1;
    ph.innerHTML = `<span class="badge">${isImg ? "IMAGE" : "TEXT"}</span><span class="dim" style="font-size: 12px;">${bytes(rec.size)} · ${esc(fmtDate(rec.time))}</span>`;
    if (isImg) {
      body.className = "body image";
      body.innerHTML = `<img src="${esc(rec.url)}" alt="">`;
    } else {
      body.className = "body mono";
      body.innerHTML = hlWords(rec.data, searchWords());
    }
    updateButtons();
  }

  function act(name) {
    const ids = [...state.sel];
    if (!ids.length) return;
    if (name === "instaPaste" || name === "delete") bridge.send(name, ids);
    else if (ids.length === 1) bridge.send(name, ids[0]);
  }

  // ---------- events ----------
  bridge.on("i18n", (m) => { Object.assign(T, m || {}); applyI18n(); });
  bridge.on("list", (d) => {
    state.rows = (d.rows || []).map((r) => ({ ...r, id: +r.id, type: +r.type, size: +r.size }));
    if (d.partial != null) { state.partial = !!+d.partial; el("partial").classList.toggle("on", state.partial); el("exact").classList.toggle("on", !state.partial); }
    const ids = new Set(state.rows.map((r) => r.id));
    state.sel = new Set([...state.sel].filter((id) => ids.has(id)));
    render();
    renderStatus(d);
    if (state.sel.size === 1) bridge.send("get", [...state.sel][0]);
    else showPreview(null);
  });
  bridge.on("preview", (rec) => { rec.id = +rec.id; if (state.sel.size === 1 && state.sel.has(rec.id)) showPreview(rec); });
  bridge.on("toast", (t) => cj.toast(t));
  bridge.on("refreshed", requestList);

  qEl.addEventListener("input", debounce(() => { state.q = qEl.value; requestList(); }, 120));
  el("partial").addEventListener("click", () => { state.partial = true; el("partial").classList.add("on"); el("exact").classList.remove("on"); bridge.send("setPartial", 1); requestList(); });
  el("exact").addEventListener("click", () => { state.partial = false; el("exact").classList.add("on"); el("partial").classList.remove("on"); bridge.send("setPartial", 0); requestList(); });
  el("refresh").addEventListener("click", requestList);
  el("clear").addEventListener("click", () => bridge.send("clear"));
  el("hdr").addEventListener("click", (e) => {
    const s = e.target.closest("[data-sort]");
    if (!s) return;
    if (state.sort === s.dataset.sort) state.asc = !state.asc; else { state.sort = s.dataset.sort; state.asc = s.dataset.sort === "clip"; }
    requestList();
  });
  rowsEl.addEventListener("mousedown", (e) => {
    const tr = e.target.closest(".tr");
    if (!tr) return;
    select(+tr.dataset.id, { add: e.ctrlKey, range: e.shiftKey });
  });
  rowsEl.addEventListener("dblclick", (e) => { if (e.target.closest(".tr")) act("instaPaste"); });
  document.querySelector(".actions").addEventListener("click", (e) => {
    const b = e.target.closest("[data-act]");
    if (b) act(b.dataset.act);
  });

  document.addEventListener("keydown", (e) => {
    const k = hotkey(e);
    if (k === "Escape") { if (isTyping(e) && qEl.value) { qEl.value = ""; state.q = ""; requestList(); } else bridge.send("close"); e.preventDefault(); return; }
    if (k === "Ctrl+F" || k === "Alt+D") { qEl.focus(); qEl.select(); e.preventDefault(); return; }
    if (k === "F5") { requestList(); e.preventDefault(); return; }
    if (isTyping(e) && !["ArrowDown", "ArrowUp", "Enter"].includes(e.key)) return;
    const ids = state.rows.map((r) => r.id);
    const i = ids.indexOf(state.focusId);
    switch (k) {
      case "ArrowDown": case "Shift+ArrowDown": if (ids.length) select(ids[Math.min(ids.length - 1, i + 1)], { range: e.shiftKey }); e.preventDefault(); break;
      case "ArrowUp": case "Shift+ArrowUp": if (ids.length) select(ids[Math.max(0, i - 1)], { range: e.shiftKey }); e.preventDefault(); break;
      case "Home": if (ids.length) select(ids[0]); e.preventDefault(); break;
      case "End": if (ids.length) select(ids[ids.length - 1]); e.preventDefault(); break;
      case "Ctrl+A": state.sel = new Set(ids); document.querySelectorAll(".tr").forEach((n) => n.classList.add("sel")); showPreview(null); e.preventDefault(); break;
      case "Ctrl+C": act("copy"); e.preventDefault(); break;
      case "Space": case "Enter": act("instaPaste"); e.preventDefault(); break;
      case "Alt+C": act("hold"); e.preventDefault(); break;
      case "Ctrl+H": act("edit"); e.preventDefault(); break;
      case "Ctrl+E": act("export"); e.preventDefault(); break;
      case "Delete": act("delete"); e.preventDefault(); break;
    }
  });

  bridge.whenReady(() => {
    applyI18n();
    updateButtons();
    bridge.send("ready");
    qEl.focus();
  });
})();
