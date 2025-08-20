<script lang="ts">
  import { onMount } from 'svelte';
  import type { LiveSvelteProps } from './liveSvelte';
  import { Button } from './ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
  import { Badge } from './ui/badge';
  import { Input } from './ui/input';
  import { Sheet, SheetContent, SheetTrigger } from './ui/sheet';
  import { Menu, Github, Twitter, Mail, MapPin, Phone, Star } from '@lucide/svelte';

  interface Props extends LiveSvelteProps {
    [key: string]: any;
  }

  let { live, ...props }: Props = $props();

  let activeTab = $state('overview');
  let currentCode = $state('import pandas as pd');
  let codeIndex = $state(0);

  const codeExamples = [
    'import pandas as pd',
    'def analyze_data():',
    'FROM node:18-alpine',
    'SELECT * FROM users',
    'const app = express()'
  ];

  // Typing animation
  onMount(() => {
    const interval = setInterval(() => {
      codeIndex = (codeIndex + 1) % codeExamples.length;
      currentCode = codeExamples[codeIndex];
    }, 3000);

    return () => clearInterval(interval);
  });

  const coreServices = [
    {
      name: "Editor",
      icon: "✏️",
      description: "Where Ideas Become Infrastructure",
      tagline: "The focal point where thoughts transform into deployable reality",
      color: "from-violet-500 to-purple-600",
      svgIcon: `<circle cx="15" cy="15" r="15" fill="#8b5cf6"/><path d="M8 12 L12 8 L20 16 L16 20 Z" fill="white" stroke="white" stroke-width="1"/><path d="M8 12 L8 20 L16 20" fill="none" stroke="white" stroke-width="1.5" stroke-linecap="round"/><circle cx="18" cy="6" r="2" fill="white"/>`,
      port: ":3000",
      features: ["LSP Superpower", "AI Boosting", "Storage Tooting", "DAG Roosting"],
      status: "Primary Interface",
      priority: true
    },
    {
      name: "Build",
      icon: "🔧",
      description: "Folder-First Development Engine",
      tagline: "Design your folder structure, get your service architecture",
      color: "from-blue-500 to-cyan-500",
      svgIcon: `<circle cx="15" cy="15" r="15" fill="#0ea5e9"/><rect x="8" y="10" width="14" height="10" rx="1" fill="none" stroke="white" stroke-width="1.5"/><rect x="10" y="8" width="10" height="6" rx="1" fill="none" stroke="white" stroke-width="1.5"/><rect x="12" y="6" width="6" height="4" rx="1" fill="none" stroke="white" stroke-width="1.5"/>`,
      port: ":4001",
      features: ["Directory-Driven Deployment", "Organic Service Scaling", "Filesystem Service Discovery", "Hierarchical Load Balancing"],
      status: "Running"
    },
    {
      name: "Lang",
      icon: "💻",
      description: "Polyglot Runtime Orchestrator",
      tagline: "Every language, every framework, one unified execution environment",
      color: "from-green-500 to-emerald-500",
      svgIcon: `<circle cx="15" cy="15" r="15" fill="#10b981"/><path d="M10 8 L6 12 L10 16" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/><path d="M20 8 L24 12 L20 16" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/><circle cx="15" cy="12" r="1" fill="white"/><circle cx="15" cy="18" r="1" fill="white"/>`,
      port: ":4002",
      features: ["Multi-Language Harmony", "Dependency Resolution", "Runtime Optimization", "Cross-Language Communication"],
      status: "Running"
    },
    {
      name: "Proc",
      icon: "⚡",
      description: "Workflow Choreography Engine",
      tagline: "Orchestrating services through directory arrangement",
      color: "from-purple-500 to-pink-500",
      svgIcon: `<circle cx="15" cy="15" r="15" fill="#a855f7"/><circle cx="10" cy="10" r="2" fill="white"/><circle cx="20" cy="10" r="2" fill="white"/><circle cx="15" cy="20" r="2" fill="white"/><path d="M12 10 L18 10" stroke="white" stroke-width="1.5"/><path d="M10 12 L13 18" stroke="white" stroke-width="1.5"/><path d="M20 12 L17 18" stroke="white" stroke-width="1.5"/>`,
      port: ":4003",
      features: ["Directory Choreography", "Event-Driven Architecture", "Process Monitoring", "Workflow Automation"],
      status: "Running"
    },
    {
      name: "Store",
      icon: "💾",
      description: "Collaborative Knowledge Fabric",
      tagline: "Tending your service ecosystem like organizing files",
      color: "from-orange-500 to-red-500",
      svgIcon: `<circle cx="15" cy="15" r="15" fill="#f59e0b"/><ellipse cx="15" cy="10" rx="6" ry="2" fill="white"/><ellipse cx="15" cy="15" rx="6" ry="2" fill="white"/><ellipse cx="15" cy="20" rx="6" ry="2" fill="white"/><rect x="9" y="10" width="12" height="10" fill="white" opacity="0.8"/>`,
      port: ":4004",
      features: ["Service Gardening", "Filesystem Telemetry", "Real-time Collaboration", "Organic Architecture"],
      status: "Running"
    }
  ];

  const folderExamples = [
    {
      name: "my-ecommerce-app",
      status: "running",
      services: ["web-frontend", "api-gateway", "database"],
      metrics: "45 req/min",
      icon: "🛒"
    },
    {
      name: "data-pipeline",
      status: "healthy",
      services: ["ingestion", "processing", "storage"],
      metrics: "2.3k events/sec",
      icon: "📊"
    },
    {
      name: "ml-platform",
      status: "scaling",
      services: ["training", "inference", "monitoring"],
      metrics: "12 models active",
      icon: "🤖"
    }
  ];

  const architectureFeatures = [
    {
      title: "Folder-First Development",
      description: "Design your folder structure, get your service architecture automatically",
      icon: "📁"
    },
    {
      title: "AI-Powered Editor",
      description: "Collaborative editing with AI assistance and real-time execution",
      icon: "🤖"
    },
    {
      title: "Directory-Driven Deployment",
      description: "Your file organization IS your deployment strategy",
      icon: "🚀"
    },
    {
      title: "Organic Service Scaling",
      description: "Add folders to scale, remove folders to descale services naturally",
      icon: "📈"
    }
  ];

  function getStatusColor(status: string) {
    switch(status) {
      case 'running': return 'bg-green-500/20 text-green-400';
      case 'healthy': return 'bg-blue-500/20 text-blue-400';
      case 'scaling': return 'bg-yellow-500/20 text-yellow-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  }

  function setActiveTab(tab: string) {
    activeTab = tab;
  }
</script>

<div class="bg-slate-950 text-white relative min-h-screen">
  <!-- Animated Background -->
  <div class="fixed inset-0 overflow-hidden -z-10">
    <div class="absolute -top-40 -right-40 w-80 h-80 bg-primary/20 rounded-full blur-3xl animate-pulse"></div>
    <div class="absolute -bottom-40 -left-40 w-80 h-80 bg-accent/20 rounded-full blur-3xl animate-pulse"></div>
  </div>



  <!-- Hero Section with Editor -->
  <section class="relative z-10 py-20">
    <div class="max-w-7xl mx-auto px-6">
      <!-- Hero Text -->
      <div class="text-center mb-12">
        <h2 class="text-6xl font-bold mb-6">
          You think you're just
          <span class="bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent block">
            writing documents...
          </span>
        </h2>
        <p class="text-xl text-gray-300 mb-4">
          Behind every keystroke is an entire <strong>computational infrastructure</strong>
        </p>
        <p class="text-lg text-gray-400 mb-8">
          designed to make your ideas <em>executable</em>, <em>collaborative</em>, and <em>infinitely scalable</em>.
        </p>
      </div>

      <!-- HERO EDITOR INTERFACE -->
      <div class="bg-white rounded-xl shadow-2xl border border-gray-200 overflow-hidden mb-12 max-w-6xl mx-auto">
        <!-- Editor Toolbar -->
        <div class="bg-gray-50 border-b border-gray-200 px-4 py-3 flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <div class="flex items-center space-x-1">
              <button class="p-1.5 hover:bg-gray-200 rounded text-gray-600">
                <strong>B</strong>
              </button>
              <button class="p-1.5 hover:bg-gray-200 rounded text-gray-600">
                <em>I</em>
              </button>
              <button class="p-1.5 hover:bg-gray-200 rounded text-gray-600">
                <u>U</u>
              </button>
            </div>
            <div class="w-px h-6 bg-gray-300"></div>
            <div class="flex items-center space-x-1">
              <button class="px-2 py-1 hover:bg-gray-200 rounded text-sm text-gray-600">H1</button>
              <button class="px-2 py-1 hover:bg-gray-200 rounded text-sm text-gray-600">H2</button>
              <button class="px-2 py-1 hover:bg-gray-200 rounded text-sm text-gray-600">H3</button>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <Badge variant="secondary">Build</Badge>
            <Badge variant="secondary">Lang</Badge>
            <Badge variant="secondary">Proc</Badge>
            <Badge variant="secondary">Store</Badge>
          </div>
        </div>

        <!-- Editor Content -->
        <div class="p-8 bg-white min-h-[500px] relative">
          <div class="prose max-w-none">
            <h1 class="text-3xl font-bold text-gray-900 mb-6">Welcome to Kyozo Store</h1>
            <p class="text-gray-700 mb-6 text-lg">The revolutionary platform that transforms your folders into services.</p>

            <!-- Terminal Demo -->
            <div class="bg-gray-900 rounded-lg p-6 font-mono text-sm relative group mb-6">
              <div class="text-green-400 mb-3 text-base">$ kyozo deploy my-app</div>
              <div class="text-white space-y-1 text-base">
                <div><span class="text-blue-300">✓</span> <span class="text-yellow-300">Scanning folder structure...</span></div>
                <div><span class="text-blue-300">✓</span> <span class="text-yellow-300">Building services...</span></div>
                <div><span class="text-blue-300">✓</span> <span class="text-yellow-300">Deploying to cloud...</span></div>
                <div class="mt-3">
                  <span class="border-r-2 border-green-500 animate-pulse">█</span>
                </div>
              </div>

              <!-- Service Status Indicators -->
              <div class="absolute top-4 right-4 flex space-x-2">
                <div class="w-2 h-2 bg-blue-500 rounded-full animate-pulse" title="Build Active"></div>
                <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse" title="Lang Active"></div>
                <div class="w-2 h-2 bg-purple-500 rounded-full animate-pulse" title="Proc Active"></div>
                <div class="w-2 h-2 bg-orange-500 rounded-full animate-pulse" title="Store Active"></div>
              </div>
            </div>

            <!-- Service Integration Demo -->
            <div class="p-4 bg-purple-50 border-l-4 border-purple-400 rounded-r mb-6">
              <div class="flex items-start space-x-3">
                <div class="flex-shrink-0">
                  <svg width="24" height="24" viewBox="0 0 30 30">
                    {@html coreServices[0].svgIcon}
                  </svg>
                </div>
                <div>
                  <div class="text-sm font-medium text-purple-800 mb-2">Editor Service Active</div>
                  <div class="text-sm text-purple-700 mb-3">Real-time collaboration with AI assistance enabled</div>
                  <div class="flex flex-wrap gap-2">
                    <button class="text-xs bg-purple-600 text-white px-3 py-1 rounded hover:bg-purple-700">LSP</button>
                    <button class="text-xs bg-purple-600 text-white px-3 py-1 rounded hover:bg-purple-700">AI</button>
                    <button class="text-xs bg-purple-600 text-white px-3 py-1 rounded hover:bg-purple-700">Storage</button>
                    <button class="text-xs bg-purple-600 text-white px-3 py-1 rounded hover:bg-purple-700">DAG</button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Service Flow Demo -->
            <div class="p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
              <div class="text-base font-medium text-gray-800 mb-4 flex items-center">
                <span class="mr-2">🔄</span> Service Flow
              </div>
              <div class="flex items-center justify-center space-x-8">
                <div class="text-center">
                  <div class="w-16 h-16 bg-blue-500 rounded-lg flex items-center justify-center text-white font-bold mb-2 shadow-lg">
                    <svg width="24" height="24" viewBox="0 0 30 30">
                      <circle cx="15" cy="15" r="15" fill="white"/>
                      <text x="15" y="20" text-anchor="middle" font-size="12" fill="#0ea5e9">B</text>
                    </svg>
                  </div>
                  <div class="text-sm text-gray-600 font-medium">Build</div>
                  <div class="text-xs text-green-600">Active</div>
                </div>
                <div class="text-gray-400 text-2xl">→</div>
                <div class="text-center">
                  <div class="w-16 h-16 bg-green-500 rounded-lg flex items-center justify-center text-white font-bold mb-2 shadow-lg">
                    <svg width="24" height="24" viewBox="0 0 30 30">
                      <circle cx="15" cy="15" r="15" fill="white"/>
                      <text x="15" y="20" text-anchor="middle" font-size="12" fill="#10b981">L</text>
                    </svg>
                  </div>
                  <div class="text-sm text-gray-600 font-medium">Lang</div>
                  <div class="text-xs text-green-600">Active</div>
                </div>
                <div class="text-gray-400 text-2xl">→</div>
                <div class="text-center">
                  <div class="w-16 h-16 bg-orange-500 rounded-lg flex items-center justify-center text-white font-bold mb-2 shadow-lg">
                    <svg width="24" height="24" viewBox="0 0 30 30">
                      <circle cx="15" cy="15" r="15" fill="white"/>
                      <text x="15" y="20" text-anchor="middle" font-size="12" fill="#f59e0b">S</text>
                    </svg>
                  </div>
                  <div class="text-sm text-gray-600 font-medium">Store</div>
                  <div class="text-xs text-green-600">Active</div>
                </div>
              </div>
              <div class="text-center mt-4">
                <button class="bg-teal-600 text-white px-6 py-2 rounded-lg hover:bg-teal-700 transition-colors font-medium">
                  Deploy Application
                </button>
              </div>
            </div>
          </div>

          <!-- Floating Service Status -->
          <div class="absolute bottom-6 right-6 flex space-x-3">
            {#each coreServices.slice(1, 5) as service}
              <div class="bg-gray-900 text-white px-3 py-2 rounded-lg shadow-lg flex items-center space-x-2 text-sm">
                <svg width="16" height="16" viewBox="0 0 30 30">
                  {@html service.svgIcon}
                </svg>
                <span>{service.name}</span>
                <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
              </div>
            {/each}
          </div>
        </div>
      </div>

      <!-- CTA Buttons -->
      <div class="flex justify-center space-x-4">
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-8 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105 text-lg">
          <a href="/auth/register">Get Started Now</a>
        </Button>
        <Button variant="outline" class="border border-slate-600 text-white px-8 py-4 rounded-lg font-semibold hover:bg-white/5 transition-all text-lg">
          <a href="/openapi">View Documentation</a>
        </Button>
      </div>
    </div>
  </section>

  <!-- Platform Section -->
  <section id="platform" class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto">
      <h3 class="text-4xl font-bold text-center mb-4">The Kyozo Platform</h3>
      <p class="text-gray-300 text-center mb-12 text-lg">
        A revolutionary approach to development where every folder becomes a complete service ecosystem
      </p>
      
      <div class="grid md:grid-cols-3 gap-8">
        <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10">
          <div class="w-16 h-16 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-lg flex items-center justify-center mx-auto mb-6">
            <span class="text-2xl">🗂️</span>
          </div>
          <h4 class="text-2xl font-bold text-center mb-4">Folder as a Service</h4>
          <p class="text-gray-300 text-center">Transform any folder into a complete microservice with built-in APIs, storage, and processing capabilities.</p>
        </div>
        
        <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10">
          <div class="w-16 h-16 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center mx-auto mb-6">
            <span class="text-2xl">⚡</span>
          </div>
          <h4 class="text-2xl font-bold text-center mb-4">FileOps Engine</h4>
          <p class="text-gray-300 text-center">Advanced file operations with built-in versioning, collaboration, and real-time synchronization across teams.</p>
        </div>
        
        <div class="bg-white/5 backdrop-blur rounded-xl p-8 border border-white/10">
          <div class="w-16 h-16 bg-gradient-to-r from-green-500 to-emerald-500 rounded-lg flex items-center justify-center mx-auto mb-6">
            <span class="text-2xl">🔗</span>
          </div>
          <h4 class="text-2xl font-bold text-center mb-4">Universal Integration</h4>
          <p class="text-gray-300 text-center">Connect with any tool, API, or service through our extensible architecture and plugin ecosystem.</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Features Section -->
  <section id="features" class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto">
      <h3 class="text-4xl font-bold text-center mb-4">Why Kyozo Store?</h3>
      <p class="text-gray-300 text-center mb-12 text-lg">
        The revolutionary approach to service development
      </p>

      <div class="grid md:grid-cols-4 gap-6 mt-12">
        <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
          <div class="w-12 h-12 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-lg flex items-center justify-center mx-auto mb-4">
            💡
          </div>
          <h4 class="text-lg font-bold text-center mb-2">Intuitive</h4>
          <p class="text-gray-300 text-sm text-center">Organize folders, get services</p>
        </div>

        <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
          <div class="w-12 h-12 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center mx-auto mb-4">
            🚀
          </div>
          <h4 class="text-lg font-bold text-center mb-2">Fast</h4>
          <p class="text-gray-300 text-sm text-center">Deploy in seconds, not hours</p>
        </div>

        <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
          <div class="w-12 h-12 bg-gradient-to-r from-green-500 to-emerald-500 rounded-lg flex items-center justify-center mx-auto mb-4">
            🔧
          </div>
          <h4 class="text-lg font-bold text-center mb-2">Scalable</h4>
          <p class="text-gray-300 text-sm text-center">Organic service scaling</p>
        </div>

        <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10">
          <div class="w-12 h-12 bg-gradient-to-r from-orange-500 to-red-500 rounded-lg flex items-center justify-center mx-auto mb-4">
            🤖
          </div>
          <h4 class="text-lg font-bold text-center mb-2">AI-Powered</h4>
          <p class="text-gray-300 text-sm text-center">Intelligent assistance</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Services Section -->
  <section id="services" class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <h3 class="text-4xl font-bold text-center mb-4">Core Services</h3>
      <p class="text-gray-300 text-center mb-12 text-lg">
        Five interconnected services that power your development
      </p>

      <div class="grid lg:grid-cols-5 md:grid-cols-3 gap-6">
        {#each coreServices as service}
          <div class="bg-white/5 backdrop-blur rounded-xl p-6 border border-white/10 hover:border-white/20 transition-all duration-300 transform hover:scale-105 {service.priority ? 'ring-2 ring-teal-500/50' : ''}">
            <div class="flex items-center justify-between mb-4">
              <div class="w-12 h-12 rounded-lg flex items-center justify-center">
                <svg width="30" height="30" viewBox="0 0 30 30">
                  {@html service.svgIcon}
                </svg>
              </div>
              <span class="text-xs text-gray-400">{service.port}</span>
            </div>
            <h4 class="text-xl font-bold mb-2">{service.name}</h4>
            <p class="text-gray-300 text-sm mb-2">{service.description}</p>
            <p class="text-gray-400 text-xs mb-4 italic">{service.tagline}</p>
            <div class="space-y-2">
              {#each service.features as feature}
                <div class="flex items-center text-xs text-gray-400">
                  <span class="w-1 h-1 bg-gray-500 rounded-full mr-2"></span>
                  {feature}
                </div>
              {/each}
            </div>
            <div class="mt-4 pt-3 border-t border-white/10">
              <Badge class="px-2 py-1 bg-green-500/20 text-green-400 text-xs rounded">
                {service.status}
              </Badge>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Folder Examples Section -->
  <section class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto">
      <h3 class="text-4xl font-bold text-center mb-12">See It In Action</h3>

      <div class="bg-gray-900/50 rounded-xl p-8 border border-gray-700">
        <div class="font-mono text-sm">
          <div class="text-green-400 mb-4">$ ls -la ~/my-projects/</div>
          {#each folderExamples as folder}
            <div class="ml-4 mb-4">
              <div class="flex items-center space-x-4 mb-2">
                <span class="text-blue-400">{folder.icon} {folder.name}/</span>
                <span class="px-2 py-1 rounded text-xs {getStatusColor(folder.status)}">
                  {folder.status}
                </span>
                <span class="text-gray-400 text-xs">{folder.metrics}</span>
              </div>
              {#each folder.services as service}
                <div class="ml-8 text-gray-300">├── {service}/</div>
              {/each}
            </div>
          {/each}
        </div>
      </div>
    </div>
  </section>

  <!-- Architecture Section -->
  <section id="architecture" class="relative z-10 py-20 px-6">
    <div class="max-w-7xl mx-auto">
      <h3 class="text-4xl font-bold text-center mb-12">Revolutionary Architecture</h3>

      <div class="grid md:grid-cols-2 gap-8">
        {#each architectureFeatures as feature}
          <div class="flex space-x-4 p-6 bg-white/5 rounded-xl border border-white/10">
            <div class="flex-shrink-0 text-4xl">
              {feature.icon}
            </div>
            <div>
              <h4 class="text-xl font-bold mb-2">{feature.title}</h4>
              <p class="text-gray-300">{feature.description}</p>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Live Demo Section -->
  <section id="demo" class="relative z-10 py-20 px-6 bg-black/20">
    <div class="max-w-7xl mx-auto text-center">
      <h3 class="text-4xl font-bold mb-6">
        See Kyozo Store in Action
      </h3>
      <p class="text-xl text-gray-300 mb-8">
        Experience the power of folder-based services with our interactive demo
      </p>
      <div class="flex justify-center">
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-8 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105 text-lg">
          <a href="/editor">Try Live Demo</a>
        </Button>
      </div>
    </div>
  </section>

  <!-- Get Started Section -->
  <section id="get-started" class="relative z-10 py-20 px-6">
    <div class="max-w-4xl mx-auto text-center">
      <h3 class="text-4xl font-bold mb-6">
        Ready to Transform Your Development?
      </h3>
      <p class="text-xl text-gray-300 mb-8">
        Join thousands of developers building the future with folder-first development
      </p>
      <div class="flex justify-center space-x-4">
        <Button class="bg-gradient-to-r from-teal-500 to-cyan-500 text-white px-8 py-4 rounded-lg font-semibold hover:shadow-lg hover:shadow-teal-500/25 transition-all transform hover:scale-105 text-lg">
          <a href="/auth/register">Get Started Free</a>
        </Button>
        <Button variant="outline" class="border border-white/20 text-white px-8 py-4 rounded-lg font-semibold hover:bg-white/5 transition-all text-lg">
          <a href="/openapi">View Documentation</a>
        </Button>
      </div>
    </div>

</div>

<style>
  .gradient-text {
    background: linear-gradient(135deg, #8b5cf6, #06b6d4);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  /* Ensure proper scrolling */
  :global(html, body) {
    height: auto;
    min-height: 100vh;
    overflow-x: hidden;
    overflow-y: auto;
  }
</style>
