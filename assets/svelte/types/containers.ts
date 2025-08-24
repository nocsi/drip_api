export interface ContainerService {
  id: string;
  name: string;
  folder_path: string;
  service_type: string;
  detection_confidence?: number;
  status: ServiceStatus;
  container_id?: string;
  image_id?: string;
  deployment_config: DeploymentConfig;
  port_mappings: PortMapping;
  environment_variables: Record<string, string>;
  volume_mounts: VolumeMount;
  resource_limits?: ResourceLimits;
  scaling_config?: ScalingConfig;
  health_check_config?: HealthCheckConfig;
  labels: Record<string, string>;
  network_config: NetworkConfig;
  created_at: string;
  updated_at: string;
  deployed_at?: string;
  last_health_check_at?: string;
  stopped_at?: string;
  workspace_id: string;
  team_id: string;
  created_by_id?: string;
  topology_detection_id?: string;
  workspace?: {
    id: string;
    name: string;
    description?: string;
    status: string;
    storage_backend: string;
    storage_path?: string;
  };
  team?: {
    id: string;
    name: string;
    created_at: string;
    updated_at: string;
  };
  deployment_events?: DeploymentEvent[];
  health_checks?: HealthCheck[];
  service_metrics?: ServiceMetric[];
}

export type ServiceStatus = 
  | 'detecting'
  | 'pending'
  | 'building'
  | 'deploying'
  | 'running'
  | 'stopped'
  | 'error'
  | 'scaling'
  | 'restarting';

export interface DeploymentConfig {
  dockerfile_path?: string;
  build_context?: string;
  image_name?: string;
  build_args?: Record<string, string>;
  registry?: {
    url: string;
    username?: string;
    password?: string;
  };
  auto_deploy?: boolean;
  rollback_on_failure?: boolean;
}

export interface PortMapping {
  [containerPort: string]: {
    host_port: number;
    protocol: 'tcp' | 'udp';
    host_ip?: string;
  };
}

export interface VolumeMount {
  [containerPath: string]: {
    host_path: string;
    mode: 'ro' | 'rw';
    type?: 'bind' | 'volume' | 'tmpfs';
  };
}

export interface ResourceLimits {
  memory_mb?: number;
  cpu_cores?: number;
  cpu_shares?: number;
  disk_mb?: number;
  network_mbps?: number;
  swap_mb?: number;
  ulimits?: Record<string, number>;
}

export interface ScalingConfig {
  min_replicas: number;
  max_replicas: number;
  target_cpu_percent?: number;
  target_memory_percent?: number;
  scale_up_cooldown_seconds?: number;
  scale_down_cooldown_seconds?: number;
  auto_scaling_enabled: boolean;
}

export interface HealthCheckConfig {
  enabled: boolean;
  type: 'http' | 'tcp' | 'command';
  endpoint?: string;
  port?: number;
  command?: string[];
  interval_seconds: number;
  timeout_seconds: number;
  retries: number;
  start_period_seconds?: number;
  headers?: Record<string, string>;
  expected_status_codes?: number[];
}

export interface NetworkConfig {
  network_mode?: 'bridge' | 'host' | 'none' | 'container' | string;
  networks?: string[];
  dns_servers?: string[];
  dns_search?: string[];
  hostname?: string;
  domain_name?: string;
  extra_hosts?: Record<string, string>;
  publish_all_ports?: boolean;
}

export interface ServiceMetrics {
  service_id: string;
  resource_utilization: ResourceUtilization;
  recent_metrics: ServiceMetric[];
  updated_at: string;
}

export interface ResourceUtilization {
  cpu_percent: number;
  memory_percent: number;
  memory_usage_bytes: number;
  memory_limit_bytes?: number;
  network_rx_bytes: number;
  network_tx_bytes: number;
  network_rx_packets?: number;
  network_tx_packets?: number;
  disk_read_bytes: number;
  disk_write_bytes: number;
  disk_read_ops?: number;
  disk_write_ops?: number;
  uptime_seconds?: number;
  restart_count?: number;
}

export interface ServiceMetric {
  id: string;
  metric_type: MetricType;
  value: number;
  unit: string;
  metadata: Record<string, any>;
  collected_at: string;
  service_instance_id: string;
}

export type MetricType =
  | 'cpu_percent'
  | 'memory_percent'
  | 'memory_usage_bytes'
  | 'network_rx_bytes'
  | 'network_tx_bytes'
  | 'disk_read_bytes'
  | 'disk_write_bytes'
  | 'response_time_ms'
  | 'request_count'
  | 'error_count'
  | 'custom';

export interface HealthCheck {
  id: string;
  check_type: 'http' | 'tcp' | 'command';
  endpoint?: string;
  status: HealthStatus;
  response_time_ms?: number;
  status_code?: number;
  response_body?: string;
  error_message?: string;
  checked_at: string;
  service_instance_id: string;
}

export type HealthStatus = 'healthy' | 'unhealthy' | 'unknown' | 'starting';

export interface DeploymentEvent {
  id: string;
  event_type: DeploymentEventType;
  event_data: Record<string, any>;
  error_message?: string;
  error_details: Record<string, any>;
  duration_ms?: number;
  sequence_number: number;
  occurred_at: string;
  service_instance_id: string;
  team_id: string;
  triggered_by_id?: string;
}

export type DeploymentEventType =
  | 'deployment_started'
  | 'deployment_completed'
  | 'deployment_failed'
  | 'container_started'
  | 'container_stopped'
  | 'container_restarted'
  | 'scaling_started'
  | 'scaling_completed'
  | 'health_check_failed'
  | 'health_check_recovered'
  | 'image_built'
  | 'image_pulled'
  | 'volume_mounted'
  | 'network_connected';

