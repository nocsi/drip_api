<script lang="ts">
  import { onMount } from 'svelte';
  import { getDefaultApi } from './api.ts';
  import type { 
    TopologyAnalysis,
    ServiceRecommendation,
    CreateServiceRequest,
    DeploymentWizardState 
  } from '../types/containers.ts';
  
  import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '../ui/dialog';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Label } from '../ui/label';
  import { Textarea } from '../ui/textarea';
  import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select';
  import { Checkbox } from '../ui/checkbox';
  import { Progress } from '../ui/progress';
  import { Skeleton } from '../ui/skeleton';
  import { ScrollArea } from '../ui/scroll-area';
  
  import { 
    Search,
    FolderOpen,
    Settings,
    CheckCircle,
    Play,
    AlertCircle,
    ChevronLeft,
    ChevronRight,
    X,
    Upload,
    Cpu,
    MemoryStick,
    HardDrive,
    Network,
    Heart,
    Zap,
    Code,
    Database,
    Globe
  } from '@lucide/svelte';

  // Props using Svelte 5 syntax
  let { 
    teamId, 
    workspaceId = undefined,
    onclose,
    ondeployed
  }: { 
    teamId: string; 
    workspaceId?: string;
    onclose?: () => void;
    ondeployed?: (services: string[]) => void;
  } = $props();

  // State using Svelte 5
  let wizardState = $state<DeploymentWizardState>({
    step: 'analyze',
    workspace_id: workspaceId || '',
    folder_path: '/',
    analysis: undefined,
    selected_services: [],
    custom_config: {},
    deployment_progress: {},
    loading: false,
    error: undefined
  });

  const api = getDefaultApi();

  // Derived reactive values using Svelte 5 syntax
  let currentStep = $derived(wizardState.step);
  let canProceed = $derived(() => {
    switch (wizardState.step) {
      case 'analyze':
        return wizardState.analysis && wizardState.analysis.detected_services.length > 0;
      case 'configure':
        return wizardState.selected_services.length > 0;
      case 'review':
        return true;
      case 'deploy':
        return false;
      default:
        return false;
    }
  });

  let stepProgress = $derived(() => {
    switch (wizardState.step) {
      case 'analyze': return 25;
      case 'configure': return 50;
      case 'review': return 75;
      case 'deploy': return 100;
      default: return 0;
    }
  });

  // Lifecycle
  onMount(() => {
    if (workspaceId) {
      analyzeWorkspace();
    }
  });

  // Methods
  async function analyzeWorkspace() {
    wizardState.loading = true;
    wizardState.error = undefined;

    try {
      const response = await api.analyzeWorkspaceTopology(
        teamId, 
        state.workspace_id, 
        state.folder_path
      );
      
      wizardState.analysis = response.data;
      wizardState.selected_services = response.data.detected_services.map(service => service.id);
      wizardState.loading = false;
    } catch (error) {
      console.error('Failed to analyze workspace:', error);
      wizardState.error = 'Failed to analyze workspace';
      wizardState.loading = false;
    }
  }

  async function deployServices() {
    wizardState.step = 'deploy';
    wizardState.loading = true;
    wizardState.deployment_progress = {};

    const deployedServices = [];

    try {
      for (const service of state.selected_services) {
        const serviceId = service.service_name;
        
        // Update progress
        wizardState.update(s => ({
          ...s,
          deployment_progress: {
            ...s.deployment_progress,
            [serviceId]: { status: 'deploying', message: 'Deploying service...' }
          }
        }));

        // Merge custom config with recommendation
        const customConfig = state.custom_config[serviceId] || {};
        const deploymentRequest: CreateServiceRequest = {
          name: customConfig.name || service.service_name,
          folder_path: customConfig.folder_path || service.service_name,
          service_type: service.service_type,
          workspace_id: state.workspace_id,
          deployment_config: {
            dockerfile_content: service.dockerfile_content,
            auto_deploy: true,
            ...customConfig.deployment_config
          },
          port_mappings: { ...service.port_mappings, ...customConfig.port_mappings },
          environment_variables: { ...service.environment_variables, ...customConfig.environment_variables },
          volume_mounts: { ...service.volume_mounts, ...customConfig.volume_mounts },
          resource_limits: { ...service.resource_limits, ...customConfig.resource_limits },
          health_check_config: { ...service.health_check, ...customConfig.health_check_config },
          labels: customConfig.labels || {},
          auto_deploy: true
        };

        try {
          const response = await api.createService(teamId, deploymentRequest);
          
          deployedServices.push(response.data.id);
          
          wizardState.update(s => ({
            ...s,
            deployment_progress: {
              ...s.deployment_progress,
              [serviceId]: { 
                status: 'completed', 
                message: 'Service deployed successfully'
              }
            }
          }));
        } catch (error) {
          console.error(`Failed to deploy service ${serviceId}:`, error);
          
          wizardState.update(s => ({
            ...s,
            deployment_progress: {
              ...s.deployment_progress,
              [serviceId]: { 
                status: 'error', 
                message: error instanceof Error ? error.message : 'Deployment failed'
              }
            }
          }));
        }
      }

      // Wait a bit to show completion
      setTimeout(() => {
        wizardState.loading = false;
        ondeployed?.(deployedServices);
      }, 2000);

    } catch (error) {
      console.error('Deployment failed:', error);
      wizardState.update(s => ({
        ...s,
        error: error instanceof Error ? error.message : 'Deployment failed',
        loading: false
      }));
    }
  }

  function nextStep() {
    switch (wizardState.step) {
      case 'analyze':
        wizardState.step = 'configure';
        break;
      case 'configure':
        wizardState.step = 'review';
        break;
      case 'review':
        deployServices();
        break;
    }
  }

  function previousStep() {
    switch (wizardState.step) {
      case 'configure':
        wizardState.step = 'analyze';
        break;
      case 'review':
        wizardState.step = 'configure';
        break;
    }
  }

  function toggleService(service: ServiceRecommendation) {
    wizardState.update(state => {
      const isSelected = state.selected_services.some(s => s.service_name === service.service_name);
      
      if (isSelected) {
        return {
          ...state,
          selected_services: state.selected_services.filter(s => s.service_name !== service.service_name)
        };
      } else {
        return {
          ...state,
          selected_services: [...state.selected_services, service]
        };
      }
    });
  }

  function updateServiceConfig(serviceId: string, config: any) {
    wizardState.custom_config = {
      ...wizardState.custom_config,
      [serviceId]: {
        ...wizardState.custom_config[serviceId],
        ...config
      }
    };
  }

  function handleClose() {
    onclose?.();
  }

  function getServiceTypeIcon(serviceType: string) {
    switch (serviceType.toLowerCase()) {
      case 'nodejs':
      case 'javascript':
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
      case 'database':
        return '🗃️';
      case 'static':
        return '📄';
      default:
        return '📦';
    }
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
</script>

<Dialog open={true} onOpenChange={handleClose}>
  <DialogContent class="max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
    <DialogHeader>
      <div class="flex items-center justify-between">
        <div>
          <DialogTitle class="text-xl">Deploy Services</DialogTitle>
          <DialogDescription>
            Analyze your workspace and deploy containerized services
          </DialogDescription>
        </div>
        <Button variant="ghost" size="sm" onclick={handleClose}>
          <X class="w-4 h-4" />
        </Button>
      </div>
    </DialogHeader>

    <!-- Progress Bar -->
    <div class="px-6">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-medium">Step {wizardState.step === 'analyze' ? 1 : wizardState.step === 'configure' ? 2 : wizardState.step === 'review' ? 3 : 4} of 4</span>
        <span class="text-sm text-gray-500">{stepProgress}%</span>
      </div>
      <Progress value={stepProgress} class="w-full" />
    </div>

    <div class="flex-1 overflow-hidden px-6">
      <!-- Analyze Step -->
      {#if wizardState.step === 'analyze'}
        <div class="h-full flex flex-col">
          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-4">Analyze Workspace</h2>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <Label for="workspace">Workspace</Label>
                <Select disabled={!!workspaceId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select workspace..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={workspaceId || ''}>Current Workspace</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              
              <div>
                <Label for="folder_path">Folder Path</Label>
                <Input
                  id="folder_path"
                  bind:value={wizardState.folder_path}
                  placeholder="/"
                  oninput={analyzeWorkspace}
                />
              </div>
            </div>

            <Button onclick={analyzeWorkspace} disabled={wizardState.loading} class="mb-4">
              <Search class="w-4 h-4 mr-2" />
              {wizardState.loading ? 'Analyzing...' : 'Analyze Workspace'}
            </Button>
          </div>

          {#if wizardState.loading}
            <div class="space-y-4">
              <Skeleton class="h-32 w-full" />
              <Skeleton class="h-24 w-full" />
              <Skeleton class="h-24 w-full" />
            </div>
          {:else if wizardState.error}
            <div class="text-center py-8">
              <AlertCircle class="w-12 h-12 text-red-500 mx-auto mb-4" />
              <h3 class="text-lg font-semibold text-red-700 mb-2">Analysis Failed</h3>
              <p class="text-red-600 mb-4">{wizardState.error}</p>
              <Button onclick={analyzeWorkspace}>Try Again</Button>
            </div>
          {:else if wizardState.analysis}
            <ScrollArea class="flex-1">
              <div class="space-y-6">
                <!-- Detection Summary -->
                <Card>
                  <CardHeader>
                    <CardTitle>Detection Summary</CardTitle>
                    <CardDescription>
                      Found {wizardState.analysis.detected_services.length} services in {wizardState.analysis.folder_path}
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div>
                        <p class="text-sm text-gray-500">Languages</p>
                        <div class="flex flex-wrap gap-1 mt-1">
                          {#each wizardState.analysis.detected_patterns.languages || [] as language}
                            <Badge variant="outline" class="text-xs">{language}</Badge>
                          {/each}
                        </div>
                      </div>
                      <div>
                        <p class="text-sm text-gray-500">Frameworks</p>
                        <div class="flex flex-wrap gap-1 mt-1">
                          {#each wizardState.analysis.detected_patterns.frameworks || [] as framework}
                            <Badge variant="outline" class="text-xs">{framework}</Badge>
                          {/each}
                        </div>
                      </div>
                      <div>
                        <p class="text-sm text-gray-500">Databases</p>
                        <div class="flex flex-wrap gap-1 mt-1">
                          {#each wizardState.analysis.detected_patterns.databases || [] as db}
                            <Badge variant="outline" class="text-xs">{db}</Badge>
                          {/each}
                        </div>
                      </div>
                      <div>
                        <p class="text-sm text-gray-500">Strategy</p>
                        <Badge>{wizardState.analysis.deployment_strategy || 'single_container'}</Badge>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <!-- Recommended Services -->
                <Card>
                  <CardHeader>
                    <CardTitle>Recommended Services</CardTitle>
                    <CardDescription>
                      Services we detected and recommend for deployment
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div class="space-y-3">
                      {#each wizardState.analysis.detected_services as service}
                        <div class="border rounded-lg p-4">
                          <div class="flex items-center justify-between mb-2">
                            <div class="flex items-center gap-3">
                              <span class="text-lg">{getServiceTypeIcon(service.service_type)}</span>
                              <div>
                                <h4 class="font-medium">{service.service_name}</h4>
                                <p class="text-sm text-gray-500">{service.service_type}</p>
                              </div>
                            </div>
                            <div class="text-right">
                              <div class="flex items-center gap-2">
                                <div class="w-2 h-2 rounded-full bg-green-500"></div>
                                <span class="text-sm font-medium">{Math.round(service.confidence * 100)}%</span>
                              </div>
                            </div>
                          </div>
                          
                          <div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs text-gray-600">
                            <div>
                              <span class="font-medium">Ports:</span>
                              {Object.keys(service.port_mappings || {}).join(', ') || 'None'}
                            </div>
                            <div>
                              <span class="font-medium">Memory:</span>
                              {service.resource_limits?.memory_mb ? `${service.resource_limits.memory_mb}MB` : 'Default'}
                            </div>
                            <div>
                              <span class="font-medium">CPU:</span>
                              {service.resource_limits?.cpu_cores ? `${service.resource_limits.cpu_cores} cores` : 'Default'}
                            </div>
                            <div>
                              <span class="font-medium">Health Check:</span>
                              {service.health_check?.enabled ? 'Enabled' : 'Disabled'}
                            </div>
                          </div>
                        </div>
                      {/each}
                    </div>
                  </CardContent>
                </Card>
              </div>
            </ScrollArea>
          {:else}
            <div class="text-center py-8">
              <FolderOpen class="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <h3 class="text-lg font-semibold mb-2">Ready to Analyze</h3>
              <p class="text-gray-600">Click "Analyze Folder" to detect services in your workspace</p>
            </div>
          {/if}
        </div>

      <!-- Configure Step -->
      {:else if wizardState.step === 'configure'}
        <div class="h-full flex flex-col">
          <div class="mb-4">
            <h2 class="text-lg font-semibold">Configure Services</h2>
            <p class="text-gray-600">Select and configure the services you want to deploy</p>
          </div>

          <ScrollArea class="flex-1">
            <div class="space-y-4">
              {#each wizardState.analysis?.detected_services || [] as service}
                {@const isSelected = wizardState.selected_services.includes(service.id)}
                {@const customConfig = wizardState.custom_config[service.id] || {}}
                
                <Card class="border-2 {isSelected ? 'border-blue-500' : 'border-gray-200'}">
                  <CardHeader>
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <Checkbox
                          checked={isSelected}
                          onCheckedChange={() => toggleService(service)}
                        />
                        <span class="text-lg">{getServiceTypeIcon(service.service_type)}</span>
                        <div>
                          <CardTitle class="text-base">{service.service_name}</CardTitle>
                          <CardDescription>{service.service_type} • {Math.round(service.confidence * 100)}% confidence</CardDescription>
                        </div>
                      </div>
                      <Badge variant={isSelected ? 'default' : 'secondary'}>
                        {isSelected ? 'Selected' : 'Available'}
                      </Badge>
                    </div>
                  </CardHeader>
                  
                  {#if isSelected}
                    <CardContent class="pt-0">
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <Label for="name-{service.service_name}">Service Name</Label>
                          <Input
                            id="name-{service.service_name}"
                            value={customConfig.name || service.service_name}
                            oninput={(e) => updateServiceConfig(service.id, { name: e.currentTarget.value })}
                          />
                        </div>
                        
                        <div>
                          <Label for="folder-{service.service_name}">Folder Path</Label>
                          <Input
                            id="folder-{service.service_name}"
                            value={customConfig.folder_path || service.service_name}
                            oninput={(e) => updateServiceConfig(service.id, { folder_path: e.currentTarget.value })}
                          />
                        </div>

                        {#if service.resource_limits}
                          <div>
                            <Label for="memory-{service.service_name}">Memory Limit (MB)</Label>
                            <Input
                              id="memory-{service.service_name}"
                              type="number"
                              value={customConfig.resource_limits?.memory_mb || service.resource_limits.memory_mb || 512}
                              oninput={(e) => updateServiceConfig(service.id, {
                                resource_limits: {
                                  ...customConfig.resource_limits,
                                  memory_mb: parseInt(e.target.value)
                                }
                              })}
                            />
                          </div>

                          <div>
                            <Label for="cpu-{service.service_name}">CPU Cores</Label>
                            <Input
                              id="cpu-{service.service_name}"
                              type="number"
                              step="0.1"
                              value={customConfig.resource_limits?.cpu_cores || service.resource_limits.cpu_cores || 1}
                              oninput={(e) => updateServiceConfig(service.id, {
                                resource_limits: {
                                  ...customConfig.resource_limits,
                                  cpu_cores: parseFloat(e.target.value)
                                }
                              })}
                            />
                          </div>
                        {/if}

                        {#if Object.keys(service.environment_variables || {}).length > 0}
                          <div class="md:col-span-2">
                            <Label>Environment Variables</Label>
                            <Textarea
                              class="mt-1"
                              rows="3"
                              placeholder="KEY=value&#10;ANOTHER_KEY=another_value"
                              value={Object.entries(service.environment_variables || {})
                                .map(([k, v]) => `${k}=${v}`)
                                .join('\n')}
                              oninput={(e) => {
                                const env = {};
                                e.target.value.split('\n').forEach(line => {
                                  const [key, ...valueParts] = line.split('=');
                                  if (key && valueParts.length > 0) {
                                    env[key.trim()] = valueParts.join('=').trim();
                                  }
                                });
                                updateServiceConfig(service.service_name, { environment_variables: env });
                              }}
                            />
                          </div>
                        {/if}
                      </div>
                    </CardContent>
                  {/if}
                </Card>
              {/each}
            </div>
          </ScrollArea>
        </div>

      <!-- Review Step -->
      {:else if wizardState.step === 'review'}
        <div class="h-full flex flex-col">
          <div class="mb-4">
            <h2 class="text-lg font-semibold">Review Deployment</h2>
            <p class="text-gray-600">Review your configuration before deploying {wizardState.selected_services.length} service{wizardState.selected_services.length !== 1 ? 's' : ''}</p>
          </div>

          <ScrollArea class="flex-1">
            <div class="space-y-4">
              {#each wizardState.selected_services as serviceId}
                {@const service = wizardState.analysis?.detected_services.find(s => s.id === serviceId)}
                {@const customConfig = wizardState.custom_config[serviceId] || {}}
                
                <Card>
                  <CardHeader>
                    <div class="flex items-center gap-3">
                      <span class="text-lg">{getServiceTypeIcon(service.service_type)}</span>
                      <div>
                        <CardTitle class="text-base">{customConfig.name || service.service_name}</CardTitle>
                        <CardDescription>{service.service_type}</CardDescription>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                      <div>
                        <span class="font-medium text-gray-500">Folder:</span>
                        <p class="font-mono">{customConfig.folder_path || service.service_name}</p>
                      </div>
                      <div>
                        <span class="font-medium text-gray-500">Memory:</span>
                        <p>{customConfig.resource_limits?.memory_mb || service.resource_limits?.memory_mb || 512} MB</p>
                      </div>
                      <div>
                        <span class="font-medium text-gray-500">CPU:</span>
                        <p>{customConfig.resource_limits?.cpu_cores || service.resource_limits?.cpu_cores || 1} cores</p>
                      </div>
                      <div>
                        <span class="font-medium text-gray-500">Ports:</span>
                        <p>{Object.keys(service.port_mappings || {}).join(', ') || 'None'}</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              {/each}
            </div>
          </ScrollArea>
        </div>

      <!-- Deploy Step -->
      {:else if wizardState.step === 'deploy'}
        <div class="h-full flex flex-col">
          <div class="mb-6">
            <h2 class="text-lg font-semibold">Deploying Services</h2>
            <p class="text-gray-600">Deploying {wizardState.selected_services.length} service{wizardState.selected_services.length !== 1 ? 's' : ''}...</p>
          </div>

          <ScrollArea class="flex-1">
            <div class="space-y-4">
              {#each wizardState.selected_services as serviceId}
                {@const service = wizardState.analysis?.detected_services.find(s => s.id === serviceId)}
                {@const progress = wizardState.deployment_progress[serviceId]}
                
                <Card>
                  <CardContent class="p-4">
                    <div class="flex items-center justify-between mb-3">
                      <div class="flex items-center gap-3">
                        <span class="text-lg">{getServiceTypeIcon(service.service_type)}</span>
                        <div>
                          <p class="font-medium">{service.service_name}</p>
                          <p class="text-sm text-gray-500">{service.service_type}</p>
                        </div>
                      </div>
                      
                      <div class="flex items-center gap-2">
                        {#if progress?.status === 'deploying'}
                          <div class="animate-spin w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full"></div>
                          <span class="text-sm text-blue-600">Deploying...</span>
                        {:else if progress?.status === 'completed'}
                          <CheckCircle class="w-4 h-4 text-green-600" />
                          <span class="text-sm text-green-600">Complete</span>
                        {:else if progress?.status === 'error'}
                          <AlertCircle class="w-4 h-4 text-red-600" />
                          <span class="text-sm text-red-600">Failed</span>
                        {:else}
                          <div class="w-4 h-4 border-2 border-gray-300 rounded-full"></div>
                          <span class="text-sm text-gray-500">Pending</span>
                        {/if}
                      </div>
                    </div>
                    
                    {#if progress?.message}
                      <p class="text-sm text-gray-600">{progress.message}</p>
                    {/if}
                  </CardContent>
                </Card>
              {/each}
            </div>
          </ScrollArea>
        </div>
      {/if}
    </div>

    <!-- Footer -->
    <div class="flex items-center justify-between px-6 py-4 border-t">
      <Button 
        variant="outline" 
        onclick={previousStep}
        disabled={wizardState.step === 'analyze' || wizardState.step === 'deploy'}
      >
        <ChevronLeft class="w-4 h-4 mr-2" />
        Previous
      </Button>

      <div class="flex items-center gap-2">
        {#if wizardState.step === 'deploy'}
          <Button variant="outline" onclick={handleClose} disabled={wizardState.loading}>
            {wizardState.loading ? 'Deploying...' : 'Close'}
          </Button>
        {:else}
          <Button onclick={nextStep} disabled={!canProceed}>
            {#if wizardState.step === 'review'}
              <Play class="w-4 h-4 mr-2" />
              Deploy Services
            {:else}
              Next
              <ChevronRight class="w-4 h-4 ml-2" />
            {/if}
          </Button>
        {/if}
      </div>
    </div>
  </DialogContent>
</Dialog>