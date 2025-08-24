<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { ServiceMetrics, ServiceMetric } from '../types/containers.ts';

  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select';

  import {
    BarChart3,
    TrendingUp,
    TrendingDown,
    Minus,
    RefreshCw,
    Download,
    Settings
  } from '@lucide/svelte';

  // Props using Svelte 5 syntax
  let {
    metrics,
    height = 300,
    showControls = true,
    refreshInterval = 30000,
    maxDataPoints = 50
  }: {
    metrics: ServiceMetrics;
    height?: number;
    showControls?: boolean;
    refreshInterval?: number;
    maxDataPoints?: number;
  } = $props();

  // State using Svelte 5 syntax
  let chartType = $state<'line' | 'bar' | 'area'>('line');
  let timeRange = $state<'1h' | '6h' | '24h' | '7d'>('1h');
  let selectedMetric = $state<string>('cpu_percent');
  let isRealtime = $state(true);
  let chartData = $state<ServiceMetric[]>([]);
  let loading = $state(false);

  // Chart dimensions
  const margin = { top: 20, right: 30, bottom: 40, left: 60 };
  let chartWidth = $derived(600 - margin.left - margin.right);
  const chartHeight = height - margin.top - margin.bottom;

  let svgElement: SVGSVGElement;
  let refreshTimer: number | null = null;

  // Lifecycle
  onMount(() => {
    updateChartData();

    if (isRealtime && refreshInterval > 0) {
      refreshTimer = window.setInterval(() => {
        updateChartData();
      }, refreshInterval);
    }
  });

  onDestroy(() => {
    if (refreshTimer) {
      clearInterval(refreshTimer);
    }
  });

  // Methods
  function updateChartData() {
    if (!metrics?.recent_metrics) return;

    // Filter metrics by selected type
    const filteredMetrics = metrics.recent_metrics
      .filter(metric => metric.metric_type === selectedMetric)
      .slice(-maxDataPoints)
      .sort((a, b) => new Date(a.collected_at).getTime() - new Date(b.collected_at).getTime());

    chartData = filteredMetrics;
  }

  function generatePath(data: ServiceMetric[]): string {
    if (data.length === 0) return '';

    const xScale = (index: number) => (index / (data.length - 1)) * chartWidth;
    const yScale = (value: number) => {
      const maxValue = Math.max(...data.map(d => d.value), 100);
      return chartHeight - (value / maxValue) * chartHeight;
    };

    let path = `M ${xScale(0)} ${yScale(data[0].value)}`;

    for (let i = 1; i < data.length; i++) {
      path += ` L ${xScale(i)} ${yScale(data[i].value)}`;
    }

    return path;
  }

  function generateAreaPath(data: ServiceMetric[]): string {
    if (data.length === 0) return '';

    const linePath = generatePath(data);
    const xScale = (index: number) => (index / (data.length - 1)) * $chartWidth;

    return `${linePath} L ${xScale(data.length - 1)} ${chartHeight} L ${xScale(0)} ${chartHeight} Z`;
  }

  function generateBars(data: ServiceMetric[]): Array<{x: number, y: number, width: number, height: number, value: number}> {
    if (data.length === 0) return [];

    const barWidth = chartWidth / data.length * 0.8;
    const maxValue = Math.max(...data.map(d => d.value), 100);

    return data.map((d, index) => {
      const x = (index / data.length) * chartWidth + (barWidth * 0.1);
      const barHeight = (d.value / maxValue) * chartHeight;
      const y = chartHeight - barHeight;

      return {
        x,
        y,
        width: barWidth,
        height: barHeight,
        value: d.value
      };
    });
  }

  function getYAxisTicks(data: ServiceMetric[]): number[] {
    if (data.length === 0) return [0, 25, 50, 75, 100];

    const maxValue = Math.max(...data.map(d => d.value), 100);
    const tickCount = 5;
    const step = maxValue / (tickCount - 1);

    return Array.from({ length: tickCount }, (_, i) => Math.round(i * step));
  }

  function getXAxisTicks(data: ServiceMetric[]): Array<{position: number, label: string}> {
    if (data.length === 0) return [];

    const tickCount = Math.min(5, data.length);
    const step = (data.length - 1) / (tickCount - 1);

    return Array.from({ length: tickCount }, (_, i) => {
      const index = Math.round(i * step);
      const metric = data[index];
      const position = (index / (data.length - 1)) * chartWidth;
      const date = new Date(metric.collected_at);
      const label = date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });

      return { position, label };
    });
  }

  function downloadChart() {
    if (!svgElement) return;

    const svgData = new XMLSerializer().serializeToString(svgElement);
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const img = new Image();

    canvas.width = 600;
    canvas.height = height;

    img.onload = () => {
      ctx?.drawImage(img, 0, 0);
      const link = document.createElement('a');
      link.download = `${selectedMetric}_chart_${new Date().toISOString().split('T')[0]}.png`;
      link.href = canvas.toDataURL();
      link.click();
    };

    img.src = 'data:image/svg+xml;base64,' + btoa(svgData);
  }

  function formatValue(value: number, unit: string): string {
    if (unit === 'percent') {
      return `${value.toFixed(1)}%`;
    } else if (unit === 'bytes') {
      return formatBytes(value);
    } else if (unit === 'ms') {
      return `${value.toFixed(0)}ms`;
    }
    return `${value.toFixed(2)} ${unit}`;
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  function getMetricColor(metricType: string): string {
    switch (metricType) {
      case 'cpu_percent': return '#3b82f6'; // blue
      case 'memory_percent': return '#10b981'; // green
      case 'memory_usage_bytes': return '#10b981'; // green
      case 'network_rx_bytes': return '#8b5cf6'; // purple
      case 'network_tx_bytes': return '#f59e0b'; // amber
      case 'disk_read_bytes': return '#ef4444'; // red
      case 'disk_write_bytes': return '#f97316'; // orange
      case 'response_time_ms': return '#06b6d4'; // cyan
      default: return '#6b7280'; // gray
    }
  }

  function getTrend(data: ServiceMetric[]): 'up' | 'down' | 'stable' {
    if (data.length < 2) return 'stable';

    const first = data[0].value;
    const last = data[data.length - 1].value;
    const threshold = first * 0.05; // 5% threshold

    if (last > first + threshold) return 'up';
    if (last < first - threshold) return 'down';
    return 'stable';
  }

  // Derived reactive values
  let yTicks = $derived(getYAxisTicks(chartData));
  let xTicks = $derived(getXAxisTicks(chartData));
  let trend = $derived(getTrend(chartData));
  let latestValue = $derived(chartData.length > 0 ? chartData[chartData.length - 1] : null);
  let metricColor = $derived(getMetricColor(selectedMetric));

  // Available metrics
  const availableMetrics = [
    { value: 'cpu_percent', label: 'CPU Usage', unit: 'percent' },
    { value: 'memory_percent', label: 'Memory Usage', unit: 'percent' },
    { value: 'memory_usage_bytes', label: 'Memory Bytes', unit: 'bytes' },
    { value: 'network_rx_bytes', label: 'Network In', unit: 'bytes' },
    { value: 'network_tx_bytes', label: 'Network Out', unit: 'bytes' },
    { value: 'disk_read_bytes', label: 'Disk Read', unit: 'bytes' },
    { value: 'disk_write_bytes', label: 'Disk Write', unit: 'bytes' },
    { value: 'response_time_ms', label: 'Response Time', unit: 'ms' }
  ];

  let currentMetricInfo = $derived(availableMetrics.find(m => m.value === selectedMetric) || availableMetrics[0]);
</script>

<Card>
  <CardHeader>
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <BarChart3 class="w-5 h-5 text-{metricColor.replace('#', '')}" />
        <div>
          <CardTitle class="text-lg">{currentMetricInfo.label}</CardTitle>
          <CardDescription>
            {#if latestValue}
              Current: {formatValue(latestValue.value, currentMetricInfo.unit)}
              {#if trend === 'up'}
                <TrendingUp class="inline w-4 h-4 ml-1 text-green-500" />
              {:else if trend === 'down'}
                <TrendingDown class="inline w-4 h-4 ml-1 text-red-500" />
              {:else}
                <Minus class="inline w-4 h-4 ml-1 text-gray-500" />
              {/if}
            {:else}
              No data available
            {/if}
          </CardDescription>
        </div>
      </div>

      {#if showControls}
        <div class="flex items-center gap-2">
          <Select bind:value={selectedMetric}>
            <SelectTrigger class="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {#each availableMetrics as metric}
                <SelectItem value={metric.value}>{metric.label}</SelectItem>
              {/each}
            </SelectContent>
          </Select>

          <Select bind:value={chartType}>
            <SelectTrigger class="w-20">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="line">Line</SelectItem>
              <SelectItem value="area">Area</SelectItem>
              <SelectItem value="bar">Bar</SelectItem>
            </SelectContent>
          </Select>

          <Button variant="outline" size="sm" onclick={downloadChart}>
            <Download class="w-4 h-4" />
          </Button>
        </div>
      {/if}
    </div>
  </CardHeader>

  <CardContent>
    {#if loading}
      <div class="flex items-center justify-center" style="height: {height}px">
        <div class="animate-spin w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full"></div>
      </div>
    {:else if chartData.length === 0}
      <div class="flex items-center justify-center" style="height: {height}px">
        <div class="text-center">
          <BarChart3 class="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p class="text-gray-500">No metric data available</p>
          <p class="text-sm text-gray-400">Data will appear once metrics are collected</p>
        </div>
      </div>
    {:else}
      <div class="chart-container">
        <svg
          bind:this={svgElement}
          width="600"
          height="{height}"
          viewBox="0 0 600 {height}"
          class="w-full h-auto"
        >
          <defs>
            <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color: {metricColor}; stop-opacity: 0.3" />
              <stop offset="100%" style="stop-color: {metricColor}; stop-opacity: 0.1" />
            </linearGradient>
          </defs>

          <g transform="translate({margin.left}, {margin.top})">
            <!-- Grid lines -->
            {#each yTicks as tick}
              {@const y = chartHeight - (tick / Math.max(...yTicks)) * chartHeight}
              <line
                x1="0"
                y1="{y}"
                x2="{chartWidth}"
                y2="{y}"
                stroke="#e5e7eb"
                stroke-width="1"
                opacity="0.5"
              />
              <text
                x="-10"
                y="{y + 4}"
                text-anchor="end"
                class="text-xs fill-gray-500"
              >
                {formatValue(tick, currentMetricInfo.unit)}
              </text>
            {/each}

            <!-- Chart content -->
            {#if chartType === 'line'}
              <path
                d="{generatePath(chartData)}"
                fill="none"
                stroke="{metricColor}"
                stroke-width="2"
                class="transition-all duration-300"
              />

              <!-- Data points -->
              {#each chartData as point, index}
                {@const x = (index / (chartData.length - 1)) * chartWidth}
                {@const y = chartHeight - (point.value / Math.max(...chartData.map(d => d.value))) * chartHeight}
                <circle
                  cx="{x}"
                  cy="{y}"
                  r="3"
                  fill="{metricColor}"
                  class="hover:r-4 transition-all duration-200"
                >
                  <title>{formatValue(point.value, currentMetricInfo.unit)} at {new Date(point.collected_at).toLocaleTimeString()}</title>
                </circle>
              {/each}

            {:else if chartType === 'area'}
              <path
                d="{generateAreaPath(chartData)}"
                fill="url(#areaGradient)"
                stroke="{metricColor}"
                stroke-width="2"
                class="transition-all duration-300"
              />

            {:else if chartType === 'bar'}
              {#each generateBars(chartData) as bar}
                <rect
                  x="{bar.x}"
                  y="{bar.y}"
                  width="{bar.width}"
                  height="{bar.height}"
                  fill="{metricColor}"
                  opacity="0.8"
                  class="hover:opacity-100 transition-opacity duration-200"
                >
                  <title>{formatValue(bar.value, currentMetricInfo.unit)}</title>
                </rect>
              {/each}
            {/if}

            <!-- X-axis -->
            <line
              x1="0"
              y1="{chartHeight}"
              x2="{chartWidth}"
              y2="{chartHeight}"
              stroke="#374151"
              stroke-width="1"
            />

            <!-- X-axis labels -->
            {#each xTicks as tick}
              <text
                x="{tick.position}"
                y="{chartHeight + 20}"
                text-anchor="middle"
                class="text-xs fill-gray-500"
              >
                {tick.label}
              </text>
            {/each}

            <!-- Y-axis -->
            <line
              x1="0"
              y1="0"
              x2="0"
              y2="{chartHeight}"
              stroke="#374151"
              stroke-width="1"
            />
          </g>
        </svg>
      </div>
    {/if}

    {#if isRealtime && refreshInterval > 0}
      <div class="flex items-center justify-between mt-4 pt-4 border-t">
        <div class="flex items-center gap-2 text-sm text-gray-500">
          <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
          Live updates every {Math.round(refreshInterval / 1000)}s
        </div>

        <div class="flex items-center gap-2">
          <Badge variant="outline" class="text-xs">
            {chartData.length} data points
          </Badge>
          {#if latestValue}
            <Badge variant="outline" class="text-xs">
              Last: {new Date(latestValue.collected_at).toLocaleTimeString()}
            </Badge>
          {/if}
        </div>
      </div>
    {/if}
  </CardContent>
</Card>

<style>
  .chart-container {
    overflow: hidden;
  }

  svg {
    font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
  }

  .transition-all {
    transition: all 0.3s ease-in-out;
  }
</style>
