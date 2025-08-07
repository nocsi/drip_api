export interface ApiConfig {
  baseUrl: string;
  apiToken: string;
  csrfToken: string;
  teamId?: string;
}

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

export class ApiService {
  private config: ApiConfig;

  constructor(config: ApiConfig) {
    this.config = config;
  }

  private async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.config.baseUrl}${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.config.apiToken}`,
      'X-CSRF-Token': this.config.csrfToken,
      ...options.headers,
    };

    if (this.config.teamId) {
      headers['X-Team-ID'] = this.config.teamId;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.message ||
        `API Error: ${response.status} ${response.statusText}`
      );
    }

    return response.json();
  }

  private buildQueryString(params: QueryParams): string {
    const searchParams = new URLSearchParams();

    Object.entries(params).forEach(([key, value]) => {
      if (value === undefined || value === null) return;

      if (Array.isArray(value)) {
        value.forEach(item => searchParams.append(`${key}[]`, String(item)));
      } else if (typeof value === 'object') {
        Object.entries(value).forEach(([subKey, subValue]) => {
          searchParams.append(`${key}[${subKey}]`, String(subValue));
        });
      } else {
        searchParams.append(key, String(value));
      }
    });

    return searchParams.toString();
  }

  // Generic CRUD operations
  async get<T>(endpoint: string, params?: QueryParams): Promise<ApiResponse<T>> {
    const queryString = params ? this.buildQueryString(params) : '';
    const url = queryString ? `${endpoint}?${queryString}` : endpoint;
    return this.request<T>(url);
  }

  async post<T>(endpoint: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async put<T>(endpoint: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async patch<T>(endpoint: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async delete<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'DELETE',
    });
  }

  async upload(endpoint: string, formData: FormData): Promise<ApiResponse<any>> {
    const url = `${this.config.baseUrl}${endpoint}`;
    const headers: HeadersInit = {
      'Authorization': `Bearer ${this.config.apiToken}`,
      'X-CSRF-Token': this.config.csrfToken,
    };

    if (this.config.teamId) {
      headers['X-Team-ID'] = this.config.teamId;
    }

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: formData,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.message ||
        `Upload Error: ${response.status} ${response.statusText}`
      );
    }

    return response.json();
  }

  // Dashboard API
  async getDashboardStats(period: string = 'week') {
    return this.get(`/dashboard/stats`, { filter: { period } });
  }

  async getDashboardActivity() {
    return this.get('/dashboard/activity');
  }

  // Team API
  async listTeams() {
    return this.get('/teams');
  }

  async getTeam(id: string) {
    return this.get(`/teams/${id}`, { load: ['user_teams', 'invitations'] });
  }

  async createTeam(teamData: any) {
    return this.post('/teams', { team: teamData });
  }

  async updateTeam(id: string, teamData: any) {
    return this.put(`/teams/${id}`, { team: teamData });
  }

  async deleteTeam(id: string) {
    return this.delete(`/teams/${id}`);
  }

  async inviteTeamMember(teamId: string, invitationData: any) {
    return this.post(`/teams/${teamId}/invitations`, { invitation: invitationData });
  }

  async removeTeamMember(teamId: string, memberId: string) {
    return this.delete(`/teams/${teamId}/members/${memberId}`);
  }

  async updateMemberRole(teamId: string, memberId: string, role: string) {
    return this.patch(`/teams/${teamId}/members/${memberId}`, { role });
  }

  async acceptInvitation(invitationId: string) {
    return this.post(`/invitations/${invitationId}/accept`);
  }

  async declineInvitation(invitationId: string) {
    return this.post(`/invitations/${invitationId}/decline`);
  }

  async cancelInvitation(teamId: string, invitationId: string) {
    return this.delete(`/teams/${teamId}/invitations/${invitationId}`);
  }

  // Workspace API
  async listWorkspaces(params?: QueryParams) {
    return this.get('/workspaces', params);
  }

  async getWorkspace(id: string) {
    return this.get(`/workspaces/${id}`, { load: ['documents', 'notebooks', 'team'] });
  }

  async createWorkspace(workspaceData: any) {
    return this.post('/workspaces', { workspace: workspaceData });
  }

  async updateWorkspace(id: string, workspaceData: any) {
    return this.put(`/workspaces/${id}`, { workspace: workspaceData });
  }

  async deleteWorkspace(id: string) {
    return this.delete(`/workspaces/${id}`);
  }

  async duplicateWorkspace(id: string, options: any = {}) {
    return this.post(`/workspaces/${id}/duplicate`, { options });
  }

  async archiveWorkspace(id: string) {
    return this.post(`/workspaces/${id}/archive`);
  }

  async restoreWorkspace(id: string) {
    return this.post(`/workspaces/${id}/restore`);
  }

  async getWorkspaceStatistics(id: string) {
    return this.get(`/workspaces/${id}/statistics`);
  }

  async getWorkspaceStorageInfo(id: string) {
    return this.get(`/workspaces/${id}/storage_info`);
  }

  async changeStorageBackend(id: string, backendData: any) {
    return this.post(`/workspaces/${id}/change_storage_backend`, { backend: backendData });
  }

  // Document API
  async listDocuments(workspaceId?: string, params?: QueryParams) {
    const endpoint = workspaceId
      ? `/workspaces/${workspaceId}/documents`
      : '/documents';
    return this.get(endpoint, params);
  }

  async getDocument(id: string) {
    return this.get(`/documents/${id}`, { load: ['workspace', 'team'] });
  }

  async createDocument(documentData: any) {
    return this.post('/documents', { document: documentData });
  }

  async updateDocument(id: string, documentData: any) {
    return this.put(`/documents/${id}`, { document: documentData });
  }

  async deleteDocument(id: string) {
    return this.delete(`/documents/${id}`);
  }

  async duplicateDocument(id: string, options: any = {}) {
    return this.post(`/documents/${id}/duplicate`, { options });
  }

  async getDocumentContent(id: string, version?: string) {
    const endpoint = version
      ? `/documents/${id}/content?version=${version}`
      : `/documents/${id}/content`;
    return this.get(endpoint);
  }

  async updateDocumentContent(id: string, content: string, commitMessage: string = 'Update content') {
    return this.put(`/documents/${id}/content`, { content, commit_message: commitMessage });
  }

  async getDocumentVersions(id: string) {
    return this.get(`/documents/${id}/versions`);
  }

  async renderDocumentAs(id: string, format: string, options: any = {}) {
    return this.post(`/documents/${id}/render/${format}`, { options });
  }

  async uploadDocuments(workspaceId: string, formData: FormData) {
    const endpoint = `/workspaces/${workspaceId}/documents/upload`;
    return this.upload(endpoint, formData);
  }

  async renameDocument(id: string, newTitle: string, commitMessage: string = 'Rename document') {
    return this.patch(`/documents/${id}/rename`, { new_title: newTitle, commit_message: commitMessage });
  }

  async viewDocument(id: string) {
    return this.post(`/documents/${id}/view`);
  }

  // Notebook API
  async listNotebooks(workspaceId?: string, params?: QueryParams) {
    const endpoint = workspaceId
      ? `/workspaces/${workspaceId}/notebooks`
      : '/notebooks';
    return this.get(endpoint, params);
  }

  async getNotebook(id: string) {
    return this.get(`/notebooks/${id}`, { load: ['workspace', 'team', 'document', 'tasks'] });
  }

  async createNotebookFromDocument(documentId: string, notebookData: any) {
    return this.post(`/documents/${documentId}/notebooks`, { notebook: notebookData });
  }

  async updateNotebook(id: string, notebookData: any) {
    return this.put(`/notebooks/${id}`, { notebook: notebookData });
  }

  async deleteNotebook(id: string) {
    return this.delete(`/notebooks/${id}`);
  }

  async duplicateNotebook(id: string, options: any = {}) {
    return this.post(`/notebooks/${id}/duplicate`, { options });
  }

  async executeNotebook(id: string, options: any = {}) {
    return this.post(`/notebooks/${id}/execute`, options);
  }

  async executeNotebookTask(notebookId: string, taskId: string, options: any = {}) {
    return this.post(`/notebooks/${notebookId}/tasks/${taskId}/execute`, options);
  }

  async stopNotebookExecution(id: string) {
    return this.post(`/notebooks/${id}/stop_execution`);
  }

  async resetNotebookExecution(id: string) {
    return this.post(`/notebooks/${id}/reset_execution`);
  }

  async toggleCollaborativeMode(id: string) {
    return this.post(`/notebooks/${id}/toggle_collaborative_mode`);
  }

  async updateNotebookAccessTime(id: string) {
    return this.post(`/notebooks/${id}/update_access_time`);
  }

  async getNotebookTasks(id: string) {
    return this.get(`/notebooks/${id}/tasks`);
  }

  async getWorkspaceTasks(workspaceId: string) {
    return this.get(`/workspaces/${workspaceId}/tasks`);
  }

  // User/Profile API
  async getCurrentUser() {
    return this.get('/user/profile');
  }

  async updateProfile(profileData: any) {
    return this.put('/user/profile', { profile: profileData });
  }

  async getNotifications() {
    return this.get('/user/notifications');
  }

  async markNotificationRead(id: string) {
    return this.patch(`/user/notifications/${id}`, { read: true });
  }

  async markAllNotificationsRead() {
    return this.patch('/user/notifications', { mark_all_read: true });
  }

  // Search API
  async search(query: string, types: string[] = [], filters: any = {}) {
    return this.get('/search', {
      search: query,
      filter: { ...filters, types }
    });
  }

  // Admin API (if applicable)
  async getSystemStats() {
    return this.get('/admin/stats');
  }

  async listAllUsers(params?: QueryParams) {
    return this.get('/admin/users', params);
  }

  async listAllTeams(params?: QueryParams) {
    return this.get('/admin/teams', params);
  }

  // Utility methods
  updateConfig(newConfig: Partial<ApiConfig>) {
    this.config = { ...this.config, ...newConfig };
  }

  getConfig(): ApiConfig {
    return { ...this.config };
  }

  // WebSocket/Real-time connection helper
  createWebSocketUrl(endpoint: string): string {
    const baseUrl = this.config.baseUrl.replace(/^http/, 'ws');
    const url = new URL(`${baseUrl}${endpoint}`);
    url.searchParams.set('token', this.config.apiToken);
    if (this.config.teamId) {
      url.searchParams.set('team_id', this.config.teamId);
    }
    return url.toString();
  }
}

// Export a factory function for creating API instances
export function createApiService(config: ApiConfig): ApiService {
  return new ApiService(config);
}

// Export default instance that can be configured
let defaultApi: ApiService | null = null;

export function configureDefaultApi(config: ApiConfig): void {
  defaultApi = new ApiService(config);
}

export function getDefaultApi(): ApiService {
  if (!defaultApi) {
    throw new Error('Default API not configured. Call configureDefaultApi first.');
  }
  return defaultApi;
}

// Error types for better error handling
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public code?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
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

// Type definitions for common data structures
export interface User {
  id: string;
  name: string;
  email: string;
  avatar?: string;
  created_at: string;
  updated_at: string;
}

export interface Team {
  id: string;
  name: string;
  description?: string;
  domain?: string;
  created_at: string;
  updated_at: string;
  members_count?: number;
  is_personal: boolean;
}

export interface Workspace {
  id: string;
  name: string;
  description?: string;
  status: 'active' | 'archived' | 'deleted';
  storage_backend: string;
  storage_path?: string;
  git_repository_url?: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
  documents_count?: number;
  notebooks_count?: number;
}

export interface Document {
  id: string;
  title: string;
  description?: string;
  content?: string;
  content_type: 'markdown' | 'html' | 'text';
  is_public: boolean;
  tags?: string[];
  workspace_id: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
}

export interface Notebook {
  id: string;
  title: string;
  description?: string;
  content?: string;
  status: 'idle' | 'running' | 'completed' | 'error';
  language?: string;
  collaborative_mode: boolean;
  task_count?: number;
  avg_execution_time?: number;
  workspace_id: string;
  document_id?: string;
  team_id: string;
  created_by_id: string;
  created_at: string;
  updated_at: string;
}
