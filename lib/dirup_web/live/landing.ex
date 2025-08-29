defmodule DirupWeb.Live.Landing do
  use DirupWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:show_demo, false)
     |> assign(:active_tab, :overview)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100">
      <!-- Navigation -->
      <nav class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between h-16">
            <div class="flex items-center">
              <h1 class="text-2xl font-bold text-gray-900">Dirup</h1>
              <span class="ml-2 text-sm text-gray-500">Folder Infrastructure Platform</span>
            </div>
            <div class="flex items-center space-x-4">
              <a href="/docs" class="text-gray-600 hover:text-gray-900">Documentation</a>
              <a href="/pricing" class="text-gray-600 hover:text-gray-900">Pricing</a>
              <a href="/login" class="text-gray-600 hover:text-gray-900">Sign In</a>
              <button class="bg-gray-800 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                Get Started
              </button>
            </div>
          </div>
        </div>
      </nav>
      
    <!-- Hero Section -->
      <section class="pt-20 pb-32 px-4">
        <div class="max-w-7xl mx-auto text-center">
          <h2 class="text-5xl font-bold text-gray-900 mb-6">
            Your Folders Are Your Infrastructure
          </h2>
          <p class="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Deploy services by organizing folders. No YAML, no configs, no complexity.
            Just intuitive folder structures that become running infrastructure.
          </p>
          <div class="flex justify-center space-x-4 mb-12">
            <button
              phx-click="show_demo"
              class="bg-gray-800 text-white px-8 py-3 rounded-lg text-lg hover:bg-gray-700 transition-colors"
            >
              See Live Demo
            </button>
            <button class="border-2 border-gray-300 text-gray-700 px-8 py-3 rounded-lg text-lg hover:border-gray-400 transition-colors">
              View Documentation
            </button>
          </div>
          
    <!-- Code Example -->
          <div class="bg-white rounded-xl shadow-lg p-8 max-w-4xl mx-auto border border-gray-200">
            <div class="flex items-center justify-between mb-4">
              <span class="text-sm font-mono text-gray-500">folder structure → deployment</span>
              <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">AUTOMATIC</span>
            </div>
            <pre class="text-left bg-gray-50 p-6 rounded-lg overflow-x-auto">
              <code class="text-sm font-mono">
    <span class="text-gray-600">my-app/</span>
    ├── <span class="text-blue-600">services/</span>
    │   ├── <span class="text-green-600">api/</span>          <span class="text-gray-500">→ REST API container</span>
    │   ├── <span class="text-green-600">worker/</span>       <span class="text-gray-500">→ Background job processor</span>
    │   └── <span class="text-green-600">frontend/</span>     <span class="text-gray-500">→ Static web server</span>
    ├── <span class="text-blue-600">data/</span>
    │   ├── <span class="text-purple-600">postgres/</span>     <span class="text-gray-500">→ PostgreSQL instance</span>
    │   └── <span class="text-purple-600">redis/</span>        <span class="text-gray-500">→ Redis cache</span>
    └── <span class="text-blue-600">gateway/</span>
    └── <span class="text-orange-600">nginx/</span>        <span class="text-gray-500">→ Load balancer</span>
              </code>
            </pre>
            <div class="mt-4 flex items-center justify-center">
              <code class="bg-gray-900 text-green-400 px-4 py-2 rounded font-mono text-sm">
                $ dirup deploy ./my-app
              </code>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Features Tabs -->
      <section class="py-20 bg-white">
        <div class="max-w-7xl mx-auto px-4">
          <h3 class="text-3xl font-bold text-center text-gray-900 mb-12">
            Enterprise-Grade Folder Execution
          </h3>

          <div class="flex justify-center mb-8">
            <div class="bg-gray-100 p-1 rounded-lg inline-flex">
              <button
                phx-click="set_tab"
                phx-value-tab="overview"
                class={"px-6 py-2 rounded-md transition-colors " <> if(@active_tab == :overview, do: "bg-white text-gray-900 shadow", else: "text-gray-600")}
              >
                Overview
              </button>
              <button
                phx-click="set_tab"
                phx-value-tab="storage"
                class={"px-6 py-2 rounded-md transition-colors " <> if(@active_tab == :storage, do: "bg-white text-gray-900 shadow", else: "text-gray-600")}
              >
                Storage
              </button>
              <button
                phx-click="set_tab"
                phx-value-tab="execution"
                class={"px-6 py-2 rounded-md transition-colors " <> if(@active_tab == :execution, do: "bg-white text-gray-900 shadow", else: "text-gray-600")}
              >
                Execution
              </button>
              <button
                phx-click="set_tab"
                phx-value-tab="ai"
                class={"px-6 py-2 rounded-md transition-colors " <> if(@active_tab == :ai, do: "bg-white text-gray-900 shadow", else: "text-gray-600")}
              >
                AI Analysis
              </button>
            </div>
          </div>

          <div class="bg-gray-50 rounded-xl p-12 border border-gray-200">
            <%= case @active_tab do %>
              <% :overview -> %>
                <div class="grid md:grid-cols-2 gap-8">
                  <div>
                    <h4 class="text-xl font-semibold text-gray-900 mb-4">
                      Folder-First Architecture
                    </h4>
                    <p class="text-gray-600 mb-4">
                      Every folder in your project represents a deployable unit. Services are automatically
                      detected from file patterns - Node.js from package.json, Python from requirements.txt,
                      or custom Dockerfiles.
                    </p>
                    <ul class="space-y-2 text-gray-600">
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Auto-detection of 12+ frameworks
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span>
                        Dependency graph from folder structure
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Zero-config deployments
                      </li>
                    </ul>
                  </div>
                  <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <div class="text-sm font-mono text-gray-600 mb-2">Detection Example</div>
                    <pre class="text-xs bg-gray-50 p-3 rounded">
    /api/
    package.json     → Node.js service
    Dockerfile       → Custom overrides
    .env.example     → Environment setup</pre>
                  </div>
                </div>
              <% :storage -> %>
                <div class="grid md:grid-cols-2 gap-8">
                  <div>
                    <h4 class="text-xl font-semibold text-gray-900 mb-4">
                      Content-Addressable Storage
                    </h4>
                    <p class="text-gray-600 mb-4">
                      Every folder state is hashed and stored, enabling perfect rollbacks and
                      deduplication. Track infrastructure changes at the semantic level with
                      JSON-LD manifests.
                    </p>
                    <ul class="space-y-2 text-gray-600">
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> SHA-256 content hashing
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Automatic deduplication
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Semantic differencing
                      </li>
                    </ul>
                  </div>
                  <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <div class="text-sm font-mono text-gray-600 mb-2">Storage Stats</div>
                    <div class="space-y-3">
                      <div class="flex justify-between">
                        <span class="text-gray-500">Dedup Ratio</span>
                        <span class="font-semibold">87.3%</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-gray-500">Avg Rollback Time</span>
                        <span class="font-semibold">1.2s</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-gray-500">Storage Saved</span>
                        <span class="font-semibold">2.4TB</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% :execution -> %>
                <div class="grid md:grid-cols-2 gap-8">
                  <div>
                    <h4 class="text-xl font-semibold text-gray-900 mb-4">
                      Smart Container Orchestration
                    </h4>
                    <p class="text-gray-600 mb-4">
                      Folders are analyzed, containerized, and deployed with automatic resource
                      allocation, health checks, and scaling policies derived from your code structure.
                    </p>
                    <ul class="space-y-2 text-gray-600">
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Automatic Dockerfile generation
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Multi-stage optimized builds
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Resource limits from code analysis
                      </li>
                    </ul>
                  </div>
                  <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <div class="text-sm font-mono text-gray-600 mb-2">Execution Pipeline</div>
                    <div class="space-y-2 text-sm">
                      <div class="flex items-center">
                        <div class="w-8 h-8 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-xs font-bold mr-3">
                          1
                        </div>
                        <span>Analyze folder structure</span>
                      </div>
                      <div class="flex items-center">
                        <div class="w-8 h-8 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-xs font-bold mr-3">
                          2
                        </div>
                        <span>Generate containers</span>
                      </div>
                      <div class="flex items-center">
                        <div class="w-8 h-8 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-xs font-bold mr-3">
                          3
                        </div>
                        <span>Deploy with dependencies</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% :ai -> %>
                <div class="grid md:grid-cols-2 gap-8">
                  <div>
                    <h4 class="text-xl font-semibold text-gray-900 mb-4">AI-Enhanced Analysis</h4>
                    <p class="text-gray-600 mb-4">
                      Three AI providers work in parallel to optimize your deployments: Anthropic for
                      code analysis, OpenAI for pattern detection, and xAI for architecture reasoning.
                    </p>
                    <ul class="space-y-2 text-gray-600">
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Security vulnerability detection
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Optimization suggestions
                      </li>
                      <li class="flex items-start">
                        <span class="text-gray-400 mr-2">•</span> Dependency graph enhancement
                      </li>
                    </ul>
                  </div>
                  <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <div class="text-sm font-mono text-gray-600 mb-2">AI Provider Routing</div>
                    <div class="space-y-2 text-sm">
                      <div class="flex justify-between">
                        <span class="text-gray-500">Code Analysis</span>
                        <span class="font-mono text-xs bg-gray-100 px-2 py-1 rounded">Claude</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-gray-500">Patterns</span>
                        <span class="font-mono text-xs bg-gray-100 px-2 py-1 rounded">GPT-4</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-gray-500">Architecture</span>
                        <span class="font-mono text-xs bg-gray-100 px-2 py-1 rounded">Grok</span>
                      </div>
                    </div>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </section>
      
    <!-- Stats Section -->
      <section class="py-20 bg-gray-50">
        <div class="max-w-7xl mx-auto px-4">
          <div class="grid md:grid-cols-4 gap-8">
            <div class="text-center">
              <div class="text-4xl font-bold text-gray-900">0</div>
              <div class="text-gray-600 mt-2">Configuration Files</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-bold text-gray-900">&lt;5s</div>
              <div class="text-gray-600 mt-2">Deploy Time</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-bold text-gray-900">87%</div>
              <div class="text-gray-600 mt-2">Storage Saved</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-bold text-gray-900">∞</div>
              <div class="text-gray-600 mt-2">Folder Structures</div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- CTA Section -->
      <section class="py-20 bg-gray-900">
        <div class="max-w-4xl mx-auto text-center px-4">
          <h3 class="text-3xl font-bold text-white mb-4">
            Start Deploying Folders Today
          </h3>
          <p class="text-gray-300 mb-8">
            Join developers who've eliminated configuration complexity by letting folders define infrastructure.
          </p>
          <form phx-submit="subscribe" class="max-w-md mx-auto flex gap-3">
            <input
              type="email"
              name="email"
              value={@email}
              phx-change="update_email"
              placeholder="Enter your email"
              class="flex-1 px-4 py-3 rounded-lg border border-gray-700 bg-gray-800 text-white placeholder-gray-400 focus:outline-none focus:border-gray-500"
              required
            />
            <button
              type="submit"
              class="bg-white text-gray-900 px-6 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors"
            >
              Get Early Access
            </button>
          </form>
        </div>
      </section>
      
    <!-- Footer -->
      <footer class="bg-gray-100 border-t border-gray-200 py-12">
        <div class="max-w-7xl mx-auto px-4">
          <div class="grid md:grid-cols-4 gap-8">
            <div>
              <h4 class="font-bold text-gray-900 mb-3">Dirup</h4>
              <p class="text-sm text-gray-600">Folder infrastructure platform</p>
            </div>
            <div>
              <h5 class="font-semibold text-gray-700 mb-3">Product</h5>
              <ul class="space-y-2 text-sm text-gray-600">
                <li><a href="/features" class="hover:text-gray-900">Features</a></li>
                <li><a href="/pricing" class="hover:text-gray-900">Pricing</a></li>
                <li><a href="/docs" class="hover:text-gray-900">Documentation</a></li>
              </ul>
            </div>
            <div>
              <h5 class="font-semibold text-gray-700 mb-3">Company</h5>
              <ul class="space-y-2 text-sm text-gray-600">
                <li><a href="/about" class="hover:text-gray-900">About</a></li>
                <li><a href="/blog" class="hover:text-gray-900">Blog</a></li>
                <li><a href="/careers" class="hover:text-gray-900">Careers</a></li>
              </ul>
            </div>
            <div>
              <h5 class="font-semibold text-gray-700 mb-3">Connect</h5>
              <ul class="space-y-2 text-sm text-gray-600">
                <li><a href="https://github.com/dirup" class="hover:text-gray-900">GitHub</a></li>
                <li><a href="https://twitter.com/dirup" class="hover:text-gray-900">Twitter</a></li>
                <li><a href="/contact" class="hover:text-gray-900">Contact</a></li>
              </ul>
            </div>
          </div>
          <div class="mt-12 pt-8 border-t border-gray-200 text-center text-sm text-gray-600">
            © 2024 Dirup. Folders are infrastructure.
          </div>
        </div>
      </footer>
      
    <!-- Demo Modal -->
      <%= if @show_demo do %>
        <div
          class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          phx-click="close_demo"
        >
          <div class="bg-white rounded-xl p-8 max-w-2xl w-full mx-4" phx-click-away="close_demo">
            <h3 class="text-2xl font-bold mb-4">Live Demo</h3>
            <div class="bg-gray-900 text-green-400 p-4 rounded-lg font-mono text-sm">
              <div>$ dirup init my-project</div>
              <div class="text-gray-500">Creating folder structure...</div>
              <div>$ dirup deploy ./my-project</div>
              <div class="text-gray-500">Analyzing folders...</div>
              <div class="text-gray-500">Detected: 3 services, 2 databases</div>
              <div class="text-gray-500">Building containers...</div>
              <div>✓ Deployment complete</div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  def handle_event("show_demo", _params, socket) do
    {:noreply, assign(socket, :show_demo, true)}
  end

  def handle_event("close_demo", _params, socket) do
    {:noreply, assign(socket, :show_demo, false)}
  end

  def handle_event("update_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, :email, email)}
  end

  def handle_event("subscribe", %{"email" => email}, socket) do
    # Here you would typically save to database using Ash
    # Dirup.Marketing.Subscriber.create!(%{email: email})

    socket =
      socket
      |> put_flash(:info, "Thanks for subscribing! We'll notify you when we launch.")
      |> assign(:email, "")

    {:noreply, socket}
  end
end
