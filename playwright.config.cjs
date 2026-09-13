const { defineConfig, devices } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './tests', fullyParallel: true, retries: process.env.CI ? 1 : 0,
  timeout: 60000,
  use: { baseURL: 'http://127.0.0.1:4000', screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  webServer: { command: 'node scripts/serve.cjs', url: 'http://127.0.0.1:4000', reuseExistingServer: !process.env.CI },
  snapshotPathTemplate: '{testDir}/visual-baselines/{arg}{ext}',
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'webkit', testMatch: /smoke\.spec\.cjs/, use: { ...devices['Desktop Safari'] } },
  ],
  reporter: [['list'], ['html', {open:'never'}]],
});
