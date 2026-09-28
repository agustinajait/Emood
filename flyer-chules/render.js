// Genera flyer-chules.pdf y flyer-chules.png a partir de flyer.html
const { chromium } = require('playwright-core');
const path = require('path');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await browser.newPage({ viewport: { width: 1200, height: 1680 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(__dirname, 'flyer.html'), { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  const h = await page.evaluate(() => document.querySelector('footer').getBoundingClientRect().bottom);
  console.log('content bottom', h);
  await page.screenshot({ path: path.join(__dirname, 'flyer-chules.png') });
  await page.pdf({ path: path.join(__dirname, 'flyer-chules.pdf'), width: '1200px', height: '1680px', printBackground: true });
  await browser.close();
})();
