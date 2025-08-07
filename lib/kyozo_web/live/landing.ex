defmodule KyozoWeb.Live.Landing do
  use KyozoWeb, :live_view

  on_mount {KyozoWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("newsletter_subscribe", %{"email" => email}, socket) do
    # Here you can integrate with your email service (e.g., Mailchimp, ConvertKit, etc.)
    # For now, we'll just simulate a successful subscription
    
    case validate_email(email) do
      {:ok, _email} ->
        # TODO: Integrate with actual newsletter service
        # Example: MyApp.Newsletter.subscribe(email)
        
        {:reply, %{success: true}, socket}
      
      {:error, reason} ->
        {:reply, %{success: false, error: reason}, socket}
    end
  end

  defp validate_email(email) when is_binary(email) do
    if String.contains?(email, "@") and String.length(email) > 3 do
      {:ok, email}
    else
      {:error, "Please enter a valid email address"}
    end
  end

  defp validate_email(_), do: {:error, "Please enter a valid email address"}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-slate-50 to-white">
      <!-- Hero Section -->
      <section class="relative overflow-hidden">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-24">
          <div class="text-center">
            <h1 class="text-5xl md:text-6xl font-bold text-gray-900 leading-tight">
              Literate Programming
              <span class="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                Reimagined
              </span>
            </h1>
            <p class="mt-8 text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
              Create executable documents that combine code, documentation, and interactive visualizations. 
              Transform your ideas into living, breathing documents that your team can understand and execute.
            </p>
            
            <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <button class="px-8 py-4 bg-blue-600 text-white rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all transform hover:scale-105 shadow-lg">
                Start Writing →
              </button>
              <button class="px-8 py-4 border-2 border-gray-300 text-gray-700 rounded-lg text-lg font-semibold hover:border-gray-400 transition-colors">
                View Demo
              </button>
            </div>
          </div>

          <!-- Hero Visual -->
          <div class="mt-20 relative">
            <div class="bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden">
              <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 flex items-center space-x-2">
                <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                <span class="ml-4 text-sm text-gray-500">my-analysis.kyozo</span>
              </div>
              <div class="p-8">
                <div class="space-y-6">
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <h3 class="text-lg font-semibold text-blue-900 mb-2"># Data Analysis Report</h3>
                    <p class="text-blue-700">This document analyzes customer behavior patterns using machine learning.</p>
                  </div>
                  <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 font-mono text-sm">
                    <span class="text-green-600">import</span> <span class="text-blue-600">pandas</span> <span class="text-purple-600">as</span> pd<br/>
                    <span class="text-green-600">import</span> <span class="text-blue-600">matplotlib.pyplot</span> <span class="text-purple-600">as</span> plt
                  </div>
                  <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-4">
                    <div class="flex items-center space-x-2 mb-2">
                      <div class="w-4 h-4 bg-gradient-to-r from-purple-500 to-pink-500 rounded"></div>
                      <span class="text-sm font-medium text-purple-900">Interactive Chart</span>
                    </div>
                    <div class="h-24 bg-white rounded border flex items-center justify-center">
                      <span class="text-gray-400">📊 Live Visualization</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Features Section -->
      <section id="features" class="py-24 bg-gray-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-4xl font-bold text-gray-900 mb-4">
              Everything you need for executable documentation
            </h2>
            <p class="text-xl text-gray-600 max-w-2xl mx-auto">
              Kyozo combines the best of notebooks, documentation, and collaborative editing
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-8">
            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">📝</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">Rich Text Editor</h3>
              <p class="text-gray-600 leading-relaxed">
                Write beautiful documentation with our powerful editor. Support for markdown, 
                math equations, diagrams, and interactive elements.
              </p>
            </div>

            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">⚡</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">Live Code Execution</h3>
              <p class="text-gray-600 leading-relaxed">
                Execute code blocks in real-time. Support for Python, R, JavaScript, and more. 
                See results instantly without leaving your document.
              </p>
            </div>

            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">👥</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">Real-time Collaboration</h3>
              <p class="text-gray-600 leading-relaxed">
                Work together with your team in real-time. See changes as they happen, 
                leave comments, and track document versions.
              </p>
            </div>

            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">📊</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">Interactive Visualizations</h3>
              <p class="text-gray-600 leading-relaxed">
                Create stunning charts, graphs, and interactive visualizations. 
                Your data comes to life within your documents.
              </p>
            </div>

            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">🔗</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">API Integration</h3>
              <p class="text-gray-600 leading-relaxed">
                Connect to external APIs, databases, and services. Pull live data 
                and keep your documents always up-to-date.
              </p>
            </div>

            <div class="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="w-12 h-12 bg-teal-100 rounded-lg flex items-center justify-center mb-6">
                <span class="text-2xl">📱</span>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-4">Export & Share</h3>
              <p class="text-gray-600 leading-relaxed">
                Export to PDF, HTML, or interactive web pages. Share your work 
                with stakeholders in the format they prefer.
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- Use Cases Section -->
      <section class="py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-4xl font-bold text-gray-900 mb-4">
              Perfect for every use case
            </h2>
            <p class="text-xl text-gray-600">
              From research papers to business reports, Kyozo adapts to your workflow
            </p>
          </div>

          <div class="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h3 class="text-2xl font-bold text-gray-900 mb-6">Data Science & Research</h3>
              <ul class="space-y-4">
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-blue-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Jupyter-like notebooks with enhanced collaboration</span>
                </li>
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-blue-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Reproducible research with version control</span>
                </li>
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-blue-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Interactive dashboards for stakeholders</span>
                </li>
              </ul>
            </div>
            <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl p-8">
              <div class="text-center">
                <span class="text-6xl mb-4 block">🔬</span>
                <p class="text-gray-600">
                  "Kyozo transformed how we share research findings. Our stakeholders 
                  can now interact with our data directly."
                </p>
                <p class="text-sm text-gray-500 mt-4">— Dr. Sarah Chen, Research Director</p>
              </div>
            </div>
          </div>

          <div class="grid md:grid-cols-2 gap-12 items-center mt-16">
            <div class="bg-gradient-to-br from-green-50 to-emerald-50 rounded-2xl p-8 md:order-first">
              <div class="text-center">
                <span class="text-6xl mb-4 block">📈</span>
                <p class="text-gray-600">
                  "Our quarterly reports went from static PDFs to interactive 
                  documents that engage our entire team."
                </p>
                <p class="text-sm text-gray-500 mt-4">— Marcus Johnson, Business Analyst</p>
              </div>
            </div>
            <div class="md:order-last">
              <h3 class="text-2xl font-bold text-gray-900 mb-6">Business Intelligence</h3>
              <ul class="space-y-4">
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-green-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Dynamic reports that update automatically</span>
                </li>
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-green-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Connect to your existing data sources</span>
                </li>
                <li class="flex items-start space-x-3">
                  <div class="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center mt-0.5">
                    <span class="text-green-600 text-sm">✓</span>
                  </div>
                  <span class="text-gray-700">Share insights with interactive visualizations</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <!-- Pricing Section -->
      <section id="pricing" class="py-24 bg-gray-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-4xl font-bold text-gray-900 mb-4">
              Simple, transparent pricing
            </h2>
            <p class="text-xl text-gray-600">
              Choose the plan that fits your team's needs
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
            <!-- Starter Plan -->
            <div class="bg-white rounded-2xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="text-center">
                <h3 class="text-xl font-semibold text-gray-900 mb-2">Starter</h3>
                <div class="mb-6">
                  <span class="text-4xl font-bold text-gray-900">$0</span>
                  <span class="text-gray-600">/month</span>
                </div>
                <ul class="space-y-3 text-left mb-8">
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">5 documents</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Basic code execution</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">PDF export</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Community support</span>
                  </li>
                </ul>
                <button class="w-full py-3 border-2 border-gray-300 text-gray-700 rounded-lg font-semibold hover:border-gray-400 transition-colors">
                  Get Started Free
                </button>
              </div>
            </div>

            <!-- Pro Plan -->
            <div class="bg-white rounded-2xl p-8 shadow-lg border-2 border-blue-500 relative">
              <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
                <span class="bg-blue-500 text-white px-4 py-1 rounded-full text-sm font-medium">
                  Most Popular
                </span>
              </div>
              <div class="text-center">
                <h3 class="text-xl font-semibold text-gray-900 mb-2">Pro</h3>
                <div class="mb-6">
                  <span class="text-4xl font-bold text-gray-900">$29</span>
                  <span class="text-gray-600">/month</span>
                </div>
                <ul class="space-y-3 text-left mb-8">
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Unlimited documents</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Advanced code execution</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Real-time collaboration</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">All export formats</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Priority support</span>
                  </li>
                </ul>
                <button class="w-full py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition-colors">
                  Start Pro Trial
                </button>
              </div>
            </div>

            <!-- Team Plan -->
            <div class="bg-white rounded-2xl p-8 shadow-sm hover:shadow-md transition-shadow">
              <div class="text-center">
                <h3 class="text-xl font-semibold text-gray-900 mb-2">Team</h3>
                <div class="mb-6">
                  <span class="text-4xl font-bold text-gray-900">$99</span>
                  <span class="text-gray-600">/month</span>
                </div>
                <ul class="space-y-3 text-left mb-8">
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Everything in Pro</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Team management</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">SSO integration</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Custom branding</span>
                  </li>
                  <li class="flex items-center space-x-3">
                    <span class="text-green-500">✓</span>
                    <span class="text-gray-700">Dedicated support</span>
                  </li>
                </ul>
                <button class="w-full py-3 border-2 border-gray-300 text-gray-700 rounded-lg font-semibold hover:border-gray-400 transition-colors">
                  Contact Sales
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- CTA Section -->
      <section class="py-24 bg-gradient-to-r from-blue-600 to-purple-600">
        <div class="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
          <h2 class="text-4xl font-bold text-white mb-6">
            Ready to transform your documentation?
          </h2>
          <p class="text-xl text-blue-100 mb-10">
            Join thousands of teams already using Kyozo to create better, more engaging documents.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-4 bg-white text-blue-600 rounded-lg text-lg font-semibold hover:bg-gray-50 transition-colors">
              Start Free Trial
            </button>
            <button class="px-8 py-4 border-2 border-white text-white rounded-lg text-lg font-semibold hover:bg-white/10 transition-colors">
              Schedule Demo
            </button>
          </div>
        </div>
      </section>

      <!-- Footer -->
      <footer class="bg-gray-900 text-white py-16">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Main Footer Content -->
          <div class="text-center mb-12">
            <!-- Logo and Brand -->
            <div class="flex items-center justify-center space-x-2 mb-6">
              <div class="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
                <span class="text-white font-bold text-sm">K</span>
              </div>
              <span class="text-xl font-bold">Kyozo</span>
            </div>
            
            <!-- Description -->
            <p class="text-gray-400 leading-relaxed mb-8 max-w-2xl mx-auto">
              The future of executable documentation. Create, collaborate, and share 
              interactive documents that bring your ideas to life.
            </p>
            
            <!-- Newsletter Subscription - Centered -->
            <div class="flex justify-center mb-8">
              <.svelte 
                name="newsletter-form"
              />
            </div>
          </div>
          
          <!-- Footer Links Grid -->
          <div class="grid md:grid-cols-3 gap-8 mb-12 text-center md:text-left">
            <div>
              <h4 class="font-semibold mb-4">Product</h4>
              <ul class="space-y-2 text-gray-400">
                <li><a href="#features" class="hover:text-white transition-colors">Features</a></li>
                <li><a href="#pricing" class="hover:text-white transition-colors">Pricing</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Templates</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Integrations</a></li>
              </ul>
            </div>
            
            <div>
              <h4 class="font-semibold mb-4">Resources</h4>
              <ul class="space-y-2 text-gray-400">
                <li><a href="#docs" class="hover:text-white transition-colors">Documentation</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Tutorials</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Blog</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Community</a></li>
              </ul>
            </div>
            
            <div>
              <h4 class="font-semibold mb-4">Company</h4>
              <ul class="space-y-2 text-gray-400">
                <li><a href="#" class="hover:text-white transition-colors">About</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Careers</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Contact</a></li>
                <li><a href="#" class="hover:text-white transition-colors">Privacy</a></li>
              </ul>
            </div>
          </div>
          
          <!-- Copyright - Centered -->
          <div class="border-t border-gray-800 pt-8 text-center">
            <p class="text-gray-400">&copy; 2024 Kyozo. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end