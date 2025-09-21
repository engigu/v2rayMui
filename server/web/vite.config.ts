import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'

export default defineConfig({
  plugins: [
    vue(),
    AutoImport({
      imports: [
        'vue',
        'vue-router',
        '@vueuse/core'
      ],
      dts: true
    }),
    Components({
      dts: true
    })
  ],
  publicDir: resolve(__dirname, 'src/public'),
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src')
    }
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: `http://localhost:${process.env.VITE_API_PORT || '58080'}`,
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: '../dist'
  }
})
