<script lang="ts">
  import type { ContainerService, ServiceStatus } from '../types/containers.ts';
  
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Progress } from '../ui/progress';
  import { 
    Play, 
    Square, 
    RotateCcw, 
    Trash2,
    ExternalLink,
    AlertCircle,
    CheckCircle,
    Clock,
    Activity,
    Cpu,
    MemoryStick,
    HardDrive,
    Network,
    Eye,
    Settings
  } from '@lucide/svelte';

  // Props using Svelte 5 syntax
  let { 
    service, 
    onselect, 
    onaction 
  }: { 
    service: ContainerService; 
    onselect?: () => void;
    onaction?: (action: string, params?: any) => void;
  } = $props();

  // Derived reactive values using Svelte 5 syntax
  let statusColor = $derived(getStatusColor(service.status));
  let statusIcon = $derived(getStatusIcon(service.status));
  let canStart = $derived(['stopped', 'error'].includes(service.status));
  let canStop = $derived(['running', 'deploying'].includes(service.status));
  let canRestart = $derived(service.status === 'running');
  
  let uptime = $derived(service.deployed_at ? getUptime(service.deployed_at) : null);
  let lastHealthCheck = $derived(service.last_health_check_at ? getTimeAgo(service.last_health_check_at) : null);

  // Methods
  function getStatusColor(status: ServiceStatus): string {
    switch (status) {
      case 'running': return 'bg-green-500';
      case 'stopped': return 'bg-gray-500';
      case 'error': return 'bg-red-500';
      case 'deploying': return 'bg-blue-500';
      case 'building': return 'bg-yellow-500';
      case 'scaling': return 'bg-purple-500';
      case 'restarting': return 'bg-orange-500';
      default: return 'bg-gray-400';
    }
  }

  function getStatusIcon(status: ServiceStatus) {
    switch (status) {
      case 'running': return CheckCircle;
      case 'stopped': return Square;
      case 'error': return AlertCircle;
      case 'deploying': return Activity;
      case 'building': return Activity;
      case 'scaling': return Activity;
      case 'restarting': return RotateCcw;
      default: return Clock;
    }
  }

  function getStatusText(status: ServiceStatus): string {
    switch (status) {
      case 'detecting': return 'Detecting';
      case 'pending': return 'Pending';
      case 'building': return 'Building';
      case 'deploying': return 'Deploying';
      case 'running': return 'Running';
      case 'stopped': return 'Stopped';
      case 'error': return 'Error';
      case 'scaling': return 'Scaling';
      case 'restarting': return 'Restarting';
      default: return status;
    }
  }

  function getUptime(deployedAt: string): string {
    const deployed = new Date(deployedAt);
    const now = new Date();
    const diffMs = now.getTime() - deployed.getTime();
    
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    
    if (days > 0) return `${days}d ${hours}h`;
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }

  function getTimeAgo(timestamp: string): string {
    const time = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - time.getTime();
    
    const minutes = Math.floor(diffMs / (1000 * 60));
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return 'Just now';
  }

  function getServiceTypeIcon(serviceType: string) {
    switch (serviceType.toLowerCase()) {
      case 'nodejs':
      case 'node':
        return '🟢';
      case 'python':
        return '🐍';
      case 'golang':
      case 'go':
        return '🔵';
      case 'rust':
        return '🦀';
      case 'java':
        return '☕';
      case 'ruby':
        return '💎';
      case 'php':
        return '🐘';
      case 'docker':
        return '🐳';
      default:
        return '📦';
    }
  }

  function handleAction(action: string, params?: any) {
    onaction?.(action, params);
  }

  function handleSelect() {
    onselect?.();
  }

  function getPortsText(): string {
    const ports = Object.entries(service.port_mappings || {});
    if (ports.length === 0) return 'No ports exposed';
    
    return ports
      .map(([containerPort, config]) => `${config.host_port}:${containerPort}`)
      .join(', ');
  }

  function getResourceUsageText(): string {
    // This would come from metrics in a real implementation
    // For now, show placeholder or empty
    return 'No metrics available';
  }
</script>

