// Core API types
export interface ApiResponse<T = any> {
  data: T;
  message?: string;
  status: number;
}

export interface PaginatedResponse<T = any> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  };
}

export interface QueryParams {
  search?: string;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
  page?: number;
  per_page?: number;
  filter?: Record<string, any>;
  load?: string[];
}

// User and Authentication types
export interface User {
  id: string;
  name: string;
  email: string;
  avatar?: string;
  created_at: string;
  updated_at: string;
  confirmed_at?: string;
  is_admin?: boolean;
  settings?: UserSettings;
}

export interface UserSettings {
  theme: 'light' | 'dark' | 'system';
  language: string;
  timezone: string;
  notifications_enabled: boolean;
  email_notifications: boolean;
}

// Team types
export interface Team {
  id: string;
  name: string;
  description?: string;
  domain?: string;
  is_personal: boolean;
  created_at: string;
  updated_at: string;
  members_count?: number;
  workspaces_count?: number;
  user_teams?: UserTeam[];
  invitations?: TeamInvitation[];
}

export interface UserTeam {
  id: string;
  user_id: string;
  team_id: string;
  role: TeamRole;
  status: 'active' | 'inactive';
  joined_at: string;
  user?: User;
  team?: Team;
}

export interface TeamInvitation {
  id: string;
  email: string;
  role: TeamRole;
  status: 'pending' | 'accepted' | 'declined' | 'expired';
  invited_by_id: string;
  team_id: string;
  token: string;
  expires_at: string;
  created_at: string;
  invited_by?: User;
  team?: Team;
}

export type TeamRole = 'owner' | 'admin' | 'member' | 'viewer';

// Workspace types
export interface Workspace {
  id: string;
  name: string;
  description?: string;
  status: 'active' | 'archived' | 'deleted';
  storage_backend: 'local' | 'git' | 's3' | 'github';
  storage_path?: string;
  git_repository_url?: string;
  git_branch?: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
  accessed_at?: string;
  documents_count?: number;
  notebooks_count?: number;
  size_bytes?: number;
  team?: Team;
  created_by?: User;
  documents?: Document[];
  notebooks?: Notebook[];
  statistics?: WorkspaceStatistics;
}

export interface WorkspaceStatistics {
  total_documents: number;
  total_notebooks: number;
  total_tasks: number;
  completed_tasks: number;
  total_executions: number;
  successful_executions: number;
  storage_used_bytes: number;
  last_activity_at?: string;
  most_active_day?: string;
  avg_execution_time_ms?: number;
}

export interface WorkspaceStorageInfo {
  backend: string;
  total_size_bytes: number;
  available_space_bytes?: number;
  file_count: number;
  last_backup_at?: string;
  compression_ratio?: number;
}

// Document types
export interface Document {
  id: string;
  title: string;
  description?: string;
  content?: string;
  content_type: 'markdown' | 'html' | 'text';
  is_public: boolean;
  tags?: string[];
  metadata?: Record<string, any>;
  file_path?: string;
  file_size_bytes?: number;
  checksum?: string;
  workspace_id: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
  accessed_at?: string;
  version?: number;
  workspace?: Workspace;
  team?: Team;
  created_by?: User;
  versions?: DocumentVersion[];
  notebooks?: Notebook[];
}

export interface DocumentVersion {
  id: string;
  document_id: string;
  version_number: number;
  title: string;
  content: string;
  commit_message?: string;
  created_by_id: string;
  created_at: string;
  file_size_bytes: number;
  created_by?: User;
}

// Notebook types
export interface Notebook {
  id: string;
  title: string;
  description?: string;
  content?: string;
  status: 'idle' | 'running' | 'completed' | 'error' | 'cancelled';
  language?: string;
  collaborative_mode: boolean;
  execution_timeout_seconds?: number;
  auto_save_enabled: boolean;
  task_count?: number;
  completed_task_count?: number;
  avg_execution_time_ms?: number;
  total_execution_time_ms?: number;
  last_execution_at?: string;
  workspace_id: string;
  document_id?: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
  accessed_at?: string;
  workspace?: Workspace;
  document?: Document;
  team?: Team;
  created_by?: User;
  tasks?: NotebookTask[];
  execution_history?: ExecutionHistory[];
}

export interface NotebookTask {
  id: string;
  notebook_id: string;
  runme_id?: string;
  name: string;
  description?: string;
  language: string;
  code: string;
  order_index: number;
  line_start?: number;
  line_end?: number;
  is_executable: boolean;
  execution_count: number;
  last_execution_status?: 'success' | 'error' | 'timeout' | 'cancelled';
  last_execution_at?: string;
  last_execution_time_ms?: number;
  last_output?: string;
  last_error?: string;
  timeout_seconds?: number;
  created_at: string;
  updated_at: string;
}

export interface ExecutionHistory {
  id: string;
  notebook_id: string;
  task_id?: string;
  status: 'success' | 'error' | 'timeout' | 'cancelled';
  output?: string;
  error_message?: string;
  execution_time_ms: number;
  started_at: string;
  completed_at?: string;
  triggered_by_id: string;
  triggered_by?: User;
}

