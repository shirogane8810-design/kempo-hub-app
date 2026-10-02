import { expect, test } from '@playwright/test'

test('トップページが表示される', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toContainText('日本拳法 大会ハブ')
})

test('審判画面は共通ヘッダーなしで開く', async ({ page }) => {
  await page.goto('/ref')
  await expect(page.getByRole('heading', { name: '審判画面' })).toBeVisible()
  await expect(page.getByRole('banner')).toHaveCount(0)
})
