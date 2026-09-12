// app.js - the Help window page. Topics are HTML fragments under topics/; the reference tables inside them
// are filled from the host's `reference` message.
const TOPICS = [
  "start", "tasks", "reference-pastemode", "reference-actionmode", "reference-formats", "reference-rules",
  "reference-settings", "reference-plugins", "reference-shortcuts", "trouble", "about",
];
const state = { topics: [], current: "", i18n: {}, reference: null };

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

function renderList() {
  const list = document.getElementById("list");
  list.textContent = "";
  for (const t of state.topics) {
    const b = document.createElement("button");
    b.textContent = t.title;
    b.dataset.id = t.id;
    if (t.id === state.current) b.className = "on";
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
}

function fillReference(root) {
  if (!root || !state.reference) return;
  for (const el of root.querySelectorAll("[data-ref]")) {
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
    case "formats":
      return {
        head: [t.HLP_key || "Key", t.HLP_format || "Format", t.HLP_appliesTo || "Applies to"],
        body: (r.formats || []).map((x) => [kbd(x.key), x.label + (x.desc ? " — " + x.desc : ""), x.kinds || "every clip"]),
      };
    case "hotkeys":
      return { head: head("HLP_shortcut", "HLP_description"), body: (r.hotkeys || []).map((x) => [kbd(x.keys), x.label]) };
    case "ruleActions":
      return { head: head("HLP_action", "HLP_description"), body: (r.rules && r.rules.actions || []).map((a) => [a, ""]) };
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

bridge.on("i18n", (m) => {
  state.i18n = m || {};
  const q = document.getElementById("q");
  if (state.i18n.HLP_search) q.placeholder = state.i18n.HLP_search;
});
bridge.on("reference", (d) => { state.reference = d; fillReference(document.getElementById("doc")); });
bridge.on("opened", (topic) => { if (topic) show(topic); });

bridge.whenReady(async () => {
  state.topics = await loadTopics();
  show(state.topics.length ? state.topics[0].id : "");
  bridge.send("ready");
});