// Project types (from Projects domain)
export interface Project {
  id: string;
  path: string;
  type: 'directory' | 'file';
  name: string;
  status: 'loading' | 'loaded' | 'error';
  identity_mode: 'auto' | 'document' | 'cell';
  options?: ProjectOptions;
  document_count?: number;
  task_count?: number;
  user_id: string;
  created_at: string;
  updated_at: string;
  user?: User;
  documents?: ProjectDocument[];
  tasks?: ProjectTask[];
  load_events?: LoadEvent[];
}

export interface ProjectOptions {
  skip_gitignore?: boolean;
  ignore_file_patterns?: string[];
  repository_discovery?: boolean;
  [key: string]: any;
}

export interface ProjectDocument {
  id: string;
  project_id: string;
  path: string;
  absolute_path: string;
  content?: string;
  parsed_content?: any;
  status: 'pending' | 'parsing' | 'parsed' | 'error';
  size_bytes?: number;
  line_count?: number;
  task_count?: number;
  created_at: string;
  updated_at: string;
  project?: Project;
  tasks?: ProjectTask[];
}

export interface ProjectTask {
  id: string;
  project_id: string;
  document_id?: string;
  runme_id?: string;
  name: string;
  language: string;
  code: string;
  line_start?: number;
  line_end?: number;
  order_index: number;
  execution_count: number;
  last_execution_status?: 'success' | 'error' | 'timeout' | 'cancelled';
  last_execution_at?: string;
  last_execution_time_ms?: number;
  last_output?: string;
  last_error?: string;
  is_executable: boolean;
  timeout_seconds?: number;
  created_at: string;
  updated_at: string;
  project?: Project;
  document?: ProjectDocument;
}

export interface LoadEvent {
  id: string;
  project_id: string;
  document_id?: string;
  task_id?: string;
  event_type: LoadEventType;
  event_data?: any;
  sequence_number: number;
  path?: string;
  error_message?: string;
  task_name?: string;
  task_runme_id?: string;
  created_at: string;
}

export type LoadEventType = 
  | 'started_walk'
  | 'found_dir'
  | 'found_file'
  | 'finished_walk'
  | 'started_parsing_doc'
  | 'finished_parsing_doc'
  | 'found_task'
  | 'error';

// Search and filtering types
export interface SearchResult {
  id: string;
  type: 'team' | 'workspace' | 'document' | 'notebook' | 'task';
  title: string;
  description?: string;
  content_snippet?: string;
  score: number;
  metadata?: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface SearchFilters {
  types?: string[];
  team_ids?: string[];
  workspace_ids?: string[];
  date_range?: {
    start: string;
    end: string;
  };
  tags?: string[];
  status?: string[];
  language?: string[];
}

// Notification types
export interface Notification {
  id: string;
  user_id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  title: string;
  message: string;
  data?: any;
  read: boolean;
  read_at?: string;
  created_at: string;
  expires_at?: string;
}

// UI State types
export interface UIState {
  sidebarOpen: boolean;
  mobileMenuOpen: boolean;
  theme: 'light' | 'dark' | 'system';
  loading: boolean;
  error?: string;
  currentTeam?: Team;
  currentWorkspace?: Workspace;
}

export interface TableState<T = any> {
  data: T[];
  loading: boolean;
  error?: string;
  pagination: {
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  };
  sort: {
    field: string;
    order: 'asc' | 'desc';
  };
  filters: Record<string, any>;
  selection: Set<string>;
}

// Form types
export interface FormField {
  name: string;
  label: string;
  type: 'text' | 'email' | 'password' | 'textarea' | 'select' | 'checkbox' | 'file';
  value?: any;
  placeholder?: string;
  required?: boolean;
  disabled?: boolean;
  options?: { label: string; value: any }[];
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
    custom?: (value: any) => string | null;
  };
  error?: string;
}

export interface FormState {
  fields: Record<string, FormField>;
  dirty: boolean;
  valid: boolean;
  submitting: boolean;
  submitted: boolean;
  errors: Record<string, string>;
}

// WebSocket types
export interface WebSocketMessage {
  type: string;
  payload: any;
  timestamp: string;
  user_id?: string;
  team_id?: string;
  workspace_id?: string;
}

export interface RealtimeEvent {
  event: string;
  payload: any;
  ref?: string;
}

// Error types
export interface AppError {
  code: string;
  message: string;
  details?: any;
  timestamp: string;
  user_id?: string;
  context?: Record<string, any>;
}

// Utility types
export type LoadingState = 'idle' | 'loading' | 'success' | 'error';

export type SortDirection = 'asc' | 'desc';

export type ViewMode = 'list' | 'grid' | 'card';

export interface MenuItem {
  id: string;
  label: string;
  icon?: string;
  href?: string;
  action?: () => void;
  children?: MenuItem[];
  badge?: string | number;
  disabled?: boolean;
  separator?: boolean;
}

export interface BreadcrumbItem {
  label: string;
  href?: string;
  icon?: string;
  current?: boolean;
}

// Export all types
export * from './api';