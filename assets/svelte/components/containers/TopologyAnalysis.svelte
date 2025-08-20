<script>
  import { onMount } from 'svelte';
  import { slide, fade } from 'svelte/transition';
  import { 
    RefreshCw, 
    Folder, 
    File, 
    GitBranch, 
    Database, 
    Globe, 
    Cpu, 
    CheckCircle,
    AlertCircle,
    Clock,
    Play,
    Settings
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
  let analysisFilter = $state('all'); // all, completed, analyzing, failed

  const filteredDetections = $derived(() => {
    if (analysisFilter === 'all') return detections;
    return detections.filter(d => {
      switch (analysisFilter) {
        case 'completed': return d.attributes.status === 'completed';
        case 'analyzing': return d.attributes.status === 'analyzing';
        case 'failed': return d.attributes.status === 'failed';
        default: return true;
      }
    });
  });

  const detectionStats = $derived(() => {
    const stats = { total: 0, completed: 0, analyzing: 0, failed: 0 };
    detections.forEach(d => {
      stats.total++;
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
      case 'completed': return CheckCircle;
      case 'analyzing': return Clock;
      case 'failed': return AlertCircle;
      default: return Clock;
    }
  }

  function formatDateTime(dateString) {
    if (!dateString) return 'Unknown';
    return new Date(dateString).toLocaleString();
  }

  function handleSelectDetection(detection) {
    selectedDetection = selectedDetection?.id === detection.id ? null : detection;
  }

  function handleDeployFromTopology(serviceConfig) {
    deploymentConfig = serviceConfig;
    showDeployDialog = true;
  }

  function confirmDeploy() {
    onDeployService('new-service', deploymentConfig);
    showDeployDialog = false;
    deploymentConfig = {};
  }

  function getServiceTypeIcon(type) {
    switch (type) {
      case 'web_app': return Globe;
      case 'api_service': return Cpu;
      case 'database': return Database;
      case 'static_site': return File;
      default: return Folder;
    }
  }

  // Mock topology data for demonstration
  const mockTopologyResults = {
    services: [
      {
        name: 'frontend',
        type: 'web_app',
        path: '/frontend',
        dockerfile: '/frontend/Dockerfile',
        ports: ['3000'],
        dependencies: ['backend-api'],
        confidence: 0.95
      },
      {
        name: 'backend-api',
        type: 'api_service',
        path: '/api',
        dockerfile: '/api/Dockerfile',
        ports: ['8080'],
        dependencies: ['database'],
        confidence: 0.88
      },
      {
        name: 'database',
        type: 'database',
        path: '/db',
        dockerfile: '/db/Dockerfile',
        ports: ['5432'],
        dependencies: [],
        confidence: 0.92
      }
    ],
    relationships: [
      { from: 'frontend', to: 'backend-api', type: 'http_request' },
      { from: 'backend-api', to: 'database', type: 'database_connection' }
    ]
  };
</script>

<div class="topology-analysis">
  <!-- Header -->
  <div class="analysis-header">
    <div>
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        Topology Analysis
      </h3>
      <p class="text-gray-600 dark:text-gray-300">
        AI-powered analysis of your folder structure to identify deployable services
      </p>
    </div>
    
    <button class="btn btn-outline" onclick={onRefresh}>
      <RefreshCw class="w-4 h-4 mr-2" />
      Refresh
    </button>
  </div>

  <!-- Stats -->
  <div class="stats-grid">
    <div class="stat-item">
      <div class="stat-value">{detectionStats.total}</div>
      <div class="stat-label">Total Analyses</div>
    </div>
    <div class="stat-item">
      <div class="stat-value text-green-600">{detectionStats.completed || 0}</div>
      <div class="stat-label">Completed</div>
    </div>
    <div class="stat-item">
      <div class="stat-value text-blue-600">{detectionStats.analyzing || 0}</div>
      <div class="stat-label">Analyzing</div>
    </div>
    <div class="stat-item">
      <div class="stat-value text-red-600">{detectionStats.failed || 0}</div>
      <div class="stat-label">Failed</div>
    </div>
  </div>

  <!-- Filter Tabs -->
  <div class="filter-tabs">
    {#each ['all', 'completed', 'analyzing', 'failed'] as filter}
      <button 
        class="tab"
        class:tab-active={analysisFilter === filter}
        onclick={() => analysisFilter = filter}
      >
        {filter.charAt(0).toUpperCase() + filter.slice(1)}
        {#if filter !== 'all'}
          ({detectionStats[filter] || 0})
        {:else}
          ({detectionStats.total})
        {/if}
      </button>
    {/each}
  </div>

  <!-- Analysis Results -->
  <div class="analysis-results">
    {#if filteredDetections.length === 0}
      <div class="empty-state">
        <Folder class="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <p class="text-gray-600 dark:text-gray-400">
          {analysisFilter === 'all' 
            ? 'No topology analyses found. Start an analysis to see results here.'
            : `No ${analysisFilter} analyses found.`}
        </p>
      </div>
    {:else}
      <div class="detections-list">
        {#each filteredDetections as detection (detection.id)}
          <div class="detection-card" class:selected={selectedDetection?.id === detection.id}>
            <div class="detection-header" onclick={() => handleSelectDetection(detection)}>
              <div class="detection-info">
                <div class="flex items-center gap-2">
                  {#if detection.attributes.status}
                    {@const StatusIcon = getStatusIcon(detection.attributes.status)}
                    <StatusIcon class="w-5 h-5 text-{getStatusColor(detection.attributes.status) === 'success' ? 'green' : getStatusColor(detection.attributes.status) === 'info' ? 'blue' : 'red'}-600" />
                  {/if}
                  <span class="detection-id font-mono text-sm">
                    {detection.id.slice(0, 8)}
                  </span>
                  <span class="status-badge badge-{getStatusColor(detection.attributes.status)}">
                    {detection.attributes.status}
                  </span>
                </div>
                <div class="detection-meta">
                  <span class="text-sm text-gray-600 dark:text-gray-400">
                    {formatDateTime(detection.attributes.created_at)}
                  </span>
                  <span class="text-sm text-gray-600 dark:text-gray-400">
                    Depth: {detection.attributes.analysis_depth}
                  </span>
                </div>
              </div>
              
              <div class="expand-indicator">
                {#if selectedDetection?.id === detection.id}
                  <Settings class="w-4 h-4 transform rotate-45" />
                {:else}
                  <Settings class="w-4 h-4" />
                {/if}
              </div>
            </div>

            {#if selectedDetection?.id === detection.id && detection.attributes.status === 'completed'}
              <div class="detection-details" transition:slide={{ duration: 300 }}>
                <!-- Service Topology Visualization -->
                <div class="topology-section">
                  <h4 class="section-title">Detected Services</h4>
                  <div class="services-grid">
                    {#each mockTopologyResults.services as service}
                      <div class="service-node">
                        <div class="service-header">
                          {@const ServiceIcon = getServiceTypeIcon(service.type)}
                          <ServiceIcon class="w-5 h-5 text-blue-600" />
                          <span class="service-name">{service.name}</span>
                          <span class="confidence-badge">
                            {Math.round(service.confidence * 100)}%
                          </span>
                        </div>
                        
                        <div class="service-details">
                          <div class="detail-row">
                            <Folder class="w-3 h-3" />
                            <span class="text-xs">{service.path}</span>
                          </div>
                          {#if service.dockerfile}
                            <div class="detail-row">
                              <File class="w-3 h-3" />
                              <span class="text-xs">{service.dockerfile}</span>
                            </div>
                          {/if}
                          {#if service.ports.length > 0}
                            <div class="detail-row">
                              <span class="text-xs font-medium">Ports:</span>
                              <span class="text-xs">{service.ports.join(', ')}</span>
                            </div>
                          {/if}
                        </div>

                        <button 
                          class="deploy-btn"
                          onclick={() => handleDeployFromTopology(service)}
                        >
                          <Play class="w-3 h-3 mr-1" />
                          Deploy
                        </button>
                      </div>
                    {/each}
                  </div>
                </div>

                <!-- Dependency Graph -->
                <div class="topology-section">
                  <h4 class="section-title">Service Dependencies</h4>
                  <div class="dependencies-graph">
                    {#each mockTopologyResults.relationships as rel}
                      <div class="dependency-edge">
                        <span class="from-service">{rel.from}</span>
                        <GitBranch class="w-4 h-4 text-gray-400" />
                        <span class="to-service">{rel.to}</span>
                        <span class="relationship-type">{rel.type}</span>
                      </div>
                    {/each}
                  </div>
                </div>
              </div>
            {:else if selectedDetection?.id === detection.id && detection.attributes.status === 'analyzing'}
              <div class="detection-details" transition:slide={{ duration: 300 }}>
                <div class="analyzing-state">
                  <div class="spinner"></div>
                  <p class="text-gray-600 dark:text-gray-400">
                    Analyzing folder structure and detecting services...
                  </p>
                </div>
              </div>
            {:else if selectedDetection?.id === detection.id && detection.attributes.status === 'failed'}
              <div class="detection-details" transition:slide={{ duration: 300 }}>
                <div class="error-state">
                  <AlertCircle class="w-8 h-8 text-red-600 mb-2" />
                  <p class="text-red-600 dark:text-red-400 font-medium">
                    Analysis Failed
                  </p>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    The topology analysis encountered an error. Please try again or check the logs.
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

<!-- Deploy Confirmation Dialog -->
{#if showDeployDialog}
  <div class="modal-overlay" onclick={() => showDeployDialog = false}>
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <h3 class="modal-title">Deploy Service</h3>
      <p class="modal-text">
        Deploy "{deploymentConfig.name}" as a {deploymentConfig.type}?
      </p>
      
      <div class="deployment-preview">
        <div class="preview-row">
          <span class="preview-label">Service Name:</span>
          <span class="preview-value">{deploymentConfig.name}</span>
        </div>
        <div class="preview-row">
          <span class="preview-label">Type:</span>
          <span class="preview-value">{deploymentConfig.type}</span>
        </div>
        <div class="preview-row">
          <span class="preview-label">Path:</span>
          <span class="preview-value">{deploymentConfig.path}</span>
        </div>
        {#if deploymentConfig.ports?.length > 0}
          <div class="preview-row">
            <span class="preview-label">Ports:</span>
            <span class="preview-value">{deploymentConfig.ports.join(', ')}</span>
          </div>
        {/if}
      </div>

      <div class="modal-actions">
        <button class="btn btn-outline" onclick={() => showDeployDialog = false}>
          Cancel
        </button>
        <button class="btn btn-primary" onclick={confirmDeploy}>
          <Play class="w-4 h-4 mr-2" />
          Deploy Service
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .topology-analysis {
    @apply space-y-6;
  }

  .analysis-header {
    @apply flex items-start justify-between;
  }

  .stats-grid {
    @apply grid grid-cols-2 md:grid-cols-4 gap-4;
  }

  .stat-item {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
    @apply text-center;
  }

  .stat-value {
    @apply text-2xl font-bold text-gray-900 dark:text-white;
  }

  .stat-label {
    @apply text-sm text-gray-600 dark:text-gray-400 mt-1;
  }

  .filter-tabs {
    @apply flex border-b border-gray-200 dark:border-gray-700;
  }

  .tab {
    @apply px-4 py-2 text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300;
    @apply border-b-2 border-transparent hover:border-gray-300 dark:hover:border-gray-600;
  }

  .tab-active {
    @apply text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400;
  }

  .analysis-results {
    @apply min-h-64;
  }

  .empty-state {
    @apply text-center py-12;
  }

  .detections-list {
    @apply space-y-4;
  }

  .detection-card {
    @apply bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700;
    @apply hover:shadow-md transition-shadow duration-200;
  }

  .detection-card.selected {
    @apply ring-2 ring-blue-500 dark:ring-blue-400;
  }

  .detection-header {
    @apply flex items-center justify-between p-4 cursor-pointer;
  }

  .detection-info {
    @apply space-y-2;
  }

  .detection-meta {
    @apply flex gap-4;
  }

  .status-badge {
    @apply px-2 py-1 rounded text-xs font-medium;
  }

  .badge-success {
    @apply bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400;
  }

  .badge-info {
    @apply bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400;
  }

  .badge-error {
    @apply bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400;
  }

  .badge-neutral {
    @apply bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300;
  }

  .expand-indicator {
    @apply transition-transform duration-200;
  }

  .detection-details {
    @apply border-t border-gray-200 dark:border-gray-700 p-4 space-y-6;
  }

  .topology-section {
    @apply space-y-4;
  }

  .section-title {
    @apply font-medium text-gray-900 dark:text-white;
  }

  .services-grid {
    @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4;
  }

  .service-node {
    @apply bg-gray-50 dark:bg-gray-700 rounded-lg p-4 space-y-3;
  }

  .service-header {
    @apply flex items-center gap-2;
  }

  .service-name {
    @apply font-medium text-gray-900 dark:text-white flex-1;
  }

  .confidence-badge {
    @apply px-2 py-1 bg-green-100 dark:bg-green-900/20 text-green-800 dark:text-green-400 rounded text-xs font-medium;
  }

  .service-details {
    @apply space-y-2;
  }

  .detail-row {
    @apply flex items-center gap-2 text-gray-600 dark:text-gray-400;
  }

  .deploy-btn {
    @apply w-full px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors;
    @apply flex items-center justify-center text-sm font-medium;
  }

  .dependencies-graph {
    @apply space-y-2;
  }

  .dependency-edge {
    @apply flex items-center gap-3 p-2 bg-gray-50 dark:bg-gray-700 rounded;
  }

  .from-service, .to-service {
    @apply font-medium text-gray-900 dark:text-white;
  }

  .relationship-type {
    @apply text-xs text-gray-600 dark:text-gray-400 bg-gray-200 dark:bg-gray-600 px-2 py-1 rounded;
  }

  .analyzing-state {
    @apply text-center py-8;
  }

  .spinner {
    @apply w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-4;
  }

  .error-state {
    @apply text-center py-8;
  }

  .btn {
    @apply px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center;
  }

  .btn-primary {
    @apply bg-blue-600 text-white hover:bg-blue-700;
  }

  .btn-outline {
    @apply border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700;
  }

  .modal-overlay {
    @apply fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50;
  }

  .modal {
    @apply bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4;
  }

  .modal-title {
    @apply text-lg font-semibold text-gray-900 dark:text-white mb-2;
  }

  .modal-text {
    @apply text-gray-600 dark:text-gray-400 mb-4;
  }

  .deployment-preview {
    @apply bg-gray-50 dark:bg-gray-700 rounded-lg p-4 space-y-2 mb-6;
  }

  .preview-row {
    @apply flex justify-between items-center;
  }

  .preview-label {
    @apply text-sm font-medium text-gray-600 dark:text-gray-400;
  }

  .preview-value {
    @apply text-sm text-gray-900 dark:text-white font-mono;
  }

  .modal-actions {
    @apply flex gap-3 justify-end;
  }
</style>