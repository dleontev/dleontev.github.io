const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;
const pages = ['/', '/about/', '/blog/', '/projects/', '/blog/ccna-ocg', '/blog/entra-sign-in-troubleshooting-framework', '/blog/microsoft-365-service-ownership-framework', '/blog/tags', '/404.html'];
for (const width of [320, 390, 768, 1280]) {
  test('pages fit viewport '+width, async ({page}) => {
    await page.setViewportSize({width,height:900});
    for (const url of pages) {
      await page.goto(url);
      await page.evaluate(() => document.fonts.ready);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),url).toBe(true);
      await expect(page.locator('h1')).toHaveCount(1);
    }
  });
}
for (const scheme of ['light','dark']) {
  test('accessibility in '+scheme, async ({page}) => {
    await page.emulateMedia({colorScheme:scheme});
    for (const url of pages) {
      await page.goto(url);
      const audit = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
      expect(audit.violations, url+': '+JSON.stringify(audit.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>n.target)})))).toEqual([]);
    }
  });
}
test('mobile menu and theme work from keyboard', async ({page}) => {
  await page.setViewportSize({width:390,height:844});
  await page.goto('/');
  const menu = page.getByRole('button',{name:'Menu',exact:true});
  await menu.focus(); await page.keyboard.press('Enter');
  await expect(page.getByRole('link',{name:'About',exact:true})).toBeVisible();
  await page.getByRole('link',{name:'About',exact:true}).focus();
  await page.keyboard.press('Tab');
  const theme = page.getByRole('button',{name:'Dark mode',exact:true});
  await expect(theme).toBeFocused();
  const before = await theme.getAttribute('aria-pressed');
  await page.keyboard.press('Space');
  await expect(theme).toHaveAttribute('aria-pressed', before === 'true' ? 'false' : 'true');
  await page.keyboard.press('Escape');
  await expect(menu).toBeFocused();
  await expect(menu).toHaveAttribute('aria-expanded','false');
});
test('search has results, empty and no-match states', async ({page}) => {
  await page.goto('/blog/');
  const field = page.getByRole('searchbox',{name:'Search articles'});
  await expect(field).toBeEnabled();
  await field.fill('Entra');
  await expect(page.locator('#results-container a')).toHaveCount(1);
  await field.fill('zzzz-no-match');
  await expect(page.getByRole('status')).toContainText('No matching articles');
  await field.fill('');
  await expect(page.locator('#results-container a')).toHaveCount(0);
});
test('search failure preserves browsing', async ({page}) => {
  await page.route('**/search.json',route=>route.fulfill({status:503,body:'Unavailable'}));
  await page.goto('/blog/');
  await expect(page.getByRole('status')).toContainText('Search is unavailable');
  await expect(page.locator('.article-card')).toHaveCount(3);
});
test('project article button opens the article', async ({page}) => {
  await page.goto('/projects/entra-sign-in-troubleshooting-framework/');
  await page.getByRole('link',{name:'Read the initial article',exact:true}).click();
  await expect(page).toHaveURL(/\/blog\/entra-sign-in-troubleshooting-framework$/);
  await expect(page.locator('h1')).toHaveText('Building a Practical Microsoft Entra Sign-In Troubleshooting Framework');
});
test('badges remain readable and share verification data', async ({page}) => {
  await page.setViewportSize({width:320,height:740});
  await page.goto('/');
  const badges = await page.locator('.cert-link').evaluateAll(links=>links.map(e=>({href:e.href,width:e.querySelector('img').getBoundingClientRect().width})));
  expect(badges).toHaveLength(13);
  expect(badges.every(b=>b.width>=96)).toBe(true);
  await page.goto('/about/');
  expect((await page.locator('.certification-list a').evaluateAll(links=>links.map(e=>e.href))).sort()).toEqual(badges.map(b=>b.href).sort());
});
test('table of contents targets rendered headings', async ({page}) => {
  await page.goto('/blog/microsoft-365-service-ownership-framework');
  const toc = page.getByRole('navigation',{name:'On this page'});
  expect(await toc.getByRole('link').count()).toBeGreaterThan(5);
  const link = toc.getByRole('link').first();
  const target = await link.getAttribute('href');
  await link.click();
  await expect(page.locator(target)).toBeFocused();
});
test('content and navigation remain available without JavaScript', async ({browser}) => {
  const context = await browser.newContext({javaScriptEnabled:false,viewport:{width:390,height:844}});
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:4000/blog/');
  await expect(page.getByRole('link',{name:'Projects',exact:true})).toBeVisible();
  await expect(page.locator('.article-card')).toHaveCount(3);
  await context.close();
});
