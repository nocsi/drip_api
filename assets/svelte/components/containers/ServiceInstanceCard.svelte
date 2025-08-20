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

<div class="service-card" class:detailed>
  <!-- Card Header -->
  <div class="card-header">
    <div class="flex items-center gap-3">
      <span class="service-icon">{serviceTypeIcon}</span>
      <div>
        <h3 class="service-name">{service.attributes.name}</h3>
        <p class="service-type">{service.attributes.serviceType.replace('_', ' ')}</p>
      </div>
    </div>
    
    <div class="status-indicators">
      <span class="status-badge badge-{statusColor}">
        {service.attributes.containerStatus}
      </span>
      <span class="health-badge badge-{healthColor}">
        {service.attributes.healthStatus}
      </span>
    </div>
  </div>

  <!-- Card Content -->
  <div class="card-content">
    <!-- Basic Info -->
    <div class="info-row">
      <span class="info-label">Image:</span>
      <span class="info-value">
        {service.attributes.imageName}:{service.attributes.imageTag}
      </span>
    </div>
    
    <div class="info-row">
      <span class="info-label">Replicas:</span>
      <span class="info-value">{service.attributes.replicaCount}</span>
    </div>

    {#if service.attributes.deployedAt}
      <div class="info-row">
        <span class="info-label">Uptime:</span>
        <span class="info-value">{formatUptime(service.attributes.deployedAt)}</span>
      </div>
    {/if}

    <!-- Resource Usage -->
    {#if service.attributes.cpuUsagePercent || service.attributes.memoryUsageMb}
      <div class="resource-usage">
        {#if service.attributes.cpuUsagePercent}
          <div class="usage-item">
            <Cpu class="w-3 h-3 text-gray-500" />
            <span class="usage-label">CPU:</span>
            <div class="usage-bar">
              <div 
                class="usage-fill"
                style="width: {Math.min(service.attributes.cpuUsagePercent, 100)}%"
              ></div>
            </div>
            <span class="usage-value">{Math.round(service.attributes.cpuUsagePercent)}%</span>
          </div>
        {/if}

        {#if service.attributes.memoryUsageMb}
          <div class="usage-item">
            <HardDrive class="w-3 h-3 text-gray-500" />
            <span class="usage-label">Memory:</span>
            <div class="usage-bar">
              <div 
                class="usage-fill"
                style="width: {Math.min((service.attributes.memoryUsageMb / 1024) * 100, 100)}%"
              ></div>
            </div>
            <span class="usage-value">{Math.round(service.attributes.memoryUsageMb)}MB</span>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Detailed Info (expandable) -->
    {#if detailed}
      <button 
        class="details-toggle"
        onclick={() => showDetails = !showDetails}
      >
        {#if showDetails}
          <ChevronDown class="w-4 h-4" />
        {:else}
          <ChevronRight class="w-4 h-4" />
        {/if}
        Details
      </button>

      {#if showDetails}
        <div class="detailed-info" transition:slide={{ duration: 200 }}>
          <div class="info-section">
            <h4>Container Info</h4>
            <div class="info-grid">
              <div class="info-row">
                <span class="info-label">Container ID:</span>
                <span class="info-value font-mono text-xs">
                  {service.attributes.containerId?.slice(0, 12) || 'Not deployed'}
                </span>
              </div>
              <div class="info-row">
                <span class="info-label">Auto Restart:</span>
                <span class="info-value">{service.attributes.autoRestart ? 'Yes' : 'No'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Last Health Check:</span>
                <span class="info-value text-xs">
                  {formatDateTime(service.attributes.lastHealthCheckAt)}
                </span>
              </div>
            </div>
          </div>

          {#if Object.keys(service.attributes.portMappings || {}).length > 0}
            <div class="info-section">
              <h4>Port Mappings</h4>
              <div class="port-mappings">
                {#each Object.entries(service.attributes.portMappings) as [internal, external]}
                  <span class="port-mapping">{external} → {internal}</span>
                {/each}
              </div>
            </div>
          {/if}

          {#if Object.keys(service.attributes.environmentVariables || {}).length > 0}
            <div class="info-section">
              <h4>Environment Variables</h4>
              <div class="env-vars">
                {#each Object.entries(service.attributes.environmentVariables) as [key, value]}
                  <div class="env-var">
                    <span class="env-key">{key}:</span>
                    <span class="env-value">{value}</span>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      {/if}
    {/if}
  </div>

  <!-- Card Actions -->
  <div class="card-actions">
    {#if service.attributes.containerStatus === 'pending'}
      <button class="btn btn-primary btn-sm" onclick={handleDeploy}>
        <Rocket class="w-3 h-3 mr-1" />
        Deploy
      </button>
    {:else if service.attributes.containerStatus === 'stopped'}
      <button class="btn btn-success btn-sm" onclick={handleStart}>
        <Play class="w-3 h-3 mr-1" />
        Start
      </button>
    {:else if service.attributes.containerStatus === 'running'}
      <button class="btn btn-warning btn-sm" onclick={handleStop}>
        <Square class="w-3 h-3 mr-1" />
        Stop
      </button>
      <button class="btn btn-outline btn-sm" onclick={() => showScaleDialog = true}>
        <BarChart3 class="w-3 h-3 mr-1" />
        Scale
      </button>
    {/if}

    {#if detailed}
      <button class="btn btn-outline btn-sm">
        <FileText class="w-3 h-3 mr-1" />
        Logs
      </button>
      <button class="btn btn-outline btn-sm">
        <BarChart3 class="w-3 h-3 mr-1" />
        Metrics
      </button>
    {/if}
  </div>
</div>

<!-- Scale Dialog -->
{#if showScaleDialog}
  <div class="modal-overlay" onclick={() => showScaleDialog = false}>
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <h3 class="modal-title">Scale Service</h3>
      <p class="modal-text">Adjust the number of replicas for {service.attributes.name}</p>
      
      <div class="form-group">
        <label for="replica-count">Replica Count:</label>
        <input 
          id="replica-count"
          type="number" 
          min="0" 
          max="10" 
          bind:value={newReplicaCount}
          class="form-input"
        />
      </div>

      <div class="modal-actions">
        <button class="btn btn-outline" onclick={() => showScaleDialog = false}>
          Cancel
        </button>
        <button class="btn btn-primary" onclick={handleScale}>
          Scale to {newReplicaCount}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .service-card {
    @apply bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm hover:shadow-md transition-shadow duration-200;
  }

  .service-card.detailed {
    @apply max-w-none;
  }

  .card-header {
    @apply flex items-start justify-between p-4 border-b border-gray-100 dark:border-gray-700;
  }

  .service-icon {
    @apply text-2xl;
  }

  .service-name {
    @apply font-semibold text-gray-900 dark:text-white;
  }

  .service-type {
    @apply text-sm text-gray-500 dark:text-gray-400 capitalize;
  }

  .status-indicators {
    @apply flex flex-col gap-1 items-end;
  }

  .status-badge, .health-badge {
    @apply px-2 py-1 rounded text-xs font-medium;
  }

  .badge-success {
    @apply bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400;
  }

  .badge-warning {
    @apply bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400;
  }

  .badge-error {
    @apply bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400;
  }

  .badge-info {
    @apply bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400;
  }

  .badge-neutral {
    @apply bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300;
  }

  .card-content {
    @apply p-4 space-y-3;
  }

  .info-row {
    @apply flex justify-between items-center;
  }

  .info-label {
    @apply text-sm font-medium text-gray-600 dark:text-gray-400;
  }

  .info-value {
    @apply text-sm text-gray-900 dark:text-white;
  }

  .resource-usage {
    @apply space-y-2 mt-4;
  }

  .usage-item {
    @apply flex items-center gap-2;
  }

  .usage-label {
    @apply text-xs font-medium text-gray-600 dark:text-gray-400 w-12;
  }

  .usage-bar {
    @apply flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden;
  }

  .usage-fill {
    @apply h-full bg-blue-500 transition-all duration-300;
  }

  .usage-value {
    @apply text-xs font-medium text-gray-600 dark:text-gray-400 w-12 text-right;
  }

  .details-toggle {
    @apply text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 font-medium flex items-center gap-1;
  }

  .detailed-info {
    @apply mt-4 space-y-4 border-t border-gray-100 dark:border-gray-700 pt-4;
  }

  .info-section h4 {
    @apply font-medium text-gray-900 dark:text-white mb-2;
  }

  .info-grid {
    @apply space-y-2;
  }

  .port-mappings {
    @apply flex flex-wrap gap-2;
  }

  .port-mapping {
    @apply px-2 py-1 bg-gray-100 dark:bg-gray-700 rounded text-sm font-mono;
  }

  .env-vars {
    @apply space-y-1 max-h-32 overflow-y-auto;
  }

  .env-var {
    @apply flex gap-2 text-sm;
  }

  .env-key {
    @apply font-medium text-gray-600 dark:text-gray-400;
  }

  .env-value {
    @apply text-gray-900 dark:text-white font-mono;
  }

  .card-actions {
    @apply flex gap-2 p-4 border-t border-gray-100 dark:border-gray-700;
  }

  .btn {
    @apply px-3 py-1.5 rounded-md font-medium transition-colors duration-200 text-sm inline-flex items-center;
  }

  .btn-sm {
    @apply px-2 py-1 text-xs;
  }

  .btn-primary {
    @apply bg-blue-600 text-white hover:bg-blue-700;
  }

  .btn-success {
    @apply bg-green-600 text-white hover:bg-green-700;
  }

  .btn-warning {
    @apply bg-yellow-600 text-white hover:bg-yellow-700;
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

  .form-group {
    @apply mb-4;
  }

  .form-group label {
    @apply block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1;
  }

  .form-input {
    @apply w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white;
  }

  .modal-actions {
    @apply flex gap-3 justify-end;
  }
</style>