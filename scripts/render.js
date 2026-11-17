// Screenshots each fN.html in a folder, adding a mouse pointer that glides to
// the pane selected in that frame and clicks it. Called by demo.sh.
// Usage: node render.js <folder> <frame count>
// Reads fN.dur (seconds on screen), fN.cur ("col row" the pointer rests on)
// and fN.key (keys pressed for that frame, shown as keycaps; may be empty).
// Writes the PNGs and list.txt, the ffmpeg concat list in playing order.
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const [dir, count] = process.argv.slice(2);
const read = (f) => fs.readFileSync(path.join(dir, f), 'utf8').trim();

const STEPS = 9;        // frames for one glide
const STEP_DUR = 0.045; // seconds each
const CLICK_DUR = 0.18;

const POINTER = `<svg width="26" height="26" viewBox="0 0 26 26" style="display:block">
  <path d="M3 2 L3 21 L8 16.5 L11.5 24 L15 22.5 L11.5 15 L18 15 Z"
        fill="#fff" stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg>`;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 1400, height: 900 } });
  const list = [];
  let shot = 0;

  // Loads frame i and returns a function that maps a cell to pixels in the page.
  async function load(i) {
    await page.goto('file://' + path.join(dir, `f${i}.html`));
    return page.evaluate((svg) => {
      // room under the window for the keycaps, same size on every frame
      Object.assign(document.body.style, { position: 'relative', paddingBottom: '84px' });
      const pre = document.querySelector('pre');
      const probe = document.createElement('span');
      probe.textContent = 'M'.repeat(100);
      pre.appendChild(probe);
      const cw = probe.getBoundingClientRect().width / 100;
      probe.remove();
      const cs = getComputedStyle(pre), r = pre.getBoundingClientRect(), b = document.body.getBoundingClientRect();
      const ptr = document.createElement('div');
      ptr.id = 'ptr';
      ptr.style.cssText = 'position:absolute;z-index:10;pointer-events:none;filter:drop-shadow(0 2px 3px rgba(0,0,0,.5))';
      ptr.innerHTML = svg;
      const ring = document.createElement('div');
      ring.id = 'ring';
      ring.style.cssText = 'position:absolute;z-index:9;width:34px;height:34px;margin:-17px 0 0 -17px;border-radius:50%;' +
        'border:3px solid rgba(77,196,255,.95);box-shadow:0 0 12px rgba(77,196,255,.7);display:none';
      const keys = document.createElement('div');
      keys.id = 'keys';
      keys.style.cssText = 'position:absolute;z-index:11;left:50%;bottom:18px;transform:translateX(-50%);display:none;' +
        'gap:8px;padding:10px 14px;border-radius:12px;background:rgba(14,15,20,.88);box-shadow:0 8px 24px rgba(0,0,0,.5);' +
        'font:600 20px/1 "DejaVu Sans",sans-serif;color:#fff';
      document.body.append(ring, ptr, keys);
      return { x0: r.left - b.left + parseFloat(cs.paddingLeft), y0: r.top - b.top + parseFloat(cs.paddingTop),
               cw, ch: parseFloat(cs.lineHeight) };
    }, POINTER);
  }
  const px = (g, [c, r]) => [g.x0 + (c + 0.5) * g.cw, g.y0 + (r + 0.5) * g.ch];
  async function snap(x, y, click, dur, key = '') {
    await page.evaluate(([x, y, click, key]) => {
      const k = document.getElementById('keys');
      k.style.display = key ? 'flex' : 'none';
      k.innerHTML = key.split(/\s{2,}/).map((c) => '<span style="padding:7px 12px;border-radius:7px;background:#2e3140;' +
        'border:1px solid #555a6e;border-bottom-width:3px">' + c + '</span>').join('');
      Object.assign(document.getElementById('ptr').style, { left: x + 'px', top: y + 'px' });
      Object.assign(document.getElementById('ring').style, { left: x + 'px', top: y + 'px', display: click ? 'block' : 'none' });
    }, [x, y, click, key]);
    const file = path.join(dir, `s${shot++}.png`);
    await page.locator('body').screenshot({ path: file });
    list.push([file, dur]);
    return file;
  }

  let prev = null;
  for (let i = 0; i < Number(count); i++) {
    const cur = read(`f${i}.cur`).split(' ').map(Number);
    if (prev && (cur[0] !== prev[0] || cur[1] !== prev[1])) {
      // glide over the previous screen, then click
      const g = await load(i - 1);
      const [ax, ay] = px(g, prev), [bx, by] = px(g, cur);
      for (let s = 1; s <= STEPS; s++) {
        const t = s / STEPS, e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        // bow sideways off the straight line, like a hand moving a mouse
        const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy) || 1;
        const bow = Math.sin(Math.PI * e) * Math.min(60, len * 0.18);
        await snap(ax + dx * e + (dy / len) * bow, ay + dy * e - (dx / len) * bow, false, STEP_DUR);
      }
      await snap(bx, by, true, CLICK_DUR);
    }
    const g = await load(i);
    const [x, y] = px(g, cur);
    const key = read(`f${i}.key`), dur = Number(read(`f${i}.dur`));
    let file;
    if (key) { // the keycaps show for most of the frame, then the screen stays a bit without them
      file = await snap(x, y, false, Math.min(1.0, dur), key);
      if (dur > 1.0) await snap(x, y, false, dur - 1.0);
    } else {
      file = await snap(x, y, false, dur);
    }
    fs.copyFileSync(file, path.join(dir, `f${i}.png`));
    prev = cur;
  }
  const last = list[list.length - 1][0];
  fs.writeFileSync(path.join(dir, 'list.txt'),
    list.map(([f, d]) => `file '${f}'\nduration ${d}\n`).join('') + `file '${last}'\n`);
  await browser.close();
})();
