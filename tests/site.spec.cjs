const {test, expect} = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;
const data = require('../.validation/manifest.json');
for (const width of [320,390,768,1280]) {
  test('all pages fit and preserve heading hierarchy at '+width, async ({page}) => {
    await page.setViewportSize({width,height:900});
    for (const target of data.pages) {
      const response = await page.goto(target.url);
      expect(response.status(),target.url).toBe(200);
      await page.evaluate(()=>document.fonts.ready);
      expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),target.url).toBe(true);
      await expect(page).toHaveTitle(target.browserTitle);
      await expect(page.locator('h1')).toHaveCount(1);
      const sizes = await page.locator('h1,h2,h3,h4,h5,h6').evaluateAll(nodes=>nodes.map(e=>({level:Number(e.tagName.slice(1)),size:parseFloat(getComputedStyle(e).fontSize)})));
      for (let level=2;level<=6;level++) {
        const parents=sizes.filter(h=>h.level===level-1), children=sizes.filter(h=>h.level===level);
        if(parents.length && children.length) expect(Math.max(...children.map(h=>h.size)),target.url).toBeLessThanOrEqual(Math.min(...parents.map(h=>h.size)));
      }
    }
  });
}
for(const scheme of ['light','dark']) {
  test('all pages are accessible in '+scheme,async({page})=>{
    await page.emulateMedia({colorScheme:scheme});
    for(const target of data.pages) {
      await page.goto(target.url);
      const audit=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
      expect(audit.violations,target.url+': '+JSON.stringify(audit.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>n.target)})))).toEqual([]);
    }
  });
}
test('Home and active navigation distinguish pages from sections',async({page})=>{
  for(const target of data.pages) {
    await page.goto(target.url);
    const nav=page.getByRole('navigation',{name:'Main navigation'});
    await expect(nav.getByRole('link',{name:'Home',exact:true})).toBeVisible();
    if(target.section) {
      const link=nav.getByRole('link',{name:target.section,exact:true});
      if(await link.getAttribute('href')===target.url) await expect(link).toHaveAttribute('aria-current','page');
      else { await expect(link).toHaveClass('active-section'); expect(await link.getAttribute('aria-current')).toBeNull(); }
    }
    if(target.url!=='/') expect(await nav.getByRole('link',{name:'Home',exact:true}).getAttribute('aria-current')).toBeNull();
  }
});
test('mobile menu and changing theme action work by keyboard and persist',async({page})=>{
  await page.emulateMedia({colorScheme:'light'}); await page.setViewportSize({width:390,height:844}); await page.goto('/');
  const menu=page.getByRole('button',{name:'Menu',exact:true}); await menu.focus(); await page.keyboard.press('Enter');
  await expect(page.getByRole('navigation',{name:'Main navigation'}).getByRole('link',{name:'Home',exact:true})).toBeVisible();
  await page.getByRole('link',{name:'About',exact:true}).focus(); await page.keyboard.press('Tab');
  const theme=page.getByRole('button',{name:'Switch to dark mode',exact:true}); await expect(theme).toBeFocused();
  await page.keyboard.press('Space'); await expect(page.getByRole('button',{name:'Switch to light mode',exact:true})).toBeFocused();
  expect(await page.locator('#theme-toggle').getAttribute('aria-pressed')).toBeNull();
  await page.keyboard.press('Escape'); await expect(menu).toBeFocused(); await expect(menu).toHaveAttribute('aria-expanded','false');
  await page.goto('/about/'); await menu.click(); await expect(page.getByRole('button',{name:'Switch to light mode',exact:true})).toBeVisible();
});
test('search separates results from the archive and clears without losing focus',async({page})=>{
  await page.goto('/blog/'); const field=page.getByRole('searchbox',{name:'Search articles'}); await expect(field).toBeEnabled();
  const query=data.pages.find(p=>p.tags?.length).title;
  await field.fill(query); await expect(page.locator('#results-container a')).toHaveCount(1); await expect(page.locator('#results-container p')).not.toBeEmpty();
  await field.fill('zzzz-no-match'); await expect(page.getByRole('status')).toContainText('No matching articles');
  await expect(page.getByRole('heading',{name:'All articles',exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Clear search'}).click(); await expect(field).toBeFocused(); await expect(page.locator('#search-results')).toBeHidden();
});
test('failed and malformed search can retry while browsing remains available',async({page})=>{
  let requests=0; await page.route('**/search.json',route=>{requests++; return requests===1 ? route.fulfill({status:503,body:'Unavailable'}) : route.continue();});
  await page.goto('/blog/'); await expect(page.getByRole('status')).toContainText('Search is unavailable');
  await expect(page.locator('.article-card')).toHaveCount(data.pages.filter(p=>p.tags).length);
  await page.getByRole('button',{name:'Retry search'}).click(); await expect(page.getByRole('searchbox')).toBeEnabled();
  await page.route('**/search.json',route=>route.fulfill({contentType:'application/json',body:'[{"title":"bad"}]'}));
  await page.reload(); await expect(page.getByRole('status')).toContainText('Search is unavailable');
});
test('slow search stops loading and offers retry',async({page})=>{
  await page.route('**/search.json',()=>new Promise(()=>{})); await page.goto('/blog/');
  await expect(page.getByRole('button',{name:'Retry search'})).toBeVisible({timeout:12000});
  await expect(page.locator('.article-card')).toHaveCount(data.pages.filter(p=>p.tags).length);
});
test('source certification links and every skill remain available',async({page})=>{
  await page.setViewportSize({width:320,height:740}); await page.goto('/');
  const links=await page.locator('.cert-link').evaluateAll(nodes=>nodes.map(e=>({href:e.href,width:e.querySelector('img').getBoundingClientRect().width})));
  expect(links.map(l=>l.href).sort()).toEqual(data.certifications.map(c=>c.verification_url).sort()); expect(links.every(l=>l.width>=96)).toBe(true);
  for(const skill of data.skills) await expect(page.getByText(skill.home,{exact:true})).toBeVisible();
  await page.goto('/about/'); expect((await page.locator('.certification-list a').evaluateAll(nodes=>nodes.map(e=>e.href))).sort()).toEqual(data.certifications.map(c=>c.verification_url).sort());
});
test('project cards link directly to available material',async({page})=>{
  await page.goto('/projects/'); await expect(page.getByRole('heading',{name:'Current work',exact:true})).toBeVisible();
  const current=data.pages.filter(p=>p.article);
  for(const target of current) {
    const card=page.locator('.project-summary').filter({has:page.getByRole('heading',{name:target.title,exact:true})});
    const url=await card.getByRole('link',{name:'Read the initial article'}).getAttribute('href');
    expect(data.pages.some(p=>p.url===url && p.tags)).toBe(true);
  }
  await page.goto(current[0].url); await page.getByRole('link',{name:'All projects',exact:true}).click(); await expect(page).toHaveURL(/\/projects\/$/);
});
test('mobile contents disclose and focus their target, with a back-to-top link',async({page})=>{
  await page.setViewportSize({width:390,height:844}); await page.goto('/blog/ccna-ocg');
  const toc=page.locator('.article-toc'); expect(await toc.evaluate(e=>e.open)).toBe(false);
  await toc.locator('summary').click(); const link=toc.getByRole('link').first(); const target=await link.getAttribute('href');
  await link.click(); await expect(page.locator(target)).toBeFocused();
  await page.getByRole('link',{name:'Back to top',exact:true}).click(); await expect(page.locator('#article-top')).toBeFocused();
  expect(await page.locator('.related-reading li').count()).toBeLessThanOrEqual(3);
});
test('legacy redirects still reach their destination',async({page})=>{
  for(const target of data.redirects){ await page.goto(target.url); await expect(page).toHaveURL('http://127.0.0.1:4000'+target.target); }
});
test('content, Home and contents remain available without JavaScript',async({browser})=>{
  const context=await browser.newContext({javaScriptEnabled:false,viewport:{width:390,height:844}}); const page=await context.newPage();
  await page.goto('http://127.0.0.1:4000/blog/ccna-ocg'); await expect(page.getByRole('link',{name:'Home',exact:true})).toBeVisible();
  await page.locator('.article-toc summary').click(); await expect(page.locator('.article-toc nav')).toBeVisible(); await context.close();
});
