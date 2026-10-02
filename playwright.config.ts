import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: 'e2e',
  use: {
    baseURL: 'http://localhost:4173',
    // ブラウザを別の場所に入れている環境用（通常は不要）
    launchOptions: process.env.PW_CHROMIUM_PATH ? { executablePath: process.env.PW_CHROMIUM_PATH } : {},
  },
  webServer: { command: 'npm run build && npm run preview -- --port 4173', port: 4173, reuseExistingServer: true },
})
