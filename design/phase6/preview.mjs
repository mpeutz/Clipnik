// Standalone preview of an artboard with the dark palette filled in (no editor). node preview.mjs <Name> [light]
import { readFileSync, writeFileSync } from "node:fs";
const [name, mode] = process.argv.slice(2);
const dark = "--bg:#202020;--surface:#2B2B2B;--surfaceAlt:#363636;--border:#3F3F3F;--text:#F0F0F0;--muted:#9A9A9A;--hover:#333333;--accent:#C42B1C;--accentText:#FFFFFF";
const light = "--bg:#F3F3F3;--surface:#FFFFFF;--surfaceAlt:#EDEDED;--border:#D9D9D9;--text:#1B1B1B;--muted:#6B6B6B;--hover:#E9E9E9;--accent:#C42B1C;--accentText:#FFFFFF";
let html = readFileSync(`${name}.dc.html`, "utf8").replace("{{vars}}", mode === "light" ? light : dark).replace(/<script src="\.\/support\.js"><\/script>/, "").replace(/<script data-dc-script[\s\S]*?<\/script>/, "").replace(/<\/?x-dc>|<\/?helmet>/g, "");
writeFileSync(`preview-${name}.html`, html);
console.log(`preview-${name}.html`);
