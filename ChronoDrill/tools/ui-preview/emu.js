// Roblox GUI emulator: runs game UI Lua code under a mocked Roblox API (fengari) and renders the
// resulting ScreenGui tree to HTML, then screenshots it with Playwright.
// Usage: node emu.js <scenario.lua> <out.png> [width=1280] [height=720] [bg.png]
//   npm install fengari playwright   (Chromium для Playwright)
//   ICON_ID=1 — показать цветные иконки из атласа; SC_WINDOW=Pets — какое окно открыть в sc/window.lua
// Это не Roblox: 3D (ViewportFrame) рисуется заглушкой, анимации прыгают к конечному состоянию.
const fs = require("fs");
const path = require("path");
const fengari = require("fengari");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
const { chromium } = require("playwright");

const SRC = process.env.SRC || path.join(__dirname, "..", "..", "src");
const ICONS = process.env.ICONS || path.join(__dirname, "..", "..", "Icons", "ChronoDrill_Icons.png");

function listing(root) {
  const out = {};
  (function walk(d) {
    const entries = fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
    out[d] = entries.map((e) => ({ name: e.name, dir: e.isDirectory() }));
    for (const e of entries) if (e.isDirectory()) walk(path.join(d, e.name));
  })(root);
  let s = "LISTING = {\n";
  for (const [d, es] of Object.entries(out)) {
    s += `[${JSON.stringify(d)}] = {` + es.map((e) => `{name=${JSON.stringify(e.name)},dir=${e.dir}}`).join(",") + "},\n";
  }
  return s + "}\n";
}

function runLua(scenario) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const prelude =
    `SRC_ROOT = ${JSON.stringify(SRC)}\nEMU = ${JSON.stringify(__dirname)}\n` + (process.env.ICON_ID ? `ICON_ID = "rbxassetid://1"\n` : "") +
    listing(SRC) +
    `R = dofile(${JSON.stringify(path.join(__dirname, "roblox.lua"))})\n` +
    `R.listdir = function(d) return LISTING[d] or {} end\n`;
  const code = prelude + `local ok, err = xpcall(function() dofile(${JSON.stringify(scenario)}) end, debug.traceback)\nif not ok then print("SCENARIO ERROR", err) end\n`;
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  lua.lua_getglobal(L, to_luastring("OUTPUT"));
  const s = lua.lua_tojsstring(L, -1);
  if (!s) throw new Error("scenario did not set OUTPUT");
  return JSON.parse(s);
}

const PAGE = fs.readFileSync(path.join(__dirname, "render.html"), "utf8");

(async () => {
  const [scenario, out, W = "1280", H = "720", bg = ""] = process.argv.slice(2);
  const tree = runLua(path.resolve(scenario));
  const html = PAGE.replace("/*TREE*/null", JSON.stringify(tree))
    .replace("/*W*/1280", W).replace("/*H*/720", H)
    .replace("/*BG*/\"\"", JSON.stringify(bg ? "file://" + path.resolve(bg) : ""))
    .replace("/*ICONS*/\"\"", JSON.stringify("file://" + ICONS))
    .replace("/*THREEJS*/", "file://" + (process.env.THREE_JS || path.join(path.dirname(require.resolve("three")), "three.min.js")))
    .replace("/*FONTS*/", fs.readFileSync(path.join(__dirname, "fonts", "local.css"), "utf8").replace(/url\(([^)]+)\)/g, (m, f) => `url(file://${path.join(__dirname, "fonts", f)})`));
  const tmp = path.join(require("os").tmpdir(), "ui-preview-last.html");
  fs.writeFileSync(tmp, html);
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"] });
  const page = await browser.newPage({ viewport: { width: +W, height: +H }, deviceScaleFactor: 1 });
  page.on("console", (m) => { if (m.type() === "error" || m.text().startsWith("[emu]")) console.log("page:", m.text()); });
  await page.goto("file://" + tmp);
  await page.waitForFunction(() => window.__done === true, null, { timeout: 15000 });
  await page.screenshot({ path: out });
  await browser.close();
  console.log("wrote", out);
})().catch((e) => { console.error(e); process.exit(1); });
