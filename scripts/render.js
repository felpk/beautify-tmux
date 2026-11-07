// Screenshots each fN.html in a folder as fN.png. Called by demo.sh.
// Usage: node render.js <folder> <frame count>
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const [dir, count] = process.argv.slice(2);

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 1400, height: 900 } });
  for (let i = 0; i < Number(count); i++) {
    await page.goto('file://' + path.join(dir, `f${i}.html`));
    await page.locator('body').screenshot({ path: path.join(dir, `f${i}.png`), omitBackground: false });
  }
  await browser.close();
})();
