<script>
  import { Button } from '$lib/ui/button';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/ui/card';
  import { Badge } from '$lib/ui/badge';
  import { Tabs, TabsContent, TabsList, TabsTrigger } from '$lib/ui/tabs';
  import {
    Play,
    Code2,
    Eye,
    Copy,
    CheckCircle2,
    Loader2
  } from '@lucide/svelte';

  let isExecuting = $state(false);
  let hasExecuted = $state(false);
  let showOutput = $state(true);

  const markdownInput = `# Data Analysis Report

Let's analyze our user engagement data from the past month:

\`\`\`python
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load the data
data = {
    'day': range(1, 31),
    'users': np.random.randint(100, 500, 30),
    'sessions': np.random.randint(150, 800, 30)
}
df = pd.DataFrame(data)

print(f"Total users: {df['users'].sum():,}")
print(f"Average daily users: {df['users'].mean():.1f}")
print(f"Peak day: Day {df.loc[df['users'].idxmax(), 'day']} with {df['users'].max()} users")

# Show first 5 rows
df.head()
\`\`\`

## Key Insights

The data shows interesting patterns in user behavior:
- **Growth trend**: {{ 'Positive' if df['users'].corr(df['day']) > 0 else 'Negative' }}
- **Engagement ratio**: {{ (df['sessions'].sum() / df['users'].sum()).round(2) }} sessions per user

\`\`\`python
# Create a simple visualization
plt.figure(figsize=(10, 6))
plt.plot(df['day'], df['users'], marker='o', linewidth=2, markersize=4)
plt.title('Daily Active Users - Past 30 Days')
plt.xlabel('Day of Month')
plt.ylabel('Number of Users')
plt.grid(True, alpha=0.3)
plt.show()
\`\`\``;

  async function executeCode() {
    isExecuting = true;
    // Simulate code execution
    await new Promise(resolve => setTimeout(resolve, 2000));
    isExecuting = false;
    hasExecuted = true;
    showOutput = true;
  }

  function copyCode() {
    navigator.clipboard.writeText(markdownInput);
  }
</script>

