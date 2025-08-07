<script>
  import { Button } from '$lib/ui/button';
  import { Separator } from '$lib/ui/separator';
  import {
    Github,
    Twitter,
    Linkedin,
    Mail,
    FileText,
    Heart
  } from '@lucide/svelte';

  const currentYear = new Date().getFullYear();

  const footerLinks = {
    product: [
      { name: 'Features', href: '#features' },
      { name: 'Pricing', href: '#pricing' },
      { name: 'Documentation', href: '/docs' },
      { name: 'Examples', href: '/examples' },
      { name: 'Changelog', href: '/changelog' }
    ],
    company: [
      { name: 'About', href: '/about' },
      { name: 'Blog', href: '/blog' },
      { name: 'Careers', href: '/careers' },
      { name: 'Contact', href: '/contact' },
      { name: 'Press Kit', href: '/press' }
    ],
    resources: [
      { name: 'Community', href: '/community' },
      { name: 'Help Center', href: '/help' },
      { name: 'Status', href: '/status' },
      { name: 'API Reference', href: '/api' },
      { name: 'Tutorials', href: '/tutorials' }
    ],
    legal: [
      { name: 'Privacy Policy', href: '/privacy' },
      { name: 'Terms of Service', href: '/terms' },
      { name: 'Cookie Policy', href: '/cookies' },
      { name: 'Security', href: '/security' }
    ]
  };

  const socialLinks = [
    { name: 'GitHub', href: 'https://github.com/kyozo', icon: Github },
    { name: 'Twitter', href: 'https://twitter.com/kyozo', icon: Twitter },
    { name: 'LinkedIn', href: 'https://linkedin.com/company/kyozo', icon: Linkedin },
    { name: 'Email', href: 'mailto:hello@kyozo.dev', icon: Mail }
  ];

  let email = $state('');

  function handleSubscribe() {
    if (email) {
      console.log('Subscribing:', email);
      // Handle newsletter subscription
      email = '';
    }
  }
</script>

<footer class="bg-background border-t">
  <div class="mx-auto max-w-7xl px-6 py-16 lg:px-8">
    <!-- Main Footer Content -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-8">
      <!-- Brand Section -->
      <div class="lg:col-span-2">
        <div class="flex items-center mb-4">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center mr-3">
            <FileText class="w-5 h-5 text-primary-foreground" />
          </div>
          <span class="text-xl font-bold">Kyozo</span>
        </div>
        <p class="text-muted-foreground text-sm leading-relaxed mb-6 max-w-sm">
          The future of executable documentation. Transform your markdown notes into interactive,
          living documents that combine beautiful prose with live code execution.
        </p>

        <!-- Social Links -->
        <div class="flex space-x-4">
          {#each socialLinks as social}
            <a
              href={social.href}
              class="text-muted-foreground hover:text-foreground transition-colors"
              aria-label={social.name}
            >
              <social.icon class="w-5 h-5" />
            </a>
          {/each}
        </div>
      </div>

      <!-- Product Links -->
      <div>
        <h3 class="text-sm font-semibold text-foreground mb-4">Product</h3>
        <ul class="space-y-3">
          {#each footerLinks.product as link}
            <li>
              <a
                href={link.href}
                class="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                {link.name}
              </a>
            </li>
          {/each}
        </ul>
      </div>

      <!-- Company Links -->
      <div>
        <h3 class="text-sm font-semibold text-foreground mb-4">Company</h3>
        <ul class="space-y-3">
          {#each footerLinks.company as link}
            <li>
              <a
                href={link.href}
                class="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                {link.name}
              </a>
            </li>
          {/each}
        </ul>
      </div>

      <!-- Resources Links -->
      <div>
        <h3 class="text-sm font-semibold text-foreground mb-4">Resources</h3>
        <ul class="space-y-3">
          {#each footerLinks.resources as link}
            <li>
              <a
                href={link.href}
                class="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                {link.name}
              </a>
            </li>
          {/each}
        </ul>
      </div>

      <!-- Legal Links -->
      <div>
        <h3 class="text-sm font-semibold text-foreground mb-4">Legal</h3>
        <ul class="space-y-3">
          {#each footerLinks.legal as link}
            <li>
              <a
                href={link.href}
                class="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                {link.name}
              </a>
            </li>
          {/each}
        </ul>
      </div>
    </div>

    <!-- Newsletter Signup -->
    <div class="mt-12 pt-8 border-t">
      <div class="flex flex-col lg:flex-row items-center justify-between gap-6">
        <div class="text-center lg:text-left">
          <h3 class="text-lg font-semibold mb-2">Stay updated</h3>
          <p class="text-muted-foreground text-sm">
            Get the latest features, tutorials, and product updates delivered to your inbox.
          </p>
        </div>
        <form class="flex w-full max-w-sm gap-2" onsubmit={handleSubscribe}>
          <input
            type="email"
            bind:value={email}
            placeholder="Enter your email"
            class="flex-1 px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"
            required
          />
          <Button type="submit" size="sm" class="px-4">
            Subscribe
          </Button>
        </form>
      </div>
    </div>

    <Separator class="my-8" />

    <!-- Bottom Footer -->
    <div class="flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-muted-foreground">
      <div class="flex items-center">
        <span>&copy; {currentYear} Kyozo. All rights reserved.</span>
      </div>

      <div class="flex items-center gap-1">
        <span>Made with</span>
        <Heart class="w-4 h-4 text-red-500 fill-current" />
        <span>for developers and researchers</span>
      </div>
    </div>
  </div>
</footer>