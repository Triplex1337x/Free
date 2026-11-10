// Растеризует иконки из Icons/ (после tools/make_icons.py) в PNG через Chromium (Playwright).
//   Icons/ChronoDrill_Icons.png — атлас 1024x1024 для загрузки в Roblox
//   Icons/png/<Имя>.png         — отдельные иконки 256x256
// Запуск: node tools/render_icons.js
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const ROOT = path.dirname(__dirname);
const ICONS = path.join(ROOT, "Icons");

async function shot(page, svg, w, h, out) {
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(
    `<html><body style="margin:0;background:transparent">${svg}</body></html>`
  );
  await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } });
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await shot(page, fs.readFileSync(path.join(ICONS, "atlas.svg"), "utf8"), 1024, 1024, path.join(ICONS, "ChronoDrill_Icons.png"));
  const pngDir = path.join(ICONS, "png");
  fs.mkdirSync(pngDir, { recursive: true });
  for (const f of fs.readdirSync(path.join(ICONS, "svg"))) {
    if (!f.endsWith(".svg")) continue;
    const svg = fs.readFileSync(path.join(ICONS, "svg", f), "utf8");
    await shot(page, svg, 256, 256, path.join(pngDir, f.replace(/\.svg$/, ".png")));
  }
  await browser.close();
  console.log("rendered");
})();
