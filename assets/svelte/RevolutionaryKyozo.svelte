<script>
  import { onMount } from 'svelte';
  import { Badge } from '$lib/components/ui/badge';
  import { Button } from '$lib/components/ui/button';

  // Navigation state
  let scrollY = $state(0);
  let mobileMenuOpen = $state(false);

  // Demo state
  let activeDemo = $state('folder-drop');
  let currentStep = $state(0);
  let isAnimating = $state(false);

  const navItems = [
    { href: '#platform', label: 'Platform' },
    { href: '#revolution', label: 'Revolution' },
    { href: '#use-cases', label: 'Use Cases' },
    { href: '#enterprise', label: 'Enterprise' },
    { href: '/openapi', label: 'API Docs' }
  ];

  const revolutionSteps = [
    {
      id: 'folder-drop',
      title: 'Drop Your Folder',
      description: 'Any project structure',
      icon: '📁',
      detail: 'Simply drag any project folder into Kyozo. React, Node.js, Python, Go, Rust - we detect them all.'
    },
    {
      id: 'ai-analysis',
      title: 'AI Detects Services',
      description: '95% accuracy in seconds',
      icon: '🤖',
      detail: 'Advanced AI analyzes your folder structure, identifying services, dependencies, and deployment patterns.'
    },
    {
      id: 'one-click-deploy',
      title: 'One-Click Deploy',
      description: '60 seconds to production',
      icon: '🚀',
      detail: 'From folder to running, monitored, production-ready service in under 60 seconds. No configuration needed.'
    },
    {
      id: 'live-monitoring',
      title: 'Enterprise Monitoring',
      description: 'Real-time dashboards',
      icon: '📊',
      detail: 'Enterprise-grade monitoring, health checks, metrics, and alerting built-in from day one.'
    }
  ];

  const productSuite = [
    {
      name: "Editor",
      tagline: "Where Ideas Become Infrastructure",
      description: "AI-powered collaborative development with real-time execution",
      status: "Core Platform",
      color: "from-violet-500 to-purple-600",
      icon: "✏️",
      features: ["Real-time collaboration", "AI code completion", "Integrated debugging", "Multi-language support"],
      priority: true
    },
    {
      name: "Store",
      tagline: "Folder as a Service Revolution",
      description: "Transform any folder into production-ready services automatically",
      status: "🚀 Revolutionary",
      color: "from-orange-500 to-red-500",
      icon: "💾",
      features: ["AI service detection (95% accuracy)", "Zero-config deployment", "Enterprise monitoring", "Circuit breaker patterns"],
      priority: true,
      revolutionary: true
    },
    {
      name: "Build",
      tagline: "Directory-Driven Architecture",
      description: "Your folder structure IS your service architecture",
      status: "Infrastructure Engine",
      color: "from-blue-500 to-cyan-500",
      icon: "🔧",
      features: ["Auto-scaling based on folders", "Service discovery", "Load balancing", "Health monitoring"]
    },
    {
      name: "Lang",
      tagline: "Polyglot Runtime Engine", 
      description: "Every language, unified execution environment",
      status: "Runtime Orchestrator",
      color: "from-green-500 to-emerald-500",
      icon: "💻",
      features: ["Multi-language harmony", "Dependency resolution", "Runtime optimization", "Cross-language APIs"]
    },
    {
      name: "Proc", 
      tagline: "Workflow Choreography",
      description: "Event-driven microservice orchestration",
      status: "Process Orchestrator",
      color: "from-purple-500 to-pink-500", 
      icon: "⚡",
      features: ["Event streaming", "Workflow automation", "Process monitoring", "Fault tolerance"]
    }
  ];

  const revolutionaryFeatures = [
    {
      title: "95% Service Detection Accuracy",
      description: "AI-powered analysis identifies deployable services from any folder structure",
      icon: "🎯",
      metric: "95%"
    },
    {
      title: "60-Second Deployments",
      description: "From folder drop to production-ready service in under a minute",
      icon: "⚡",
      metric: "60s"
    },
    {
      title: "Zero Configuration Required",
      description: "No YAML, no Docker knowledge, no DevOps expertise needed",
      icon: "🎪",
      metric: "0"
    },
    {
      title: "Enterprise-Grade Monitoring",
      description: "Built-in health checks, metrics, alerting, and circuit breakers",
      icon: "📊",
      metric: "100%"
    }
  ];

  const useCases = [
    {
      title: "E-commerce Platform",
      folder: "my-ecommerce-store",
      services: ["react-frontend", "node-api", "postgres-db", "redis-cache"],
      status: "Running",
      metrics: "15.2K req/min • 99.9% uptime",
      icon: "🛒",
      confidence: 94,
      deployTime: "47s"
    },
    {
      title: "ML Training Pipeline", 
      folder: "ai-model-trainer",
      services: ["data-ingestion", "model-training", "inference-api", "monitoring"],
      status: "Scaling",
      metrics: "2.1K predictions/sec • 12 models",
      icon: "🤖", 
      confidence: 89,
      deployTime: "52s"
    },
    {
      title: "Social Media App",
      folder: "social-platform",
      services: ["react-web", "mobile-api", "websocket-service", "media-processor"],
      status: "Healthy", 
      metrics: "8.7K active users • 45ms latency",
      icon: "📱",
      confidence: 96,
      deployTime: "38s"
    }
  ];

  const enterpriseStats = [
    { label: "Services Deployed", value: "50K+", icon: "🚀" },
    { label: "Developer Hours Saved", value: "2M+", icon: "⏰" },
    { label: "Infrastructure Cost Reduction", value: "67%", icon: "💰" },
    { label: "Deployment Success Rate", value: "99.7%", icon: "✅" }
  ];

  const enterpriseFeatures = [
    { title: "Circuit Breakers", description: "Fault-tolerant service communication with automatic recovery", icon: "🛡️" },
    { title: "Auto-scaling", description: "Dynamic resource allocation based on demand patterns", icon: "📈" },
    { title: "Health Monitoring", description: "Real-time service health and performance metrics", icon: "💚" },
    { title: "Zero-Config Deployment", description: "No YAML files, no complex configuration needed", icon: "🎯" },
    { title: "Multi-Cloud Support", description: "Deploy to AWS, Azure, GCP, or on-premise infrastructure", icon: "☁️" },
    { title: "Security by Default", description: "Container isolation and secure networking built-in", icon: "🔒" }
  ];

  onMount(() => {
    const interval = setInterval(() => {
      if (!isAnimating) {
        currentStep = (currentStep + 1) % revolutionSteps.length;
      }
    }, 4000);

    return () => clearInterval(interval);
  });

  function setActiveDemo(demo, index) {
    activeDemo = demo;
    currentStep = index;
  }

  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
  }

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }

  function getStatusColor(status) {
    switch (status.toLowerCase()) {
      case 'running': return 'bg-green-500/20 text-green-400 border-green-500/30';
      case 'scaling': return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
      case 'healthy': return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
      default: return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  }
</script>

<svelte:window bind:scrollY />

<!-- Navigation -->
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
          <a href={item.href} class="text-gray-300 hover:text-white transition-colors duration-200 font-medium">
            {item.label}
          </a>
        {/each}
      </div>

      <!-- Desktop Actions -->
      <div class="hidden md:flex items-center space-x-4">
        <a href="/auth/login" class="text-gray-300 hover:text-white transition-colors duration-200 font-medium">
          Sign In
        </a>
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-6 py-2 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105">
          <a href="/auth/register">Start Revolution</a>
        </Button>
      </div>

      <!-- Mobile Menu Button -->
      <button class="md:hidden text-white p-2" onclick={toggleMobileMenu}>
        {#if mobileMenuOpen}
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        {:else}
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
          <a href={item.href} class="block text-gray-300 hover:text-white transition-colors duration-200 font-medium py-2" onclick={closeMobileMenu}>
            {item.label}
          </a>
        {/each}
        <div class="border-t border-slate-800/50 pt-4 space-y-4">
          <a href="/auth/login" class="block text-gray-300 hover:text-white transition-colors duration-200 font-medium py-2" onclick={closeMobileMenu}>
            Sign In
          </a>
          <Button class="w-full bg-gradient-to-r from-teal-500 to-cyan-500 text-white py-3 rounded-lg font-semibold">
            <a href="/auth/register" onclick={closeMobileMenu}>Start Revolution</a>
          </Button>
        </div>
      </div>
    </div>
  {/if}
</nav>

<!-- Main Content -->
<div class="bg-slate-950 text-white relative min-h-screen overflow-hidden">
  <!-- Background Effects -->
  <div class="fixed inset-0 overflow-hidden -z-10">
    <div class="absolute -top-40 -right-40 w-80 h-80 bg-gradient-to-r from-teal-500/20 to-cyan-500/20 rounded-full blur-3xl animate-pulse"></div>
    <div class="absolute -bottom-40 -left-40 w-80 h-80 bg-gradient-to-r from-purple-500/20 to-pink-500/20 rounded-full blur-3xl animate-pulse"></div>
    <div class="absolute top-1/3 left-1/3 w-96 h-96 bg-gradient-to-r from-orange-500/10 to-red-500/10 rounded-full blur-3xl"></div>
  </div>

  <!-- Hero Section -->
  <section class="relative z-10 pt-32 pb-20">
    <div class="max-w-7xl mx-auto px-6">
      <div class="text-center mb-16">
        <div class="mb-8">
          <Badge class="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 text-base font-bold border-none animate-pulse">
            🚀 REVOLUTIONARY: Folder as a Service
          </Badge>
        </div>
        
        <h1 class="text-6xl md:text-8xl font-black mb-8 leading-tight">
          Directory Organization
          <span class="bg-gradient-to-r from-teal-400 via-cyan-400 to-blue-400 bg-clip-text text-transparent block animate-pulse">
            IS Deployment Strategy
          </span>
        </h1>
        
        <p class="text-xl md:text-3xl text-gray-200 mb-8 max-w-5xl mx-auto leading-relaxed">
          Drop any project folder → Watch it become a <strong class="text-teal-400">production-ready service</strong> in 60 seconds
        </p>
        
        <p class="text-lg md:text-xl text-gray-400 mb-12 max-w-4xl mx-auto">
          <span class="text-teal-400">●</span> AI-powered service detection with 95% accuracy
          <span class="mx-4 text-gray-600">|</span>
          <span class="text-cyan-400">●</span> Zero-configuration deployment  
          <span class="mx-4 text-gray-600">|</span>
          <span class="text-purple-400">●</span> Enterprise-grade monitoring built-in
        </p>

        <!-- CTA Buttons -->
        <div class="flex flex-col sm:flex-row justify-center gap-6 mb-20">
          <Button class="bg-gradient-to-r from-teal-500 via-cyan-500 to-blue-500 text-white px-12 py-6 rounded-xl font-bold hover:shadow-2xl hover:shadow-teal-500/25 transition-all transform hover:scale-110 text-xl">
            <a href="/auth/register" class="flex items-center gap-3">
              🚀 Start Your Revolution
            </a>
          </Button>
          <Button variant="outline" class="border-2 border-white/30 text-white px-12 py-6 rounded-xl font-bold hover:bg-white/10 transition-all text-xl backdrop-blur-sm">
            <a href="#revolution" class="flex items-center gap-3">
              ⚡ See It In Action
            </a>
          </Button>
        </div>

        <!-- Revolutionary Stats -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-16">
          {#each enterpriseStats as stat}
            <div class="text-center">
              <div class="text-4xl mb-2">{stat.icon}</div>
              <div class="text-3xl font-bold text-teal-400 mb-1">{stat.value}</div>
              <div class="text-sm text-gray-400">{stat.label}</div>
            </div>
          {/each}
        </div>
      </div>
    </div>
  </section>

  <!-- Revolutionary Demo Section -->
  <section id="revolution" class="relative z-10 py-20 px-6 bg-black/30">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h2 class="text-5xl font-bold mb-6">The Revolution in Action</h2>
        <p class="text-xl text-gray-300 max-w-3xl mx-auto">
          Watch how Kyozo transforms complex container orchestration into something as simple as organizing files
        </p>
      </div>
        
      <!-- Step Indicators -->
      <div class="flex flex-wrap justify-center gap-4 mb-16">
        {#each revolutionSteps as step, index}
          <button 
            class="flex flex-col items-center space-y-3 p-6 rounded-2xl transition-all duration-500 min-w-[200px] {currentStep === index ? 'bg-gradient-to-r from-teal-500/30 to-cyan-500/30 border-2 border-teal-500/50 scale-105' : 'bg-slate-800/40 hover:bg-slate-700/40 border border-slate-700'}"
            onclick={() => setActiveDemo(step.id, index)}
          >
            <div class="text-6xl animate-bounce">{step.icon}</div>
            <div class="text-center">
              <div class="font-bold text-lg mb-2">{step.title}</div>
              <div class="text-sm text-gray-400">{step.description}</div>
            </div>
          </button>
        {/each}
      </div>

      <!-- Demo Visual -->
      <div class="bg-gradient-to-r from-slate-900/80 to-slate-800/80 rounded-3xl p-8 border border-slate-700 backdrop-blur-sm">
        <div class="mb-6 text-center">
          <h3 class="text-2xl font-bold text-teal-400 mb-2">{revolutionSteps[currentStep].title}</h3>
          <p class="text-gray-300">{revolutionSteps[currentStep].detail}</p>
        </div>

        {#if currentStep === 0}
          <div class="text-center py-16">
            <div class="text-9xl mb-8 animate-bounce">{revolutionSteps[0].icon}</div>
            <div class="text-3xl font-bold mb-6">Drop Your Project Folder</div>
            <div class="text-gray-400 mb-8 max-w-2xl mx-auto">
              Any structure works: React apps, Node.js APIs, Python ML models, Go microservices, Rust backends...
            </div>
            <div class="max-w-md mx-auto border-4 border-dashed border-teal-500/50 rounded-2xl p-12 bg-teal-500/5 hover:bg-teal-500/10 transition-all">
              <div class="text-teal-400 font-mono text-2xl mb-2">my-awesome-project/</div>
              <div class="text-gray-500 text-sm">Drag your folder here</div>
            </div>
          </div>
        {:else if currentStep === 1}
          <div class="text-center py-16">
            <div class="text-9xl mb-8 animate-spin">{revolutionSteps[1].icon}</div>
            <div class="text-3xl font-bold mb-6">AI Analyzes Your Structure</div>
            <div class="text-gray-400 mb-8">Advanced AI detects services, dependencies, and optimal deployment patterns...</div>
            <div class="max-w-2xl mx-auto space-y-4">
              {#each ['🔍 Scanning file structure...', '📦 Dockerfile detected', '⚙️ package.json analyzed', '🔗 Service dependencies mapped', '✅ Deployment strategy optimized'] as step, i}
                <div class="flex items-center justify-center space-x-4 opacity-{i < 4 ? '100' : '60'}">
                  <div class="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
                  <div class="text-green-400 font-mono text-lg">{step}</div>
                </div>
              {/each}
            </div>
          </div>
        {:else if currentStep === 2}
          <div class="text-center py-16">
            <div class="text-9xl mb-8 animate-pulse">{revolutionSteps[2].icon}</div>
            <div class="text-3xl font-bold mb-6">Services Deploy Automatically</div>
            <div class="text-gray-400 mb-8">Building containers and deploying to production infrastructure...</div>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
              {#each ['Frontend Service', 'API Gateway', 'Database'] as service, i}
                <div class="bg-slate-800/60 rounded-xl p-6 border-2 border-green-500/30 backdrop-blur-sm">
                  <div class="text-green-400 font-bold text-xl mb-2">{service}</div>
                  <div class="text-xs text-gray-400 mb-4">Status: Running ✅</div>
                  <div class="w-full bg-slate-700 rounded-full h-3">
                    <div class="bg-gradient-to-r from-green-500 to-emerald-500 h-3 rounded-full w-full animate-pulse"></div>
                  </div>
                  <div class="text-xs text-green-400 mt-2">Deployed in {38 + i * 4}s</div>
                </div>
              {/each}
            </div>
          </div>
        {:else if currentStep === 3}
          <div class="text-center py-16">
            <div class="text-9xl mb-8">{revolutionSteps[3].icon}</div>
            <div class="text-3xl font-bold mb-6">Enterprise Monitoring Active</div>
            <div class="text-gray-400 mb-8">Real-time health monitoring, performance metrics, and alerting systems online</div>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-6 max-w-5xl mx-auto">
              <div class="bg-slate-800/60 rounded-xl p-6 backdrop-blur-sm">
                <div class="text-teal-400 font-bold text-lg mb-2">CPU Usage</div>
                <div class="text-4xl font-bold text-white mb-1">23%</div>
                <div class="text-xs text-green-400">Healthy ✅</div>
              </div>
              <div class="bg-slate-800/60 rounded-xl p-6 backdrop-blur-sm">
                <div class="text-purple-400 font-bold text-lg mb-2">Requests</div>
                <div class="text-4xl font-bold text-white mb-1">1.2K</div>
                <div class="text-xs text-green-400">per minute</div>
              </div>
              <div class="bg-slate-800/60 rounded-xl p-6 backdrop-blur-sm">
                <div class="text-blue-400 font-bold text-lg mb-2">Response Time</div>
                <div class="text-4xl font-bold text-white mb-1">45ms</div>
                <div class="text-xs text-green-400">Average</div>
              </div>
              <div class="bg-slate-800/60 rounded-xl p-6 backdrop-blur-sm">
                <div class="text-green-400 font-bold text-lg mb-2">Uptime</div>
                <div class="text-4xl font-bold text-white mb-1">99.9%</div>
                <div class="text-xs text-green-400">Last 30d</div>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </section>

  <!-- Revolutionary Features -->
  <section class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-6">Revolutionary Capabilities</h3>
        <p class="text-xl text-gray-300 max-w-3xl mx-auto">
          Features that transform container orchestration from complex to intuitive
        </p>
      </div>

      <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
        {#each revolutionaryFeatures as feature}
          <div class="bg-gradient-to-br from-slate-800/50 to-slate-900/50 rounded-2xl p-8 border border-slate-700/50 backdrop-blur-sm text-center">
            <div class="text-6xl mb-6">{feature.icon}</div>
            <div class="text-4xl font-bold text-teal-400 mb-4">{feature.metric}</div>
            <h4 class="text-xl font-bold mb-4">{feature.title}</h4>
            <p class="text-gray-300 text-sm">{feature.description}</p>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Platform Suite -->
  <section id="platform" class="relative z-10 py-20 px-6 bg-black/30">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-6">Complete Development Platform</h3>
        <p class="text-xl text-gray-300 max-w-4xl mx-auto">
          Five integrated services that work together to transform how you build, deploy, and manage applications
        </p>
      </div>

      <div class="grid lg:grid-cols-3 md:grid-cols-2 gap-8">
        {#each productSuite as product}
          <div class="bg-white/5 backdrop-blur-sm rounded-2xl p-8 border border-white/10 hover:border-white/20 transition-all duration-300 transform hover:scale-105 {product.priority ? 'ring-2 ring-teal-500/50' : ''}">
            <div class="flex items-center justify-between mb-6">
              <div class="text-5xl">{product.icon}</div>
              {#if product.revolutionary}
                <Badge class="bg-gradient-to-r from-orange-500 to-red-500 text-white border-none px-3 py-2 font-bold animate-pulse">
                  REVOLUTIONARY
                </Badge>
              {/if}
            </div>
            
            <h4 class="text-2xl font-bold mb-3">{product.name}</h4>
            <p class="text-teal-400 font-semibold mb-4">{product.tagline}</p>
            <p class="text-gray-300 mb-6 leading-relaxed">{product.description}</p>
            
            <div class="space-y-3 mb-8">
              {#each product.features as feature}
                <div class="flex items-center text-sm text-gray-400">
                  <div class="w-2 h-2 bg-teal-400 rounded-full mr-3 flex-shrink-0"></div>
                  {feature}
                </div>
              {/each}
            </div>
            
            <Badge class="px-4 py-3 bg-gradient-to-r {product.color} text-white text-sm rounded-lg border-none font-semibold">
              {product.status}
            </Badge>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Use Cases -->
  <section id="use-cases" class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-6">Real-World Success Stories</h3>
        <p class="text-xl text-gray-300 max-w-4xl mx-auto">
          See how teams deploy complex, production-grade applications with zero configuration
        </p>
      </div>

      <div class="grid md:grid-cols-3 gap-8">
        {#each useCases as useCase}
          <div class="bg-gradient-to-br from-slate-900/70 to-slate-800/70 rounded-2xl p-8 border border-slate-700/50 backdrop-blur-sm hover:border-teal-500/30 transition-all duration-300">
            <div class="flex items-center justify-between mb-6">
              <div class="text-4xl">{useCase.icon}</div>
              <Badge class="px-3 py-2 {getStatusColor(useCase.status)} border text-sm rounded-lg font-medium">
                {useCase.status}
              </Badge>
            </div>
            
            <h4 class="text-2xl font-bold mb-2">{useCase.title}</h4>
            <p class="text-teal-400 font-mono text-sm mb-6">📁 {useCase.folder}/</p>
            
            <div class="space-y-3 mb-6">
              {#each useCase.services as service}
                <div class="flex items-center justify-between bg-slate-800/50 rounded-lg px-4 py-3">
                  <span class="text-sm font-medium">{service}</span>
                  <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                </div>
              {/each}
            </div>
            
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-gray-400">Performance:</span>
                <span class="text-white font-medium">{useCase.metrics}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-400">Deploy Time:</span>
                <span class="text-green