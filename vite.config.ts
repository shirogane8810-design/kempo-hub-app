import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { defineConfig } from 'vitest/config'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: '日本拳法 大会ハブ',
        short_name: '拳法ハブ',
        lang: 'ja',
        start_url: '/',
        display: 'standalone',
        background_color: '#ffffff',
        theme_color: '#1f2937',
        icons: [{ src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml' }],
      },
    }),
  ],
  test: {
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
  },
})