<Card class="service-card cursor-pointer transition-all duration-200 hover:shadow-lg">
  <CardHeader class="pb-3">
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-2 flex-1 min-w-0">
        <span class="text-lg">{getServiceTypeIcon(service.service_type)}</span>
        <div class="flex-1 min-w-0">
          <CardTitle class="text-lg font-semibold truncate">{service.name}</CardTitle>
          <CardDescription class="text-sm text-muted-foreground truncate">
            {service.folder_path}
          </CardDescription>
        </div>
      </div>
      
      <div class="flex flex-col items-end gap-1">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 rounded-full {statusColor}"></div>
          <Badge variant={service.status === 'running' ? 'default' : 
                       service.status === 'error' ? 'destructive' : 'secondary'}>
            <svelte:component this={statusIcon} class="w-3 h-3 mr-1" />
            {getStatusText(service.status)}
          </Badge>
        </div>
        
        {#if service.detection_confidence}
          <div class="text-xs text-muted-foreground">
            {Math.round(service.detection_confidence * 100)}% confidence
          </div>
        {/if}
      </div>
    </div>
  </CardHeader>

  <CardContent class="pt-0">
    <!-- Service Info -->
    <div class="space-y-3">
      <!-- Service Type and Workspace -->
      <div class="flex items-center justify-between text-sm">
        <span class="text-muted-foreground">Type:</span>
        <Badge variant="outline">{service.service_type}</Badge>
      </div>

      <!-- Ports -->
      <div class="flex items-center justify-between text-sm">
        <span class="text-muted-foreground">Ports:</span>
        <span class="text-xs font-mono truncate max-w-[150px]" title={getPortsText()}>
          {getPortsText()}
        </span>
      </div>

      <!-- Uptime/Status Info -->
      {#if service.status === 'running' && uptime}
        <div class="flex items-center justify-between text-sm">
          <span class="text-muted-foreground">Uptime:</span>
          <span class="text-xs font-medium text-green-600">{uptime}</span>
        </div>
      {/if}

      {#if lastHealthCheck}
        <div class="flex items-center justify-between text-sm">
          <span class="text-muted-foreground">Health:</span>
          <span class="text-xs text-muted-foreground">{lastHealthCheck}</span>
        </div>
      {/if}

      <!-- Resource Usage (placeholder) -->
      {#if service.status === 'running'}
        <div class="space-y-2">
          <div class="text-xs text-muted-foreground">Resource Usage</div>
          <div class="grid grid-cols-2 gap-2 text-xs">
            <div class="flex items-center gap-1">
              <Cpu class="w-3 h-3" />
              <span>--</span>
            </div>
            <div class="flex items-center gap-1">
              <MemoryStick class="w-3 h-3" />
              <span>--</span>
            </div>
          </div>
        </div>
      {/if}

      <!-- Created/Updated Info -->
      <div class="pt-2 border-t border-border">
        <div class="flex items-center justify-between text-xs text-muted-foreground">
          <span>Created: {new Date(service.created_at).toLocaleDateString()}</span>
          <span>Updated: {getTimeAgo(service.updated_at)}</span>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center gap-1 pt-2">
        <Button
          size="sm"
          variant="outline"
          onclick={handleSelect}
          class="flex-1"
        >
          <Eye class="w-3 h-3 mr-1" />
          View
        </Button>

        {#if canStart}
          <Button
            size="sm"
            variant="default"
            onclick={(e) => { e.stopPropagation(); handleAction('start'); }}
            class="px-2"
            title="Start service"
          >
            <Play class="w-3 h-3" />
          </Button>
        {/if}

        {#if canStop}
          <Button
            size="sm"
            variant="outline"
            onclick={(e) => { e.stopPropagation(); handleAction('stop'); }}
            class="px-2"
            title="Stop service"
          >
            <Square class="w-3 h-3" />
          </Button>
        {/if}

        {#if canRestart}
          <Button
            size="sm"
            variant="outline"
            onclick={(e) => { e.stopPropagation(); handleAction('restart'); }}
            class="px-2"
            title="Restart service"
          >
            <RotateCcw class="w-3 h-3" />
          </Button>
        {/if}

        <Button
          size="sm"
          variant="ghost"
          onclick={(e) => { e.stopPropagation(); handleAction('delete'); }}
          class="px-2 text-red-500 hover:text-red-700"
          title="Delete service"
        >
          <Trash2 class="w-3 h-3" />
        </Button>
      </div>
    </div>
  </CardContent>
</Card>

<style>
  .service-card {
    transition: all 0.2s ease-in-out;
  }

  .service-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px -2px rgba(0, 0, 0, 0.1);
  }
</style>