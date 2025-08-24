defmodule KyozoWeb.Live.SafeMDLanding do
  use KyozoWeb, :live_view

  on_mount {KyozoWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "SafeMD - Protect Your AI from Markdown Attacks")}
  end

  @impl true
  def handle_event("try_demo", _params, socket) do
    {:noreply, push_navigate(socket, to: "/safemd/demo")}
  end

  @impl true
  def handle_event("view_pricing", _params, socket) do
    {:noreply, push_navigate(socket, to: "/safemd/pricing")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-slate-950 text-white min-h-screen">
      <!-- Hero Section -->
      <section class="relative pt-20 pb-32 overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-red-900/20 via-slate-900 to-orange-900/20">
        </div>
        <div class="relative max-w-7xl mx-auto px-6 text-center">
          <h1 class="text-6xl font-bold mb-6">
            <span class="bg-gradient-to-r from-red-400 to-orange-400 bg-clip-text text-transparent">
              SafeMD
            </span>
          </h1>
          <h2 class="text-3xl font-semibold mb-6 text-gray-300">
            Protect Your AI from Markdown Attacks
          </h2>
          <p class="text-xl text-gray-400 mb-8 max-w-3xl mx-auto">
            Enterprise-grade security scanning for markdown content.
            Detect prompt injection, hidden scripts, and malicious links before they reach your AI systems.
          </p>

          <div class="flex justify-center space-x-6">
            <button
              phx-click="try_demo"
              class="bg-gradient-to-r from-red-500 to-red-600 text-white px-8 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-red-500/25 transition-all transform hover:scale-105 text-lg"
            >
              Try Free Demo
            </button>
            <button
              phx-click="view_pricing"
              class="border border-red-500 text-red-400 px-8 py-4 rounded-lg font-semibold hover:bg-red-500/10 transition-all text-lg"
            >
              View Pricing
            </button>
          </div>
          
    <!-- Stats -->
          <div class="mt-16 grid grid-cols-1 md:grid-cols-3 gap-8 max-w-4xl mx-auto">
            <div class="text-center">
              <div class="text-3xl font-bold text-red-400">50MB/s</div>
              <div class="text-gray-400">Processing Speed</div>
            </div>
            <div class="text-center">
              <div class="text-3xl font-bold text-red-400">$0.03</div>
              <div class="text-gray-400">Per Scan</div>
            </div>
            <div class="text-center">
              <div class="text-3xl font-bold text-red-400">99.9%</div>
              <div class="text-gray-400">Accuracy</div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Problem/Solution Section -->
      <section class="py-20 bg-black/20">
        <div class="max-w-7xl mx-auto px-6">
          <h3 class="text-4xl font-bold text-center mb-12">The Markdown Security Problem</h3>

          <div class="grid md:grid-cols-2 gap-12">
            <!-- Problem -->
            <div class="bg-red-900/20 border border-red-500/30 rounded-xl p-8">
              <h4 class="text-2xl font-bold mb-6 text-red-400">⚠️ Hidden Threats</h4>
              <div class="space-y-4">
                <div class="bg-gray-900 rounded-lg p-4 font-mono text-sm">
                  <div class="text-red-400 mb-2"># Innocent markdown?</div>
                  <div class="text-gray-300">[Click for rewards](javascript:alert('XSS'))</div>
                  <div class="text-gray-300 mt-2">```python</div>
                  <div class="text-gray-300">import os; os.system('rm -rf /')</div>
                  <div class="text-gray-300">```</div>
                </div>
                <ul class="text-gray-300 space-y-2">
                  <li>• Prompt injection attacks</li>
                  <li>• Hidden JavaScript execution</li>
                  <li>• Malicious code blocks</li>
                  <li>• Unicode-based attacks</li>
                  <li>• Zero-width character exploits</li>
                </ul>
              </div>
            </div>
            
    <!-- Solution -->
            <div class="bg-green-900/20 border border-green-500/30 rounded-xl p-8">
              <h4 class="text-2xl font-bold mb-6 text-green-400">✅ SafeMD Protection</h4>
              <div class="space-y-4">
                <div class="bg-gray-900 rounded-lg p-4 font-mono text-sm">
                  <div class="text-green-400 mb-2">POST /api/v1/scan</div>
                  <div class="text-gray-300">&#123;</div>
                  <div class="text-gray-300">"safe": false,</div>
                  <div class="text-gray-300">"threat_level": "high",</div>
                  <div class="text-gray-300">"threats_detected": 3</div>
                  <div class="text-gray-300">&#125;</div>
                </div>
                <ul class="text-gray-300 space-y-2">
                  <li>• Real-time threat detection</li>
                  <li>• API-first integration</li>
                  <li>• Enterprise-grade security</li>
                  <li>• Sub-second response times</li>
                  <li>• Comprehensive threat analysis</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Features Section -->
      <section class="py-20">
        <div class="max-w-7xl mx-auto px-6">
          <h3 class="text-4xl font-bold text-center mb-12">Security Features</h3>

          <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-red-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">🔍</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Prompt Injection Detection</h4>
              <p class="text-gray-300">
                Identify and block attempts to manipulate AI systems through crafted prompts.
              </p>
            </div>

            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-orange-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">🛡️</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Script Scanning</h4>
              <p class="text-gray-300">
                Detect hidden JavaScript, malicious code blocks, and embedded threats.
              </p>
            </div>

            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-yellow-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">🔤</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Unicode Attack Prevention</h4>
              <p class="text-gray-300">
                Normalize content and prevent Unicode-based security exploits.
              </p>
            </div>

            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-green-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">🔗</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Link Validation</h4>
              <p class="text-gray-300">
                Scan and sanitize malicious links, including data URLs and redirects.
              </p>
            </div>

            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">👁️</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Zero-Width Detection</h4>
              <p class="text-gray-300">Remove invisible characters used to hide malicious content.</p>
            </div>

            <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
              <div class="w-12 h-12 bg-purple-500 rounded-lg flex items-center justify-center mb-4">
                <span class="text-2xl">🚀</span>
              </div>
              <h4 class="text-xl font-bold mb-3">Real-time Processing</h4>
              <p class="text-gray-300">Stream large documents with real-time threat analysis.</p>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Pricing Section -->
      <section class="py-20 bg-black/20">
        <div class="max-w-7xl mx-auto px-6">
          <h3 class="text-4xl font-bold text-center mb-12">Simple, Fair Pricing</h3>

          <div class="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
            <!-- Free Tier -->
            <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10">
              <h4 class="text-2xl font-bold mb-4">Free</h4>
              <div class="text-4xl font-bold mb-6">
                $0<span class="text-lg text-gray-400">/month</span>
              </div>
              <ul class="space-y-3 mb-8">
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>10 scans/month
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Basic threat detection
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>API access
                </li>
                <li class="flex items-center">
                  <span class="text-gray-500 mr-2">×</span>Advanced features
                </li>
              </ul>
              <button class="w-full bg-gray-700 text-white py-3 rounded-lg font-semibold">
                Get Started
              </button>
            </div>
            
    <!-- Pro Tier -->
            <div class="bg-red-500/10 backdrop-blur rounded-xl p-8 border-2 border-red-500 relative">
              <div class="absolute -top-3 left-1/2 transform -translate-x-1/2 bg-red-500 text-white px-4 py-1 rounded-full text-sm font-semibold">
                Most Popular
              </div>
              <h4 class="text-2xl font-bold mb-4">Pro</h4>
              <div class="text-4xl font-bold mb-6">
                $0.03<span class="text-lg text-gray-400">/scan</span>
              </div>
              <ul class="space-y-3 mb-8">
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Unlimited scans
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Advanced threat detection
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Real-time streaming
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Priority support
                </li>
              </ul>
              <button class="w-full bg-red-500 text-white py-3 rounded-lg font-semibold hover:bg-red-600 transition-colors">
                Start Pro Trial
              </button>
            </div>
            
    <!-- Enterprise -->
            <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10">
              <h4 class="text-2xl font-bold mb-4">Enterprise</h4>
              <div class="text-4xl font-bold mb-6">Custom</div>
              <ul class="space-y-3 mb-8">
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Volume discounts
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>SLA guarantees
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>Custom deployment
                </li>
                <li class="flex items-center">
                  <span class="text-green-400 mr-2">✓</span>24/7 support
                </li>
              </ul>
              <button class="w-full border border-white/20 text-white py-3 rounded-lg font-semibold hover:bg-white/5 transition-colors">
                Contact Sales
              </button>
            </div>
          </div>
        </div>
      </section>
      
    <!-- CTA Section -->
      <section class="py-20">
        <div class="max-w-4xl mx-auto px-6 text-center">
          <h3 class="text-4xl font-bold mb-6">Ready to Secure Your AI?</h3>
          <p class="text-xl text-gray-300 mb-8">
            Join thousands of developers protecting their AI systems with SafeMD
          </p>
          <div class="flex justify-center space-x-4">
            <button
              phx-click="try_demo"
              class="bg-gradient-to-r from-red-500 to-red-600 text-white px-8 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-red-500/25 transition-all transform hover:scale-105 text-lg"
            >
              Try Free Demo
            </button>
            <button class="border border-red-500 text-red-400 px-8 py-4 rounded-lg font-semibold hover:bg-red-500/10 transition-all text-lg">
              <a href="/api/v1/docs">View API Docs</a>
            </button>
          </div>
        </div>
      </section>
    </div>
    """
  end
end
