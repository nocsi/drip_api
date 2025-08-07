// API Configuration
export interface ApiConfig {
  baseUrl: string;
  apiToken: string;
  csrfToken: string;
  teamId?: string;
}

// HTTP Method types
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

// Request/Response types
export interface ApiRequestOptions extends RequestInit {
  params?: Record<string, any>;
  timeout?: number;
}

export interface ApiError {
  status: number;
  code?: string;
  message: string;
  details?: any;
  timestamp: string;
}

export class NetworkError extends Error {
  constructor(message: string = 'Network request failed') {
    super(message);
    this.name = 'NetworkError';
  }
}

export class ValidationError extends Error {
  constructor(
    message: string,
    public errors: Record<string, string[]>
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class AuthenticationError extends Error {
  constructor(message: string = 'Authentication failed') {
    super(message);
    this.name = 'AuthenticationError';
  }
}

export class AuthorizationError extends Error {
  constructor(message: string = 'Access denied') {
    super(message);
    this.name = 'AuthorizationError';
  }
}

// Team API types
export interface CreateTeamRequest {
  name: string;
  description?: string;
  domain?: string;
}

export interface UpdateTeamRequest {
  name?: string;
  description?: string;
  domain?: string;
}

export interface InviteTeamMemberRequest {
  email: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  message?: string;
}

export interface UpdateMemberRoleRequest {
  role: 'owner' | 'admin' | 'member' | 'viewer';
}

// Workspace API types
export interface CreateWorkspaceRequest {
  name: string;
  description?: string;
  storage_backend?: 'local' | 'git' | 's3' | 'github';
  storage_path?: string;
  git_repository_url?: string;
  git_branch?: string;
}

export interface UpdateWorkspaceRequest {
  name?: string;
  description?: string;
  storage_path?: string;
  git_repository_url?: string;
  git_branch?: string;
}

export interface DuplicateWorkspaceRequest {
  name: string;
  description?: string;
  include_documents?: boolean;
  include_notebooks?: boolean;
}

export interface ChangeStorageBackendRequest {
  backend: 'local' | 'git' | 's3' | 'github';
  configuration: Record<string, any>;
}

// Document API types
export interface CreateDocumentRequest {
  title: string;
  description?: string;
  content?: string;
  content_type?: 'markdown' | 'html' | 'text';
  is_public?: boolean;
  tags?: string[];
  workspace_id: string;
}

export interface UpdateDocumentRequest {
  title?: string;
  description?: string;
  content?: string;
  is_public?: boolean;
  tags?: string[];
}

export interface UpdateDocumentContentRequest {
  content: string;
  commit_message?: string;
}

export interface DuplicateDocumentRequest {
  title: string;
  description?: string;
  workspace_id?: string;
}

export interface RenderDocumentRequest {
  format: 'html' | 'pdf' | 'docx' | 'txt';
  options?: Record<string, any>;
}

export interface RenameDocumentRequest {
  new_title: string;
  commit_message?: string;
}

// Notebook API types
export interface CreateNotebookRequest {
  title: string;
  description?: string;
  content?: string;
  language?: string;
  execution_timeout_seconds?: number;
  collaborative_mode?: boolean;
  auto_save_enabled?: boolean;
  workspace_id: string;
  document_id?: string;
}

export interface UpdateNotebookRequest {
  title?: string;
  description?: string;
  content?: string;
  language?: string;
  execution_timeout_seconds?: number;
  collaborative_mode?: boolean;
  auto_save_enabled?: boolean;
}

export interface ExecuteNotebookRequest {
  environment?: Record<string, string>;
  timeout_seconds?: number;
  save_output?: boolean;
}

export interface ExecuteTaskRequest {
  environment?: Record<string, string>;
  timeout_seconds?: number;
  save_output?: boolean;
}

export interface DuplicateNotebookRequest {
  title: string;
  description?: string;
  workspace_id?: string;
}

// Project API types (from Projects domain)
export interface LoadDirectoryProjectRequest {
  path: string;
  skip_gitignore?: boolean;
  ignore_file_patterns?: string[];
  repository_discovery?: boolean;
  identity?: 'auto' | 'document' | 'cell';
}

export interface LoadFileProjectRequest {
  path: string;
  identity?: 'auto' | 'document' | 'cell';
}

export interface LoadProjectResponse {
  project: {
    id: string;
    path: string;
    type: 'directory' | 'file';
    name: string;
    status: 'loading' | 'loaded' | 'error';
  };
  events: LoadEventResponse[];
}

export interface LoadEventResponse {
  event_type: string;
  path?: string;
  error_message?: string;
  task_name?: string;
  task_runme_id?: string;
  sequence_number: number;
  event_data?: any;
}

// Search API types
export interface SearchRequest {
  query: string;
  types?: string[];
  filters?: {
    team_ids?: string[];
    workspace_ids?: string[];
    date_range?: {
      start: string;
      end: string;
    };
    tags?: string[];
    status?: string[];
    language?: string[];
  };
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
  page?: number;
  per_page?: number;
}

// Upload types
export interface UploadDocumentRequest {
  files: File[];
  workspace_id: string;
  extract_tasks?: boolean;
  overwrite_existing?: boolean;
}

export interface UploadResponse {
  uploaded_files: {
    filename: string;
    document_id: string;
    size_bytes: number;
    tasks_extracted?: number;
  }[];
  failed_files: {
    filename: string;
    error: string;
  }[];
}

// Dashboard API types
export interface DashboardStatsRequest {
  period?: 'day' | 'week' | 'month' | 'year';
  team_id?: string;
}

export interface DashboardStatsResponse {
  period: string;
  stats: {
    total_workspaces: number;
    active_workspaces: number;
    total_documents: number;
    total_notebooks: number;
    total_tasks: number;
    completed_tasks: number;
    total_executions: number;
    successful_executions: number;
    avg_execution_time_ms: number;
    storage_used_bytes: number;
  };
  trends: {
    workspaces_created: number[];
    documents_created: number[];
    notebooks_executed: number[];
    tasks_completed: number[];
  };
  top_languages: {
    language: string;
    count: number;
    execution_time_ms: number;
  }[];
}

export interface ActivityResponse {
  activities: {
    id: string;
    type: 'create' | 'update' | 'delete' | 'execute' | 'share';
    resource_type: 'workspace' | 'document' | 'notebook' | 'task';
    resource_id: string;
    resource_title: string;
    user_id: string;
    user_name: string;
    user_avatar?: string;
    team_id: string;
    workspace_id?: string;
    description: string;
    metadata?: Record<string, any>;
    created_at: string;
  }[];
}

// User profile types
export interface UpdateProfileRequest {
  name?: string;
  email?: string;
  avatar?: string;
  settings?: {
    theme?: 'light' | 'dark' | 'system';
    language?: string;
    timezone?: string;
    notifications_enabled?: boolean;
    email_notifications?: boolean;
  };
}

export interface ChangePasswordRequest {
  current_password: string;
  new_password: string;
  new_password_confirmation: string;
}

// Notification types
export interface NotificationResponse {
  notifications: {
    id: string;
    type: 'info' | 'success' | 'warning' | 'error';
    title: string;
    message: string;
    data?: any;
    read: boolean;
    read_at?: string;
    created_at: string;
    expires_at?: string;
  }[];
  unread_count: number;
}

export interface MarkNotificationReadRequest {
  notification_ids?: string[];
  mark_all_read?: boolean;
}

// Real-time types
export interface WebSocketConfig {
  endpoint: string;
  token: string;
  team_id?: string;
  auto_reconnect?: boolean;
  heartbeat_interval?: number;
}

export interface ChannelConfig {
  topic: string;
  payload?: Record<string, any>;
}

export interface RealtimeMessage {
  event: string;
  topic: string;
  payload: any;
  ref?: string;
  join_ref?: string;
}

// Pagination helpers
export interface PaginationMeta {
  current_page: number;
  per_page: number;
  total_entries: number;
  total_pages: number;
  has_previous: boolean;
  has_next: boolean;
}

export interface PaginatedApiResponse<T> {
  data: T[];
  meta: PaginationMeta;
  links?: {
    first?: string;
    prev?: string;
    next?: string;
    last?: string;
  };
}

// Filter and sort types
export interface FilterOption {
  field: string;
  operator: 'eq' | 'ne' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'nin' | 'contains' | 'starts_with' | 'ends_with';
  value: any;
}

export interface SortOption {
  field: string;
  direction: 'asc' | 'desc';
}

export interface QueryOptions {
  filters?: FilterOption[];
  sort?: SortOption[];
  search?: string;
  page?: number;
  per_page?: number;
  include?: string[];
}

// Response status types
export type ApiStatus = 'idle' | 'loading' | 'success' | 'error';

export interface ApiState<T = any> {
  data?: T;
  status: ApiStatus;
  error?: ApiError;
  lastFetch?: Date;
}

// Batch operation types
export interface BatchOperation {
  method: HttpMethod;
  endpoint: string;
  data?: any;
  id: string;
}

export interface BatchRequest {
  operations: BatchOperation[];
}

export interface BatchResponse {
  results: {
    id: string;
    status: number;
    data?: any;
    error?: ApiError;
  }[];
}

// Export utility types
export type ApiEndpoint = string;
export type ApiToken = string;
export type TeamId = string;
export type WorkspaceId = string;
export type DocumentId = string;
export type NotebookId = string;
export type TaskId = string;
export type UserId = string;