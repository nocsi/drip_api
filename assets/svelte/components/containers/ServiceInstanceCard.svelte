<script>
  import { slide } from 'svelte/transition';
  import {
    Play,
    Square,
    Rocket,
    BarChart3,
    FileText,
    Settings,
    ChevronRight,
    ChevronDown,
    Cpu,
    HardDrive
  } from '@lucide/svelte';

  let {
    service,
    detailed = false,
    onDeploy = () => {},
    onStart = () => {},
    onStop = () => {},
    onScale = () => {}
  } = $props();

  let showDetails = $state(false);
  let showScaleDialog = $state(false);
  let newReplicaCount = $state(service.attributes.replicaCount || 1);

  const statusColor = $derived(getStatusColor(service.attributes.containerStatus));
  const healthColor = $derived(getHealthColor(service.attributes.healthStatus));
  const serviceTypeIcon = $derived(getServiceTypeIcon(service.attributes.serviceType));

  function getStatusColor(status) {
    switch (status) {
      case 'running': return 'success';
      case 'stopped': return 'warning';
      case 'error': return 'error';
      case 'deploying': return 'info';
      default: return 'neutral';
    }
  }

  function getHealthColor(health) {
    switch (health) {
      case 'healthy': return 'success';
      case 'unhealthy': return 'error';
      default: return 'warning';
    }
  }

  function getServiceTypeIcon(type) {
    switch (type) {
      case 'web_app': return '🌐';
      case 'api_service': return '🔌';
      case 'background_job': return '⚙️';
      case 'database': return '🗄️';
      case 'static_site': return '📄';
      case 'microservice': return '🔧';
      default: return '📦';
    }
  }

  function handleDeploy() {
    onDeploy(service.id, {});
  }

  function handleStart() {
    onStart(service.id);
  }

  function handleStop() {
    onStop(service.id);
  }

  function handleScale() {
    onScale(service.id, newReplicaCount);
    showScaleDialog = false;
  }

  function formatDateTime(dateString) {
    if (!dateString) return 'Never';
    return new Date(dateString).toLocaleString();
  }

  function formatUptime(deployedAt) {
    if (!deployedAt) return 'Not deployed';
    const now = new Date();
    const deployed = new Date(deployedAt);
    const diffMs = now - deployed;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffDays > 0) return `${diffDays}d ${diffHours % 24}h`;
    if (diffHours > 0) return `${diffHours}h ${diffMins % 60}m`;
    return `${diffMins}m`;
  }
</script>