export interface TopologyAnalysis {
  id: string;
  folder_path: string;
  detection_timestamp: string;
  detected_patterns: DetectedPatterns;
  service_graph: ServiceGraph;
  recommended_services: ServiceRecommendation[];
  confidence_scores: Record<string, number>;
  file_indicators: FileIndicator[];
  deployment_strategy?: DeploymentStrategy;
  total_services_detected: number;
  analysis_metadata: Record<string, any>;
  workspace_id: string;
  team_id: string;
  created_at: string;
  updated_at: string;
}

export interface DetectedPatterns {
  languages: string[];
  frameworks: string[];
  databases: string[];
  services: string[];
  deployment_files: string[];
  config_files: string[];
}

export interface ServiceGraph {
  nodes: ServiceNode[];
  edges: ServiceEdge[];
  clusters: ServiceCluster[];
}

export interface ServiceNode {
  id: string;
  name: string;
  type: string;
  port?: number;
  dependencies: string[];
  file_path: string;
  confidence: number;
}

export interface ServiceEdge {
  from: string;
  to: string;
  type: 'depends_on' | 'connects_to' | 'volumes_from';
  metadata?: Record<string, any>;
}

export interface ServiceCluster {
  id: string;
  name: string;
  nodes: string[];
  type: 'microservice' | 'database' | 'cache' | 'queue';
}

export interface ServiceRecommendation {
  service_name: string;
  service_type: string;
  confidence: number;
  port_mappings: PortMapping;
  environment_variables: Record<string, string>;
  volume_mounts: VolumeMount;
  resource_limits: ResourceLimits;
  health_check: HealthCheckConfig;
  dependencies: string[];
  dockerfile_content?: string;
  build_instructions?: string[];
}

export interface FileIndicator {
  file_path: string;
  file_type: string;
  indicators: string[];
  confidence: number;
  metadata: Record<string, any>;
}

export type DeploymentStrategy = 
  | 'single_container'
  | 'docker_compose'
  | 'kubernetes'
  | 'swarm'
  | 'custom';

export interface ContainerLogs {
  logs: string;
  timestamp: string;
  service_id: string;
  container_id?: string;
}

export interface ServiceAction {
  type: 'start' | 'stop' | 'restart' | 'scale' | 'delete' | 'deploy';
  service_id: string;
  params?: Record<string, any>;
  timestamp: string;
  user_id: string;
}

export interface ServiceDashboardStats {
  total_services: number;
  running_services: number;
  stopped_services: number;
  error_services: number;
  total_cpu_usage: number;
  total_memory_usage: number;
  recent_deployments: number;
  avg_response_time: number;
  uptime_percentage: number;
}

export interface ServiceFilter {
  status?: ServiceStatus[];
  service_type?: string[];
  workspace_id?: string;
  search?: string;
  sort_by?: 'name' | 'created_at' | 'deployed_at' | 'status';
  sort_order?: 'asc' | 'desc';
}

export interface CreateServiceRequest {
  name: string;
  folder_path: string;
  service_type?: string;
  workspace_id: string;
  deployment_config?: Partial<DeploymentConfig>;
  port_mappings?: PortMapping;
  environment_variables?: Record<string, string>;
  volume_mounts?: VolumeMount;
  resource_limits?: ResourceLimits;
  health_check_config?: HealthCheckConfig;
  labels?: Record<string, string>;
  auto_deploy?: boolean;
}

export interface UpdateServiceRequest {
  name?: string;
  deployment_config?: Partial<DeploymentConfig>;
  port_mappings?: PortMapping;
  environment_variables?: Record<string, string>;
  volume_mounts?: VolumeMount;
  resource_limits?: ResourceLimits;
  scaling_config?: ScalingConfig;
  health_check_config?: HealthCheckConfig;
  labels?: Record<string, string>;
}

export interface ServiceStatusInfo {
  id: string;
  name: string;
  status: ServiceStatus;
  container_id?: string;
  image_id?: string;
  deployed_at?: string;
  last_health_check_at?: string;
  uptime?: string;
  deployment_status?: string;
  ports?: Array<{
    container_port: number;
    host_port: number;
    protocol: string;
  }>;
  resource_usage?: {
    cpu_percent: number;
    memory_percent: number;
    memory_usage_mb: number;
  };
}

// Real-time updates
export interface ServiceUpdate {
  service_id: string;
  type: 'status_change' | 'metrics_update' | 'health_check' | 'deployment_event';
  data: any;
  timestamp: string;
}

export interface WebSocketMessage {
  event: string;
  payload: any;
  timestamp: string;
}

// UI State types
export interface ContainerDashboardState {
  services: ContainerService[];
  selectedService?: ContainerService;
  filter: ServiceFilter;
  stats: ServiceDashboardStats;
  loading: boolean;
  error?: string;
  realtime_connected: boolean;
}

export interface ServiceDetailState {
  service: ContainerService;
  metrics: ServiceMetrics;
  logs: ContainerLogs;
  health: HealthCheck[];
  events: DeploymentEvent[];
  loading: {
    service: boolean;
    metrics: boolean;
    logs: boolean;
    health: boolean;
    events: boolean;
  };
  error?: string;
  log_follow: boolean;
}

export interface DeploymentWizardState {
  step: 'analyze' | 'configure' | 'review' | 'deploy';
  workspace_id: string;
  folder_path: string;
  analysis?: TopologyAnalysis;
  selected_services: ServiceRecommendation[];
  custom_config: Record<string, Partial<CreateServiceRequest>>;
  deployment_progress: Record<string, {
    status: 'pending' | 'deploying' | 'completed' | 'error';
    message?: string;
  }>;
  loading: boolean;
  error?: string;
}