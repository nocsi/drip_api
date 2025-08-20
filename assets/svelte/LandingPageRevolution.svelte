<script lang="ts">
  import { onMount } from 'svelte';
  import { Badge } from '$lib/components/ui/badge';
  import { Button } from '$lib/components/ui/button';

  interface Props {
    live?: any;
  }

  let { live, ...props }: Props = $props();

  let activeDemo = $state('folder-drop');
  let currentStep = $state(0);
  let isAnimating = $state(false);

  const revolutionSteps = [
    {
      id: 'folder-drop',
      title: 'Drop Your Folder',
      description: 'Simply drag any project folder into Kyozo',
      icon: '📁',
      visual: 'folder-animation'
    },
    {
      id: 'ai-analysis',
      title: 'AI Analyzes Structure',
      description: '95% accurate service detection in seconds',
      icon: '🤖',
      visual: 'analysis-animation'
    },
    {
      id: 'one-click-deploy',
      title: 'One-Click Deploy',
      description: 'From folder to running service in 60 seconds',
      icon: '🚀',
      visual: 'deploy-animation'
    },
    {
      id: 'live-monitoring',
      title: 'Enterprise Monitoring',
      description: 'Real-time dashboards and health monitoring',
      icon: '📊',
      visual: 'monitor-animation'
    }
  ];

  const productSuite = [
    {
      name: "Editor",
      tagline: "Where Ideas Become Infrastructure",
      description: "AI-powered collaborative development environment",
      status: "Core Platform",
      color: "from-violet-500 to-purple-600",
      icon: "✏️",
      features: ["Real-time collaboration", "AI code completion", "Integrated debugging", "Multi-language support"],
      priority: true
    },
    {
      name: "Store",
      tagline: "Folder as a Service Revolution",
      description: "Transform any folder into production-ready services",
      status: "🚀 Revolutionary",
      color: "from-orange-500 to-red-500",
      icon: "💾",
      features: ["AI service detection", "One-click deployment", "Enterprise monitoring", "Circuit breakers"],
      priority: true,
      new: true
    },
    {
      name: "Build",
      tagline: "Directory-Driven Architecture",
      description: "Your folder structure IS your service architecture",
      status: "Infrastructure",
      color: "from-blue-500 to-cyan-500",
      icon: "🔧",
      features: ["Auto-scaling", "Load balancing", "Service discovery", "Health checks"]
    },
    {
      name: "Lang",
      tagline: "Polyglot Runtime Engine",
      description: "Every language, unified execution environment",
      status: "Runtime",
      color: "from-green-500 to-emerald-500",
      icon: "💻",
      features: ["Multi-language support", "Dependency resolution", "Runtime optimization", "Cross-language APIs"]
    },
    {
      name: "Proc",
      tagline: "Workflow Orchestration",
      description: "Event-driven microservice choreography",
      status: "Orchestration",
      color: "from-purple-500 to-pink-500",
      icon: "⚡",
      features: ["Event streaming", "Workflow automation", "Process monitoring", "Fault tolerance"]
    }
  ];

  const useCases = [
    {
      title: "E-commerce Platform",
      folder: "my-ecommerce",
      services: ["frontend", "api", "payments", "inventory"],
      status: "Running",
      metrics: "15K req/min",
      icon: "🛒",
      confidence: 94
    },
    {
      title: "ML Pipeline",
      folder: "ai-platform",
      services: ["data-ingestion", "model-training", "inference-api"],
      status: "Scaling",
      metrics: "2.1K predictions/sec",
      icon: "🤖",
      confidence: 89
    },
    {
      title: "Microservices App",
      folder: "social-platform",
      services: ["user-service", "posts-api", "media-processor", "notifications"],
      status: "Healthy",
      metrics: "8.7K users active",
      icon: "📱",
      confidence: 96
    }
  ];

  const enterpriseFeatures = [
    { title: "Circuit Breakers", description: "Fault-tolerant service communication", icon: "🛡️" },
    { title: "Auto-scaling", description: "Dynamic resource allocation based on demand", icon: "📈" },
    { title: "Health Monitoring", description: "Real-time service health and performance metrics", icon: "💚" },
    { title: "Zero-Config Deployment", description: "No YAML, no complex configuration files", icon: "🎯" },
    { title: "Multi-Cloud Support", description: "Deploy to AWS, Azure, GCP, or on-premise", icon: "☁️" },
    { title: "Security by Default", description: "Container isolation and secure networking", icon: "🔒" }
  ];

  onMount(() => {
    const interval = setInterval(() => {
      if (!isAnimating) {
        currentStep = (currentStep + 1) % revolutionSteps.length;
      }
    }, 3000);

    return () => clearInterval(interval);
  });

  function setActiveDemo(demo: string) {
    activeDemo = demo;
    currentStep = revolutionSteps.findIndex(step => step.id === demo);
  }

  function getStatusColor(status: string) {
    switch (status.toLowerCase()) {
      case 'running': return 'bg-green-500/20 text-green-400 border-green-500/30';
      case 'scaling': return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
      case 'healthy': return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
      default: return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  }
</script>

<div class="bg-slate-950 text-white relative min-h-screen overflow-hidden">
  <!-- Background Effects -->
  <div class="fixed inset-0 overflow-hidden -z-10">
    <div class="absolute -top-40 -right-40 w-80 h-80 bg-primary/20 rounded-full blur-3xl animate-pulse"></div>
    <div class="absolute -bottom-40 -left-40 w-80 h-80 bg-accent/20 rounded-full blur-3xl animate-pulse"></div>
    <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-gradient-to-r from-teal-500/10 to-purple-500/10 rounded-full blur-3xl"></div>
  </div>

  <!-- Hero Section -->
  <section class="relative z-10 py-20">
    <div class="max-w-7xl mx-auto px-6">
      <div class="text-center mb-16">
        <div class="mb-6">
          <Badge class="bg-gradient-to-r from-orange-500 to-red-500 text-white px-4 py-2 text-sm font-medium border-none">
            🚀 Revolutionary: Folder as a Service
          </Badge>
        </div>
        
        <h1 class="text-7xl font-bold mb-8 leading-tight">
          Directory Organization
          <span class="bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent block">
            IS Deployment Strategy
          </span>
        </h1>
        
        <p class="text-2xl text-gray-300 mb-6 max-w-4xl mx-auto">
          Drop any project folder → Watch it become a <strong>production-ready service</strong> in 60 seconds
        </p>
        
        <p class="text-lg text-gray-400 mb-12 max-w-3xl mx-auto">
          AI-powered service detection • Zero-configuration deployment • Enterprise-grade monitoring
        </p>

        <!-- CTA Buttons -->
        <div class="flex justify-center space-x-6 mb-16">
          <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-10 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105 text-lg">
            <a href="/auth/register">Start Your Revolution</a>
          </Button>
          <Button variant="outline" class="border border-white/20 text-white px-10 py-4 rounded-lg font-semibold hover:bg-white/5 transition-all text-lg">
            <a href="/demo">See It In Action</a>
          </Button>
        </div>
      </div>

      <!-- Revolutionary Demo Section -->
      <div class="bg-gradient-to-r from-slate-900/50 to-slate-800/50 rounded-2xl border border-slate-700/50 backdrop-blur-sm p-8 mb-16">
        <h3 class="text-3xl font-bold text-center mb-12">The Revolution in Action</h3>
        
        <!-- Step Indicators -->
        <div class="flex justify-center space-x-8 mb-12">
          {#each revolutionSteps as step, index}
            <button 
              class="flex flex-col items-center space-y-3 p-4 rounded-xl transition-all duration-300 {currentStep === index ? 'bg-teal-500/20 border border-teal-500/30' : 'bg-slate-800/30 hover:bg-slate-700/30'}"
              onclick={() => setActiveDemo(step.id)}
            >
              <div class="text-4xl">{step.icon}</div>
              <div class="text-center">
                <div class="font-semibold text-sm">{step.title}</div>
                <div class="text-xs text-gray-400">{step.description}</div>
              </div>
            </button>
          {/each}
        </div>

        <!-- Demo Visual -->
        <div class="bg-slate-900 rounded-xl p-8 border border-slate-700">
          {#if currentStep === 0}
            <div class="text-center py-12">
              <div class="text-8xl mb-6 animate-bounce">📁</div>
              <div class="text-2xl font-bold mb-4">Drop Your Project Folder</div>
              <div class="text-gray-400">Any structure: React, Node.js, Python, Go, Rust...</div>
              <div class="mt-6 border-2 border-dashed border-teal-500/50 rounded-xl p-8 bg-teal-500/5">
                <div class="text-teal-400 font-mono text-lg">my-awesome-app/</div>
              </div>
            </div>
          {:else if currentStep === 1}
            <div class="text-center py-12">
              <div class="text-8xl mb-6 animate-spin">🤖</div>
              <div class="text-2xl font-bold mb-4">AI Analyzes Structure</div>
              <div class="text-gray-400 mb-6">Detecting services with 95% confidence...</div>
              <div class="space-y-3">
                {#each ['Dockerfile detected', 'package.json analyzed', 'Services identified', 'Dependencies mapped'] as item}
                  <div class="flex items-center justify-center space-x-3">
                    <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                    <div class="text-green-400 font-mono">{item}</div>
                  </div>
                {/each}
              </div>
            </div>
          {:else if currentStep === 2}
            <div class="text-center py-12">
              <div class="text-8xl mb-6 animate-pulse">🚀</div>
              <div class="text-2xl font-bold mb-4">One-Click Deploy</div>
              <div class="text-gray-400 mb-6">Building containers and deploying services...</div>
              <div class="grid grid-cols-3 gap-4">
                {#each ['Frontend', 'API', 'Database'] as service}
                  <div class="bg-slate-800 rounded-lg p-4 border border-green-500/30">
                    <div class="text-green-400 font-bold">{service}</div>
                    <div class="text-xs text-gray-400">Status: Running</div>
                    <div class="w-full bg-slate-700 rounded-full h-2 mt-2">
                      <div class="bg-green-500 h-2 rounded-full w-full"></div>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {:else if currentStep === 3}
            <div class="text-center py-12">
              <div class="text-8xl mb-6">📊</div>
              <div class="text-2xl font-bold mb-4">Enterprise Monitoring</div>
              <div class="text-gray-400 mb-6">Real-time health and performance metrics</div>
              <div class="grid grid-cols-2 gap-6">
                <div class="bg-slate-800 rounded-lg p-4">
                  <div class="text-teal-400 font-bold">CPU Usage</div>
                  <div class="text-3xl font-bold">23%</div>
                  <div class="text-xs text-gray-400">Healthy</div>
                </div>
                <div class="bg-slate-800 rounded-lg p-4">
                  <div class="text-purple-400 font-bold">Requests/min</div>
                  <div class="text-3xl font-bold">1.2K</div>
                  <div class="text-xs text-gray-400">Active</div>
                </div>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>
  </section>

  <!-- Product Suite Section -->
  <section id="products" class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-4">Complete Development Platform</h3>
        <p class="text-gray-300 text-lg max-w-3xl mx-auto">
          Five integrated services that transform how you build, deploy, and manage applications
        </p>
      </div>

      <div class="grid lg:grid-cols-3 md:grid-cols-2 gap-8">
        {#each productSuite as product}
          <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10 hover:border-white/20 transition-all duration-300 transform hover:scale-105 {product.priority ? 'ring-2 ring-teal-500/50' : ''}">
            <div class="flex items-center justify-between mb-6">
              <div class="text-4xl">{product.icon}</div>
              {#if product.new}
                <Badge class="bg-gradient-to-r from-orange-500 to-red-500 text-white border-none">NEW</Badge>
              {/if}
            </div>
            
            <h4 class="text-2xl font-bold mb-2">{product.name}</h4>
            <p class="text-teal-400 font-medium mb-3">{product.tagline}</p>
            <p class="text-gray-300 mb-6">{product.description}</p>
            
            <div class="space-y-2 mb-6">
              {#each product.features as feature}
                <div class="flex items-center text-sm text-gray-400">
                  <span class="w-1 h-1 bg-teal-400 rounded-full mr-3"></span>
                  {feature}
                </div>
              {/each}
            </div>
            
            <Badge class="px-3 py-2 bg-gradient-to-r {product.color} text-white text-sm rounded-lg border-none">
              {product.status}
            </Badge>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Use Cases Section -->
  <section id="use-cases" class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-4">Real-World Success Stories</h3>
        <p class="text-gray-300 text-lg max-w-3xl mx-auto">
          See how teams are using Kyozo to deploy complex applications with zero configuration
        </p>
      </div>

      <div class="grid md:grid-cols-3 gap-8">
        {#each useCases as useCase}
          <div class="bg-slate-900/50 rounded-xl p-8 border border-slate-700/50 backdrop-blur-sm">
            <div class="flex items-center justify-between mb-4">
              <div class="text-3xl">{useCase.icon}</div>
              <Badge class="px-2 py-1 {getStatusColor(useCase.status)} border text-xs rounded">
                {useCase.status}
              </Badge>
            </div>
            
            <h4 class="text-xl font-bold mb-2">{useCase.title}</h4>
            <p class="text-gray-400 font-mono text-sm mb-4">/{useCase.folder}/</p>
            
            <div class="space-y-2 mb-6">
              {#each useCase.services as service}
                <div class="flex items-center justify-between bg-slate-800/50 rounded px-3 py-2">
                  <span class="text-sm font-medium">{service}</span>
                  <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                </div>
              {/each}
            </div>
            
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-400">{useCase.metrics}</span>
              <span class="text-sm text-teal-400 font-medium">{useCase.confidence}% confidence</span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Enterprise Features -->
  <section id="enterprise" class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-4">Enterprise-Grade Features</h3>
        <p class="text-gray-300 text-lg max-w-3xl mx-auto">
          Production-ready infrastructure that scales with your business
        </p>
      </div>

      <div class="grid md:grid-cols-3 gap-8">
        {#each enterpriseFeatures as feature}
          <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
            <div class="text-3xl mb-4">{feature.icon}</div>
            <h4 class="text-xl font-bold mb-3">{feature.title}</h4>
            <p class="text-gray-300">{feature.description}</p>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Developer Experience -->
  <section id="developer-experience" class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-16">
        <h3 class="text-4xl font-bold mb-4">The Future of Deployment</h3>
        <p class="text-gray-300 text-lg max-w-4xl mx-auto">
          Transform the complex world of container orchestration into an intuitive, file-based experience
        </p>
      </div>

      <div class="bg-gradient-to-r from-slate-900/80 to-slate-800/80 rounded-2xl p-8 border border-slate-700/50">
        <div class="grid md:grid-cols-2 gap-12 items-center">
          <div>
            <h4 class="text-3xl font-bold mb-6">Before Kyozo</h4>
            <div class="space-y-4">
              <div class="flex items-center space-x-3 text-red-400">
                <span>❌</span>
                <span>Complex YAML configurations</span>
              </div>
              <div class="flex items-center space-x-3 text-red-400">
                <span>❌</span>
                <span>Hours of DevOps setup</span>
              </div>
              <div class="flex items-center space-x-3 text-red-400">
                <span>❌</span>
                <span>Kubernetes expertise required</span>
              </div>
              <div class="flex items-center space-x-3 text-red-400">
                <span>❌</span>
                <span>Manual service discovery</span>
              </div>
            </div>
          </div>
          
          <div>
            <h4 class="text-3xl font-bold mb-6">With Kyozo</h4>
            <div class="space-y-4">
              <div class="flex items-center space-x-3 text-green-400">
                <span>✅</span>
                <span>Drop folder → Running service</span>
              </div>
              <div class="flex items-center space-x-3 text-green-400">
                <span>✅</span>
                <span>60-second deployments</span>
              </div>
              <div class="flex items-center space-x-3 text-green-400">
                <span>✅</span>
                <span>Zero configuration required</span>
              </div>
              <div class="flex items-center space-x-3 text-green-400">
                <span>✅</span>
                <span>AI-powered service detection</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Call to Action -->
  <section id="get-started" class="relative z-10 py-20 px-6 bg-gradient-to-r from-teal-900/20 to-purple-900/20">
    <div class="max-w-4xl mx-auto text-center">
      <h3 class="text-5xl font-bold mb-6">
        Ready to Start Your
        <span class="bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent">
          Revolution?
        </span>
      </h3>
      <p class="text-xl text-gray-300 mb-8">
        Join thousands of developers who've discovered that infrastructure can be as simple as organizing files
      </p>
      
      <div class="flex justify-center space-x-6 mb-12">
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-10 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105 text-lg">
          <a href="/auth/register">Start Free Trial</a>
        </Button>
        <Button variant="outline" class="border border-white/20 text-white px-10 py-4 rounded-lg font-semibold hover:bg-white/5 transition-all text-lg">
          <a href="/openapi">View Documentation</a>
        </Button>
      </div>
      
      <p class="text-sm text-gray-400">
        No credit card required • Deploy unlimited projects • Enterprise support available
      </p>
    </div>
  </section>
</div>

<style>
  .gradient-text {
    background: linear-gradient(135deg, #14b8a6, #06b6d4);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  :global(html, body) {
    scroll-behavior: smooth;
    font-family: 'Inter', system-ui, -apple-system, sans-serif;
  }
</style>