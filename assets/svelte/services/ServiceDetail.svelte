<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { getDefaultApi } from './api.ts';
  import type {
    ContainerService,
    ServiceMetrics,
    ContainerLogs,
    HealthCheck,
    DeploymentEvent
  } from '../types/containers.ts';

  import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '../ui/dialog';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
  import { Progress } from '../ui/progress';
  import { ScrollArea } from '../ui/scroll-area';
  import { Skeleton } from '../ui/skeleton';

  import {
    Play,
    Square,
    RotateCcw,
    Trash2,
    Settings,
    Activity,
    Terminal,
    BarChart3,
    Heart,
    Clock,
    Cpu,
    MemoryStick,
    HardDrive,
    Network,
    AlertCircle,
    CheckCircle,
    Info,
    ExternalLink,
    Download,
    RefreshCw,
    X
  } from '@lucide/svelte';

  // Props using Svelte 5 syntax
  let {
    service,
    teamId,
    onclose,
    onaction
  }: {
    service: ContainerService;
    teamId: string;
    onclose?: () => void;
    onaction?: (action: string, params?: any) => void;
  } = $props();

  // State using Svelte 5 syntax
  let metrics = $state<ServiceMetrics | null>(null);
  let logs = $state<ContainerLogs | null>(null);
  let health = $state<HealthCheck[]>([]);
  let events = $state<DeploymentEvent[]>([]);
  let loading = $state({
    metrics: false,
    logs: false,
    health: false,
    events: false
  });
  let error = $state<string | null>(null);
  let logFollow = $state(false);

  // API instance
  const api = getDefaultApi();
  let refreshInterval: number | null = null;

  // Lifecycle
  onMount(() => {
    loadServiceDetails();

    // Auto-refresh every 30 seconds
    refreshInterval = window.setInterval(() => {
      refreshData();
    }, 30000);
  });

  onDestroy(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
  });

  // Methods
  async function loadServiceDetails() {
    await Promise.all([
      loadMetrics(),
      loadLogs(),
      loadHealth(),
      loadEvents()
    ]);
  }

  async function loadMetrics() {
    try {
      loading.metrics = true;
      const response = await api.getServiceMetrics(teamId, service.id);
      metrics = response.data;
    } catch (err) {
      console.error('Failed to load metrics:', err);
      error = 'Failed to load metrics';
    } finally {
      loading.metrics = false;
    }
  }

  async function loadLogs() {
    try {
      loading.logs = true;
      const response = await api.getServiceLogs(teamId, service.id, 100, logFollow);
      logs = response.data;
    } catch (err) {
      console.error('Failed to load logs:', err);
      error = 'Failed to load logs';
    } finally {
      loading.logs = false;
    }
  }

  async function loadHealth() {
    try {
      loading.health = true;
      const response = await api.getServiceHealth(teamId, service.id);
      health = response.data.recent_checks || [];
    } catch (err) {
      console.error('Failed to load health:', err);
      error = 'Failed to load health checks';
    } finally {
      loading.health = false;
    }
  }

  async function loadEvents() {
    try {
      loading.events = true;
      // Get events from service.deployment_events if available
      if (service.deployment_events) {
        events = service.deployment_events;
      } else {
        events = [];
      }
    } catch (err) {
      console.error('Failed to load events:', err);
      error = 'Failed to load events';
    } finally {
      loading.events = false;
    }
  }

  async function refreshData() {
    await Promise.all([
      loadMetrics(),
      loadHealth()
    ]);
  }

  function handleAction(action: string, params?: any) {
    onaction?.(action, params);
  }

  function handleClose() {
    onclose?.();
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'running': return 'text-green-600 bg-green-50 border-green-200';
      case 'stopped': return 'text-gray-600 bg-gray-50 border-gray-200';
      case 'error': return 'text-red-600 bg-red-50 border-red-200';
      case 'deploying': return 'text-blue-600 bg-blue-50 border-blue-200';
      case 'building': return 'text-yellow-600 bg-yellow-50 border-yellow-200';
      default: return 'text-gray-600 bg-gray-50 border-gray-200';
    }
  }

  function getHealthStatusColor(status: string): string {
    switch (status) {
      case 'healthy': return 'text-green-600';
      case 'unhealthy': return 'text-red-600';
      case 'starting': return 'text-yellow-600';
      default: return 'text-gray-600';
    }
  }

  function formatUptime(deployedAt: string): string {
    if (!deployedAt) return 'N/A';

    const deployed = new Date(deployedAt);
    const now = new Date();
    const diffMs = now.getTime() - deployed.getTime();

    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    if (days > 0) return `${days}d ${hours}h ${minutes}m`;
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }

  function formatDateTime(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  function downloadLogs() {
    if (!logs) return;

    const blob = new Blob([logs.logs], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${service.name}-logs-${new Date().toISOString().split('T')[0]}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // Derived reactive values using Svelte 5 syntax
  let canStart = $derived(['stopped', 'error'].includes(service.status));
  let canStop = $derived(['running', 'deploying'].includes(service.status));
  let canRestart = $derived(service.status === 'running');
</script>

<Dialog open={true} onOpenChange={handleClose}>
  <DialogContent class="max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
    <DialogHeader>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-blue-500 text-white flex items-center justify-center font-semibold">
            {service.service_type.charAt(0).toUpperCase()}
          </div>
          <div>
            <DialogTitle class="text-xl">{service.name}</DialogTitle>
            <DialogDescription class="text-sm">
              {service.folder_path} • {service.service_type}
            </DialogDescription>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <Badge class={getStatusColor(service.status)}>
            {service.status.charAt(0).toUpperCase() + service.status.slice(1)}
          </Badge>
          <Button variant="ghost" size="sm" onclick={handleClose}>
            <X class="w-4 h-4" />
          </Button>
        </div>
      </div>
    </DialogHeader>

    <div class="flex-1 overflow-hidden">
      <Tabs defaultValue="overview" class="h-full flex flex-col">
        <TabsList class="grid w-full grid-cols-5">
          <TabsTrigger value="overview">
            <Info class="w-4 h-4 mr-2" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="metrics">
            <BarChart3 class="w-4 h-4 mr-2" />
            Metrics
          </TabsTrigger>
          <TabsTrigger value="logs">
            <Terminal class="w-4 h-4 mr-2" />
            Logs
          </TabsTrigger>
          <TabsTrigger value="health">
            <Heart class="w-4 h-4 mr-2" />
            Health
          </TabsTrigger>
          <TabsTrigger value="events">
            <Clock class="w-4 h-4 mr-2" />
            Events
          </TabsTrigger>
        </TabsList>

        <!-- Overview Tab -->
        <TabsContent value="overview" class="flex-1 overflow-auto space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Service Info -->
            <Card>
              <CardHeader>
                <CardTitle class="text-lg">Service Information</CardTitle>
              </CardHeader>
              <CardContent class="space-y-4">
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="font-medium text-gray-500">Container ID:</span>
                    <p class="font-mono text-xs mt-1">{service.container_id || 'Not deployed'}</p>
                  </div>
                  <div>
                    <span class="font-medium text-gray-500">Image ID:</span>
                    <p class="font-mono text-xs mt-1">{service.image_id || 'Not built'}</p>
                  </div>
                  <div>
                    <span class="font-medium text-gray-500">Deployed:</span>
                    <p class="text-xs mt-1">
                      {service.deployed_at ? formatDateTime(service.deployed_at) : 'Not deployed'}
                    </p>
                  </div>
                  <div>
                    <span class="font-medium text-gray-500">Uptime:</span>
                    <p class="text-xs mt-1">{formatUptime(service.deployed_at || '')}</p>
                  </div>
                </div>

                {#if service.detection_confidence}
                  <div>
                    <span class="font-medium text-gray-500">Detection Confidence:</span>
                    <div class="flex items-center gap-2 mt-1">
                      <Progress value={service.detection_confidence * 100} class="flex-1" />
                      <span class="text-xs font-medium">{Math.round(service.detection_confidence * 100)}%</span>
                    </div>
                  </div>
                {/if}
              </CardContent>
            </Card>

            <!-- Resource Limits -->
            <Card>
              <CardHeader>
                <CardTitle class="text-lg">Resource Configuration</CardTitle>
              </CardHeader>
              <CardContent class="space-y-4">
                {#if service.resource_limits}
                  <div class="grid grid-cols-2 gap-4 text-sm">
                    {#if service.resource_limits.memory_mb}
                      <div class="flex items-center gap-2">
                        <MemoryStick class="w-4 h-4 text-gray-500" />
                        <div>
                          <span class="font-medium">Memory Limit</span>
                          <p class="text-xs text-gray-500">{service.resource_limits.memory_mb} MB</p>
                        </div>
                      </div>
                    {/if}
                    {#if service.resource_limits.cpu_cores}
                      <div class="flex items-center gap-2">
                        <Cpu class="w-4 h-4 text-gray-500" />
                        <div>
                          <span class="font-medium">CPU Limit</span>
                          <p class="text-xs text-gray-500">{service.resource_limits.cpu_cores} cores</p>
                        </div>
                      </div>
                    {/if}
                  </div>
                {:else}
                  <p class="text-sm text-gray-500">No resource limits configured</p>
                {/if}
              </CardContent>
            </Card>

            <!-- Port Mappings -->
            <Card>
              <CardHeader>
                <CardTitle class="text-lg">Port Mappings</CardTitle>
              </CardHeader>
              <CardContent>
                {#if Object.keys(service.port_mappings || {}).length > 0}
                  <div class="space-y-2">
                    {#each Object.entries(service.port_mappings || {}) as [containerPort, config]}
                      <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                        <span class="font-mono text-sm">{config.host_port} → {containerPort}</span>
                        <Badge variant="outline">{config.protocol}</Badge>
                      </div>
                    {/each}
                  </div>
                {:else}
                  <p class="text-sm text-gray-500">No port mappings configured</p>
                {/if}
              </CardContent>
            </Card>

            <!-- Environment Variables -->
            <Card>
              <CardHeader>
                <CardTitle class="text-lg">Environment Variables</CardTitle>
              </CardHeader>
              <CardContent>
                {#if Object.keys(service.environment_variables || {}).length > 0}
                  <ScrollArea class="h-32">
                    <div class="space-y-1">
                      {#each Object.entries(service.environment_variables || {}) as [key, value]}
                        <div class="flex items-center justify-between p-2 bg-gray-50 rounded text-sm">
                          <span class="font-mono font-medium">{key}</span>
                          <span class="font-mono text-gray-600 truncate ml-2">{value}</span>
                        </div>
                      {/each}
                    </div>
                  </ScrollArea>
                {:else}
                  <p class="text-sm text-gray-500">No environment variables configured</p>
                {/if}
              </CardContent>
            </Card>
          </div>

          <!-- Actions -->
          <Card>
            <CardHeader>
              <CardTitle class="text-lg">Actions</CardTitle>
            </CardHeader>
            <CardContent>
              <div class="flex flex-wrap gap-2">
                {#if canStart}
                  <Button onclick={() => handleAction('start')} class="gap-2">
                    <Play class="w-4 h-4" />
                    Start
                  </Button>
                {/if}

                {#if canStop}
                  <Button variant="outline" onclick={() => handleAction('stop')} class="gap-2">
                    <Square class="w-4 h-4" />
                    Stop
                  </Button>
                {/if}

                {#if canRestart}
                  <Button variant="outline" onclick={() => handleAction('restart')} class="gap-2">
                    <RotateCcw class="w-4 h-4" />
                    Restart
                  </Button>
                {/if}

                <Button variant="outline" onclick={() => handleAction('scale', { replica_count: 2 })} class="gap-2">
                  <Activity class="w-4 h-4" />
                  Scale
                </Button>

                <Button variant="destructive" onclick={() => handleAction('delete')} class="gap-2">
                  <Trash2 class="w-4 h-4" />
                  Delete
                </Button>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <!-- Metrics Tab -->
        <TabsContent value="metrics" class="flex-1 overflow-auto">
          {#if loading.metrics}
            <div class="space-y-4">
              <Skeleton class="h-32 w-full" />
              <Skeleton class="h-32 w-full" />
            </div>
          {:else if metrics}
            <div class="space-y-6">
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center gap-2">
                      <Cpu class="w-5 h-5 text-blue-500" />
                      <div class="flex-1">
                        <p class="text-sm font-medium">CPU Usage</p>
                        <p class="text-2xl font-bold">{metrics.resource_utilization.cpu_percent.toFixed(1)}%</p>
                        <Progress value={metrics.resource_utilization.cpu_percent} class="mt-2" />
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center gap-2">
                      <MemoryStick class="w-5 h-5 text-green-500" />
                      <div class="flex-1">
                        <p class="text-sm font-medium">Memory Usage</p>
                        <p class="text-2xl font-bold">{metrics.resource_utilization.memory_percent.toFixed(1)}%</p>
                        <p class="text-xs text-gray-500">{formatBytes(metrics.resource_utilization.memory_usage_bytes)}</p>
                        <Progress value={metrics.resource_utilization.memory_percent} class="mt-2" />
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center gap-2">
                      <Network class="w-5 h-5 text-purple-500" />
                      <div class="flex-1">
                        <p class="text-sm font-medium">Network I/O</p>
                        <p class="text-xs text-gray-600">↓ {formatBytes(metrics.resource_utilization.network_rx_bytes)}</p>
                        <p class="text-xs text-gray-600">↑ {formatBytes(metrics.resource_utilization.network_tx_bytes)}</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center gap-2">
                      <HardDrive class="w-5 h-5 text-orange-500" />
                      <div class="flex-1">
                        <p class="text-sm font-medium">Disk I/O</p>
                        <p class="text-xs text-gray-600">R: {formatBytes(metrics.resource_utilization.disk_read_bytes)}</p>
                        <p class="text-xs text-gray-600">W: {formatBytes(metrics.resource_utilization.disk_write_bytes)}</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>

              <!-- Recent Metrics Table -->
              <Card>
                <CardHeader>
                  <CardTitle>Recent Metrics</CardTitle>
                  <CardDescription>Last 10 metric collections</CardDescription>
                </CardHeader>
                <CardContent>
                  <ScrollArea class="h-64">
                    <div class="space-y-2">
                      {#each metrics.recent_metrics as metric}
                        <div class="flex items-center justify-between p-2 border-b">
                          <span class="text-sm font-medium">{metric.metric_type}</span>
                          <div class="text-right">
                            <span class="text-sm font-mono">{metric.value} {metric.unit}</span>
                            <p class="text-xs text-gray-500">{formatDateTime(metric.collected_at)}</p>
                          </div>
                        </div>
                      {/each}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>
            </div>
          {:else}
            <div class="text-center py-8">
              <BarChart3 class="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p class="text-gray-500">No metrics available</p>
              <Button variant="outline" size="sm" on:click={loadMetrics} class="mt-2">
                <RefreshCw class="w-4 h-4 mr-2" />
                Reload
              </Button>
            </div>
          {/if}
        </TabsContent>

        <!-- Logs Tab -->
        <TabsContent value="logs" class="flex-1 overflow-hidden flex flex-col">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium">Container Logs</h3>
            <div class="flex items-center gap-2">
              <Button variant="outline" size="sm" onclick={loadLogs}>
                <RefreshCw class="w-4 h-4 mr-2" />
                Refresh
              </Button>
              <Button variant="outline" size="sm" onclick={downloadLogs} disabled={!logs}>
                <Download class="w-4 h-4 mr-2" />
                Download
              </Button>
            </div>
          </div>

          {#if loading.logs}
            <Skeleton class="flex-1" />
          {:else if logs}
            <ScrollArea class="flex-1 border rounded-lg p-4 bg-gray-900 text-green-400">
              <pre class="text-xs font-mono whitespace-pre-wrap">{logs.logs}</pre>
            </ScrollArea>
          {:else}
            <div class="flex-1 flex items-center justify-center border rounded-lg">
              <div class="text-center">
                <Terminal class="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p class="text-gray-500">No logs available</p>
              </div>
            </div>
          {/if}
        </TabsContent>

        <!-- Health Tab -->
        <TabsContent value="health" class="flex-1 overflow-auto">
          {#if loading.health}
            <div class="space-y-4">
              {#each Array(5) as _}
                <Skeleton class="h-16 w-full" />
              {/each}
            </div>
          {:else if health.length > 0}
            <div class="space-y-4">
              {#each health as check}
                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <div class="w-3 h-3 rounded-full {check.status === 'healthy' ? 'bg-green-500' : check.status === 'unhealthy' ? 'bg-red-500' : 'bg-yellow-500'}"></div>
                        <div>
                          <p class="font-medium {getHealthStatusColor(check.status)}">{check.status}</p>
                          <p class="text-sm text-gray-500">{check.check_type} check</p>
                          {#if check.endpoint}
                            <p class="text-xs font-mono text-gray-400">{check.endpoint}</p>
                          {/if}
                        </div>
                      </div>
                      <div class="text-right">
                        {#if check.response_time_ms}
                          <p class="text-sm font-medium">{check.response_time_ms}ms</p>
                        {/if}
                        {#if check.status_code}
                          <p class="text-xs text-gray-500">Status: {check.status_code}</p>
                        {/if}
                        <p class="text-xs text-gray-500">{formatDateTime(check.checked_at)}</p>
                      </div>
                    </div>
                    {#if check.error_message}
                      <div class="mt-3 p-2 bg-red-50 border border-red-200 rounded">
                        <p class="text-sm text-red-700">{check.error_message}</p>
                      </div>
                    {/if}
                  </CardContent>
                </Card>
              {/each}
            </div>
          {:else}
            <div class="text-center py-8">
              <Heart class="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p class="text-gray-500">No health checks available</p>
            </div>
          {/if}
        </TabsContent>

        <!-- Events Tab -->
        <TabsContent value="events" class="flex-1 overflow-auto">
          {#if loading.events}
            <div class="space-y-4">
              {#each Array(5) as _}
                <Skeleton class="h-16 w-full" />
              {/each}
            </div>
          {:else if events.length > 0}
            <div class="space-y-4">
              {#each events as event}
                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-start justify-between">
                      <div class="flex items-start gap-3">
                        <div class="w-2 h-2 rounded-full bg-blue-500 mt-2"></div>
                        <div>
                          <p class="font-medium">{event.event_type.replace(/_/g, ' ')}</p>
                          <p class="text-sm text-gray-500">{formatDateTime(event.occurred_at)}</p>
                          {#if event.duration_ms}
                            <p class="text-xs text-gray-400">Duration: {event.duration_ms}ms</p>
                          {/if}
                        </div>
                      </div>
                      <Badge variant="outline">{event.sequence_number}</Badge>
                    </div>
                    {#if event.error_message}
                      <div class="mt-3 p-2 bg-red-50 border border-red-200 rounded">
                        <p class="text-sm text-red-700">{event.error_message}</p>
                      </div>
                    {/if}
                  </CardContent>
                </Card>
              {/each}
            </div>
          {:else}
            <div class="text-center py-8">
              <Clock class="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p class="text-gray-500">No events available</p>
            </div>
          {/if}
        </TabsContent>
      </Tabs>
    </div>
  </DialogContent>
</Dialog>

<style>
  pre {
    font-family: 'Fira Code', 'Consolas', 'Monaco', 'Courier New', monospace;
  }
</style>
