<script>
  import { Card, CardDescription, CardHeader, CardTitle } from '$lib/ui/card';
  import { Badge } from '$lib/ui/badge';
  import {
    Code2,
    FileText,
    PlayCircle,
    GitBranch,
    Layers,
    Zap,
    Database,
    Share2,
    Eye,
    Palette,
    Terminal,
    BookOpen
  } from '@lucide/svelte';
</script>

<section class="py-24 bg-muted/30">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="text-center mb-16">
      <Badge variant="outline" class="mb-4">Features</Badge>
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        Everything you need for literate programming
      </h2>
      <p class="mt-4 text-lg text-muted-foreground max-w-2xl mx-auto">
        Powerful features designed to make your executable documentation workflow seamless and productive.
      </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      <!-- Multi-language Support -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-blue-100 dark:bg-blue-900/20 flex items-center justify-center mb-4">
            <Code2 class="w-6 h-6 text-blue-600 dark:text-blue-400" />
          </div>
          <CardTitle>Multi-language Support</CardTitle>
          <CardDescription>
            Execute Python, JavaScript, R, SQL, and more within the same document
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Live Execution -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-green-100 dark:bg-green-900/20 flex items-center justify-center mb-4">
            <PlayCircle class="w-6 h-6 text-green-600 dark:text-green-400" />
          </div>
          <CardTitle>Live Execution</CardTitle>
          <CardDescription>
            Run code blocks instantly and see results in real-time as you type
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Rich Formatting -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-purple-100 dark:bg-purple-900/20 flex items-center justify-center mb-4">
            <FileText class="w-6 h-6 text-purple-600 dark:text-purple-400" />
          </div>
          <CardTitle>Rich Formatting</CardTitle>
          <CardDescription>
            Beautiful markdown rendering with syntax highlighting and math support
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Version Control Ready -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-orange-100 dark:bg-orange-900/20 flex items-center justify-center mb-4">
            <GitBranch class="w-6 h-6 text-orange-600 dark:text-orange-400" />
          </div>
          <CardTitle>Version Control Ready</CardTitle>
          <CardDescription>
            Plain markdown files that work perfectly with Git and GitHub
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Interactive Widgets -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-red-100 dark:bg-red-900/20 flex items-center justify-center mb-4">
            <Layers class="w-6 h-6 text-red-600 dark:text-red-400" />
          </div>
          <CardTitle>Interactive Widgets</CardTitle>
          <CardDescription>
            Add sliders, dropdowns, and controls to make your documents interactive
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Fast Performance -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-yellow-100 dark:bg-yellow-900/20 flex items-center justify-center mb-4">
            <Zap class="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
          </div>
          <CardTitle>Lightning Fast</CardTitle>
          <CardDescription>
            Optimized execution engine with intelligent caching and incremental updates
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Data Integration -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-indigo-100 dark:bg-indigo-900/20 flex items-center justify-center mb-4">
            <Database class="w-6 h-6 text-indigo-600 dark:text-indigo-400" />
          </div>
          <CardTitle>Data Integration</CardTitle>
          <CardDescription>
            Connect to databases, APIs, and files with built-in data connectors
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Easy Sharing -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-teal-100 dark:bg-teal-900/20 flex items-center justify-center mb-4">
            <Share2 class="w-6 h-6 text-teal-600 dark:text-teal-400" />
          </div>
          <CardTitle>Easy Sharing</CardTitle>
          <CardDescription>
            Export to HTML, PDF, or share interactive notebooks with colleagues
          </CardDescription>
        </CardHeader>
      </Card>

      <!-- Live Preview -->
      <Card class="border-0 shadow-sm hover:shadow-md transition-shadow">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-pink-100 dark:bg-pink-900/20 flex items-center justify-center mb-4">
            <Eye class="w-6 h-6 text-pink-600 dark:text-pink-400" />
          </div>
          <CardTitle>Live Preview</CardTitle>
          <CardDescription>
            See your formatted document and code results side-by-side in real-time
          </CardDescription>
        </CardHeader>
      </Card>
    </div>

    <!-- Advanced Features Section -->
    <div class="mt-20">
      <div class="text-center mb-12">
        <h3 class="text-2xl font-bold tracking-tight">Advanced Capabilities</h3>
        <p class="mt-2 text-muted-foreground">
          Professional features for power users and teams
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="text-center">
          <div class="mx-auto w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6">
            <Terminal class="w-8 h-8 text-primary" />
          </div>
          <h4 class="text-lg font-semibold mb-2">Custom Environments</h4>
          <p class="text-muted-foreground text-sm">
            Configure custom Python environments, install packages, and manage dependencies per document
          </p>
        </div>

        <div class="text-center">
          <div class="mx-auto w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6">
            <Palette class="w-8 h-8 text-primary" />
          </div>
          <h4 class="text-lg font-semibold mb-2">Themes & Styling</h4>
          <p class="text-muted-foreground text-sm">
            Customize appearance with themes, CSS injection, and branded export templates
          </p>
        </div>

        <div class="text-center">
          <div class="mx-auto w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6">
            <BookOpen class="w-8 h-8 text-primary" />
          </div>
          <h4 class="text-lg font-semibold mb-2">Documentation Sites</h4>
          <p class="text-muted-foreground text-sm">
            Generate beautiful documentation websites from your executable notebooks
          </p>
        </div>
      </div>
    </div>
  </div>
</section>