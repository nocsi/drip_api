<script>
  import { onMount, onDestroy } from 'svelte';
  import { writable } from 'svelte/store';
  import { 
    Activity, 
    Cpu, 
    HardDrive, 
    Network, 
    Zap,
    TrendingUp,
    TrendingDown,
    RefreshCw,
    BarChart3,
    PieChart,
    LineChart,
    Clock,
    AlertTriangle,
    CheckCircle,
    Settings
  } from '@lucide/svelte';

  let { 
    services = [], 
    workspaceId,
    autoRefresh = true,
    refreshInterval = 30000 // 30 seconds
  } = $props();

  let metricsData = writable({});
  let selectedTimeRange = $state('1h');
  let selectedService = $state('all');
  let isLoading = $state(false);
  let error = $state(null);
  let lastUpdated = $state(null);

  let refreshTimer = null;

  const timeRanges = [
    { value: '5m', label: '5 minutes' },
    { value: '15m', label: '15 minutes' },
    { value: '1h', label: '1 hour' },
    { value: '6h', label: '6 hours' },
    { value: '24h', label: '24 hours' },
    { value: '7d', label: '7 days' }
  ];

  const metricTypes = [
    { key: 'cpu', label: 'CPU Usage', unit: '%', icon: Cpu },
    { key: 'memory', label: 'Memory Usage', unit: 'MB', icon: HardDrive },
    { key: 'network_in', label: 'Network In', unit: 'MB/s', icon: Network },
    { key: 'network_out', label: 'Network Out', unit: 'MB/s', icon: Network },
    { key: 'disk_io', label: 'Disk I/O', unit: 'MB/s', icon: HardDrive },
    { key: 'requests', label: 'Requests/sec', unit: 'req/s', icon: Activity }
  ];

  // Mock metrics data for demonstration
  const generateMockMetrics = () => {
    const now = Date.now();
    const points = 50;
    const interval = selectedTimeRange === '5m' ? 6000 : 
                    selectedTimeRange === '15m' ? 18000 :
                    selectedTimeRange === '1h' ? 72000 :
                    selectedTimeRange === '6h' ? 432000 :
                    selectedTimeRange === '24h' ? 1728000 : 604800000;

    const mockData = {
      summary: {
        total_cpu_usage: Math.random() * 80 + 10,
        total_memory_usage: Math.random() * 2048 + 512,
        total_network_in: Math.random() * 100 + 10,
        total_network_out: Math.random() * 50 + 5,
        total_requests: Math.random() * 1000 + 100,
        active_services: services.length,
        healthy_services: services.filter(s => s.attributes.healthStatus === 'healthy').length
      },
      timeseries: {}
    };

    metricTypes.forEach(metric => {
      mockData.timeseries[metric.key] = Array.from({ length: points }, (_, i) => ({
        timestamp: now - (points - i) * interval,
        value: Math.random() * 100 + Math.sin(i * 0.1) * 20 + 50,
        service_id: selectedService === 'all' ? null : selectedService
      }));
    });

    // Add per-service breakdown
    mockData.services = services.map(service => ({
      id: service.id,
      name: service.attributes.name,
      cpu_usage: Math.random() * 80 + 5,
      memory_usage: Math.random() * 512 + 64,
      network_in: Math.random() * 50 + 5,
      network_out: Math.random() * 25 + 2,
      requests_per_sec: Math.random() * 200 + 10,
      health_score: Math.random() * 30 + 70
    }));

    return mockData;
  };

  const currentMetrics = $derived(() => {
    const data = $metricsData;
    return data.summary || {};
  });

  const serviceMetrics = $derived(() => {
    const data = $metricsData;
    return data.services || [];
  });

  const timeSeriesData = $derived(() => {
    const data = $metricsData;
    return data.timeseries || {};
  });

  onMount(async () => {
    await loadMetrics();
    if (autoRefresh) {
      startAutoRefresh();
    }
  });

  onDestroy(() => {
    if (refreshTimer) {
      clearInterval(refreshTimer);
    }
  });

  function startAutoRefresh() {
    if (refreshTimer) {
      clearInterval(refreshTimer);
    }
    refreshTimer = setInterval(loadMetrics, refreshInterval);
  }

  function stopAutoRefresh() {
    if (refreshTimer) {
      clearInterval(refreshTimer);
      refreshTimer = null;
    }
  }

  async function loadMetrics() {
    if (isLoading) return;
    
    isLoading = true;
    error = null;
    
    try {
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const mockData = generateMockMetrics();
      metricsData.set(mockData);
      lastUpdated = new Date();
      
    } catch (err) {
      console.error('Failed to load metrics:', err);
      error = 'Failed to load metrics data';
    } finally {
      isLoading = false;
    }
  }

  function handleTimeRangeChange(newRange) {
    selectedTimeRange = newRange;
    loadMetrics();
  }

  function handleServiceChange(serviceId) {
    selectedService = serviceId;
    loadMetrics();
  }

  function formatValue(value, unit) {
    if (typeof value !== 'number') return '0';
    
    if (unit === 'MB' && value > 1024) {
      return `${(value / 1024).toFixed(1)} GB`;
    }
    
    if (value > 1000000) {
      return `${(value / 1000000).toFixed(1)}M`;
    }
    
    if (value > 1000) {
      return `${(value / 1000).toFixed(1)}K`;
    }
    
    return Math.round(value).toString();
  }

  function getHealthColor(score) {
    if (score >= 90) return 'text-green-600';
    if (score >= 70) return 'text-yellow-600';
    return 'text-red-600';
  }

  function getUsageColor(percentage) {
    if (percentage >= 90) return 'bg-red-500';
    if (percentage >= 70) return 'bg-yellow-500';
    return 'bg-green-500';
  }
