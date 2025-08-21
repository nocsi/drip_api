<script>
  import { slide } from 'svelte/transition';
  import {
    RefreshCw,
    Settings,
    Folder,
    AlertCircle,
    Play,
    File,
    GitBranch
  } from '@lucide/svelte';

  let {
    detections = [],
    workspaceId,
    onDeployService = () => {},
    onRefresh = () => {}
  } = $props();

  let selectedDetection = $state(null);
  let deploymentConfig = $state({});
  let showDeployDialog = $state(false);
  let analysisFilter = $state('all');

  const filteredDetections = $derived(() => {
    if (analysisFilter === 'all') return detections;
    return detections.filter(d => d.attributes.status === analysisFilter);
  });

  const detectionStats = $derived(() => {
    const stats = { all: 0, completed: 0, analyzing: 0, failed: 0 };
    detections.forEach(d => {
      stats.all++;
      stats[d.attributes.status] = (stats[d.attributes.status] || 0) + 1;
    });
    return stats;
  });

  function getStatusColor(status) {
    switch (status) {
      case 'completed': return 'success';
      case 'analyzing': return 'info';
      case 'failed': return 'error';
      default: return 'neutral';
    }
  }

  function getStatusIcon(status) {
    switch (status) {
      case 'completed': return Play;
      case 'analyzing': return RefreshCw;
      case 'failed': return AlertCircle;
      default: return Settings;
    }
  }

  function formatDateTime(dateString) {
    return new Date(dateString).toLocaleString();
  }

  function handleSelectDetection(detection) {
    selectedDetection = detection;
  }

  function handleDeployFromTopology(service) {
    deploymentConfig = service;
    showDeployDialog = true;
  }

  function confirmDeploy() {
    onDeployService(deploymentConfig.name, deploymentConfig);
    showDeployDialog = false;
  }

  function getServiceTypeIcon(type) {
    switch (type) {
      case 'web_service': return Play;
      case 'api_service': return Settings;
      case 'database': return Folder;
      case 'worker': return RefreshCw;
      default: return File;
    }
  }

  const mockTopologyResults = {
    services: [
      {
        name: 'web-frontend',
        type: 'web_service',
        path: './frontend',
        dockerfile: 'Dockerfile',
        ports: [3000, 80],
        dependencies: ['api-backend'],
        confidence: 0.95
      },
      {
        name: 'api-backend',
        type: 'api_service',
        path: './backend',
        dockerfile: 'Dockerfile.api',
        ports: [8080],
        dependencies: ['database'],
        confidence: 0.88
      },
      {
        name: 'database',
        type: 'database',
        path: './db',
        dockerfile: null,
        ports: [5432],
        dependencies: [],
        confidence: 0.92
      }
    ],
    relationships: [
      { from: 'web-frontend', to: 'api-backend', type: 'http_calls' },
      { from: 'api-backend', to: 'database', type: 'database_connection' }
    ]
  };
</script>

