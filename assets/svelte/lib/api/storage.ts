import type { VFSListing, VFSContent } from '$lib/types/storage';
import { api } from './client.ts';

export const storageAPI = {
  /**
   * List files with virtual files included
   */
  async listVFS(teamId: string, workspaceId: string, path: string = '/'): Promise<VFSListing> {
    const response = await api.get(
      `/teams/${teamId}/workspaces/${workspaceId}/storage/vfs`,
      { params: { path } }
    );
    return response.data.data;
  },

  /**
   * Read virtual file content
   */
  async readVirtualFile(teamId: string, workspaceId: string, path: string): Promise<VFSContent> {
    const response = await api.get(
      `/teams/${teamId}/workspaces/${workspaceId}/storage/vfs/content`,
      { params: { path } }
    );
    return response.data.data;
  },
  
  /**
   * Create a shareable link for a virtual file
   */
  async createShare(teamId: string, workspaceId: string, params: { path: string; ttl?: number }) {
    const response = await api.post(
      `/teams/${teamId}/workspaces/${workspaceId}/storage/vfs/share`,
      params
    );
    return response.data;
  },
  
  /**
   * Export virtual files
   */
  async exportVFS(teamId: string, workspaceId: string, path: string, format: 'pdf' | 'html' | 'json' = 'html') {
    const response = await api.get(
      `/teams/${teamId}/workspaces/${workspaceId}/storage/vfs/export`,
      { params: { path, format } }
    );
    return response.data;
  },
  
  /**
   * Register a custom template
   */
  async registerTemplate(teamId: string, workspaceId: string, template: {
    generator_type: string;
    template_name: string;
    content: string;
  }) {
    const response = await api.post(
      `/teams/${teamId}/workspaces/${workspaceId}/storage/vfs/templates`,
      template
    );
    return response.data;
  }
};