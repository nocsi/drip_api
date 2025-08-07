<script>
  import { Card, CardDescription, CardHeader, CardTitle } from '$lib/ui/card';
  import { Badge } from '$lib/ui/badge';
  import { Button } from '$lib/ui/button';
  import {
    Edit3,
    Play,
    Eye,
    Share2,
    ArrowRight,
    CheckCircle2,
    Code2,
    FileText,
    Sparkles
  } from '@lucide/svelte';

  function handleTryYourself() {
    // Handle try yourself action
    console.log('Try it yourself clicked');
  }
</script>

<section class="py-24 bg-background">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <!-- Header -->
    <div class="text-center mb-16">
      <Badge variant="outline" class="mb-4">How It Works</Badge>
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        From idea to interactive document in minutes
      </h2>
      <p class="mt-4 text-lg text-muted-foreground max-w-2xl mx-auto">
        Simple workflow that transforms your markdown into powerful, executable documentation
      </p>
    </div>

    <!-- Steps -->
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-8 mb-20">
      <!-- Step 1 -->
      <div class="relative">
        <div class="flex flex-col items-center text-center">
          <div class="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6 relative">
            <Edit3 class="w-8 h-8 text-primary" />
            <div class="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
              1
            </div>
          </div>
          <h3 class="text-xl font-semibold mb-3">Write & Code</h3>
          <p class="text-muted-foreground text-sm leading-relaxed">
            Write your documentation in markdown and add code blocks in any supported language
          </p>
        </div>
        <!-- Arrow -->
        <div class="hidden lg:block absolute top-8 -right-4 text-muted-foreground">
          <ArrowRight class="w-8 h-8" />
        </div>
      </div>

      <!-- Step 2 -->
      <div class="relative">
        <div class="flex flex-col items-center text-center">
          <div class="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6 relative">
            <Play class="w-8 h-8 text-primary" />
            <div class="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
              2
            </div>
          </div>
          <h3 class="text-xl font-semibold mb-3">Execute</h3>
          <p class="text-muted-foreground text-sm leading-relaxed">
            Run code blocks instantly and see results appear inline with your documentation
          </p>
        </div>
        <!-- Arrow -->
        <div class="hidden lg:block absolute top-8 -right-4 text-muted-foreground">
          <ArrowRight class="w-8 h-8" />
        </div>
      </div>

      <!-- Step 3 -->
      <div class="relative">
        <div class="flex flex-col items-center text-center">
          <div class="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6 relative">
            <Eye class="w-8 h-8 text-primary" />
            <div class="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
              3
            </div>
          </div>
          <h3 class="text-xl font-semibold mb-3">Preview</h3>
          <p class="text-muted-foreground text-sm leading-relaxed">
            See your beautifully formatted document with live code results in real-time
          </p>
        </div>
        <!-- Arrow -->
        <div class="hidden lg:block absolute top-8 -right-4 text-muted-foreground">
          <ArrowRight class="w-8 h-8" />
        </div>
      </div>

      <!-- Step 4 -->
      <div class="relative">
        <div class="flex flex-col items-center text-center">
          <div class="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6 relative">
            <Share2 class="w-8 h-8 text-primary" />
            <div class="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
              4
            </div>
          </div>
          <h3 class="text-xl font-semibold mb-3">Share</h3>
          <p class="text-muted-foreground text-sm leading-relaxed">
            Export or share your interactive document with colleagues and stakeholders
          </p>
        </div>
      </div>
    </div>

    <!-- Interactive Demo -->
    <div class="mb-20">
      <div class="text-center mb-12">
        <h3 class="text-2xl font-bold tracking-tight mb-4">See it in action</h3>
        <p class="text-muted-foreground">
          Watch how easy it is to create executable documentation
        </p>
      </div>

      <div class="max-w-4xl mx-auto">
        <Card class="border-0 shadow-lg overflow-hidden">
          <div class="bg-gradient-to-r from-muted/50 to-muted/30 p-6">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center gap-2">
                <div class="w-3 h-3 rounded-full bg-red-500"></div>
                <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
                <div class="w-3 h-3 rounded-full bg-green-500"></div>
                <span class="ml-4 text-sm font-medium">data-analysis.md</span>
              </div>
              <Badge variant="secondary" class="text-xs">
                <Sparkles class="w-3 h-3 mr-1" />
                Live
              </Badge>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- Input -->
              <div class="space-y-4">
                <h4 class="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
                  Markdown Input
                </h4>
                <div class="bg-background rounded-lg p-4 font-mono text-sm space-y-2">
                  <div class="text-blue-600"># Sales Analysis</div>
                  <div class="text-muted-foreground">Let's analyze our Q3 data:</div>
                  <div class="text-gray-500">```python</div>
                  <div>import pandas as pd</div>
                  <div>df = pd.read_csv('sales.csv')</div>
                  <div>df.head()</div>
                  <div class="text-gray-500">```</div>
                </div>
              </div>

              <!-- Output -->
              <div class="space-y-4">
                <h4 class="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
                  Live Output
                </h4>
                <div class="bg-background rounded-lg p-4 space-y-4">
                  <h1 class="text-xl font-bold">Sales Analysis</h1>
                  <p class="text-muted-foreground">Let's analyze our Q3 data:</p>

                  <div class="bg-green-50 dark:bg-green-900/20 rounded p-3 text-sm">
                    <div class="text-green-700 dark:text-green-400 font-medium mb-1">Output:</div>
                    <div>Revenue: $2,847,392.50</div>
                  </div>

                  <div class="overflow-x-auto">
                    <table class="text-xs border-collapse border border-border">
                      <thead>
                        <tr class="bg-muted/50">
                          <th class="border border-border px-2 py-1">Date</th>
                          <th class="border border-border px-2 py-1">Revenue</th>
                          <th class="border border-border px-2 py-1">Units</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td class="border border-border px-2 py-1">2024-07-01</td>
                          <td class="border border-border px-2 py-1">$45,230</td>
                          <td class="border border-border px-2 py-1">342</td>
                        </tr>
                        <tr>
                          <td class="border border-border px-2 py-1">2024-07-02</td>
                          <td class="border border-border px-2 py-1">$52,180</td>
                          <td class="border border-border px-2 py-1">398</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- Benefits -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      <Card class="border-0 shadow-sm">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-green-100 dark:bg-green-900/20 flex items-center justify-center mb-4">
            <CheckCircle2 class="w-6 h-6 text-green-600 dark:text-green-400" />
          </div>
          <CardTitle>No Setup Required</CardTitle>
          <CardDescription>
            Start writing immediately - no complex installation or configuration needed
          </CardDescription>
        </CardHeader>
      </Card>

      <Card class="border-0 shadow-sm">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-blue-100 dark:bg-blue-900/20 flex items-center justify-center mb-4">
            <Code2 class="w-6 h-6 text-blue-600 dark:text-blue-400" />
          </div>
          <CardTitle>Any Language</CardTitle>
          <CardDescription>
            Support for Python, R, JavaScript, SQL, shell commands, and more
          </CardDescription>
        </CardHeader>
      </Card>

      <Card class="border-0 shadow-sm">
        <CardHeader>
          <div class="w-12 h-12 rounded-lg bg-purple-100 dark:bg-purple-900/20 flex items-center justify-center mb-4">
            <FileText class="w-6 h-6 text-purple-600 dark:text-purple-400" />
          </div>
          <CardTitle>Pure Markdown</CardTitle>
          <CardDescription>
            Standard markdown files that work with any editor and version control system
          </CardDescription>
        </CardHeader>
      </Card>
    </div>

    <!-- C
TA -->
    <div class="text-center mt-16">
      <Button size="lg" class="px-8 py-3" onclick={handleTryYourself}>
        <Play class="mr-2 h-5 w-5" />
        Try it yourself
      </Button>
    </div>
  </div>
</section>