<div class="space-y-6">
  <!-- Analysis Header -->
  <div class="flex items-start justify-between">
    <div>
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        Topology Analysis
      </h3>
      <p class="text-gray-600 dark:text-gray-300">
        Analyze folder structures to detect deployable services
      </p>
    </div>
    <button
      class="px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
      onclick={onRefresh}
    >
      <RefreshCw class="w-4 h-4 mr-2" />
      Refresh
    </button>
  </div>

  <!-- Stats Grid -->
  <div class="grid grid-cols-4 gap-4">
    <div class="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="text-2xl font-bold text-gray-900 dark:text-white">{detectionStats.all}</div>
      <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Total</div>
    </div>
    <div class="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="text-2xl font-bold text-green-600">{detectionStats.completed || 0}</div>
      <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Completed</div>
    </div>
    <div class="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="text-2xl font-bold text-blue-600">{detectionStats.analyzing || 0}</div>
      <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Analyzing</div>
    </div>
    <div class="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="text-2xl font-bold text-red-600">{detectionStats.failed || 0}</div>
      <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Failed</div>
    </div>
  </div>

  <!-- Filter Tabs -->
  <div class="flex space-x-1 bg-gray-100 dark:bg-gray-700 p-1 rounded-lg">
    {#each ['all', 'completed', 'analyzing', 'failed'] as filter}
      <button
        class="px-4 py-2 rounded-md font-medium transition-colors duration-200 text-sm {analysisFilter === filter ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm' : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'}"
        onclick={() => analysisFilter = filter}
      >
        {#if filter !== 'all'}
          {filter} ({detectionStats[filter] || 0})
        {:else}
          All ({detectionStats.all})
        {/if}
      </button>
    {/each}
  </div>

  <!-- Analysis Results -->
  <div class="min-h-96">
    {#if filteredDetections.length === 0}
      <div class="text-center py-12">
        <Folder class="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <p class="text-gray-600 dark:text-gray-400">
          No topology analyses found. Start an analysis to detect services.
        </p>
      </div>
    {:else}
      <div class="space-y-4">
        {#each filteredDetections as detection (detection.id)}
          <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm {selectedDetection?.id === detection.id ? 'ring-2 ring-blue-500 dark:ring-blue-400' : ''}">
            <div
              class="flex items-center justify-between p-4 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 rounded-t-lg"
              onclick={() => handleSelectDetection(detection)}
            >
              <div class="flex items-center gap-3">
                {#if detection.attributes.status}
                  {@const StatusIcon = getStatusIcon(detection.attributes.status)}
                  <StatusIcon class="w-5 h-5 {getStatusColor(detection.attributes.status) === 'success' ? 'text-green-600' : getStatusColor(detection.attributes.status) === 'info' ? 'text-blue-600' : getStatusColor(detection.attributes.status) === 'error' ? 'text-red-600' : 'text-gray-600'}" />
                {/if}
                <span class="font-mono text-sm text-gray-700 dark:text-gray-300">
                  #{detection.id}
                </span>
                <span class="px-2 py-1 rounded text-xs font-medium {getStatusColor(detection.attributes.status) === 'success' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400' : getStatusColor(detection.attributes.status) === 'info' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400' : getStatusColor(detection.attributes.status) === 'error' ? 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400' : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'}">
                  {detection.attributes.status}
                </span>
              </div>
              <div class="flex flex-col items-end text-sm text-gray-500 dark:text-gray-400">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {formatDateTime(detection.attributes.created_at)}
                </span>
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  Depth: {detection.attributes.analysis_depth}
                </span>
              </div>

              <div class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                {#if selectedDetection?.id === detection.id}
                  <Settings class="w-4 h-4 transform rotate-45" />
                {:else}
                  <Settings class="w-4 h-4" />
                {/if}
              </div>
            </div>

            {#if selectedDetection?.id === detection.id && detection.attributes.status === 'completed'}
              <div class="border-t border-gray-200 dark:border-gray-700 p-4" transition:slide={{ duration: 300 }}>
                <!-- Topology Section -->
                <div class="mb-6">
                  <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Detected Services</h4>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {#each mockTopologyResults.services as service}
                      {@const ServiceIcon = getServiceTypeIcon(service.type)}
                      <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
                        <div class="flex items-center justify-between mb-3">
                          <ServiceIcon class="w-5 h-5 text-blue-600" />
                          <span class="font-semibold text-gray-900 dark:text-white">{service.name}</span>
                          <span class="text-xs px-2 py-1 bg-blue-100 dark:bg-blue-900/20 text-blue-800 dark:text-blue-400 rounded-full">
                            {Math.round(service.confidence * 100)}%
                          </span>
                        </div>

                        <div class="space-y-2 text-sm">
                          <div class="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                            <Folder class="w-3 h-3" />
                            <span class="text-xs">{service.path}</span>
                          </div>
                          {#if service.dockerfile}
                            <div class="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                              <File class="w-3 h-3" />
                              <span class="text-xs">{service.dockerfile}</span>
                            </div>
                          {/if}
                          {#if service.ports.length > 0}
                            <div class="text-gray-600 dark:text-gray-400">
                              <span class="text-xs font-medium">Ports:</span>
                              <span class="text-xs">{service.ports.join(', ')}</span>
                            </div>
                          {/if}
                        </div>

                        <button
                          class="mt-3 w-full px-3 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 transition-colors duration-200 inline-flex items-center justify-center"
                          onclick={() => handleDeployFromTopology(service)}
                        >
                          <Play class="w-3 h-3 mr-1" />
                          Deploy
                        </button>
                      </div>
                    {/each}
                  </div>
                </div>

                <!-- Dependencies Section -->
                <div class="space-y-4">
                  <h4 class="text-lg font-semibold text-gray-900 dark:text-white">Service Dependencies</h4>
                  <div class="space-y-3">
                    {#each mockTopologyResults.relationships as rel}
                      <div class="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600">
                        <span class="font-mono text-sm text-gray-700 dark:text-gray-300">{rel.from}</span>
                        <GitBranch class="w-4 h-4 text-gray
-400" />
                        <span class="font-mono text-sm text-gray-700 dark:text-gray-300">{rel.to}</span>
                        <span class="text-xs px-2 py-1 bg-gray-200 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded">
                          {rel.type.replace('_', ' ')}
                        </span>
                      </div>
                    {/each}
                  </div>
                </div>
              </div>
            {:else if selectedDetection?.id === detection.id && detection.attributes.status === 'analyzing'}
              <div class="border-t border-gray-200 dark:border-gray-700 p-4" transition:slide={{ duration: 300 }}>
                <div class="flex items-center justify-center py-8">
                  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <p class="text-gray-600 dark:text-gray-400 ml-3">
                    Analyzing folder structure and dependencies...
                  </p>
                </div>
              </div>
            {:else if selectedDetection?.id === detection.id && detection.attributes.status === 'failed'}
              <div class="border-t border-gray-200 dark:border-gray-700 p-4" transition:slide={{ duration: 300 }}>
                <div class="flex flex-col items-center py-8">
                  <AlertCircle class="w-8 h-8 text-red-600 mb-2" />
                  <p class="text-red-600 dark:text-red-400 font-medium">
                    Analysis Failed
                  </p>
                  <p class="text-sm text-gray-600 dark:text-gray-400 text-center mt-1">
                    Unable to analyze the folder structure. Please check your workspace permissions.
                  </p>
                </div>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

{#if showDeployDialog}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onclick={() => showDeployDialog = false}>
    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" onclick={(e) => e.stopPropagation()}>
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Deploy Service</h3>
      <p class="text-gray-600 dark:text-gray-300 mb-4">
        Deploy {deploymentConfig.name} as a containerized service?
      </p>

      <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 space-y-3 mb-6">
        <div class="flex justify-between">
          <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Service:</span>
          <span class="text-sm text-gray-900 dark:text-white">{deploymentConfig.name}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Type:</span>
          <span class="text-sm text-gray-900 dark:text-white">{deploymentConfig.type}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Path:</span>
          <span class="text-sm text-gray-900 dark:text-white">{deploymentConfig.path}</span>
        </div>
        {#if deploymentConfig.ports?.length > 0}
          <div class="flex justify-between">
            <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Ports:</span>
            <span class="text-sm text-gray-900 dark:text-white">{deploymentConfig.ports.join(', ')}</span>
          </div>
        {/if}
      </div>

      <div class="flex gap-3">
        <button 
          class="flex-1 px-4 py-2 rounded-md font-medium transition-colors duration-200 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700" 
          onclick={() => showDeployDialog = false}
        >
          Cancel
        </button>
        <button 
          class="flex-1 px-4 py-2 rounded-md font-medium transition-colors duration-200 bg-blue-600 text-white hover:bg-blue-700 inline-flex items-center justify-center" 
          onclick={confirmDeploy}
        >
          <Play class="w-4 h-4 mr-2" />
          Deploy
        </button>
      </div>
    </div>
  </div>
{/if}