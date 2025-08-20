<script lang="ts">
  import { Button } from '$lib/ui/button';
  import { Sheet, SheetContent, SheetTrigger } from '$lib/ui/sheet';
  import { Menu } from '@lucide/svelte';
  import { Icons } from '$lib/shared/icons';

  let mobileMenuOpen = $state(false);

  const navigation = [
    { name: 'Platform', href: '#platform' },
    { name: 'Architecture', href: '#architecture' },
    { name: 'Live Demo', href: '#demo' },
    { name: 'Get Started', href: '#get-started' }
  ];

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }
</script>

<header class="sticky top-0 z-50 w-full border-b border-white/10 bg-gradient-to-br from-slate-900 via-teal-900 to-slate-900 backdrop-blur supports-[backdrop-filter]:bg-gradient-to-br supports-[backdrop-filter]:from-slate-900/95 supports-[backdrop-filter]:via-teal-900/95 supports-[backdrop-filter]:to-slate-900/95">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="flex h-16 items-center justify-between">
      <!-- Logo -->
      <div class="flex items-center">
        <a href="/" class="flex items-center space-x-4">
          <Icons.logo size={40} />
          <div>
            <span class="text-2xl font-bold text-white">Kyozo Store</span>
            <div class="text-sm text-teal-300">Folder as a Service Platform</div>
          </div>
        </a>
      </div>

      <!-- Desktop Navigation -->
      <nav class="hidden md:flex md:space-x-8">
        {#each navigation as item}
          <a
            href={item.href}
            class="text-sm font-medium text-gray-300 hover:text-white hover:bg-white/5 px-4 py-2 rounded-lg transition-all"
          >
            {item.name}
          </a>
        {/each}
      </nav>

      <!-- Desktop Actions -->
      <div class="hidden md:flex md:items-center md:space-x-4">
        <Button 
          variant="ghost" 
          size="sm" 
          class="text-sm text-gray-300 hover:text-white hover:bg-white/5 border border-gray-600 hover:border-gray-400"
        >
          <a href="/openapi">Documentation</a>
        </Button>
        <Button 
          size="sm" 
          class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105"
        >
          <a href="/auth/register">Start Building</a>
        </Button>
      </div>

      <!-- Mobile menu button -->
      <div class="md:hidden">
        <Sheet bind:open={mobileMenuOpen}>
          <SheetTrigger asChild>
            <Button variant="ghost" size="sm" class="text-white hover:bg-white/10">
              <Menu class="h-5 w-5" />
              <span class="sr-only">Toggle menu</span>
            </Button>
          </SheetTrigger>
          <SheetContent side="right" class="w-80 bg-gradient-to-br from-slate-900 via-teal-900 to-slate-900 border-l border-white/10">
            <div class="flex flex-col space-y-6">
              <!-- Mobile Logo -->
              <div class="flex items-center space-x-4">
                <Icons.logo size={32} />
                <div>
                  <span class="text-xl font-bold text-white">Kyozo Store</span>
                  <div class="text-xs text-teal-300">Folder as a Service Platform</div>
                </div>
              </div>

              <!-- Mobile Navigation -->
              <nav class="flex flex-col space-y-4">
                {#each navigation as item}
                  <a
                    href={item.href}
                    class="text-base font-medium text-gray-300 hover:text-white hover:bg-white/5 px-4 py-3 rounded-lg transition-all"
                    onclick={closeMobileMenu}
                  >
                    {item.name}
                  </a>
                {/each}
              </nav>

              <!-- Mobile Actions -->
              <div class="flex flex-col space-y-3 pt-6 border-t border-white/10">
                <Button 
                  variant="outline" 
                  class="w-full text-gray-300 border-gray-600 hover:text-white hover:bg-white/5 hover:border-gray-400"
                >
                  <a href="/openapi">Documentation</a>
                </Button>
                <Button 
                  class="w-full bg-gradient-to-r from-teal-500 to-cyan-500 text-white hover:shadow-lg hover:shadow-teal-500/25 transition-all"
                >
                  <a href="/auth/register">Start Building</a>
                </Button>
              </div>
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </div>
  </div>
</header>