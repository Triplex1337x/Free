// 3D preview of procedural pets: builds models with the real PetBuilder under the Roblox mock,
// renders them with three.js. Usage: PETS=Id1,Id2 node pet3d.js out.png [grid|lineup] [cols] [cellW] [cellH]
const fs = require("fs");
const path = require("path");
const fengari = require(process.env.FENGARI || "fengari");
const { lua, lauxlib, lualib, to_luastring } = fengari;
const { chromium } = require(process.env.PLAYWRIGHT || "playwright");
const SRC = process.env.SRC || path.join(__dirname, "..", "..", "src");
const THREE_JS = process.env.THREE_JS || path.join(path.dirname(require.resolve("three")), "three.min.js");

function listing(root) {
  const out = {};
  (function walk(d) {
    const es = fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
    out[d] = es.map((e) => ({ name: e.name, dir: e.isDirectory() }));
    for (const e of es) if (e.isDirectory()) walk(path.join(d, e.name));
  })(root);
  let s = "LISTING = {\n";
  for (const [d, es] of Object.entries(out)) s += `[${JSON.stringify(d)}] = {` + es.map((e) => `{name=${JSON.stringify(e.name)},dir=${e.dir}}`).join(",") + "},\n";
  return s + "}\n";
}

const [out, mode = "grid", cols = "4", cw = "360", ch = "360"] = process.argv.slice(2);
const pets = (process.env.PETS || "Worm").split(",");
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const code = `SRC_ROOT = ${JSON.stringify(SRC)}\n${listing(SRC)}R = dofile(${JSON.stringify(path.join(__dirname, "roblox.lua"))})
R.listdir = function(d) return LISTING[d] or {} end
local RS = game:GetService("ReplicatedStorage")
R.mountTree(RS, SRC_ROOT .. "/ReplicatedStorage")
local PB = require(RS.Shared.PetBuilder)
local PD = require(RS.Configs.PetsData)
local parts = {}
for id, tier in string.gmatch(${JSON.stringify(pets.join(","))}, "([%w_]+):?(%d*)") do
  local ok, m = pcall(PB.Build, id)
  if not ok then print("BUILD ERROR", id, m) else
    tier = tonumber(tier)
    if tier and tier > 0 and PB.ApplyTier then pcall(PB.ApplyTier, m, tier) end
    local def = PD.ById[id]
    local r = def and PD.Rarity[def.Rarity]
    local name = def and def.Name or id
    table.insert(parts, string.format('{"id":%q,"name":%q,"sub":%q,"parts":%s}', id, name, (r and r.Name or "") .. "  ·  x" .. string.format("%.2f", m:GetAttribute("Scale") or 1), R.serialize3d(m)))
  end
end
OUTPUT = "[" .. table.concat(parts, ",") .. "]"`;
if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
lua.lua_getglobal(L, to_luastring("OUTPUT"));
const data = lua.lua_tojsstring(L, -1);
let html = fs.readFileSync(path.join(__dirname, "render3d.html"), "utf8")
  .replace("/*DATA*/null", data).replace('/*MODE*/"grid"', JSON.stringify(mode))
  .replace("/*CW*/360", cw).replace("/*CH*/360", ch).replace("/*COLS*/4", cols)
  .replace("/*THREE*/", "file://" + THREE_JS)
  .replace("/*FONTS*/", fs.readFileSync(path.join(__dirname, "fonts", "local.css"), "utf8").replace(/url\(([^)]+)\)/g, (m, f) => `url(file://${path.join(__dirname, "fonts", f)})`));
const tmp = path.join(require("os").tmpdir(), "pet3d.html");
fs.writeFileSync(tmp, html);
(async () => {
  const b = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"] });
  const n = JSON.parse(data).length;
  const W = mode === "lineup" ? +cw + 20 : Math.min(n, +cols) * (+cw + 10) + 10;
  const H = mode === "lineup" ? +ch + 20 : Math.ceil(n / +cols) * (+ch + 10) + 10;
  const p = await b.newPage({ viewport: { width: W, height: H } });
  p.on("console", (m) => { if (m.type() === "error") console.log("page:", m.text()); });
  p.on("pageerror", (e) => console.log("pageerror:", e.message));
  await p.goto("file://" + tmp);
  await p.waitForFunction(() => window.__done === true, null, { timeout: 60000 });
  await p.screenshot({ path: out });
  await b.close();
  console.log("wrote", out, n, "pets");
})();
