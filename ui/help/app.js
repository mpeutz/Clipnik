// app.js - the Help window page. Topics are HTML fragments under topics/; the reference tables inside them
// are filled from the host's `reference` message.
const TOPICS = [
  "start", "tasks", "vault", "reference-pastemode", "reference-actionmode", "reference-formats", "reference-rules",
  "reference-settings", "reference-plugins", "reference-shortcuts", "trouble", "about",
];
const state = { topics: [], current: "", i18n: {}, reference: null, filter: "" };

async function loadTopics() {
  const out = [];
  for (const id of TOPICS) {
    try {
      const res = await fetch("topics/" + id + ".html");
      if (!res.ok) continue;
      const el = document.createElement("div");
      el.innerHTML = await res.text();
      const root = el.firstElementChild;
      if (!root) continue;
      out.push({ id, title: root.dataset.title || id, keywords: root.dataset.keywords || "", node: root });
    } catch (e) { /* a missing fragment just drops out of the list */ }
  }
  return out;
}

// (t.title + keywords + rendered text), lowercased and cached on the topic so repeated filtering is cheap
function topicText(t) {
  if (t._text === undefined) t._text = (t.title + " " + t.keywords + " " + t.node.textContent).toLowerCase();
  return t._text;
}

// how many times term occurs in text (plain substring count, no regex)
function countMatches(text, term) {
  if (!term) return 0;
  let n = 0, i = 0;
  for (;;) {
    const j = text.indexOf(term, i);
    if (j < 0) return n;
    n++;
    i = j + term.length;
  }
}

// topics to list for state.filter: {t, count}, count is null when there is no active filter
function filteredTopics() {
  if (!state.filter) return state.topics.map((t) => ({ t, count: null }));
  return state.topics
    .map((t) => ({ t, count: countMatches(topicText(t), state.filter) }))
    .filter((x) => x.count > 0);
}

function renderList() {
  const list = document.getElementById("list");
  list.textContent = "";
  const rows = filteredTopics();
  if (state.filter && !rows.length) {
    const p = document.createElement("div");
    p.className = "empty";
    p.textContent = state.i18n.HLP_noMatch || "No topic matches";
    list.appendChild(p);
    return;
  }
  for (const { t, count } of rows) {
    const b = document.createElement("button");
    b.textContent = t.title;
    b.dataset.id = t.id;
    if (t.id === state.current) b.className = "on";
    if (count != null) {
      const span = document.createElement("span");
      span.className = "count";
      span.textContent = count;
      b.appendChild(span);
    }
    b.addEventListener("click", () => show(t.id));
    list.appendChild(b);
  }
}

function show(id) {
  const t = state.topics.find((x) => x.id === id) || state.topics[0];
  if (!t) return;
  state.current = t.id;
  const doc = document.getElementById("doc");
  doc.textContent = "";
  doc.appendChild(t.node);
  doc.scrollTop = 0;
  fillReference(doc);
  renderList();
  highlight(state.filter);
}

// applies a new filter term: recomputes the list, jumps off a topic that dropped out, and re-highlights
function applyFilter(term) {
  state.filter = String(term || "").trim().toLowerCase();
  const rows = filteredTopics();
  if (rows.length && !rows.some((x) => x.t.id === state.current)) {
    show(rows[0].t.id);
    return;
  }
  renderList();
  highlight(state.filter);
}

// highlights every occurrence of term in the open topic using the CSS Custom Highlight API
function highlight(term) {
  if (!window.CSS || !CSS.highlights) return;
  CSS.highlights.delete("help-hit");
  if (!term) return;
  const doc = document.getElementById("doc");
  const walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT);
  const ranges = [];
  let node;
  while ((node = walker.nextNode())) {
    const text = node.data.toLowerCase();
    let i = 0;
    for (;;) {
      const j = text.indexOf(term, i);
      if (j < 0) break;
      const r = new Range();
      r.setStart(node, j);
      r.setEnd(node, j + term.length);
      ranges.push(r);
      i = j + term.length;
    }
  }
  if (ranges.length) CSS.highlights.set("help-hit", new Highlight(...ranges));
}

function fillReference(root) {
  if (!root || !state.reference) return;
  for (const el of root.querySelectorAll("[data-ref]")) {
    if (el.dataset.ref === "version") { el.textContent = state.reference.version || ""; continue; }
    const rows = table(el.dataset.ref);
    el.textContent = "";
    if (!rows || !rows.body.length) {
      const p = document.createElement("p");
      p.className = "empty";
      p.textContent = state.i18n.HLP_notAvailable || "Not available in this build";
      el.appendChild(p);
      continue;
    }
    el.appendChild(buildTable(rows.head, rows.body));
  }
}

