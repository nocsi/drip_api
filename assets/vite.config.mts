import { defineConfig } from 'vite';
import { enhancedImages } from '@sveltejs/enhanced-img';
import tailwindcss from '@tailwindcss/vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { sveltePreprocess } from "svelte-preprocess";
import tsconfigPaths from "vite-tsconfig-paths";
import path from "path";
import fs from "fs";
import fg from "fast-glob";
import { viteStaticCopy } from "vite-plugin-static-copy";

const rootDir = path.resolve(import.meta.dirname);
const cssDir = path.resolve(rootDir, "css");
const jsDir = path.resolve(rootDir, "js");
const srcImgDir = path.resolve(rootDir, "images");
const seoDir = path.resolve(rootDir, "seo");
const iconsDir = path.resolve(rootDir, "icons");
const staticDir = path.resolve(rootDir, "../priv/static");

// Cache for entry points to avoid repeated file system scans
let entryPointsCache: string[] | null = null;

function getEntryPoints(): string[] {
  if (entryPointsCache) {
    return entryPointsCache;
  }

  const entries: string[] = [];

  try {
    // Use a single glob pattern for better performance
    const jsFiles = fg.sync([`${jsDir}/**/*.{js,jsx,ts,tsx,svelte}`], {
      absolute: true,
      onlyFiles: true
    });

    const imageFiles = fg.sync([`${srcImgDir}/**/*.{jpg,jpeg,png,svg,webp}`], {
      absolute: true,
      onlyFiles: true
    });

    entries.push(...jsFiles, ...imageFiles);
    entryPointsCache = entries;
  } catch (error) {
    console.warn('[vite.config] Error scanning entry points:', error);
    // Fallback to main app file
    entries.push(path.resolve(jsDir, "app.ts"));
  }

  return entries;
}

const buildOps = (mode: string) => ({
  target: ["esnext"],
  outDir: staticDir,
  cssCodeSplit: mode === "production",
  cssMinify: mode === "production" ? "lightningcss" : false,
  external: [
    'svelte',
    'svelte/internal',
    'svelte/internal/client',
  ],
  rollupOptions: {
    input: mode === "production" ? getEntryPoints() : [path.resolve(jsDir, "app.ts")],
    output: mode === "production" ? {
      assetFileNames: "assets/[name][extname]",
      chunkFileNames: "assets/[name]-[hash].js",
      entryFileNames: "assets/[name]-[hash].js",
      // Optimize chunk splitting
      manualChunks: {
        vendor: ["phoenix", "phoenix_html", "phoenix_live_view"],
        svelte: ["svelte", "live_svelte"]
      }
    } : undefined,
    // Improve tree shaking
    treeshake: {
      moduleSideEffects: false,
      propertyReadSideEffects: false,
      unknownGlobalSideEffects: false
    }
  },
  manifest: mode === "production" ? ".vite/manifest.json" : false,
  minify: mode === "production" ? "esbuild" : false,
  emptyOutDir: true,
  sourcemap: mode === "development" ? "inline" : true,
  reportCompressedSize: mode === "production",
  assetsInlineLimit: 4096, // Inline small assets for better performance
  // Enable chunk size warnings
  chunkSizeWarningLimit: 500
});

function copyStaticAssetsDev(): void {
  console.log("[vite.config] Copying non-fingerprinted assets in dev mode...");

  const copyTargets = [
    {
      srcDir: seoDir,
      destDir: staticDir
    },
    {
      srcDir: iconsDir,
      destDir: path.resolve(staticDir, "icons")
    }
  ];

  copyTargets.forEach(({ srcDir, destDir }) => {
    if (!fs.existsSync(srcDir)) {
      console.log(`[vite.config] Source dir not found: ${srcDir}`);
      return;
    }

    try {
      if (!fs.existsSync(destDir)) {
        fs.mkdirSync(destDir, { recursive: true });
      }

      const files = fg.sync(`${srcDir}/**/*.*`, { onlyFiles: true });

      files.forEach((srcPath) => {
        const relPath = path.relative(srcDir, srcPath);
        const destPath = path.join(destDir, relPath);
        const destSubdir = path.dirname(destPath);

        if (!fs.existsSync(destSubdir)) {
          fs.mkdirSync(destSubdir, { recursive: true });
        }

        fs.copyFileSync(srcPath, destPath);
      });
    } catch (error) {
      console.error(`[vite.config] Error copying assets from ${srcDir}:`, error);
    }
  });
}

