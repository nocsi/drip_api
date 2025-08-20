<script lang="ts">
  import { Button } from './ui/button';
  import { Sheet, SheetContent, SheetTrigger } from './ui/sheet';
  import { Menu, Github, Twitter } from '@lucide/svelte';
  import { Icons } from './shared/icons';

  interface NavBarProps {
    scroll?: boolean;
    large?: boolean;
    current_user?: any;
  }

  const { scroll = false, large = false, current_user }: NavBarProps = $props();
</script>

<svelte:head>
  <title>Kyozo Store - Folder as a Service Platform</title>
</svelte:head>

<!-- Modern ShadCN Navigation -->
<nav class="sticky top-0 z-50 border-b border-slate-800 bg-slate-900/80 backdrop-blur-xl">
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="flex h-16 items-center justify-between">
      <!-- Logo -->
      <div class="flex items-center space-x-4">
        <div class="flex items-center space-x-2">
          <!-- Kyozo Logo -->
          <Icons.logo size={32} />
          <a href="/" class="text-xl font-bold bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent">
            Kyozo Store
          </a>
        </div>
      </div>

      <!-- Desktop Navigation -->
      <div class="hidden md:block">
        <div class="ml-10 flex items-baseline space-x-8">
          <a href="/#features" class="text-gray-300 hover:text-white transition-colors duration-200 text-sm font-medium">Features</a>
          <a href="/#services" class="text-gray-300 hover:text-white transition-colors duration-200 text-sm font-medium">Services</a>
          <a href="/#architecture" class="text-gray-300 hover:text-white transition-colors duration-200 text-sm font-medium">Architecture</a>
          <a href="/openapi" class="text-gray-300 hover:text-white transition-colors duration-200 text-sm font-medium">Documentation</a>
          <a href="/editor" class="text-gray-300 hover:text-white transition-colors duration-200 text-sm font-medium">Editor</a>
        </div>
      </div>

      <!-- Desktop CTA -->
      <div class="hidden md:flex items-center space-x-4">
        {#if current_user}
          <Button variant="ghost" size="sm">
            <a href="/editor">Dashboard</a>
          </Button>
          <Button size="sm">
            <a href="/editor">Go to Editor</a>
          </Button>
        {:else}
          <Button variant="ghost" size="sm">
            <a href="/auth/sign_in">Sign In</a>
          </Button>
          <Button size="sm">
            <a href="/auth/register">Get Started</a>
          </Button>
        {/if}
      </div>

      <!-- Mobile menu button -->
      <div class="md:hidden">
        <Sheet>
          <SheetTrigger>
            <Button variant="ghost" size="icon">
              <Menu class="h-5 w-5 text-gray-300" />
            </Button>
          </SheetTrigger>
          <SheetContent side="right" class="bg-slate-900 backdrop-blur-xl border-slate-700">
            <div class="flex flex-col space-y-6 mt-8">
              <a href="/#features" class="text-gray-300 hover:text-white transition-colors text-lg font-medium">Features</a>
              <a href="/#services" class="text-gray-300 hover:text-white transition-colors text-lg font-medium">Services</a>
              <a href="/#architecture" class="text-gray-300 hover:text-white transition-colors text-lg font-medium">Architecture</a>
              <a href="/openapi" class="text-gray-300 hover:text-white transition-colors text-lg font-medium">Documentation</a>
              <a href="/editor" class="text-gray-300 hover:text-white transition-colors text-lg font-medium">Editor</a>
              <div class="border-t border-slate-700 pt-6 space-y-4">
                {#if current_user}
                  <Button variant="ghost" class="w-full justify-start">
                    <a href="/editor">Dashboard</a>
                  </Button>
                  <Button class="w-full">
                    <a href="/editor">Go to Editor</a>
                  </Button>
                {:else}
                  <Button variant="ghost" class="w-full justify-start">
                    <a href="/auth/sign_in">Sign In</a>
                  </Button>
                  <Button class="w-full">
                    <a href="/auth/register">Get Started</a>
                  </Button>
                {/if}
              </div>
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </div>
  </div>
</nav>