<div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm hover:shadow-md transition-shadow duration-200 {detailed ? 'max-w-none' : ''}">
  <!-- Card Header -->
  <div class="flex items-start justify-between p-4 border-b border-gray-100 dark:border-gray-700">
    <div class="flex items-center gap-3">
      <span class="text-2xl">{serviceTypeIcon}</span>
      <div>
        <h3 class="font-semibold text-gray-900 dark:text-white">{service.attributes.name}</h3>
        <p class="text-sm text-gray-500 dark:text-gray-400 capitalize">{service.attributes.serviceType.replace('_', ' ')}</p>
      </div>
    </div>

    <div class="flex flex-col gap-1 items-end">
      <span class="px-2 py-1 rounded text-xs font-medium {statusColor === 'success' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400' : statusColor === 'warning' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400' : statusColor === 'error' ? 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400' : statusColor === 'info' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400' : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'}">
        {service.attributes.containerStatus}
      </span>
      <span class="px-2 py-1 rounded text-xs font-medium {healthColor === 'success' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400' : healthColor === 'error' ? 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400' : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400'}">
        {service.attributes.healthStatus}
      </span>
    </div>
  </div>

  <!-- Card Content -->
  <div class="p-4 space-y-3">
    <!-- Basic Info -->
    <div class="flex justify-between items-center">
      <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Image:</span>
      <span class="text-sm text-gray-900 dark:text-white">
        {service.attributes.imageName}:{service.attributes.imageTag}
      </span>
    </div>

    <div class="flex justify-between items-center">
      <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Replicas:</span>
      <div class="flex items-center gap-2">
        <span class="text-sm text-gray-900 dark:text-white">{service.attributes.replicaCount || 1}</span>
        <button
          class="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
          onclick={() => showScaleDialog = true}
        >
          <Settings class="w-3 h-3" />
        </button>
      </div>
    </div>

    <div class="flex justify-between items-center">
      <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Uptime:</span>
      <span class="text-sm text-gray-900 dark:text-white">
        {formatUptime(service.attributes.deployedAt)}
      </span>
    </div>

    <!-- Resource Usage (if running) -->
    {#if service.attributes.containerStatus === 'running'}
      <div class="space-y-2 pt-2 border-t border-gray-100 dark:border-gray-700">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <Cpu class="w-4 h-4 text-blue-600" />
            <span class="text-sm font-medium text-gray-600 dark:text-gray-400">CPU</span>
          </div>
          <span class="text-sm text-gray-900 dark:text-white">
            {service.attributes.cpuUsagePercent || 0}%
          </span>
        </div>
        <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
          <div
            class="bg-blue-600 h-2 rounded-full transition-all duration-300"
            style="width: {Math.min(service.attributes.cpuUsagePercent || 0, 100)}%"
          ></div>
        </div>

        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <HardDrive class="w-4 h-4 text-green-600" />
            <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Memory</span>
          </div>
          <span class="text-sm text-gray-900 dark:text-white">
            {service.attributes.memoryUsageMb || 0}MB
          </span>
        </div>
        <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
          <div
            class="bg-green-600 h-2 rounded-full transition-all duration-300"
            style="width: {Math.min((service.attributes.memoryUsageMb || 0) / 10, 100)}%"
          ></div>
        </div>
      </div>
    {/if}

    <!-- Detailed Info Toggle -->
    {#if detailed}
      <div class="pt-3 border-t border-gray-100 dark:border-gray-700">
        <button
          class="flex items-center gap-2 text-sm text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
          onclick={() => showDetails = !showDetails}
        >
          {#if showDetails}
            <ChevronDown class="w-4 h-4" />
            Hide Details
          {:else}
            <ChevronRight class="w-4 h-4" />
            Show Details
          {/if}
        </button>
      </div>

      {#if showDetails}
        <div class="space-y-3 pt-3" transition:slide={{ duration: 200 }}>
          <div>
            <h4 class="text-sm font-medium text-gray-900 dark:text-white mb-2">Port Mappings</h4>
            <div class="space-y-1">
              {#each Object.entries(service.attributes.portMappings || {}) as [external, internal]}
                <div class="text-xs text-gray-600 dark:text-gray-400">
                  {external}:{internal}
                </div>
              {/each}
            </div>
          </div>

          <div>
            <h4 class="text-sm font-medium text-gray-900 dark:text-white mb-2">Environment Variables</h4>
            <div class="space-y-1">
              {#each Object.entries(service.attributes.environmentVariables || {}) as [key, value]}
                <div class="text-xs text-gray-600 dark:text-gray-400">
                  {key}={value}
                </div>
              {/each}
            </div>
          </div>

          <div class="text-xs text-gray-500 dark:text-gray-400">
            Last deployed: {formatDateTime(service.attributes.deployedAt)}
          </div>
        </div>
      {/if}
    {/if}
  </div>

  <!-- Action Buttons -->
  <div class="flex gap-2 p-4 border-t border-gray-100 dark:border-gray-700">
    {#if service.attributes.containerStatus === 'stopped'}
      <button
        class="flex-1 px-3 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700 transition-colors duration-200 inline-flex items-center justify-center"
        onclick={handleStart}
      >
        <Play class="w-4 h-4 mr-2" />
        Start
      </button>
    {:else if service.attributes.containerStatus === 'running'}
      <button
        class="flex-1 px-3 py-2 bg-red-600 text-white text-sm font-medium rounded-md hover:bg-red-700 transition-colors duration-200 inline-flex items-center justify-center"
        onclick={handleStop}
      >
        <Square class="w-4 h-4 mr-2" />
        Stop
      </button>
    {:else}
      <button
        class="flex-1 px-3 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 transition-colors duration-200 inline-flex items-center justify-center"
        onclick={handleDeploy}
      >

        <Rocket class="w-4 h-4 mr-2" />
        Deploy
      </button>
    {/if}

    <button 
      class="px-3 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 text-sm font-medium rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors duration-200"
      onclick={() => showDetails = !showDetails}
    >
      <BarChart3 class="w-4 h-4" />
    </button>
  </div>
</div>

<!-- Scale Dialog -->
{#if showScaleDialog}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onclick={() => showScaleDialog = false}>
    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-sm w-full mx-4" onclick={(e) => e.stopPropagation()}>
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Scale Service</h3>
      <p class="text-gray-600 dark:text-gray-300 mb-4">
        Adjust the number of replicas for {service.attributes.name}
      </p>

      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Replica Count
        </label>
        <input 
          type="number" 
          min="1" 
          max="10" 
          bind:value={newReplicaCount}
          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
        />
      </div>

      <div class="flex gap-3">
        <button 
          class="flex-1 px-4 py-2 rounded-md font-medium transition-colors duration-200 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700" 
          onclick={() => showScaleDialog = false}
        >
          Cancel
        </button>
        <button 
          class="flex-1 px-4 py-2 rounded-md font-medium transition-colors duration-200 bg-blue-600 text-white hover:bg-blue-700" 
          onclick={handleScale}
        >
          Scale
        </button>
      </div>
    </div>
  </div>
{/if}