import { fileURLToPath, URL } from 'node:url'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  build: {
    // the Go binary embeds this directory
    outDir: '../server/dist',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/api': `http://localhost:${process.env.PORT ?? 8080}`,
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    // a repo that has just deleted the demo has no tests yet; that is not a failure
    passWithNoTests: true,
  },
})
