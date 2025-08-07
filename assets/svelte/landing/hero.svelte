<script>
  import { Button } from '$lib/ui/button';
  import { Badge } from '$lib/ui/badge';
  import { Code2, PlayCircle, FileText, Sparkles } from '@lucide/svelte';

  function handleTryNow() {
    // Handle try now action
    console.log('Try now clicked');
  }

  function handleViewExamples() {
    // Handle view examples action
    console.log('View examples clicked');
  }
</script>

<section class="relative overflow-hidden bg-gradient-to-br from-background via-background to-muted/20">
  <div class="absolute inset-0 bg-grid-slate-100 [mask-image:linear-gradient(0deg,white,rgba(255,255,255,0.6))] dark:bg-grid-slate-700/25 dark:[mask-image:linear-gradient(0deg,white,rgba(255,255,255,0.1))]"></div>

  <div class="relative mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
    <div class="text-center">
      <!-- Badge -->
      <div class="mb-8 flex justify-center">
        <Badge variant="secondary" class="px-4 py-2 text-sm font-medium">
          <Sparkles class="mr-2 h-4 w-4" />
          The future of executable documentation
        </Badge>
      </div>

      <!-- Headline -->
      <h1 class="text-4xl font-bold tracking-tight text-foreground sm:text-6xl lg:text-7xl">
        <span class="block">Write code that</span>
        <span class="block bg-gradient-to-r from-primary to-primary/80 bg-clip-text text-transparent">
          tells a story
        </span>
      </h1>

      <!-- Subheadline -->
      <p class="mx-auto mt-6 max-w-2xl text-lg leading-8 text-muted-foreground sm:text-xl">
        Transform your markdown notes into executable, interactive documents.
        Combine beautiful prose with live code execution for the ultimate literate programming experience.
      </p>

      <!-- CTA Buttons -->
      <div class="mt-10 flex items-center justify-center gap-x-6">
        <Button size="lg" class="px-8 py-3 text-base" onclick={handleTryNow}>
          <PlayCircle class="mr-2 h-5 w-5" />
          Try it now
        </Button>
        <Button variant="outline" size="lg" class="px-8 py-3 text-base" onclick={handleViewExamples}>
          <FileText class="mr-2 h-5 w-5" />
          View examples
        </Button>
      </div>

      <!-- Feature highlights -->
      <div class="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-3">
        <div class="flex flex-col items-center">
          <div class="mb-4 rounded-full bg-primary/10 p-4">
            <Code2 class="h-8 w-8 text-primary" />
          </div>
          <h3 class="text-lg font-semibold text-foreground">Execute Inline</h3>
          <p class="text-sm text-muted-foreground">Run code blocks directly in your markdown</p>
        </div>

        <div class="flex flex-col items-center">
          <div class="mb-4 rounded-full bg-primary/10 p-4">
            <FileText class="h-8 w-8 text-primary" />
          </div>
          <h3 class="text-lg font-semibold text-foreground">Beautiful Docs</h3>
          <p class="text-sm text-muted-foreground">Rich formatting meets interactive content</p>
        </div>

        <div class="flex flex-col items-center">
          <div class="mb-4 rounded-full bg-primary/10 p-4">
            <Sparkles class="h-8 w-8 text-primary" />
          </div>
          <h3 class="text-lg font-semibold text-foreground">Live Updates</h3>
          <p class="text-sm text-muted-foreground">See results instantly as you type</p>
        </div>
      </div>
    </div>

    <!-- Demo preview -->
    <div class="mt-20">
      <div class="mx-auto max-w-4xl">
        <div class="rounded-2xl border bg-card p-2 shadow-2xl">
          <div class="rounded-xl bg-muted/50 p-8">
            <div class="space-y-4">
              <div class="flex items-center gap-2">
                <div class="h-3 w-3 rounded-full bg-red-500"></div>
                <div class="h-3 w-3 rounded-full bg-yellow-500"></div>
                <div class="h-3 w-3 rounded-full bg-green-500"></div>
                <span class="ml-4 text-sm text-muted-foreground">example.md</span>
              </div>

              <div class="space-y-3 text-left">
                <div class="text-lg font-semibold"># Data Analysis Report</div>
                <div class="text-muted-foreground">Let's analyze our user engagement data:</div>

                <div class="rounded-lg bg-background p-4 font-mono text-sm">
                  <div class="text-green-600"># Python</div>
                  <div>import pandas as pd</div>
                  <div>df = pd.read_csv('users.csv')</div>
                  <div>print(f"Total users: {len(df)}")</div>
                </div>

                <div class="rounded-lg bg-primary/5 p-3 text-sm">
                  <div class="text-primary font-medium">Output:</div>
                  <div>Total users: 1,247</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<style>
  .bg-grid-slate-100 {
    background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32' width='32' height='32' fill='none' stroke='rgb(148 163 184 / 0.05)'%3e%3cpath d='m0 .5 32 0M.5 0v32'/%3e%3c/svg%3e");
  }

  .dark .bg-grid-slate-700\/25 {
    background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32' width='32' height='32' fill='none' stroke='rgb(51 65 85 / 0.25)'%3e%3cpath d='m0 .5 32 0M.5 0v32'/%3e%3c/svg%3e");
  }
</style>