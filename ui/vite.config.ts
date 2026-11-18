import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The app is served by the ColdBox module, not by an index.html:
// - build: ../dist plus a manifest that models/StudioAssets.cfc reads
// - dev: set CBSTUDIO_DEV_SERVER=http://localhost:5173 in ContentBox's .env, run `npm run dev`, open /cbstudio
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    manifest: true,
    rollupOptions: { input: 'src/main.tsx' },
  },
  server: {
    port: 5173,
    strictPort: true,
    origin: 'http://localhost:5173',
  },
})
