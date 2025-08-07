<script>
  import { Button } from '$lib/ui/button';
  import { Sheet, SheetContent, SheetTrigger } from '$lib/ui/sheet';
  import {
    FileText,
    Menu,
    Github,
    Star,
    ExternalLink
  } from '@lucide/svelte';

  let mobileMenuOpen = $state(false);

  const navigation = [
    { name: 'Features', href: '#features' },
    { name: 'How it works', href: '#how-it-works' },
    { name: 'Pricing', href: '#pricing' },
    { name: 'Docs', href: '/docs' },
    { name: 'Examples', href: '/examples' }
  ];

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }
</script>

<header class="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="flex h-16 items-center justify-between">
      <!-- Logo -->
      <div class="flex items-center">
        <a href="/" class="flex items-center space-x-2">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <FileText class="w-5 h-5 text-primary-foreground" />
          </div>
          <span class="text-xl font-bold">Kyozo</span>
        </a>
      </div>

      <!-- Desktop Navigation -->
      <nav class="hidden md:flex md:space-x-8">
        {#each navigation as item}
          <a
            href={item.href}
            class="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
          >
            {item.name}
          </a>
        {/each}
      </nav>

      <!-- Desktop Actions -->
      <div class="hidden md:flex md:items-center md:space-x-4">
        <Button variant="ghost" size="sm" class="text-sm">
          <Github class="mr-2 h-4 w-4" />
          <Star class="mr-1 h-3 w-3" />
          Star
        </Button>
        <Button variant="outline" size="sm">
          Sign in
        </Button>
        <Button size="sm">
          Get started
        </Button>
      </div>

      <!-- Mobile menu button -->
      <div class="md:hidden">
        <Sheet bind:open={mobileMenuOpen}>
          <SheetTrigger asChild>
            <Button variant="ghost" size="sm">
              <Menu class="h-5 w-5" />
              <span class="sr-only">Toggle menu</span>
            </Button>
          </SheetTrigger>
          <SheetContent side="right" class="w-80">
            <div class="flex flex-col space-y-6">
              <!-- Mobile Logo -->
              <div class="flex items-center space-x-2">
                <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                  <FileText class="w-5 h-5 text-primary-foreground" />
                </div>
                <span class="text-xl font-bold">Kyozo</span>
              </div>

              <!-- Mobile Navigation -->
              <nav class="flex flex-col space-y-4">
                {#each navigation as item}
                  <a
                    href={item.href}
                    class="text-base font-medium text-foreground hover:text-primary transition-colors"
                    onclick={closeMobileMenu}
                  >
                    {item.name}
                  </a>
                {/each}
              </nav>

              <!-- Mobile Actions -->
              <div class="flex flex-col space-y-3 pt-6 border-t">
                <Button variant="ghost" class="justify-start">
                  <Github class="mr-2 h-4 w-4" />
                  <Star class="mr-1 h-3 w-3" />
                  Star on GitHub
                  <ExternalLink class="ml-auto h-3 w-3" />
                </Button>
                <Button variant="outline" class="w-full">
                  Sign in
                </Button>
                <Button class="w-full">
                  Get started
                </Button>
              </div>
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </div>
  </div>
</header>