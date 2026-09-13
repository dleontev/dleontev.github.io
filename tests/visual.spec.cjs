const {test,expect}=require('@playwright/test');
for(const width of [390,768,1280]) {
  for(const [name,url] of [['home','/'],['article','/blog/ccna-ocg']]) {
    test(`${name} visual layout ${width}`,async({page})=>{
      await page.emulateMedia({colorScheme:'light',reducedMotion:'reduce'}); await page.setViewportSize({width,height:900}); await page.goto(url); await page.evaluate(()=>document.fonts.ready);
      await expect(page).toHaveScreenshot(`${name}-${width}.png`,{fullPage:false,animations:'disabled',maxDiffPixelRatio:0.003});
    });
  }
}
test('home dark visual layout',async({page})=>{
  await page.emulateMedia({colorScheme:'dark',reducedMotion:'reduce'}); await page.setViewportSize({width:1280,height:900}); await page.goto('/'); await page.evaluate(()=>document.fonts.ready);
  await expect(page).toHaveScreenshot('home-dark-1280.png',{animations:'disabled',maxDiffPixelRatio:0.003});
});
