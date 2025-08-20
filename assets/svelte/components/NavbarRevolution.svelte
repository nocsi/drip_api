<script>
  import { onMount } from 'svelte';
  import { Button } from '$lib/components/ui/button';
  
  let { isScrolled = false } = $props();
  let scrollY = $state(0);
  let mobileMenuOpen = $state(false);
  
  const navItems = [
    { href: '#products', label: 'Platform' },
    { href: '#use-cases', label: 'Use Cases' },
    { href: '#enterprise', label: 'Enterprise' },
    { href: '/openapi', label: 'API Docs' },
    { href: '/pricing', label: 'Pricing' }
  ];
  
  onMount(() => {
    const handleScroll = () => {
      scrollY = window.scrollY;
    };
    
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  });
  
  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
  }
  
  function closeMobileMenu() {
    mobileMenuOpen = false;
  }
</script>

<svelte:window bind:scrollY />

<nav class="fixed top-0 w-full z-50 transition-all duration-300 {scrollY > 50 ? 'bg-slate-950/95 backdrop-blur-md border-b border-slate-800/50' : 'bg-transparent'}">
  <div class="max-w-7xl mx-auto px-6">
    <div class="flex items-center justify-between h-20">
      
      <!-- Logo -->
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 bg-gradient-to-r from-teal-500 to-cyan-500 rounded-lg flex items-center justify-center">
          <span class="text-white font-bold text-xl">K</span>
        </div>
        <div class="flex flex-col">
          <span class="text-white font-bold text-xl">Kyozo</span>
          <span class="text-xs text-teal-400 -mt-1">Folder as a Service</span>
        </div>
      </div>

      <!-- Desktop Navigation -->
      <div class="hidden md:flex items-center space-x-8">
        {#each navItems as item}
          <a 
            href={item.href} 
            class="text-gray-300 hover:text-white transition-colors duration-200 font-medium"
          >
            {item.label}
          </a>
        {/each}
      </div>

      <!-- Desktop Actions -->
      <div class="hidden md:flex items-center space-x-4">
        <a 
          href="/auth/login" 
          class="text-gray-300 hover:text-white transition-colors duration-200 font-medium"
        >
          Sign In
        </a>
        
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-6 py-2 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105">
          <a href="/auth/register">Start Free Trial</a>
        </Button>
      </div>

      <!-- Mobile Menu Button -->
      <button 
        class="md:hidden text-white p-2"
        onclick={toggleMobileMenu}
        aria-label="Toggle mobile menu"
      >
        {#if mobileMenuOpen}
          <!-- Close Icon -->
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        {:else}
          <!-- Menu Icon -->
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
          </svg>
        {/if}
      </button>
    </div>
  </div>

  <!-- Mobile Menu -->
  {#if mobileMenuOpen}
    <div class="md:hidden bg-slate-950/98 backdrop-blur-md border-t border-slate-800/50">
      <div class="px-6 py-6 space-y-4">
        {#each navItems as item}
          <a 
            href={item.href}
            class="block text-gray-300 hover:text-white transition-colors duration-200 font-medium py-2"
            onclick={closeMobileMenu}
          >
            {item.label}
          </a>
        {/each}
        
        <div class="border-t border-slate-800/50 pt-4 space-y-4">
          <a 
            href="/auth/login"
            class="block text-gray-300 hover:text-white transition-colors duration-200 font-medium py-2"
            onclick={closeMobileMenu}
          >
            Sign In
          </a>
          
          <Button class="w-full bg-gradient-to-r from-teal-500 to-cyan-500 text-white py-3 rounded-lg font-semibold">
            <a href="/auth/register" onclick={closeMobileMenu}>Start Free Trial</a>
          </Button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Revolutionary Badge -->
  {#if scrollY < 100}
    <div class="absolute -bottom-6 left-1/2 transform -translate-x-1/2">
      <div class="bg-gradient-to-r from-orange-500 to-red-500 text-white px-4 py-2 rounded-full text-sm font-medium border-2 border-slate-900 animate-pulse">
        🚀 Directory Organization IS Deployment Strategy
      </div>
    </div>
  {/if}
</nav>

<!-- Spacer to prevent content overlap -->
<div class="h-20"></div>

<style>
  nav {
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
  }
</style>