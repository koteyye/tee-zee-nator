import { defineConfig } from 'vite'

export default defineConfig({
  optimizeDeps: {
    include: ['monaco-editor', 'marked']
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          monaco: ['monaco-editor'],
          marked: ['marked']
        }
      }
    }
  },
  define: {
    global: 'globalThis'
  },
  worker: {
    format: 'es'
  }
})
