<script>
  import { onMount, onDestroy } from 'svelte';
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

  let metricsData = $state({});
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
    return metricsData.summary || {};
  });

  const serviceMetrics = $derived(() => {
    return metricsData.services || [];
  });

  const timeSeriesData = $derived(() => {
    return metricsData.timeseries || {};
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
      metricsData = mockData;
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

<div class="space-y-6">
  <!-- Header -->
  <div class="flex items-start justify-between">
    <div>
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        Metrics Dashboard
      </h3>
      <p class="text-gray-600 dark:text-gray-300">
        Real-time monitoring and performance metrics
      </p>
    </div>

    <div class="flex gap-3 items-center">
      <select
        bind:value={selectedService}
        onchange={(e) => handleServiceChange(e.target.value)}
        class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white text-sm"
      >
        <option value="all">All Services</option>
        {#each services as service}
          <option value={service.id}>{service.attributes.name}</option>
        {/each}
      </select>

      <select
        bind:value={selectedTimeRange}
        onchange={(e) => handleTimeRangeChange(e.target.value)}
        class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white text-sm"
      >
        {#each timeRanges as range}
          <option value={range.value}>{range.label}</option>
        {/each}
      </select>

      <button
        class="px-4 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
        onclick={loadMetrics}
        disabled={isLoading}
      >
        <RefreshCw class="w-4 h-4 mr-2 {isLoading ? 'animate-spin' : ''}" />
        Refresh
      </button>
    </div>
  </div>

  <!-- Last Updated -->
  {#if lastUpdated}
    <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
      <Clock class="w-4 h-4 text-gray-400" />
      <span class="text-sm text-gray-600 dark:text-gray-400">
        Last updated: {lastUpdated.toLocaleTimeString()}
      </span>
    </div>
  {/if}

  <!-- Error Display -->
  {#if error}
    <div class="p-4 rounded-md border bg-red-50 border-red-200 text-red-800 dark:bg-red-900/20 dark:border-red-800 dark:text-red-400 flex items-center gap-3">
      <AlertTriangle class="w-4 h-4" />
      <span>{error}</span>
    </div>
  {/if}

  <!-- Metrics Summary -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="flex items-center gap-3 mb-3">
        <Cpu class="w-5 h-5 text-blue-600" />
        <span class="font-medium text-gray-900 dark:text-white">CPU Usage</span>
      </div>
      <div class="text-2xl font-bold text-gray-900 dark:text-white">
        {formatValue(currentMetrics.total_cpu_usage, '%')}%
      </div>
      <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 mt-3">
        <div
          class="h-2 rounded-full transition-all duration-300 {getUsageColor(currentMetrics.total_cpu_usage)}"
          style="width: {Math.min(currentMetrics.total_cpu_usage || 0, 100)}%"
        ></div>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="flex items-center gap-3 mb-3">
        <HardDrive class="w-5 h-5 text-green-600" />
        <span class="font-medium text-gray-900 dark:text-white">Memory</span>
      </div>
      <div class="text-2xl font-bold text-gray-900 dark:text-white">
        {formatValue(currentMetrics.total_memory_usage, 'MB')} MB
      </div>
      <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 mt-3">
        <div
          class="h-2 rounded-full transition-all duration-300 {getUsageColor((currentMetrics.total_memory_usage || 0) / 20)}"
          style="width: {Math.min((currentMetrics.total_memory_usage || 0) / 20, 100)}%"
        ></div>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="flex items-center gap-3 mb-3">
        <Network class="w-5 h-5 text-purple-600" />
        <span class="font-medium text-gray-900 dark:text-white">Network</span>
      </div>
      <div class="text-2xl font-bold text-gray-900 dark:text-white text-sm">
        ↓{formatValue(currentMetrics.total_network_in, 'MB/s')}<br>
        ↑{formatValue(currentMetrics.total_network_out, 'MB/s')}
      </div>
      <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
        In/Out MB/s
      </div>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
      <div class="flex items-center gap-3 mb-3">
        <Activity class="w-5 h-5 text-orange-600" />
        <span class="font-medium text-gray-900 dark:text-white">Requests</span>
      </div>
      <div class="text-2xl font-bold text-gray-900 dark:text-white">
        {formatValue(currentMetrics.total_requests, 'req/s')}
      </div>
      <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
        Requests per second
      </div>
    </div>
  </div>

  <!-- Health Overview -->
  <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
    <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Health Overview</h4>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="flex items-center gap-3">
        <CheckCircle class="w-5 h-5 text-green-600" />
        <div>
          <div class="text-2xl font-bold text-green-600">{currentMetrics.healthy_services || 0}</div>
          <div class="text-sm text-gray-600 dark:text-gray-400">Healthy Services</div>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <AlertTriangle class="w-5 h-5 text-yellow-600" />
        <div>
          <div class="text-2xl font-bold text-yellow-600">
            {(currentMetrics.active_services || 0) - (currentMetrics.healthy_services || 0)}
          </div>
          <div class="text-sm text-gray-600 dark:text-gray-400">Warning</div>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <Activity class="w-5 h-5 text-blue-600" />
        <div>
          <div class="text-2xl font-bold text-gray-900 dark:text-white">{currentMetrics.active_services || 0}</div>
          <div class="text-sm text-gray-600 dark:text-gray-400">Total Services</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Charts Section -->
  <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700">
    <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Time Series Metrics</h4>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      {#each metricTypes.slice(0, 4) as metric}
        {@const data = timeSeriesData[metric.key] || []}
        <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-2">
              <svelte:component this={metric.icon} class="w-4 h-4 text-gray-600 dark:text-gray-400" />
              <span class="font-medium text-gray-900 dark:text-white">{metric.label}</span>
            </div>
            <span class="text-xs text-gray-500 dark:text-gray-400">{metric.unit}</span>
          </div>

          <div class="relative h-32">
            {#if data.length > 0}
              <svg class="w-full h-full" viewBox="0 0 400 100">
                <polyline
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  class="text-blue-600"
                  points={data.slice(-20).map((point, i) => `${(i / 19) * 400},${100 - (point.value / 100) * 80}`).join(' ')}
                />
                {#each data.slice(-5) as point, i}
                  <circle
                    cx={((data.length - 5 + i) / (data.length - 1)) * 400}
                    cy={100 - (point.value / 100) * 80}
                    r="3"
                    class="fill-blue-600"
                  />
                {/each}
              </svg>
              <div class="absolute top-2 right-2 text-sm font-medium text-gray-900 dark:text-white">
                {formatValue(data[data.length - 1]?.value, metric.unit)}{metric.unit}
              </div>
            {:else}
              <div class="flex items-center justify-center h-full text-gray-400">
                <BarChart3 class="w-8 h-8 text-gray-400" />
                <span class="text-sm text-gray-500 ml-2">No data</span>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  </div>

  <!-- Services Table -->
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
    <h4 class="text-lg font-semibold text-gray-900 dark:text-white p-6 pb-4">Service Breakdown</h4>
    <div class="overflow-x-auto">
      <div class="min-w-full">
        <div class="grid grid-cols-6 gap-4 px-6 py-3 border-b border-gray-200 dark:border-gray-700 text-sm font-medium text-gray-600 dark:text-gray-400">
          <div>Service</div>
          <div>CPU</div>
          <div>Memory</div>
          <div>Network</div>
          <div>Requests</div>
          <div>Health</div>
        </div>

        {#each serviceMetrics as service}
          <div class="grid grid-cols-6 gap-4 px-6 py-4 border-b border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700">
            <div class="flex items-center">
              <div class="font-medium text-gray-900 dark:text-white">
                <span class="text-sm">{service.name}</span>
              </div>
            </div>
            <div class="flex flex-col">
              <span class="text-sm font-medium text-gray-900 dark:text-white">{Math.round(service.cpu_usage)}%</span>
              <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-1 mt-1">
                <div
                  class="h-1 rounded-full {getUsageColor(service.cpu_usage)}"
                  style="width: {Math.min(service.cpu_usage, 100)}%"
                ></div>
              </div>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-900 dark:text-white">{Math.round(service.memory_usage)}MB</span>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-900 dark:text-white text-xs">
                ↓{Math.round(service.network_in)}<br>↑{Math.round(service.network_out)}
              </span>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-900 dark:text-white">{Math.round(service.requests_per_sec)}</span>
            </div>
            <div>
              <span class="text-sm font-medium {getHealthColor(service.health_score)}">
                {Math.round(service.health_score)}%
              </span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </div>
</div>