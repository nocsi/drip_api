import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
  extensions: ['.svelte'],
	preprocess: vitePreprocess(),
	compilerOptions: {
	// Enable runes mode for Svelte 5
	  runes: true
	},
	vitePlugin: {
      exclude: [],
      // experimental options
      experimental: {}
    }
};

export default config;
