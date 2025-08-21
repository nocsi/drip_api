<script>
  import { onMount, onDestroy } from 'svelte';
  import ServiceInstanceCard from './ServiceInstanceCard.svelte';
  import TopologyAnalysis from './TopologyAnalysis.svelte';
  import DeploymentLogs from './DeploymentLogs.svelte';
  import MetricsDashboard from './MetricsDashboard.svelte';
  import { Search, Plus, BarChart3, Cpu, Activity } from '@lucide/svelte';

  let { workspaceId, currentUser, onDeploymentStarted = () => {} } = $props();

  // State management using Svelte 5 runes
  let serviceInstances = $state([]);
  let topologyDetections = $state([]);
  let deploymentEvents = $state([]);
  let loading = $state(false);
  let error = $state(null);
  let selectedView = $state('overview');

  // Derived state using $derived
  let runningServices = $derived(
    serviceInstances.filter(s => s.attributes.containerStatus === 'running')
  );

  let pendingDeployments = $derived(
    serviceInstances.filter(s => ['pending', 'deploying'].includes(s.attributes.containerStatus))
  );

  let websocketConnection = null;

  onMount(async () => {
    await loadInitialData();
    setupWebSocketConnection();
  });

  onDestroy(() => {
    if (websocketConnection) {
      websocketConnection.disconnect();
    }
  });

  async function loadInitialData() {
    loading = true;
    error = null;

    try {
      // Mock API calls for now - replace with actual API client
      const mockServices = [
        {
          id: '1',
          attributes: {
            name: 'web-frontend',
            serviceType: 'web_app',
            containerStatus: 'running',
            healthStatus: 'healthy',
            imageName: 'nginx',
            imageTag: 'latest',
            replicaCount: 2,
            deployedAt: new Date().toISOString(),
            cpuUsagePercent: 45,
            memoryUsageMb: 256,
            portMappings: { '80': '8080', '443': '8443' },
            environmentVariables: { NODE_ENV: 'production', PORT: '8080' }
          }
        },
        {
          id: '2',
          attributes: {
            name: 'api-backend',
            serviceType: 'api_service',
            containerStatus: 'deploying',
            healthStatus: 'unknown',
            imageName: 'node',
            imageTag: '18-alpine',
            replicaCount: 3,
            cpuUsagePercent: 0,
            memoryUsageMb: 0,
            portMappings: { '3000': '3000' },
            environmentVariables: { NODE_ENV: 'production' }
          }
        }
      ];

      serviceInstances = mockServices;
      topologyDetections = [];
      deploymentEvents = [];

    } catch (err) {
      console.error('Failed to load container data:', err);
      error = 'Failed to load container orchestration data';
    } finally {
      loading = false;
    }
  }

  function setupWebSocketConnection() {
    // Mock WebSocket setup - replace with actual implementation
    console.log(`Setting up WebSocket connection for workspace: ${workspaceId}`);
  }

  function updateServiceInstance(serviceId, updates) {
    serviceInstances = serviceInstances.map(instance =>
      instance.id === serviceId
        ? { ...instance, attributes: { ...instance.attributes, ...updates } }
        : instance
    );
  }

  function addDeploymentEvent(event) {
    deploymentEvents = [event, ...deploymentEvents.slice(0, 49)];
  }

  async function deployService(serviceInstanceId, config = {}) {
    try {
      loading = true;

      updateServiceInstance(serviceInstanceId, {
        containerStatus: 'deploying'
      });

      onDeploymentStarted({
        serviceInstanceId,
        config
      });

      // Simulate deployment process
      setTimeout(() => {
        updateServiceInstance(serviceInstanceId, {
          containerStatus: 'running',
          healthStatus: 'healthy',
          deployedAt: new Date().toISOString()
        });
        loading = false;
      }, 3000);

    } catch (err) {
      console.error('Failed to deploy service:', err);
      error = `Failed to deploy service: ${err.message}`;
      loading = false;
    }
  }

  async function stopService(serviceInstanceId) {
    try {
      loading = true;

      updateServiceInstance(serviceInstanceId, {
        containerStatus: 'stopped',
        healthStatus: 'unknown'
      });
    } catch (err) {
      console.error('Failed to stop service:', err);
      error = `Failed to stop service: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  async function startService(serviceInstanceId) {
    try {
      loading = true;

      updateServiceInstance(serviceInstanceId, {
        containerStatus: 'running',
        healthStatus: 'healthy'
      });
    } catch (err) {
      console.error('Failed to start service:', err);
      error = `Failed to start service: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  async function scaleService(serviceInstanceId, replicaCount) {
    try {
      loading = true;

      updateServiceInstance(serviceInstanceId, {
        replicaCount: replicaCount
      });
    } catch (err) {
      console.error('Failed to scale service:', err);
      error = `Failed to scale service: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  async function startTopologyAnalysis() {
    try {
      loading = true;

      const newDetection = {
        id: Date.now().toString(),
        attributes: {
          workspace_id: workspaceId,
          analysis_depth: 'deep',
          status: 'analyzing',
          created_at: new Date().toISOString()
        }
      };

      topologyDetections = [newDetection, ...topologyDetections];
      selectedView = 'topology';

      // Simulate analysis completion
      setTimeout(() => {
        topologyDetections = topologyDetections.map(d =>
          d.id === newDetection.id
            ? { ...d, attributes: { ...d.attributes, status: 'completed' } }
            : d
        );
        loading = false;
      }, 2000);

    } catch (err) {
      console.error('Failed to start topology analysis:', err);
      error = `Failed to start topology analysis: ${err.message}`;
      loading = false;
    }

  }
</script>

<div class="min-h-screen p-6 {loading ? 'pointer-events-none opacity-75' : ''}">
  <!-- Header -->
  <header class="flex items-center justify-between mb-6">
    <div>
      <h2 class="text-2xl font-bold text-gray-900 dark:text-white">
        Container Orchestration
      </h2>
      <p class="text-gray-600 dark:text-gray-300">
        Deploy and manage services from your folder structures
      </p>
    </div>

    <div class="flex gap-3">
      <button
        class="px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
        onclick={startTopologyAnalysis}
        disabled={loading}
      >
        <Search class="w-4 h-4 mr-2" />
        Analyze Topology
      </button>

      <button
        class="px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
        onclick={() => selectedView = 'create'}
        disabled={loading}
      >
        <Plus class="w-4 h-4 mr-2" />
        Deploy Service
      </button>
    </div>
  </header>

  <!-- Error Display -->
  {#if error}
    <div class="p-4 rounded-md border bg-red-50 border-red-200 text-red-800 dark:bg-red-900/20 dark:border-red-800 dark:text-red-400 mb-4">
      <span>{error}</span>
      <button class="px-2 py-1 text-sm" onclick={() => error = null}>×</button>
    </div>
  {/if}

  <!-- Navigation Tabs -->
  <div class="flex border-b border-gray-200 dark:border-gray-700 mb-6">
    <button
      class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {selectedView === 'overview' ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 border-transparent hover:border-gray-300 dark:hover:border-gray-600'}"
      onclick={() => selectedView = 'overview'}
    >
      Overview
    </button>
    <button
      class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {selectedView === 'services' ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 border-transparent hover:border-gray-300 dark:hover:border-gray-600'}"
      onclick={() => selectedView = 'services'}
    >
      Services ({serviceInstances.length})
    </button>
    <button
      class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {selectedView === 'topology' ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 border-transparent hover:border-gray-300 dark:hover:border-gray-600'}"
      onclick={() => selectedView = 'topology'}
    >
      Topology Analysis
    </button>
    <button
      class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {selectedView === 'logs' ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 border-transparent hover:border-gray-300 dark:hover:border-gray-600'}"
      onclick={() => selectedView = 'logs'}
    >
      Deployment Logs
    </button>
    <button
      class="px-4 py-2 text-sm font-medium border-b-2 transition-colors {selectedView === 'metrics' ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 border-transparent hover:border-gray-300 dark:hover:border-gray-600'}"
      onclick={() => selectedView = 'metrics'}
    >
      Metrics
    </button>
  </div>

  <!-- Content Views -->
  <main class="min-h-96">
    {#if selectedView === 'overview'}
      <!-- Overview Dashboard -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Running Services Summary -->
        <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700 flex items-start gap-4">
          <div class="flex-shrink-0">
            <Activity class="w-6 h-6 text-green-600" />
          </div>
          <div class="flex-1">
            <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Running Services</div>
            <div class="text-2xl font-bold text-gray-900 dark:text-white mt-2 text-green-600">{runningServices.length}</div>
            <div class="text-sm text-gray-500 dark:text-gray-400 mt-1">
              {pendingDeployments.length} pending deployments
            </div>
          </div>
        </div>

        <!-- Health Status Summary -->
        <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700 flex items-start gap-4">
          <div class="flex-shrink-0">
            <BarChart3 class="w-6 h-6 text-blue-600" />
          </div>
          <div class="flex-1">
            <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Health Status</div>
            <div class="flex gap-2 mt-2">
              {#each ['healthy', 'unhealthy', 'unknown'] as status}
                {@const count = serviceInstances.filter(s => s.attributes.healthStatus === status).length}
                <div class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {status === 'healthy' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400' : status === 'unhealthy' ? 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400' : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400'}">
                  {status}: {count}
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Resource Usage -->
        <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700 flex items-start gap-4">
          <div class="flex-shrink-0">
            <Cpu class="w-6 h-6 text-purple-600" />
          </div>

          <div class="flex-1">
            <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Resource Usage</div>
            <!-- {@const totalCpu = runningServices.reduce((sum, s) => sum + (s.attributes.cpuUsagePercent || 0), 0)}
            {@const totalMemory = runningServices.reduce((sum, s) => sum + (s.attributes.memoryUsageMb || 0), 0)} -->
            <div class="text-2xl font-bold text-gray-900 dark:text-white mt-2 text-sm">
              CPU: {Math.round(totalCpu)}%<br>
              Memory: {Math.round(totalMemory)}MB
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Services -->
      <section class="mt-8">
        <h3 class="text-lg font-semibold mb-4">Recent Services</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {#each serviceInstances.slice(0, 6) as service (service.id)}
            <ServiceInstanceCard
              {service}
              onDeploy={(serviceId, config) => deployService(serviceId, config)}
              onStart={(serviceId) => startService(serviceId)}
              onStop={(serviceId) => stopService(serviceId)}
              onScale={(serviceId, replicas) => scaleService(serviceId, replicas)}
            />
          {/each}
        </div>
      </section>

    {:else if selectedView === 'services'}
      <!-- All Services View -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {#each serviceInstances as service (service.id)}
          <ServiceInstanceCard
            {service}
            detailed={true}
            onDeploy={(serviceId, config) => deployService(serviceId, config)}
            onStart={(serviceId) => startService(serviceId)}
            onStop={(serviceId) => stopService(serviceId)}
            onScale={(serviceId, replicas) => scaleService(serviceId, replicas)}
          />
        {/each}

        {#if serviceInstances.length === 0}
          <div class="col-span-full text-center py-12">
            <p>No services deployed yet.</p>
            <button class="px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50" onclick={startTopologyAnalysis}>
              Analyze Folder Structure
            </button>
          </div>
        {/if}
      </div>

    {:else if selectedView === 'topology'}
      <!-- Topology Analysis View -->
      <TopologyAnalysis
        detections={topologyDetections}
        {workspaceId}
        onDeployService={(serviceId, config) => deployService(serviceId, config)}
        onRefresh={() => loadInitialData()}
      />

    {:else if selectedView === 'logs'}
      <!-- Deployment Logs View -->
      <DeploymentLogs
        events={deploymentEvents}
        services={serviceInstances}
        onRefresh={() => loadInitialData()}
      />

    {:else if selectedView === 'metrics'}
      <!-- Metrics Dashboard View -->
      <MetricsDashboard
        services={runningServices}
        {workspaceId}
      />
    {/if}
  </main>
</div>