function table(name) {
  const r = state.reference || {};
  const t = state.i18n;
  const head = (a, b) => [t[a] || a, t[b] || b];
  switch (name) {
    case "pasteMode":
      return { head: head("HLP_key", "HLP_action"), body: (r.pasteMode || []).map((x) => [kbd(x.key), x.caption]) };
    case "actions":
      return { head: head("HLP_key", "HLP_action"), body: (r.actions || []).map((x) => [kbd(x.key), x.label + (x.desc ? " — " + x.desc : "")]) };
    case "formats": {
      // r.rules.kinds carries {kind, label} for every clip kind; map a format's raw "text,code" id list
      // through those labels, falling back to the raw id when a kind has no label
      const kindLabels = new Map((r.rules && r.rules.kinds || []).map((k) => [k.kind, k.label]));
      const appliesTo = (kinds) => kinds
        ? kinds.split(",").map((k) => k.trim()).filter(Boolean).map((k) => kindLabels.get(k) || k).join(", ")
        : (t.HLP_everyClip || "Every clip");
      return {
        head: [t.HLP_key || "Key", t.HLP_format || "Format", t.HLP_appliesTo || "Applies to"],
        body: (r.formats || []).map((x) => [kbd(x.key), x.label + (x.desc ? " — " + x.desc : ""), appliesTo(x.kinds)]),
      };
    }
    case "hotkeys":
      return { head: head("HLP_shortcut", "HLP_description"), body: (r.hotkeys || []).map((x) => [kbd(x.keys), x.label]) };
    case "kinds":
      return { head: head("HLP_key", "HLP_description"), body: (r.rules && r.rules.kinds || []).map((k) => [k.kind, k.label]) };
    default:
      return null;
  }
}

function kbd(s) { const k = document.createElement("kbd"); k.textContent = s; return k; }

function buildTable(head, body) {
  const tbl = document.createElement("table");
  const thead = document.createElement("thead");
  const tr = document.createElement("tr");
  for (const h of head) { const th = document.createElement("th"); th.textContent = h; tr.appendChild(th); }
  thead.appendChild(tr);
  tbl.appendChild(thead);
  const tb = document.createElement("tbody");
  for (const row of body) {
    const r = document.createElement("tr");
    for (const cell of row) {
      const td = document.createElement("td");
      if (cell instanceof Node) td.appendChild(cell); else td.textContent = cell;
      r.appendChild(td);
    }
    tb.appendChild(r);
  }
  tbl.appendChild(tb);
  return tbl;
}

// links in a topic are external: hand them to the host's browser instead of navigating the page away
document.getElementById("doc").addEventListener("click", (e) => {
  const a = e.target.closest("a[href]");
  if (!a || !/^https?:/i.test(a.getAttribute("href"))) return;
  e.preventDefault();
  bridge.send("open", a.href);
});

bridge.on("i18n", (m) => {
  state.i18n = m || {};
  const q = document.getElementById("q");
  if (state.i18n.HLP_search) q.placeholder = state.i18n.HLP_search;
});
// every topic gets its generated tables filled here, not just the one on screen, so a term that lives only
// in a table (a hotkey, an action label, a format description) is searchable before its topic is ever opened
bridge.on("reference", (d) => {
  state.reference = d;
  for (const t of state.topics) { fillReference(t.node); t._text = undefined; }
});
// a deep link (Action Mode F1, Settings Help, the tray) must not land next to a stale filter or a no-match list
bridge.on("opened", (topic) => {
  if (!topic) return;
  state.filter = "";
  qEl.value = "";
  show(topic);
});
// test hook (see Help_Filter): applies a filter term sent from the host, same effect as typing it
bridge.on("filter", (term) => { qEl.value = term || ""; applyFilter(term); });
// test hook (see HelpWin_FilterProbe): reports how many topics the current filter lists and how many total hits
bridge.on("probe", () => {
  const rows = filteredTopics();
  const hits = rows.reduce((sum, x) => sum + (x.count || 0), 0);
  bridge.send("probe", "shown=" + rows.length + " hits=" + hits);
});
// test hook (see HelpWin_TopicProbe): reports the topic id currently on screen
bridge.on("topic", () => bridge.send("topic", state.current));

const qEl = document.getElementById("q");
qEl.addEventListener("input", cj.debounce(() => applyFilter(qEl.value), 120));

// the WebView2 child owns the keystroke while it has focus, so a Gui Escape event on the host never fires;
// catch it here instead, the same way History and Organizer do. A filter's first Escape clears the term
// (checked on state, not on which element has focus -- Help_Filter() sets it without moving DOM focus, so
// gating on focus would make the test hook flaky); an inactive filter sends `close` straight away.
document.addEventListener("keydown", (e) => {
  if (cj.hotkey(e) !== "Escape") return;
  if (qEl.value) { qEl.value = ""; applyFilter(""); } else { bridge.send("close"); }
  e.preventDefault();
});

bridge.whenReady(async () => {
  state.topics = await loadTopics();
  show(state.topics.length ? state.topics[0].id : "");
  bridge.send("ready");
});
