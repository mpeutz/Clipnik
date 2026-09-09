// bridge.js - JSON messaging with the AutoHotkey host (src/ui/web/WebHost.ahk). Messages are {cmd, data}
// both ways. When window.chrome.webview is absent (page opened in a browser) mock-bridge.js is loaded
// instead, so the pages can be laid out and tested in Chrome. Pages start from bridge.whenReady(fn).
(function () {
  const listeners = new Map();
  const wv = window.chrome && window.chrome.webview;
  const bridge = {
    native: !!wv,
    send(cmd, data) {
      const d = data === undefined ? "" : data;
      if (wv) wv.postMessage({ cmd, data: d });
      else if (window.mockBridge) window.mockBridge.handle(cmd, d);
    },
    on(cmd, fn) {
      if (!listeners.has(cmd)) listeners.set(cmd, []);
      listeners.get(cmd).push(fn);
    },
    dispatch(cmd, data) {
      for (const fn of listeners.get(cmd) || []) fn(data);
    },
  };
  if (wv) wv.addEventListener("message", (e) => { const m = e.data || {}; bridge.dispatch(m.cmd, m.data); });
  bridge.on("theme", (t) => {
    if (!t) return;
    document.documentElement.style.cssText += t.vars || "";
    document.documentElement.classList.toggle("dark", !!t.dark);
    document.documentElement.classList.toggle("light", !t.dark);
  });
  let isReady = false;
  const waiting = [];
  bridge.whenReady = (fn) => { if (isReady) fn(); else waiting.push(fn); };
  window.bridge = bridge;
  const ready = () => { isReady = true; waiting.splice(0).forEach((fn) => fn()); };
  if (wv) {
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", ready); else ready();
  } else {
    const s = document.createElement("script");
    s.src = "../common/mock-bridge.js";
    s.onload = ready;
    document.head.appendChild(s);
  }
})();
