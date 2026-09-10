// mock-bridge.js - stands in for the AutoHotkey host when a page is opened in a browser (?theme=light for light).
// Implements enough of the History and Organizer protocols to lay the pages out and click around.
(function () {
  const light = new URLSearchParams(location.search).get("theme") === "light";
  const vars = light
    ? "--bg:#F3F3F3;--surface:#FFFFFF;--surfaceAlt:#EDEDED;--border:#D9D9D9;--text:#1B1B1B;--muted:#6B6B6B;--accent:#C42B1C;--accentText:#FFFFFF;--danger:#C42B1C;"
    : "--bg:#202020;--surface:#2B2B2B;--surfaceAlt:#363636;--border:#3F3F3F;--text:#F0F0F0;--muted:#9A9A9A;--accent:#C42B1C;--accentText:#FFFFFF;--danger:#E5484D;";
  const reply = (cmd, data) => setTimeout(() => bridge.dispatch(cmd, data), 30);
  const day = (n, hm) => { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10) + " " + hm + ":00"; };

  // ---- history ----
  const kindLabels = { url: "URL", email: "Email" };
  let hist = [
    { id: 1, data: "Brings the Latest Resources widget in line with the Figma mockup: the shared resource card is restyled, the section header is restructured with the carousel prev/next buttons moved into the header, and the grid now collapses to a single column below 720px.\n\nAlso fixes a regression where the fallback image was never shown.", type: 0, time: day(0, "14:22"), size: 312, kind: "text" },
    { id: 2, data: "https://github.com/aviaryan/Clipjump/issues/143", type: 0, time: day(0, "13:58"), size: 48, kind: "url" },
    { id: 3, data: "[IMAGE]", type: 1, time: day(0, "13:40"), size: 214000, fileid: "cache\\history\\demo.jpg", url: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 180"><rect width="320" height="180" fill="#3a5f8a"/><circle cx="250" cy="45" r="22" fill="#f4d35e"/><path d="M0 180 60 110 120 150 190 80 260 130 320 100v80z" fill="#2f7d5b"/></svg>'), kind: "" },
    { id: 4, data: "SELECT id, clip, date FROM history WHERE clip LIKE '%figma%' ORDER BY date DESC", type: 0, time: day(0, "11:05"), size: 82, kind: "text" },
    { id: 5, data: "Mike Peutz <mike@example.com>", type: 0, time: day(0, "09:31"), size: 29, kind: "email" },
    { id: 6, data: "C:\\Users\\MikePeutz\\PortableApps\\Clipjump_new_x64\\design\\phase4", type: 0, time: day(1, "18:12"), size: 61, kind: "text" },
    { id: 7, data: "npm run build && node design/phase4/build.mjs", type: 0, time: day(1, "16:02"), size: 46, kind: "text" },
    { id: 8, data: "The quick brown fox jumps over the lazy dog", type: 0, time: day(3, "10:44"), size: 43, kind: "text" },
    { id: 9, data: "4111 1111 1111 1111", type: 0, time: day(4, "20:15"), size: 19, kind: "text" },
  ];
  for (let i = 10; i < 60; i++) hist.push({ id: i, data: "Filler clip number " + i + " lorem ipsum dolor sit amet", type: 0, time: day(5 + (i % 20), "08:00"), size: 40 + i, kind: "text" });

  function histList(d) {
    const q = (d.q || "").trim().toLowerCase();
    const words = d.partial ? q.split(/\s+/).filter(Boolean) : (q ? [q] : []);
    let rows = hist.filter((r) => words.every((w) => r.data.toLowerCase().includes(w)));
    if (d.kind) rows = rows.filter((r) => r.kind === d.kind);
    const col = d.sort === "clip" ? "data" : d.sort === "size" ? "size" : "time";
    rows.sort((a, b) => (a[col] > b[col] ? 1 : a[col] < b[col] ? -1 : 0) * (d.asc ? 1 : -1));
    reply("list", { rows: rows.map((r) => ({ id: r.id, clip: r.data.slice(0, 300), type: r.type, time: r.time, size: r.size, kind: r.kind })), matched: rows.length, total: hist.length, bytes: hist.reduce((s, r) => s + r.size, 0), partial: d.partial ? 1 : 0 });
    reply("kinds", { kinds: ["url", "email"], labels: kindLabels });
  }

  // ---- organizer ----
  let channels = [{ n: 0, name: "Default" }, { n: 1, name: "Work" }, { n: 2, name: "Snippets" }, { n: 3, name: "Addresses" }, { n: 4, name: "Pit" }];
  let clips = {};
  channels.forEach((c) => { clips[c.n] = []; });
  hist.slice(0, 40).forEach((h, i) => clips[0].push({ n: i + 1, text: h.data, type: h.type, tags: i === 0 ? "work" : i === 3 ? "sql" : "", fixed: i === 0 ? 1 : 0, url: h.url }));
  for (let c = 1; c < 5; c++) for (let i = 1; i <= [0, 12, 27, 5, 3][c]; i++) clips[c].push({ n: i, text: channels[c].name + " clip " + i, type: 0, tags: "", fixed: 0 });
  let active = 0;
  const chList = () => reply("channels", { channels: channels.map((c) => ({ n: c.n, name: c.name, count: clips[c.n].length })), active });
  const clipList = (ch) => reply("clips", { channel: ch, rows: clips[ch].map((c) => ({ n: c.n, clip: c.text.slice(0, 300), type: c.type, tags: c.tags, fixed: c.fixed })) });

  window.mockBridge = {
    handle(cmd, d) {
      switch (cmd) {
        case "ready": reply("theme", { vars, dark: light ? 0 : 1 }); if (location.pathname.includes("organizer")) { chList(); clipList(0); } else histList({ partial: 1 }); break;
        case "list": histList(d); break;
        case "get": { const r = hist.find((h) => h.id === +d); if (r) reply("preview", r); break; }
        case "delete": hist = hist.filter((h) => !d.includes(h.id)); reply("refreshed"); break;
        case "clear": if (confirm("Clear history?")) { hist = []; reply("refreshed"); } break;
        case "copy": reply("toast", "Copied"); break;
        case "instaPaste": reply("toast", "Insta-paste " + d.join(",")); break;
        case "close": console.log("close"); break;
        case "channels": chList(); break;
        case "clips": clipList(+d); break;
        case "getClip": { const c = (clips[d.channel] || []).find((x) => x.n === +d.n); if (c) reply("clip", { channel: d.channel, n: c.n, data: c.text, type: c.type, tags: c.tags, fixed: c.fixed, url: c.url }); break; }
        case "useChannel": active = +d; chList(); break;
        case "setProps": { const c = clips[d.channel].find((x) => x.n === +d.n); if (c) { c.tags = d.tags; c.fixed = d.fixed ? 1 : 0; } clipList(d.channel); break; }
        case "move": { const arr = clips[d.channel]; const i = arr.findIndex((x) => x.n === +d.n); const j = i + (d.delta || 0); if (i >= 0 && j >= 0 && j < arr.length) { [arr[i], arr[j]] = [arr[j], arr[i]]; arr.forEach((x, k) => (x.n = k + 1)); } clipList(d.channel); break; }
        case "transfer": { const src = clips[d.channel]; const moving = src.filter((x) => d.ns.includes(x.n)); if (!d.copy) { clips[d.channel] = src.filter((x) => !d.ns.includes(x.n)); clips[d.channel].forEach((x, k) => (x.n = k + 1)); } moving.forEach((m) => clips[d.to].push({ ...m, n: clips[d.to].length + 1 })); chList(); clipList(d.channel); break; }
        case "deleteClips": clips[d.channel] = clips[d.channel].filter((x) => !d.ns.includes(x.n)); clips[d.channel].forEach((x, k) => (x.n = k + 1)); chList(); clipList(d.channel); break;
        case "newClip": { const t = prompt("New clip text"); if (t) { clips[d].push({ n: clips[d].length + 1, text: t, type: 0, tags: "", fixed: 0 }); chList(); clipList(d); } break; }
        case "newChannel": { const n = channels.length; channels.push({ n, name: d || "Channel " + n }); clips[n] = []; chList(); break; }
        case "renameChannel": { const c = channels.find((x) => x.n === +d.n); if (c) c.name = d.name; chList(); break; }
        case "deleteChannel": { channels = channels.filter((x) => x.n !== +d.n); chList(); break; }
        case "paste": reply("toast", "Insta-paste"); break;
        case "pasteMode": reply("toast", "Paste mode"); break;
        case "edit": reply("toast", "Edit"); break;
        default: console.log("mock: unhandled", cmd, d);
      }
    },
  };
})();
