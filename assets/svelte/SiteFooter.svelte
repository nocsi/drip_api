<script lang="ts">
  import { Button } from './ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
  import { Input } from './ui/input';
  import { Github, Twitter, Mail } from '@lucide/svelte';

  interface SiteFooterProps {
    class?: string;
  }

  let { class: className }: SiteFooterProps = $props();
</script>

<!-- Beautiful ShadCN Footer -->
<footer class="relative z-10 py-20 px-6 bg-slate-950 backdrop-blur-sm border-t border-slate-800 text-white {className}">
  <div class="max-w-7xl mx-auto">
    <div class="grid md:grid-cols-4 gap-8 mb-16">
      <!-- Company Info -->
      <div class="md:col-span-2">
        <div class="flex items-center space-x-2 mb-6">
          <svg width="32" height="32" viewBox="0 0 32 32">
            <defs>
              <linearGradient id="kyozoGradFooter" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#56939a"/>
                <stop offset="50%" style="stop-color:#63a2ac"/>
                <stop offset="100%" style="stop-color:#75b7bb"/>
              </linearGradient>
            </defs>
            <rect x="4" y="12" width="24" height="16" rx="2" fill="url(#kyozoGradFooter)" opacity="0.8"/>
            <rect x="6" y="8" width="20" height="14" rx="2" fill="url(#kyozoGradFooter)" opacity="0.9"/>
            <rect x="8" y="4" width="16" height="12" rx="2" fill="url(#kyozoGradFooter)"/>
            <circle cx="16" cy="10" r="2" fill="white"/>
          </svg>
          <span class="text-xl font-bold bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent">
            Kyozo Store
          </span>
        </div>
        <p class="text-gray-300 mb-6 max-w-md">
          Transforming folders into services. The future of development is here, and it's as simple as organizing your files.
        </p>
        <div class="flex space-x-4">
          <Button variant="ghost" size="icon" class="text-gray-400 hover:text-white">
            <a href="https://github.com/nocsi">
              <Github class="h-5 w-5" />
            </a>
          </Button>
          <Button variant="ghost" size="icon" class="text-gray-400 hover:text-white">
            <a href="https://x.com/nocsi_">
              <Twitter class="h-5 w-5" />
            </a>
          </Button>
        </div>
      </div>

      <!-- Product Links -->
      <div>
        <h3 class="text-white font-semibold mb-4">Product</h3>
        <ul class="space-y-3 text-gray-300">
          <li><a href="/#features" class="hover:text-white transition-colors">Features</a></li>
          <li><a href="/#architecture" class="hover:text-white transition-colors">Architecture</a></li>
          <li><a href="/#services" class="hover:text-white transition-colors">Services</a></li>
          <li><a href="/editor" class="hover:text-white transition-colors">Editor</a></li>
        </ul>
      </div>

      <!-- Company Links -->
      <div>
        <h3 class="text-white font-semibold mb-4">Company</h3>
        <ul class="space-y-3 text-gray-300">
          <li><a href="#about" class="hover:text-white transition-colors">About</a></li>
          <li><a href="#blog" class="hover:text-white transition-colors">Blog</a></li>
          <li><a href="#contact" class="hover:text-white transition-colors">Contact</a></li>
        </ul>
      </div>
    </div>

    <!-- Newsletter Section -->
    <div class="border-t border-slate-800 pt-12 mb-12">
      <Card class="bg-slate-800/50 backdrop-blur-sm border-slate-700 max-w-2xl mx-auto">
        <CardHeader class="text-center">
          <CardTitle class="text-2xl font-bold text-white mb-2">Stay Updated</CardTitle>
          <CardDescription class="text-gray-300">
            Get the latest updates about Kyozo Store delivered to your inbox
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div class="flex flex-col sm:flex-row gap-4">
            <Input
              type="email"
              placeholder="Enter your email"
              class="bg-slate-800 border-slate-700 text-white placeholder:text-gray-400 flex-1"
            />
            <Button class="bg-teal-600 hover:bg-teal-700 text-white">
              <Mail class="mr-2 h-4 w-4" />
              Subscribe
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Copyright -->
    <div class="border-t border-slate-800 pt-8 flex flex-col sm:flex-row justify-between items-center">
      <p class="text-gray-400 text-sm">
        © 2025 NOCSI. All rights reserved.
      </p>
      <div class="flex space-x-6 mt-4 sm:mt-0">
        <a href="#privacy" class="text-gray-400 hover:text-white text-sm transition-colors">Privacy Policy</a>
        <a href="#terms" class="text-gray-400 hover:text-white text-sm transition-colors">Terms of Service</a>
      </div>
    </div>
  </div>
</footer>