<section class="py-24 bg-background">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="text-center mb-16">
      <Badge variant="outline" class="mb-4">Interactive Demo</Badge>
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        See executable markdown in action
      </h2>
      <p class="mt-4 text-lg text-muted-foreground max-w-2xl mx-auto">
        Experience how code and documentation work together seamlessly
      </p>
    </div>

    <div class="max-w-6xl mx-auto">
      <Card class="border-0 shadow-xl overflow-hidden">
        <!-- Demo Header -->
        <CardHeader class="bg-muted/30 border-b">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex gap-2">
                <div class="w-3 h-3 rounded-full bg-red-500"></div>
                <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
                <div class="w-3 h-3 rounded-full bg-green-500"></div>
              </div>
              <CardTitle class="text-lg">data-analysis.md</CardTitle>
              <Badge variant="secondary" class="text-xs">
                <Code2 class="w-3 h-3 mr-1" />
                Python
              </Badge>
            </div>
            <div class="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onclick={copyCode}
              >
                <Copy class="w-4 h-4" />
              </Button>
              <Button
                size="sm"
                onclick={executeCode}
                disabled={isExecuting}
              >
                {#if isExecuting}
                  <Loader2 class="w-4 h-4 mr-2 animate-spin" />
                  Running...
                {:else}
                  <Play class="w-4 h-4 mr-2" />
                  Execute All
                {/if}
              </Button>
            </div>
          </div>
        </CardHeader>

        <CardContent class="p-0">
          <Tabs value="preview" class="w-full">
            <div class="border-b">
              <TabsList class="grid w-full grid-cols-3 rounded-none bg-transparent h-12">
                <TabsTrigger value="source" class="rounded-none">
                  <Code2 class="w-4 h-4 mr-2" />
                  Source
                </TabsTrigger>
                <TabsTrigger value="preview" class="rounded-none">
                  <Eye class="w-4 h-4 mr-2" />
                  Preview
                </TabsTrigger>
                <TabsTrigger value="split" class="rounded-none">
                  Split View
                </TabsTrigger>
              </TabsList>
            </div>

            <!-- Source View -->
            <TabsContent value="source" class="m-0">
              <div class="p-6">
                <pre class="text-sm bg-muted/50 rounded-lg p-4 overflow-x-auto font-mono leading-relaxed">
{markdownInput}
                </pre>
              </div>
            </TabsContent>

            <!-- Preview View -->
            <TabsContent value="preview" class="m-0">
              <div class="p-6 space-y-6">
                <!-- Rendered Markdown -->
                <div class="prose prose-slate dark:prose-invert max-w-none">
                  <h1>Data Analysis Report</h1>
                  <p>Let's analyze our user engagement data from the past month:</p>
                </div>

                <!-- Code Block with Output -->
                <div class="space-y-4">
                  <div class="rounded-lg border bg-muted/20 overflow-hidden">
                    <div class="flex items-center justify-between px-4 py-2 bg-muted/50 border-b">
                      <div class="flex items-center gap-2">
                        <Code2 class="w-4 h-4 text-muted-foreground" />
                        <span class="text-sm font-medium">Python</span>
                      </div>
                      {#if hasExecuted}
                        <div class="flex items-center gap-1 text-green-600">
                          <CheckCircle2 class="w-4 h-4" />
                          <span class="text-xs">Executed successfully</span>
                        </div>
                      {/if}
                    </div>
                    <div class="p-4 font-mono text-sm space-y-1">
                      <div class="text-blue-600">import pandas as pd</div>
                      <div class="text-blue-600">import matplotlib.pyplot as plt</div>
                      <div class="text-blue-600">import numpy as np</div>
                      <div class="text-gray-500"># Load the data...</div>
                      <div>df = pd.DataFrame(data)</div>
                    </div>
                  </div>

                  {#if hasExecuted && showOutput}
                    <!-- Output -->
                    <div class="rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 p-4">
                      <div class="flex items-center gap-2 mb-2">
                        <div class="w-2 h-2 rounded-full bg-green-500"></div>
                        <span class="text-sm font-medium text-green-700 dark:text-green-400">Output</span>
                      </div>
                      <div class="font-mono text-sm space-y-1 text-green-800 dark:text-green-300">
                        <div>Total users: 8,247</div>
                        <div>Average daily users: 274.9</div>
                        <div>Peak day: Day 23 with 487 users</div>
                      </div>

                      <!-- Data Table -->
                      <div class="mt-4 overflow-x-auto">
                        <table class="text-xs border-collapse border border-green-300 dark:border-green-700">
                          <thead>
                            <tr class="bg-green-100 dark:bg-green-900/50">
                              <th class="border border-green-300 dark:border-green-700 px-2 py-1">day</th>
                              <th class="border border-green-300 dark:border-green-700 px-2 py-1">users</th>
                              <th class="border border-green-300 dark:border-green-700 px-2 py-1">sessions</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">1</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">234</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">456</td>
                            </tr>
                            <tr>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">2</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">198</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">387</td>
                            </tr>
                            <tr>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">3</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">312</td>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1">623</td>
                            </tr>
                            <tr>
                              <td class="border border-green-300 dark:border-green-700 px-2 py-1 text-center" colspan="3">...</td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  {/if}
                </div>

                <!-- More Rendered Content -->
                <div class="prose prose-slate dark:prose-invert max-w-none">
                  <h2>Key Insights</h2>
                  <p>The data shows interesting patterns in user behavior:</p>
                  <ul>
                    <li><strong>Growth trend</strong>: {hasExecuted ? 'Positive' : 'Pending execution...'}</li>
                    <li><strong>Engagement ratio</strong>: {hasExecuted ? '2.1 sessions per user' : 'Calculating...'}</li>
                  </ul>
                </div>

                <!-- Chart Placeholder -->
                {#if hasExecuted}
                  <div class="rounded-lg border bg-muted/20 p-6">
                    <div class="flex items-center justify-center h-64 bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 rounded-lg">
                      <div class="text-center">
                        <div class="w-16 h-16 mx-auto mb-4 bg-blue-500 rounded-lg flex items-center justify-center">
                          📈
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Daily Active Users Chart</h3>
                        <p class="text-sm text-muted-foreground">Interactive matplotlib visualization would appear here</p>
                      </div>
                    </div>
                  </div>
                {/if}
              </div>
            </TabsContent>

            <!-- Split View -->
            <TabsContent value="split" class="m-0">
              <div class="grid grid-cols-1 lg:grid-cols-2 min-h-[600px]">
                <!-- Source -->
                <div class="border-r p-4">
                  <h3 class="text-sm font-semibold mb-4 flex items-center">
                    <Code2 class="w-4 h-4 mr-2" />
                    Markdown Source
                  </h3>
                  <pre class="text-xs bg-muted/50 rounded p-3 overflow-auto font-mono leading-relaxed h-full max-h-[500px]">
{markdownInput}
                  </pre>
                </div>

                <!-- Preview -->
                <div class="p-4">
                  <h3 class="text-sm font-semibold mb-4 flex items-center">
                    <Eye class="w-4 h-4 mr-2" />
                    Live
 Preview
                  </h3>
                  <div class="space-y-4 overflow-auto h-full max-h-[500px]">
                    <h1 class="text-xl font-bold">Data Analysis Report</h1>
                    <p class="text-muted-foreground">Let's analyze our user engagement data...</p>

                    {#if hasExecuted}
                      <div class="bg-green-50 dark:bg-green-900/20 rounded p-3 text-sm">
                        <div class="font-mono space-y-1">
                          <div>Total users: 8,247</div>
                          <div>Average daily users: 274.9</div>
                        </div>
                      </div>
                    {:else}
                      <div class="bg-muted/50 rounded p-3 text-sm text-muted-foreground">
                        Click "Execute All" to see results...
                      </div>
                    {/if}
                  </div>
                </div>
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>

      <!-- Demo Features -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
        <Card class="border-0 shadow-sm text-center">
          <CardContent class="pt-6">
            <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-blue-100 dark:bg-blue-900/20 flex items-center justify-center">
              <Play class="w-6 h-6 text-blue-600 dark:text-blue-400" />
            </div>
            <h3 class="font-semibold mb-2">Live Execution</h3>
            <p class="text-sm text-muted-foreground">
              Code blocks execute in real-time with immediate visual feedback
            </p>
          </CardContent>
        </Card>

        <Card class="border-0 shadow-sm text-center">
          <CardContent class="pt-6">
            <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-green-100 dark:bg-green-900/20 flex items-center justify-center">
              <Eye class="w-6 h-6 text-green-600 dark:text-green-400" />
            </div>
            <h3 class="font-semibold mb-2">Rich Preview</h3>
            <p class="text-sm text-muted-foreground">
              Beautiful rendering with syntax highlighting and formatted output
            </p>
          </CardContent>
        </Card>

        <Card class="border-0 shadow-sm text-center">
          <CardContent class="pt-6">
            <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-purple-100 dark:bg-purple-900/20 flex items-center justify-center">
              <Code2 class="w-6 h-6 text-purple-600 dark:text-purple-400" />
            </div>
            <h3 class="font-semibold mb-2">Multiple Views</h3>
            <p class="text-sm text-muted-foreground">
              Switch between source, preview, and split view modes
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  </div>
</section>