const getBuildTargets = () => {
  const baseTargets = [];

  try {
    // Only add targets if source directories exist
    if (fs.existsSync(seoDir)) {
      baseTargets.push({
        src: path.resolve(seoDir, "**", "*"),
        dest: staticDir
      });
    }

    if (fs.existsSync(iconsDir)) {
      baseTargets.push({
        src: path.resolve(iconsDir, "**", "*"),
        dest: path.resolve(staticDir, "icons")
      });
    }

    // Handle web manifest if it exists
    const devManifestPath = path.resolve(staticDir, "manifest.webmanifest");
    if (fs.existsSync(devManifestPath)) {
      baseTargets.push({
        src: devManifestPath,
        dest: staticDir,
      });
    }
  } catch (error) {
    console.warn('[vite.config] Error setting up build targets:', error);
  }

  return baseTargets;
};

const resolveConfig = {
  alias: {
    "@": rootDir,
    "@js": jsDir,
    "@jsx": jsDir,
    "@css": cssDir,
    "@static": staticDir,
    "@assets": srcImgDir,
    $lib: path.resolve("./svelte/lib"),
  },
  extensions: [
    ".svelte",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".png",
    ".css",
    ".webp",
    ".jpg",
    ".jpeg",
    ".svg"
  ],
  mainFields: ["svelte", "browser", "module", "main"],
  conditions: ["svelte", "browser"]
};

const devServer = {
  cors: { origin: "http://localhost:4000" },
  allowedHosts: ["localhost"],
  strictPort: true,
  origin: "http://localhost:5180",
  port: 5180,
  host: "localhost",
  // Improve HMR performance
  hmr: {
    overlay: true
  },
  watch: {
    ignored: [
      "**/priv/static/**",
      "**/lib/**",
      "**/*.ex",
      "**/*.exs",
      "**/node_modules/**"
    ],
    // Use polling for better file watching on some systems
    usePolling: false
  }
};

export default defineConfig(({ command, mode }) => {
  const isDev = mode === "development";
  const isProd = mode === "production";

  if (command === "serve") {
    console.log("[vite.config] Running in development mode");
    // Clear entry points cache in development
    entryPointsCache = null;

    // Copy static assets in development
    copyStaticAssetsDev();

    // Handle process cleanup
    process.stdin.on("close", () => process.exit(0));
    process.stdin.resume();
  }

  return {
    base: "/",
    plugins: [
      tsconfigPaths(),
      tailwindcss(),
      svelte({
        compilerOptions: {
          css: 'external',
          dev: isDev,
          hydratable: true
        },
        configFile: path.resolve(rootDir, 'svelte.config.js'),
        preprocess: [sveltePreprocess({
          typescript: true,
          // Add PostCSS processing
          // postcss: true
        })]
      }),
      viteStaticCopy({
        targets: getBuildTargets(),
        // Only watch in development
        watch: isDev
      })
    ],
    resolve: resolveConfig,
    server: isDev ? devServer : undefined,
    build: buildOps(mode),
    publicDir: false,
    // Optimize dependencies
    optimizeDeps: {
      include: [
        "phoenix",
        "phoenix_html",
        "phoenix_live_view",
        "topbar"
      ],
      exclude: [
        "svelte",
        "live_svelte"
      ]
    },
    // Add esbuild options for better performance
    esbuild: {
      target: "esnext",
      // Drop console logs in production
      drop: isProd ? ["console", "debugger"] : []
    }
  };
});
