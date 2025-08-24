<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { getDefaultApi } from './api.ts';
  import type {
    ContainerService,
    ServiceDashboardStats,
    ServiceFilter,
    ServiceStatus,
    ServiceUpdate
  } from '../types/containers.ts';

  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select';
  import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
  import { Progress } from '../ui/progress';
  import { Skeleton } from '../ui/skeleton';

  import {
    Play,
    Square,
    RotateCcw,
    Plus,
    Search,
    Filter,
    Activity,
    Server,
    Cpu,
    MemoryStick,
    HardDrive,
    Network,
    AlertCircle,
    CheckCircle,
    Clock,
    TrendingUp
  } from '@lucide/svelte';

  import ServiceCard from './ServiceCard.svelte';
  import ServiceDetail from './ServiceDetail.svelte';
  import DeploymentWizard from './DeploymentWizard.svelte';
  import MetricsChart from './MetricsChart.svelte';

  // Props using Svelte 5 syntax
  let {
    teamId,
    workspaceId = undefined,
    onserviceaction,
    onloadservices,
    onfilterchange,
    ondeployservice
  }: {
    teamId: string;
    workspaceId?: string;
    onserviceaction?: (action: string, serviceId: string, params?: any) => void;
    onloadservices?: () => void;
    onfilterchange?: (filter: any) => void;
    ondeployservice?: (serviceData: any) => void;
  } = $props();

  // State using Svelte 5 reactivity
  let services = $state<ContainerService[]>([]);
  let stats = $state<ServiceDashboardStats>({
    total_services: 0,
    running_services: 0,
    stopped_services: 0,
    error_services: 0,
    total_cpu_usage: 0,
    total_memory_usage: 0,
    recent_deployments: 0,
    avg_response_time: 0,
    uptime_percentage: 100
  });
  let loading = $state(true);
  let error = $state<string | null>(null);
  let selectedService = $state<ContainerService | null>(null);
  let showDeploymentWizard = $state(false);
  let realtimeConnected = $state(false);

  // Filter state
  let filter = $state<ServiceFilter>({
    status: undefined,
    service_type: undefined,
    workspace_id: workspaceId,
    search: '',
    sort_by: 'created_at',
    sort_order: 'desc'
  });

  // Derived reactive values using Svelte 5 syntax
  let filteredServices = $derived(() => {
    let filtered = [...services];

    // Apply status filter
    if (filter.status && filter.status.length > 0) {
      filtered = filtered.filter(service => filter.status!.includes(service.status));
    }

    // Apply service type filter
    if (filter.service_type && filter.service_type.length > 0) {
      filtered = filtered.filter(service => filter.service_type!.includes(service.service_type));
    }

    // Apply search filter
    if (filter.search && filter.search.trim()) {
      const searchTerm = filter.search.toLowerCase();
      filtered = filtered.filter(service =>
        service.name.toLowerCase().includes(searchTerm) ||
        service.service_type.toLowerCase().includes(searchTerm) ||
        service.folder_path.toLowerCase().includes(searchTerm)
      );
    }

    // Apply sorting
    if (filter.sort_by) {
      filtered.sort((a, b) => {
        const aVal = a[filter.sort_by!];
        const bVal = b[filter.sort_by!];

        if (aVal < bVal) return filter.sort_order === 'asc' ? -1 : 1;
        if (aVal > bVal) return filter.sort_order === 'asc' ? 1 : -1;
        return 0;
      });
    }

    return filtered;
  });

  let servicesByStatus = $derived(() => {
    return services.reduce((acc, service) => {
      if (!acc[service.status]) acc[service.status] = [];
      acc[service.status].push(service);
      return acc;
    }, {} as Record<ServiceStatus, ContainerService[]>);
  });

  // API instance
  const api = getDefaultApi();
  let websocket: WebSocket | null = null;
  let refreshInterval: number | null = null;

  // Lifecycle
  onMount(() => {
    loadServices();
    loadStats();
    setupRealtime();

    // Auto-refresh every 30 seconds
    refreshInterval = window.setInterval(() => {
      if (!loading) {
        loadServices();
        loadStats();
      }
    }, 30000);
  });

  onDestroy(() => {
    if (websocket) {
      websocket.close();
    }
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
  });

  // Methods
  async function loadServices() {
    // If hook callback is provided, use it instead of direct API calls
    if (onloadservices) {
      onloadservices();
      return;
    }

    // Fallback to direct API calls
    try {
      loading = true;
      error = null;

      const response = await api.listServices(teamId, {
        filter: workspaceId ? { workspace_id: workspaceId } : {},
        load: ['workspace', 'team']
      });

      services = response.data;
    } catch (err) {
      console.error('Failed to load services:', err);
      error = err instanceof Error ? err.message : 'Failed to load services';
    } finally {
      loading = false;
    }
  }

  async function loadStats() {
    try {
      // Calculate stats from services
      const newStats: ServiceDashboardStats = {
        total_services: services.length,
        running_services: services.filter(s => s.status === 'running').length,
        stopped_services: services.filter(s => s.status === 'stopped').length,
        error_services: services.filter(s => s.status === 'error').length,
        total_cpu_usage: 0,
        total_memory_usage: 0,
        recent_deployments: services.filter(s => {
          if (!s.deployed_at) return false;
          const deployedTime = new Date(s.deployed_at).getTime();
          const dayAgo = Date.now() - (24 * 60 * 60 * 1000);
          return deployedTime > dayAgo;
        }).length,
        avg_response_time: 0,
        uptime_percentage: services.length > 0 ?
          (services.filter(s => s.status === 'running').length / services.length) * 100 : 100
      };

      stats = newStats;
    } catch (err) {
      console.error('Failed to load stats:', err);
    }
  }

  function setupRealtime() {
    try {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${protocol}//${window.location.host}/api/v1/services/realtime?team_id=${teamId}`;

      websocket = new WebSocket(wsUrl);

      websocket.onopen = () => {
        console.log('Realtime connection established');
        realtimeConnected = true;
      };

      websocket.onmessage = (event) => {
        try {
          const update: ServiceUpdate = JSON.parse(event.data);
          handleRealtimeUpdate(update);
        } catch (err) {
          console.error('Failed to parse realtime update:', err);
        }
      };

      websocket.onclose = () => {
        console.log('Realtime connection closed');
        realtimeConnected = false;

        // Attempt to reconnect after 5 seconds
        setTimeout(setupRealtime, 5000);
      };

      websocket.onerror = (err) => {
        console.error('Realtime connection error:', err);
        realtimeConnected = false;
      };
    } catch (err) {
      console.error('Failed to setup realtime connection:', err);
    }
  }

  function handleRealtimeUpdate(update: ServiceUpdate) {
    const serviceIndex = services.findIndex(s => s.id === update.service_id);

    if (serviceIndex === -1) {
      // New service, reload services
      loadServices();
      return;
    }

    // Update existing service
    const updatedServices = [...services];
    updatedServices[serviceIndex] = {
      ...updatedServices[serviceIndex],
      ...update.changes
    };
    services = updatedServices;

    // Update stats
    loadStats();

    // Update selected service if it's the one being updated
    if (selectedService && selectedService.id === update.service_id) {
      selectedService = updatedServices[serviceIndex];
    }
  }

  async function handleServiceAction(serviceId: string, action: 'start' | 'stop' | 'restart' | 'delete', params?: any) {
    // If hook callback is provided, use it instead of direct API calls
    if (onserviceaction) {
      onserviceaction(action, serviceId, params);
      return;
    }

    // Fallback to direct API calls
    try {
      const service = services.find(s => s.id === serviceId);
      if (!service) return;

      switch (action) {
        case 'start':
          await api.startService(service.id, teamId);
          break;
        case 'stop':
          await api.stopService(service.id, teamId);
          break;
        case 'restart':
          await api.restartService(service.id, teamId);
          break;
        case 'delete':
          await api.deleteService(service.id, teamId);
          selectedService = null;
          break;
      }

      // Reload services after action
      await loadServices();
      await loadStats();
    } catch (err) {
      console.error(`Failed to ${action} service:`, err);
      error = err instanceof Error ? err.message : `Failed to ${action} service`;
    }
  }

  function selectService(service: ContainerService | null) {
    selectedService = service;
  }

  function openDeploymentWizard() {
    showDeploymentWizard = true;
  }

  function closeDeploymentWizard() {
    showDeploymentWizard = false;
  }

  function onServiceDeployed(serviceData?: any) {
    closeDeploymentWizard();
    
    // Notify hook if callback is provided
    if (ondeployservice && serviceData) {
      ondeployservice(serviceData);
    }
    
    loadServices();
    loadStats();
  }

  function updateFilter(updates: Partial<ServiceFilter>) {
    filter = { ...filter, ...updates };
    
    // Notify hook if callback is provided
    if (onfilterchange) {
      onfilterchange(filter);
    }
  }

  function clearFilters() {
    filter = {
      status: undefined,
      service_type: undefined,
      workspace_id: workspaceId,
      search: '',
      sort_by: 'created_at',
      sort_order: 'desc'
    };
  }

  function getStatusColor(status: ServiceStatus): string {
    switch (status) {
      case 'running': return 'bg-green-500';
      case 'stopped': return 'bg-gray-500';
      case 'error': return 'bg-red-500';
      case 'starting': return 'bg-yellow-500';
      case 'stopping': return 'bg-orange-500';
      default: return 'bg-gray-500';
    }
  }

  function getStatusIcon(status: ServiceStatus) {
    switch (status) {
      case 'running': return CheckCircle;
      case 'stopped': return Square;
      case 'error': return AlertCircle;
      case 'starting':
      case 'stopping': return Clock;
      default: return Server;
    }
  }
