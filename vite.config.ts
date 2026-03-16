import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import * as Path from 'node:path';

// https://vitejs.dev/config/
export default defineConfig({
	base: '/shaders/',
	plugins: [vue()],
	resolve: {
		alias: {
			'@': Path.resolve('src'),
		},
	},
	server: {
		host: true,
		allowedHosts: true,
	},
})
