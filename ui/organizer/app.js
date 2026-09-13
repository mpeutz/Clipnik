// Channel Organizer page (see src/ui/web/OrganizerWin.ahk for the protocol). Clip n = display number, 1 is newest.
(function () {
  const { el, esc, oneLine, debounce, hotkey, isTyping } = cj;
  const T = {
    ORG_search: "Search clips", ORG_NewClip: "New clip", ORG_newChannel: "New channel", ORG_chooseCh: "Active channel", ORG_channels: "Channels",
    ORG_clip: "Clip", ORG_tags: "Tags", ORG_fixed: "Fixed", ORG_insta: "Insta-Paste", ORG_openPst: "Paste mode", ORG_editBtn: "Edit",
    ORG_moveTo: "Move to…", ORG_copyTo: "Copy to…", ORG_delete: "Delete", ORG_moveUp: "Move up", ORG_moveDown: "Move down",
    ORG_countStatus: "items listed", ORG_selectHint: "Select a clip", ORG_moveTitle: "Move %1 to", ORG_copyTitle: "Copy %1 to",
    ORG_moveBtn: "Move", ORG_copyBtn: "Copy", ORG_delChTitle: "Delete channel %1", ORG_delChText: "%1 clips are in this channel. What should happen to them?",
    ORG_delChMove: "Move them to another channel", ORG_delChDelete: "Delete the clips too", ORG_delChEmpty: "Keep the channel, delete the clips",
    ORG_renameTitle: "Rename channel %1", ORG_renameBtn: "Rename", ORG_newChTitle: "New channel", ORG_createBtn: "Create",
    ORG_footHint: "Double-click to use · F2 renames · Drag clips here to move", ORG_channelStatus: "Channel", ORG_clipOf: "clip %1 of %2",
    HST_viewimage: "[IMAGE]", HST_actions: "Actions", SET_cancel: "Cancel", _rename: "Rename", _new: "New",
  };
  const state = { channels: [], active: 0, channel: 0, chSel: 0, rows: [], sel: new Set(), anchor: null, focusN: null, clip: null, q: "", pane: "clips", labels: {}, actionsByKind: {} };
  const rowsEl = el("rows"), tableEl = el("table"), chEl = el("channels"), qEl = el("q"), sheet = el("sheet");
  const chName = (n) => { const c = state.channels.find((x) => x.n === n); return c ? c.name : String(n); };
  const chLabel = (n) => `${n} - ${chName(n)}`;

  function applyI18n() {
    document.querySelectorAll("[data-i18n]").forEach((n) => { const k = n.dataset.i18n; if (T[k]) n.textContent = T[k]; });
    qEl.placeholder = T.ORG_search;
    el("up").title = T.ORG_moveUp; el("down").title = T.ORG_moveDown; el("addChannel").title = T.ORG_newChannel;
  }

  // ---------- channels ----------
  function renderChannels() {
    chEl.innerHTML = state.channels.map((c) =>
      `<div class="ch${c.n === state.chSel ? " sel" : ""}${c.n === state.active ? " active" : ""}" data-n="${c.n}" title="${esc(c.name)}"><span class="n">${c.n}</span><span class="name">${esc(c.name)}</span><span class="cnt">${c.count}</span></div>`).join("");
    const sel = el("active");
    sel.innerHTML = state.channels.map((c) => `<option value="${c.n}"${c.n === state.active ? " selected" : ""}>${esc(chLabel(c.n))}</option>`).join("");
    el("chstatus").textContent = `${T.ORG_channelStatus} ${chLabel(state.channel)}`;
  }

  function selectChannel(n, load = true) {
    state.chSel = n;
    if (load && n !== state.channel) {
      state.channel = n;
      state.sel = new Set(); state.focusN = null; state.clip = null;
      bridge.send("clips", n);
    }
    renderChannels();
    el("chstatus").textContent = `${T.ORG_channelStatus} ${chLabel(state.channel)}`;
  }

  // ---------- clips ----------
  function visibleRows() {
    const q = state.q.trim().toLowerCase();
    if (!q) return state.rows;
    return state.rows.filter((r) => (r.clip + " " + (r.tags || "")).toLowerCase().includes(q));
  }

  function renderClips() {
    const rows = visibleRows();
    rowsEl.innerHTML = rows.map((r) => {
      const isImg = +r.type === 1;
      const tags = (r.tags || "").split(/\s+/).filter(Boolean).map((t) => `<span class="badge">${esc(t)}</span>`).join(" ");
      return `<div class="tr${state.sel.has(r.n) ? " sel" : ""}" data-n="${r.n}" draggable="true"><span class="dim">${r.n}</span><span class="mono${isImg ? " dim" : ""}">${esc(isImg ? T.HST_viewimage : oneLine(r.clip, 220))}</span><span>${isImg ? "" : cj.kindBadge(r.kind, state.labels)} ${tags}${+r.fixed ? ' <span class="badge accent">' + esc(T.ORG_fixed.toLowerCase()) + "</span>" : ""}</span></div>`;
    }).join("");
    el("count").textContent = `${rows.length} ${T.ORG_countStatus}`;
    updateButtons();
  }

  function selectClip(n, { add = false, range = false } = {}) {
    const ns = visibleRows().map((r) => r.n);
    if (range && state.anchor != null) {
      const a = ns.indexOf(state.anchor), b = ns.indexOf(n);
      if (a >= 0 && b >= 0) state.sel = new Set(ns.slice(Math.min(a, b), Math.max(a, b) + 1));
    } else if (add) {
      if (state.sel.has(n)) state.sel.delete(n); else state.sel.add(n);
      state.anchor = n;
    } else {
      state.sel = new Set([n]);
      state.anchor = n;
    }
    state.focusN = n;
    state.pane = "clips";
    document.querySelectorAll(".tr").forEach((x) => x.classList.toggle("sel", state.sel.has(+x.dataset.n)));
    const node = rowsEl.querySelector(`.tr[data-n="${n}"]`);
    if (node) node.scrollIntoView({ block: "nearest" });
    if (state.sel.size === 1) bridge.send("getClip", { channel: state.channel, n });
    else showClip(null);
    updateButtons();
  }

  function updateButtons() {
    const one = state.sel.size === 1, any = state.sel.size > 0;
    document.querySelectorAll("[data-act]").forEach((b) => {
      const a = b.dataset.act;
      b.disabled = a === "paste" || a === "delete" || a === "moveTo" || a === "copyTo" ? !any : !one;
    });
    const n = one ? [...state.sel][0] : null;
    el("up").disabled = !one || n <= 1;
    el("down").disabled = !one || n >= state.rows.length;
  }

  function showClip(c) {
    state.clip = c;
    const ph = el("ph").firstElementChild, body = el("body"), props = el("props");
    if (!c) {
      ph.className = "dim";
      ph.textContent = state.sel.size > 1 ? `${state.sel.size} ${T.ORG_countStatus}` : T.ORG_selectHint;
      body.className = "body mono"; body.innerHTML = "";
      props.hidden = true;
      updateButtons();
      return;
    }
    const isImg = +c.type === 1;
    const acts = state.actionsByKind[c.kind] || [];
    const dims = isImg && c.dim ? `${esc(c.dim.replace("x", "×"))} · ` : "";
    ph.className = "";
    ph.innerHTML = `${isImg ? '<span class="badge">IMAGE</span>' : cj.kindBadge(c.kind, state.labels) || '<span class="badge">TEXT</span>'}${+c.fixed ? ' <span class="badge accent">' + esc(T.ORG_fixed.toLowerCase()) + "</span>" : ""} <span class="dim" style="font-size: 12px;">${dims}${esc(T.ORG_clipOf.replace("%1", c.n).replace("%2", state.rows.length))}</span>` +
      (acts.length ? `<button class="btn" id="actions" style="height: 24px; margin-left: 8px;">${esc(T.HST_actions)} ▾</button>` : "");
    if (acts.length) el("actions").addEventListener("click", () => cj.menu(el("actions"), [{ head: state.labels[c.kind] || c.kind }, ...acts.map((a) => ({ id: a.id, label: a.label }))], (id) => bridge.send("action", { channel: state.channel, n: c.n, action: id })));
    if (isImg) { body.className = "body image"; body.innerHTML = `<img src="${esc(c.url)}" alt="">`; }
    else { body.className = "body mono"; body.textContent = c.data; }
    props.hidden = false;
    el("tags").value = c.tags || "";
    el("fixed").checked = !!+c.fixed;
    updateButtons();
  }

  function saveProps() {
    const c = state.clip;
    if (!c) return;
    const tags = el("tags").value.trim(), fixed = el("fixed").checked ? 1 : 0;
    if (tags === (c.tags || "").trim() && fixed === (+c.fixed ? 1 : 0)) return;
    c.tags = tags; c.fixed = fixed;
    bridge.send("setProps", { channel: state.channel, n: c.n, tags, fixed });
  }

  // ---------- cards ----------
  function openCard(html, onOpen) {
    sheet.innerHTML = `<div class="card">${html}</div>`;
    sheet.hidden = false;
    if (onOpen) onOpen(sheet.firstElementChild);
    sheet.querySelector("[data-cancel]")?.addEventListener("click", closeCard);
  }
  function closeCard() { sheet.hidden = true; sheet.innerHTML = ""; tableEl.focus({ preventScroll: true }); }

  function pickChannel(copy) {
    const ns = [...state.sel];
    if (!ns.length) return;
    const others = state.channels.filter((c) => copy || c.n !== state.channel);
    const label = ns.length === 1 ? `clip ${ns[0]}` : `${ns.length} clips`;
    let chosen = others.length ? others[0].n : null;
    openCard(`
      <div class="h">${esc((copy ? T.ORG_copyTitle : T.ORG_moveTitle).replace("%1", label))}</div>
      <div class="list">${others.map((c) => `<div class="ch${c.n === chosen ? " sel" : ""}" data-n="${c.n}"><span class="n">${c.n}</span><span class="name">${esc(c.name)}</span><span class="cnt">${c.count}</span></div>`).join("")}
        <div class="ch newch" data-newch="1"><svg style="width: 14px; height: 14px;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="M12 5v14"/></svg><span>${esc(T.ORG_newChannel)}…</span></div></div>
      <div class="footer"><button class="btn primary" data-ok>${esc(copy ? T.ORG_copyBtn : T.ORG_moveBtn)}</button><button class="btn" data-cancel>${esc(T.SET_cancel)}</button></div>`, (card) => {
      const go = () => { if (chosen == null) return; bridge.send("transfer", { channel: state.channel, ns, to: chosen, copy: copy ? 1 : 0 }); closeCard(); };
      card.querySelector(".list").addEventListener("click", (e) => {
        const ch = e.target.closest(".ch");
        if (!ch) return;
        if (ch.dataset.newch) { closeCard(); newChannelCard(() => pickChannel(copy)); return; }
        chosen = +ch.dataset.n;
        card.querySelectorAll(".ch").forEach((x) => x.classList.toggle("sel", +x.dataset.n === chosen));
      });
      card.querySelector(".list").addEventListener("dblclick", (e) => { if (e.target.closest(".ch[data-n]")) go(); });
      card.querySelector("[data-ok]").addEventListener("click", go);
      card.querySelector("[data-ok]").disabled = chosen == null;
      card.querySelector("[data-ok]").focus();
    });
  }

  function newChannelCard(after) {
    openCard(`
      <div class="h">${esc(T.ORG_newChTitle)}</div>
      <div class="p"><input class="edit" id="newname" type="text" spellcheck="false"></div>
      <div class="footer"><button class="btn primary" data-ok>${esc(T.ORG_createBtn)}</button><button class="btn" data-cancel>${esc(T.SET_cancel)}</button></div>`, (card) => {
      const inp = card.querySelector("#newname");
      const go = () => { bridge.send("newChannel", inp.value.trim()); closeCard(); if (after) setTimeout(after, 250); };
      card.querySelector("[data-ok]").addEventListener("click", go);
      inp.addEventListener("keydown", (e) => { if (e.key === "Enter") go(); });
      inp.focus();
    });
  }

  function renameCard() {
    const n = state.chSel;
    openCard(`
      <div class="h">${esc(T.ORG_renameTitle.replace("%1", n))}</div>
      <div class="p"><input class="edit" id="rename" type="text" spellcheck="false" value="${esc(chName(n))}"></div>
      <div class="footer"><button class="btn primary" data-ok>${esc(T.ORG_renameBtn)}</button><button class="btn" data-cancel>${esc(T.SET_cancel)}</button></div>`, (card) => {
      const inp = card.querySelector("#rename");
      const go = () => { if (inp.value.trim()) bridge.send("renameChannel", { n, name: inp.value.trim() }); closeCard(); };
      card.querySelector("[data-ok]").addEventListener("click", go);
      inp.addEventListener("keydown", (e) => { if (e.key === "Enter") go(); });
      inp.focus(); inp.select();
    });
  }

  function deleteChannelCard() {
    const n = state.chSel;
    if (n < 1) return;
    const c = state.channels.find((x) => x.n === n);
    const others = state.channels.filter((x) => x.n !== n);
    openCard(`
      <div class="h">${esc(T.ORG_delChTitle.replace("%1", chLabel(n)))}</div>
      <div class="p dim">${esc(T.ORG_delChText.replace("%1", c ? c.count : 0))}</div>
      <label class="radio"><input type="radio" name="mode" value="move" checked><span>${esc(T.ORG_delChMove)}</span><select class="edit" id="to" style="width: 150px; margin-left: auto;">${others.map((x) => `<option value="${x.n}">${esc(chLabel(x.n))}</option>`).join("")}</select></label>
      <label class="radio"><input type="radio" name="mode" value="delete"><span>${esc(T.ORG_delChDelete)}</span></label>
      <label class="radio"><input type="radio" name="mode" value="empty"><span>${esc(T.ORG_delChEmpty)}</span></label>
      <div class="footer"><button class="btn primary" data-ok>${esc(T.ORG_delete)}</button><button class="btn" data-cancel>${esc(T.SET_cancel)}</button></div>`, (card) => {
      card.querySelector("[data-ok]").addEventListener("click", () => {
        const mode = card.querySelector("input[name=mode]:checked").value;
        bridge.send("deleteChannel", { n, mode, to: +card.querySelector("#to").value });
        closeCard();
      });
    });
  }

  function act(name) {
    const ns = [...state.sel];
    switch (name) {
      case "paste": if (ns.length) bridge.send("paste", { channel: state.channel, ns }); break;
      case "delete": if (ns.length) bridge.send("deleteClips", { channel: state.channel, ns }); break;
      case "moveTo": pickChannel(false); break;
      case "copyTo": pickChannel(true); break;
      case "pasteMode": if (ns.length === 1) bridge.send("pasteMode", { channel: state.channel, n: ns[0] }); break;
      case "edit": if (ns.length === 1) bridge.send("edit", { channel: state.channel, n: ns[0] }); break;
    }
  }

  function moveClip(delta) {
    if (state.sel.size !== 1) return;
    const n = [...state.sel][0], m = n + delta;
    if (m < 1 || m > state.rows.length) return;
    state.sel = new Set([m]); state.anchor = m; state.focusN = m;
    bridge.send("move", { channel: state.channel, n, delta });
  }

  // ---------- host events ----------
  bridge.on("i18n", (m) => {
    Object.assign(T, m || {});
    state.labels = Object.fromEntries(Object.keys(T).filter((k) => k.startsWith("KIND_")).map((k) => [k.slice(5), T[k].toUpperCase()]));
    applyI18n();
  });
  bridge.on("actions", (d) => { state.actionsByKind = d || {}; });
  bridge.on("channels", (d) => {
    state.channels = (d.channels || []).map((c) => ({ ...c, n: +c.n, count: +c.count }));
    state.active = +d.active;
    if (!state.channels.some((c) => c.n === state.channel)) { state.channel = state.active; state.chSel = state.active; bridge.send("clips", state.channel); }
    if (!state.channels.some((c) => c.n === state.chSel)) state.chSel = state.channel;
    renderChannels();
  });
  bridge.on("clips", (d) => {
    if (+d.channel !== state.channel) return;
    state.rows = (d.rows || []).map((r) => ({ ...r, n: +r.n, type: +r.type, fixed: +r.fixed }));
    const ns = new Set(state.rows.map((r) => r.n));
    state.sel = new Set([...state.sel].filter((n) => ns.has(n)));
    renderClips();
    if (state.sel.size === 1) bridge.send("getClip", { channel: state.channel, n: [...state.sel][0] });
    else showClip(null);
  });
  bridge.on("clip", (c) => { c.n = +c.n; c.channel = +c.channel; if (c.channel === state.channel && state.sel.size === 1 && state.sel.has(c.n)) showClip(c); });
  bridge.on("toast", (t) => cj.toast(t));
  bridge.on("refresh", () => { bridge.send("channels"); bridge.send("clips", state.channel); });

  // ---------- page events ----------
  el("newClip").addEventListener("click", () => bridge.send("newClip", state.chSel));
  el("newChannel").addEventListener("click", () => newChannelCard());
  el("addChannel").addEventListener("click", () => newChannelCard());
  el("active").addEventListener("change", (e) => bridge.send("useChannel", +e.target.value));
  qEl.addEventListener("input", debounce(() => { state.q = qEl.value; renderClips(); }, 80));
  chEl.addEventListener("mousedown", (e) => { const ch = e.target.closest(".ch"); if (ch) { state.pane = "channels"; selectChannel(+ch.dataset.n); } });
  chEl.addEventListener("dblclick", (e) => { const ch = e.target.closest(".ch"); if (ch) bridge.send("useChannel", +ch.dataset.n); });
  rowsEl.addEventListener("mousedown", (e) => { const tr = e.target.closest(".tr"); if (tr && e.button === 0) selectClip(+tr.dataset.n, { add: e.ctrlKey, range: e.shiftKey }); });
  rowsEl.addEventListener("dblclick", (e) => { if (e.target.closest(".tr")) act("paste"); });
  rowsEl.addEventListener("contextmenu", (e) => {
    const tr = e.target.closest(".tr");
    if (!tr) return;
    e.preventDefault();
    const n = +tr.dataset.n;
    if (!state.sel.has(n)) selectClip(n);
    const row = state.rows.find((r) => r.n === n);
    const acts = row ? (state.actionsByKind[row.kind] || []).map((a) => ({ id: "act:" + a.id, label: a.label })) : [];
    const items = [...(acts.length ? [{ head: state.labels[row.kind] || row.kind }, ...acts, { sep: true }] : []),
      { id: "paste", label: T.ORG_insta, key: "Space" }, { id: "edit", label: T.ORG_editBtn, key: "F2" }, { id: "delete", label: T.ORG_delete, key: "Del" }];
    cj.menu({ x: e.clientX, y: e.clientY }, items, (pick) => pick.startsWith("act:") ? bridge.send("action", { channel: state.channel, n, action: pick.slice(4) }) : act(pick));
  });
  document.querySelector(".actions").addEventListener("click", (e) => { const b = e.target.closest("[data-act]"); if (b) act(b.dataset.act); });
  el("up").addEventListener("click", () => moveClip(-1));
  el("down").addEventListener("click", () => moveClip(1));
  el("tags").addEventListener("change", saveProps);
  el("tags").addEventListener("keydown", (e) => { if (e.key === "Enter") { saveProps(); tableEl.focus(); } e.stopPropagation(); });
  el("fixed").addEventListener("change", saveProps);
  sheet.addEventListener("mousedown", (e) => { if (e.target === sheet) closeCard(); });

  // drag clips onto a channel: move, or copy with Ctrl
  rowsEl.addEventListener("dragstart", (e) => {
    const tr = e.target.closest(".tr");
    if (!tr) return;
    const n = +tr.dataset.n;
    if (!state.sel.has(n)) selectClip(n);
    e.dataTransfer.setData("text/plain", [...state.sel].join(","));
    e.dataTransfer.effectAllowed = "copyMove";
    tr.classList.add("drag");
  });
  rowsEl.addEventListener("dragend", (e) => { const tr = e.target.closest(".tr"); if (tr) tr.classList.remove("drag"); });
  chEl.addEventListener("dragover", (e) => {
    const ch = e.target.closest(".ch");
    if (!ch || +ch.dataset.n === state.channel) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = e.ctrlKey ? "copy" : "move";
    chEl.querySelectorAll(".ch").forEach((x) => x.classList.toggle("drop", x === ch));
  });
  chEl.addEventListener("dragleave", (e) => { if (!chEl.contains(e.relatedTarget)) chEl.querySelectorAll(".ch").forEach((x) => x.classList.remove("drop")); });
  chEl.addEventListener("drop", (e) => {
    const ch = e.target.closest(".ch");
    chEl.querySelectorAll(".ch").forEach((x) => x.classList.remove("drop"));
    if (!ch) return;
    e.preventDefault();
    const ns = e.dataTransfer.getData("text/plain").split(",").map(Number).filter(Boolean);
    if (ns.length) bridge.send("transfer", { channel: state.channel, ns, to: +ch.dataset.n, copy: e.ctrlKey ? 1 : 0 });
  });

  document.addEventListener("keydown", (e) => {
    const k = hotkey(e);
    if (!sheet.hidden) { if (k === "Escape") { closeCard(); e.preventDefault(); } return; }
    if (k === "Escape") { if (isTyping(e) && qEl.value) { qEl.value = ""; state.q = ""; renderClips(); } else bridge.send("close"); e.preventDefault(); return; }
    if (k === "Ctrl+F" || k === "Alt+D") { qEl.focus(); qEl.select(); e.preventDefault(); return; }
    if (k === "Ctrl+N") { bridge.send("newClip", state.chSel); e.preventDefault(); return; }
    if (k === "F5") { bridge.send("channels"); bridge.send("clips", state.channel); e.preventDefault(); return; }
    if (isTyping(e) && !["ArrowDown", "ArrowUp", "Enter"].includes(e.key)) return;
    if (state.pane === "channels") {
      const ns = state.channels.map((c) => c.n), i = ns.indexOf(state.chSel);
      switch (k) {
        case "ArrowDown": if (i < ns.length - 1) selectChannel(ns[i + 1]); e.preventDefault(); return;
        case "ArrowUp": if (i > 0) selectChannel(ns[i - 1]); e.preventDefault(); return;
        case "Alt+ArrowUp": if (state.chSel > 1) bridge.send("moveChannel", { n: state.chSel, delta: -1 }); e.preventDefault(); return;
        case "Alt+ArrowDown": if (state.chSel >= 1) bridge.send("moveChannel", { n: state.chSel, delta: 1 }); e.preventDefault(); return;
        case "F2": renameCard(); e.preventDefault(); return;
        case "Delete": deleteChannelCard(); e.preventDefault(); return;
        case "Enter": bridge.send("useChannel", state.chSel); e.preventDefault(); return;
        case "ArrowRight": case "Tab": state.pane = "clips"; tableEl.focus(); e.preventDefault(); return;
      }
      return;
    }
    const ns = visibleRows().map((r) => r.n), i = ns.indexOf(state.focusN);
    switch (k) {
      case "ArrowDown": case "Shift+ArrowDown": if (ns.length) selectClip(ns[Math.min(ns.length - 1, i + 1)], { range: e.shiftKey }); e.preventDefault(); break;
      case "ArrowUp": case "Shift+ArrowUp": if (ns.length) selectClip(ns[Math.max(0, i - 1)], { range: e.shiftKey }); e.preventDefault(); break;
      case "ArrowLeft": state.pane = "channels"; chEl.focus(); e.preventDefault(); break;
      case "Home": if (ns.length) selectClip(ns[0]); e.preventDefault(); break;
      case "End": if (ns.length) selectClip(ns[ns.length - 1]); e.preventDefault(); break;
      case "Ctrl+A": state.sel = new Set(ns); renderClips(); showClip(null); e.preventDefault(); break;
      case "Alt+ArrowUp": moveClip(-1); e.preventDefault(); break;
      case "Alt+ArrowDown": moveClip(1); e.preventDefault(); break;
      case "Space": case "Enter": act("paste"); e.preventDefault(); break;
      case "Ctrl+O": act("pasteMode"); e.preventDefault(); break;
      case "F2": act("edit"); e.preventDefault(); break;
      case "Alt+X": act("moveTo"); e.preventDefault(); break;
      case "Alt+C": act("copyTo"); e.preventDefault(); break;
      case "Delete": act("delete"); e.preventDefault(); break;
    }
  });
  chEl.addEventListener("focus", () => { state.pane = "channels"; });
  tableEl.addEventListener("focus", () => { state.pane = "clips"; });

  bridge.whenReady(() => {
    applyI18n();
    updateButtons();
    showClip(null);
    bridge.send("ready");
    tableEl.focus();
  });
})();
