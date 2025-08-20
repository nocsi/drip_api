<script lang="ts">
  import { onMount } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';

  interface Props extends LiveSvelteProps {
    [key: string]: any;
  }

  let { live, ...props }: Props = $props();
  let mounted = $state(false);
  
  onMount(() => {
    mounted = true;
  });
</script>

<section class="relative space-y-6 py-12 sm:py-20 lg:py-24 overflow-hidden">
  <!-- Background Effects -->
  <div class="absolute inset-0 bg-gradient-to-br from-blue-50 via-white to-purple-50 -z-10"></div>
  <div class="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-full blur-3xl -z-10"></div>
  
  <div class="container flex max-w-6xl flex-col items-center gap-8 text-center relative mx-auto px-4">
    <!-- Badge -->
    <div class="px-4 py-2 text-sm font-medium bg-blue-50 text-blue-700 border border-blue-200 rounded-full inline-flex items-center">
      ⚡ Powered by Build + Lang + Proc + Store
    </div>

    <!-- Main Headline -->
    <div class="space-y-4">
      <h1 class="font-bold text-4xl sm:text-5xl md:text-6xl lg:text-7xl tracking-tight">
        You think you're just
        <br />
        <span class="text-slate-700">writing</span>
        <span class="bg-gradient-to-r from-blue-600 via-purple-600 to-pink-600 bg-clip-text text-transparent">
          documents...
        </span>
      </h1>
      
      <p class="max-w-4xl text-slate-600 sm:text-xl lg:text-2xl sm:leading-8 lg:leading-10 mx-auto">
        Behind every keystroke is an entire <strong>computational infrastructure</strong> 
        designed to make your ideas <strong>executable</strong>, <strong>collaborative</strong>, and <strong>infinitely scalable</strong>.
      </p>
    </div>

    <!-- Static Infrastructure Showcase -->
    <div class="flex items-center justify-center space-x-2 sm:space-x-4 mb-8">
      <div class="flex flex-col items-center space-y-2">
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-r from-blue-500 to-cyan-500 flex items-center justify-center shadow-lg text-white text-2xl font-bold">
          B
        </div>
        <span class="text-sm font-bold text-slate-700">Build</span>
      </div>
      <div class="text-slate-400">→</div>
      <div class="flex flex-col items-center space-y-2">
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-r from-green-500 to-emerald-500 flex items-center justify-center shadow-lg text-white text-2xl font-bold">
          L
        </div>
        <span class="text-sm font-bold text-slate-700">Lang</span>
      </div>
      <div class="text-slate-400">→</div>
      <div class="flex flex-col items-center space-y-2">
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-r from-purple-500 to-pink-500 flex items-center justify-center shadow-lg text-white text-2xl font-bold">
          P
        </div>
        <span class="text-sm font-bold text-slate-700">Proc</span>
      </div>
      <div class="text-slate-400">→</div>
      <div class="flex flex-col items-center space-y-2">
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-r from-orange-500 to-red-500 flex items-center justify-center shadow-lg text-white text-2xl font-bold">
          S
        </div>
        <span class="text-sm font-bold text-slate-700">Store</span>
      </div>
    </div>

    <!-- What Happens When... -->
    <div class="bg-slate-50 rounded-2xl p-6 sm:p-8 max-w-4xl border border-slate-200 shadow-sm">
      <p class="text-sm text-slate-500 mb-2">When you type:</p>
      <code class="text-lg sm:text-xl font-mono bg-white px-4 py-2 rounded-lg border text-green-600 inline-block mb-4">
        import pandas as pd
      </code>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
        <div class="bg-white rounded-lg p-3 text-center border shadow-sm">
          <div class="w-8 h-8 mx-auto mb-2 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-sm">L</div>
          <p class="text-xs font-medium text-slate-700">Runtime spins up</p>
        </div>
        <div class="bg-white rounded-lg p-3 text-center border shadow-sm">
          <div class="w-8 h-8 mx-auto mb-2 bg-orange-500 rounded-full flex items-center justify-center text-white font-bold text-sm">S</div>
          <p class="text-xs font-medium text-slate-700">Data loads</p>
        </div>
        <div class="bg-white rounded-lg p-3 text-center border shadow-sm">
          <div class="w-8 h-8 mx-auto mb-2 bg-purple-500 rounded-full flex items-center justify-center text-white font-bold text-sm">P</div>
          <p class="text-xs font-medium text-slate-700">AI suggests</p>
        </div>
        <div class="bg-white rounded-lg p-3 text-center border shadow-sm">
          <div class="w-8 h-8 mx-auto mb-2 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-sm">B</div>
          <p class="text-xs font-medium text-slate-700">Team syncs</p>
        </div>
      </div>
    </div>

    <!-- CTA Buttons -->
    <div class="flex flex-col sm:flex-row justify-center space-y-2 sm:space-y-0 sm:space-x-4">
      <a 
        href="/editor" 
        class="px-8 py-4 text-lg font-semibold bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white rounded-full shadow-lg hover:scale-105 transform transition-all duration-200"
      >
        ⚡ Experience the Power
      </a>
      <a
        href="#demo"
        class="px-8 py-4 text-lg font-semibold border-2 border-slate-300 text-slate-700 hover:border-slate-400 rounded-full transition-all duration-200"
      >
        See It Live →
      </a>
    </div>

    <!-- Subtle Stats -->
    <div class="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-8 text-sm text-slate-500 pt-8">
      <div class="flex items-center space-x-2">
        <div class="w-2 h-2 bg-green-500 rounded-full"></div>
        <span>Multi-language execution</span>
      </div>
      <div class="flex items-center space-x-2">
        <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
        <span>Real-time collaboration</span>
      </div>
      <div class="flex items-center space-x-2">
        <div class="w-2 h-2 bg-purple-500 rounded-full"></div>
        <span>AI-powered insights</span>
      </div>
    </div>
  </div>
</section>