</script>

<div class="metrics-dashboard">
  <!-- Header -->
  <div class="dashboard-header">
    <div>
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        Metrics Dashboard
      </h3>
      <p class="text-gray-600 dark:text-gray-300">
        Real-time monitoring and performance metrics
      </p>
    </div>
    
    <div class="header-controls">
      <select 
        bind:value={selectedService}
        onchange={(e) => handleServiceChange(e.target.value)}
        class="control-select"
      >
        <option value="all">All Services</option>
        {#each services as service}
          <option value={service.id}>{service.attributes.name}</option>
        {/each}
      </select>

      <select 
        bind:value={selectedTimeRange}
        onchange={(e) => handleTimeRangeChange(e.target.value)}
        class="control-select"
      >
        {#each timeRanges as range}
          <option value={range.value}>{range.label}</option>
        {/each}
      </select>

      <button 
        class="btn btn-outline btn-sm"
        onclick={loadMetrics}
        disabled={isLoading}
      >
        <RefreshCw class="w-4 h-4 mr-2" class:animate-spin={isLoading} />
        Refresh
      </button>
    </div>
  </div>

  <!-- Last Updated -->
  {#if lastUpdated}
    <div class="last-updated">
      <Clock class="w-4 h-4 text-gray-400" />
      <span class="text-sm text-gray-600 dark:text-gray-400">
        Last updated: {lastUpdated.toLocaleTimeString()}
      </span>
    </div>
  {/if}

  <!-- Error Display -->
  {#if error}
    <div class="alert alert-error">
      <AlertTriangle class="w-4 h-4" />
      <span>{error}</span>
    </div>
  {/if}

  <!-- Summary Metrics -->
  <div class="metrics-summary">
    <div class="metric-card">
      <div class="metric-header">
        <Cpu class="w-5 h-5 text-blue-600" />
        <span class="metric-title">Total CPU</span>
      </div>
      <div class="metric-value">
        {formatValue(currentMetrics.total_cpu_usage, '%')}%
      </div>
      <div class="metric-bar">
        <div 
          class="metric-fill {getUsageColor(currentMetrics.total_cpu_usage)}"
          style="width: {Math.min(currentMetrics.total_cpu_usage || 0, 100)}%"
        ></div>
      </div>
    </div>

    <div class="metric-card">
      <div class="metric-header">
        <HardDrive class="w-5 h-5 text-green-600" />
        <span class="metric-title">Total Memory</span>
      </div>
      <div class="metric-value">
        {formatValue(currentMetrics.total_memory_usage, 'MB')} MB
      </div>
      <div class="metric-bar">
        <div 
          class="metric-fill {getUsageColor((currentMetrics.total_memory_usage / 4096) * 100)}"
          style="width: {Math.min((currentMetrics.total_memory_usage / 4096) * 100 || 0, 100)}%"
        ></div>
      </div>
    </div>

    <div class="metric-card">
      <div class="metric-header">
        <Network class="w-5 h-5 text-purple-600" />
        <span class="metric-title">Network I/O</span>
      </div>
      <div class="metric-value">
        ↓{formatValue(currentMetrics.total_network_in, 'MB/s')} 
        ↑{formatValue(currentMetrics.total_network_out, 'MB/s')}
      </div>
      <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
        MB/s
      </div>
    </div>

    <div class="metric-card">
      <div class="metric-header">
        <Activity class="w-5 h-5 text-orange-600" />
        <span class="metric-title">Requests</span>
      </div>
      <div class="metric-value">
        {formatValue(currentMetrics.total_requests, 'req/s')}
      </div>
      <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
        req/sec
      </div>
    </div>
  </div>

  <!-- Service Health Overview -->
  <div class="health-overview">
    <h4 class="section-title">Service Health</h4>
    <div class="health-grid">
      <div class="health-stat">
        <CheckCircle class="w-5 h-5 text-green-600" />
        <div>
          <div class="health-value">{currentMetrics.healthy_services || 0}</div>
          <div class="health-label">Healthy</div>
        </div>
      </div>
      <div class="health-stat">
        <AlertTriangle class="w-5 h-5 text-yellow-600" />
        <div>
          <div class="health-value">
            {(currentMetrics.active_services || 0) - (currentMetrics.healthy_services || 0)}
          </div>
          <div class="health-label">Issues</div>
        </div>
      </div>
      <div class="health-stat">
        <Activity class="w-5 h-5 text-blue-600" />
        <div>
          <div class="health-value">{currentMetrics.active_services || 0}</div>
          <div class="health-label">Total</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Time Series Charts -->
  <div class="charts-section">
    <h4 class="section-title">Performance Trends</h4>
    <div class="charts-grid">
      {#each metricTypes.slice(0, 4) as metric}
        {@const data = timeSeriesData[metric.key] || []}
        <div class="chart-card">
          <div class="chart-header">
            <div class="flex items-center gap-2">
              <svelte:component this={metric.icon} class="w-4 h-4 text-gray-600" />
              <span class="chart-title">{metric.label}</span>
            </div>
            <span class="chart-unit">{metric.unit}</span>
          </div>
          
          <!-- Simple SVG Chart -->
          <div class="chart-container">
            {#if data.length > 0}
              <svg class="chart-svg" viewBox="0 0 400 100">
                <polyline
                  fill="none"
                  stroke="rgb(59, 130, 246)"
                  stroke-width="2"
                  points={data.map((point, i) => 
                    `${(i / (data.length - 1)) * 400},${100 - (point.value / 100) * 80}`
                  ).join(' ')}
                />
                {#each data.slice(-5) as point, i}
                  <circle
                    cx={((data.length - 5 + i) / (data.length - 1)) * 400}
                    cy={100 - (point.value / 100) * 80}
                    r="2"
                    fill="rgb(59, 130, 246)"
                  />
                {/each}
              </svg>
              <div class="chart-current-value">
                {formatValue(data[data.length - 1]?.value || 0, metric.unit)}
                {metric.unit}
              </div>
            {:else}
              <div class="chart-no-data">
                <BarChart3 class="w-8 h-8 text-gray-400" />
                <span class="text-sm text-gray-500">No data available</span>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  </div>

  <!-- Per-Service Breakdown -->
  <div class="services-section">
    <h4 class="section-title">Service Breakdown</h4>
    <div class="services-table">
      <div class="table-header">
        <div class="table-cell">Service</div>
        <div class="table-cell">CPU</div>
        <div class="table-cell">Memory</div>
        <div class="table-cell">Network</div>
        <div class="table-cell">Requests</div>
        <div class="table-cell">Health</div>
      </div>
      
      {#each serviceMetrics as service}
        <div class="table-row">
          <div class="table-cell">
            <div class="service-cell">
              <span class="service-name">{service.name}</span>
            </div>
          </div>
          <div class="table-cell">
            <span class="metric-value-sm">{Math.round(service.cpu_usage)}%</span>
            <div class="mini-bar">
              <div 
                class="mini-fill {getUsageColor(service.cpu_usage)}"
                style="width: {Math.min(service.cpu_usage, 100)}%"
              ></div>
            </div>
          </div>
          <div class="table-cell">
            <span class="metric-value-sm">{Math.round(service.memory_usage)} MB</span>
          </div>
          <div class="table-cell">
            <span class="metric-value-sm text-xs">
              ↓{Math.round(service.network_in)} ↑{Math.round(service.network_out)}
            </span>
          </div>
          <div class="table-cell">
            <span class="metric-value-sm">{Math.round(service.requests_per_sec)}</span>
          </div>
          <div class="table-cell">
            <span class="health-score {getHealthColor(service.health_score)}">
              {Math.round(service.health_score)}%
            </span>
          </div>
        </div>
      {/each}
    </div>
  </div>
</div>

<style>
  .metrics-dashboard {
    @apply space-y-6;
  }

  .dashboard-header {
    @apply flex items-start justify-between;
  }

  .header-controls {
    @apply flex gap-3;
  }

  .control-select {
    @apply px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm;
    @apply focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white;
  }

  .btn {
    @apply px-3 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center text-sm;
  }

  .btn-sm {
    @apply px-2 py-1 text-xs;
  }

  .btn-outline {
    @apply border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700;
  }

  .last-updated {
    @apply flex items-center gap-2;
  }

  .alert {
    @apply p-4 rounded-md border flex items-center gap-2;
  }

  .alert-error {
    @apply bg-red-50 border-red-200 text-red-800 dark:bg-red-900/20 dark:border-red-800 dark:text-red-400;
  }

  .metrics-summary {
    @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4;
  }

  .metric-card {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
  }

  .metric-header {
    @apply flex items-center gap-2 mb-2;
  }

  .metric-title {
    @apply text-sm font-medium text-gray-600 dark:text-gray-400;
  }

  .metric-value {
    @apply text-2xl font-bold text-gray-900 dark:text-white mb-2;
  }

  .metric-bar {
    @apply w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden;
  }

  .metric-fill {
    @apply h-full transition-all duration-300;
  }

  .health-overview {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
  }

  .section-title {
    @apply text-lg font-semibold text-gray-900 dark:text-white mb-4;
  }

  .health-grid {
    @apply grid grid-cols-3 gap-4;
  }

  .health-stat {
    @apply flex items-center gap-3;
  }

  .health-value {
    @apply text-xl font-bold text-gray-900 dark:text-white;
  }

  .health-label {
    @apply text-sm text-gray-600 dark:text-gray-400;
  }

  .charts-section {
    @apply space-y-4;
  }

  .charts-grid {
    @apply grid grid-cols-1 md:grid-cols-2 gap-4;
  }

  .chart-card {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
  }

  .chart-header {
    @apply flex items-center justify-between mb-3;
  }

  .chart-title {
    @apply text-sm font-medium text-gray-600 dark:text-gray-400;
  }

  .chart-unit {
    @apply text-xs text-gray-500 dark:text-gray-500;
  }

  .chart-container {
    @apply relative h-24;
  }

  .chart-svg {
    @apply w-full h-full;
  }

  .chart-current-value {
    @apply absolute top-1 right-1 text-sm font-medium text-blue-600 dark:text-blue-400;
  }

  .chart-no-data {
    @apply flex flex-col items-center justify-center h-full text-gray-400;
  }

  .services-section {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
  }

  .services-table {
    @apply space-y-2;
  }

  .table-header {
    @apply grid grid-cols-6 gap-4 pb-2 border-b border-gray-200 dark:border-gray-700;
  }

  .table-row {
    @apply grid grid-cols-6 gap-4 py-2 hover:bg-gray-50 dark:hover:bg-gray-700 rounded;
  }

  .table-cell {
    @apply text-sm;
  }

  .service-cell {
    @apply flex items-center gap-2;
  }

  .service-name {
    @apply font-medium text-gray-900 dark:text-white;
  }

  .metric-value-sm {
    @apply text-sm font-medium text-gray-900 dark:text-white;
  }

  .mini-bar {
    @apply w-full h-1 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden mt-1;
  }

  .mini-fill {
    @apply h-full transition-all duration-300;
  }

  .health-score {
    @apply text-sm font-medium;
  }
</style>