</script>

<div class="container-dashboard p-6 space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-3xl font-bold tracking-tight">Container Dashboard</h1>
      <p class="text-muted-foreground">
        Manage and monitor your containerized services
      </p>
    </div>
    <div class="flex items-center gap-2">
      <div class="flex items-center gap-2 text-sm">
        <div class="w-2 h-2 rounded-full {realtimeConnected ? 'bg-green-500' : 'bg-red-500'}"></div>
        <span>{realtimeConnected ? 'Connected' : 'Disconnected'}</span>
      </div>
      <Button onclick={openDeploymentWizard}>
        <Plus class="w-4 h-4 mr-2" />
        Deploy Service
      </Button>
    </div>
  </div>

  <!-- Stats Cards -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Total Services</CardTitle>
        <Server class="w-4 h-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.total_services}</div>
        <p class="text-xs text-muted-foreground">
          {stats.recent_deployments} deployed in last 24h
        </p>
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Running</CardTitle>
        <CheckCircle class="w-4 h-4 text-green-500" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold text-green-600">{stats.running_services}</div>
        <p class="text-xs text-muted-foreground">
          {stats.uptime_percentage.toFixed(1)}% uptime
        </p>
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">CPU Usage</CardTitle>
        <Cpu class="w-4 h-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.total_cpu_usage}%</div>
        <Progress value={stats.total_cpu_usage} class="mt-2" />
      </CardContent>
    </Card>

    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Memory Usage</CardTitle>
        <MemoryStick class="w-4 h-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.total_memory_usage}%</div>
        <Progress value={stats.total_memory_usage} class="mt-2" />
      </CardContent>
    </Card>
  </div>

  <!-- Filters -->
  <Card>
    <CardContent class="pt-6">
      <div class="flex flex-col sm:flex-row gap-4">
        <div class="flex-1">
          <div class="relative">
            <Search class="absolute left-2 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="Search services..."
              value={filter.search}
              oninput={(e) => updateFilter({ search: e.currentTarget.value })}
              class="pl-8"
            />
          </div>
        </div>
        <Select onValueChange={(value) => updateFilter({ sort_by: value })}>
          <SelectTrigger class="w-[180px]">
            <SelectValue placeholder="Sort by..." />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="name">Name</SelectItem>
            <SelectItem value="created_at">Created</SelectItem>
            <SelectItem value="deployed_at">Deployed</SelectItem>
            <SelectItem value="status">Status</SelectItem>
          </SelectContent>
        </Select>
        <Button
          variant="outline"
          onclick={loadServices}
          disabled={loading}
        >
          <Activity class="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>
    </CardContent>
  </Card>

  <!-- Services Grid -->
  {#if loading}
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {#each Array(6) as _}
        <Card>
          <CardHeader>
            <Skeleton class="h-4 w-3/4" />
            <Skeleton class="h-3 w-1/2" />
          </CardHeader>
          <CardContent>
            <Skeleton class="h-20 w-full" />
          </CardContent>
        </Card>
      {/each}
    </div>
  {:else if error}
    <Card>
      <CardContent class="pt-6">
        <div class="text-center py-8">
          <AlertCircle class="w-12 h-12 text-red-500 mx-auto mb-4" />
          <h3 class="text-lg font-semibold text-red-700 mb-2">Error Loading Services</h3>
          <p class="text-muted-foreground mb-4">{error}</p>
          <Button onclick={loadServices}>Try Again</Button>
        </div>
      </CardContent>
    </Card>
  {:else if filteredServices.length === 0}
    <Card>
      <CardContent class="pt-6">
        <div class="text-center py-12">
          <Server class="w-12 h-12 text-muted-foreground mx-auto mb-4" />
          <h3 class="text-lg font-semibold mb-2">No Services Found</h3>
          <p class="text-muted-foreground mb-4">
            {services.length === 0
              ? "Get started by deploying your first service"
              : "No services match your current filters"}
          </p>
          {#if services.length === 0}
            <Button onclick={openDeploymentWizard}>
              <Plus class="w-4 h-4 mr-2" />
              Deploy Your First Service
            </Button>
          {:else}
            <Button variant="outline" onclick={clearFilters}>
              Clear Filters
            </Button>
          {/if}
        </div>
      </CardContent>
    </Card>
  {:else}
    <!-- Services Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {#each filteredServices as service (service.id)}
        <ServiceCard
          {service}
          onselect={() => selectService(service)}
          onaction={(action, params) => handleServiceAction(service.id, action, params)}
        />
      {/each}
    </div>
  {/if}

  <!-- Service Detail Modal -->
  {#if selectedService}
    <ServiceDetail
      service={selectedService}
      {teamId}
      onclose={() => selectService(null)}
      onaction={(action, params) => handleServiceAction(selectedService.id, action, params)}
    />
  {/if}

  <!-- Deployment Wizard Modal -->
  {#if showDeploymentWizard}
    <DeploymentWizard
      {teamId}
      {workspaceId}
      onclose={closeDeploymentWizard}
      ondeployed={onServiceDeployed}
    />
  {/if}
</div>

<style>
  .container-dashboard {
    min-height: 100vh;
    background: hsl(var(--background));
  }

  :global(.container-dashboard .card) {
    transition: all 0.2s ease-in-out;
  }

  :global(.container-dashboard .card:hover) {
    box-shadow: 0 8px 25px -8px rgba(0, 0, 0, 0.1);
  }
</style>
