// Renderiza una página SPA con Chromium y devuelve {ok,title,text}
// Uso: node extract.cjs <url> [waitMs]
const url = process.argv[2];
const waitMs = parseInt(process.argv[3] || '6000', 10);
if (!url) { console.log(JSON.stringify({ ok: false, error: 'url requerida' })); process.exit(0); }

(async () => {
  try {
    const { chromium } = (() => {
    const candidates = [
      process.env.PW_MODULE,
      '/tmp/opencode/pw-diag/node_modules/playwright',
      'playwright',
    ].filter(Boolean);
    for (const c of candidates) { try { return require(c); } catch {} }
    throw new Error('playwright no encontrado (setea PW_MODULE)');
  })();
    const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true });
    const page = await browser.newPage({ userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126 Safari/537.36' });
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    try { await page.waitForLoadState('networkidle', { timeout: 20000 }); } catch {}
    // autoscroll para disparar lazy-loads
    await page.evaluate(async () => {
      for (let i = 0; i < 6; i++) { window.scrollBy(0, 1500); await new Promise(r => setTimeout(r, 400)); }
      window.scrollTo(0, 0);
    });
    await page.waitForTimeout(waitMs);
    const title = await page.title();
    const text = await page.evaluate(() => document.body.innerText);
    await browser.close();
    console.log(JSON.stringify({ ok: true, title, text }));
  } catch (e) {
    console.log(JSON.stringify({ ok: false, error: String(e && e.message || e) }));
  }
})();
