const {test,expect}=require('@playwright/test');
test('navigation, theme and article contents work across browser engines',async({page})=>{
  await page.setViewportSize({width:390,height:844}); await page.emulateMedia({colorScheme:'light'}); await page.goto('/');
  await page.getByRole('button',{name:'Menu',exact:true}).click();
  await page.getByRole('button',{name:'Switch to dark mode'}).click(); await expect(page.getByRole('button',{name:'Switch to light mode'})).toBeVisible();
  await page.getByRole('navigation',{name:'Main navigation'}).getByRole('link',{name:'Home',exact:true}).click();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.goto('/blog/ccna-ocg'); await page.locator('.article-toc summary').click(); await expect(page.locator('.article-toc nav')).toBeVisible();
});
