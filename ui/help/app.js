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

function fillReference(root) { /* Task 2 */ }

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
