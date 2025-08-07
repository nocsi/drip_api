import { writable, derived, readable, type Writable, type Readable } from 'svelte/store';
const browser = typeof window !== 'undefined';
import type {
  User,
  Team,
  Workspace,
  Document,
  Notebook,
  Project,
  UIState,
  ApiState,
  TableState,
  Notification,
  SearchResult,
  LoadingState
} from '../types';
import { ApiService, type ApiConfig } from '../services/api';

// Core application state
export const ui = writable<UIState>({
  sidebarOpen: true,
  mobileMenuOpen: false,
  theme: 'system',
  loading: false,
  error: undefined,
  currentTeam: undefined,
  currentWorkspace: undefined
});

// Authentication state
export const auth = writable<{
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  loading: boolean;
}>({
  user: null,
  token: null,
  isAuthenticated: false,
  loading: false
});

// API service instance
export const apiService = writable<ApiService | null>(null);

// Teams store
function createTeamsStore() {
  const { subscribe, set, update } = writable<ApiState<Team[]>>({
    data: [],
    status: 'idle',
    error: undefined
  });

  return {
    subscribe,
    async load(api: ApiService) {
      update(state => ({ ...state, status: 'loading' }));
      try {
        const response = await api.listTeams();
        set({
          data: response.data,
          status: 'success',
          error: undefined,
          lastFetch: new Date()
        });
      } catch (error) {
        set({
          data: [],
          status: 'error',
          error: error as any,
          lastFetch: new Date()
        });
      }
    },
    async create(api: ApiService, teamData: any) {
      try {
        const response = await api.createTeam(teamData);
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async update(api: ApiService, id: string, teamData: any) {
      try {
        const response = await api.updateTeam(id, teamData);
        update(state => ({
          ...state,
          data: (state.data || []).map(team => 
            team.id === id ? response.data : team
          )
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async delete(api: ApiService, id: string) {
      try {
        await api.deleteTeam(id);
        update(state => ({
          ...state,
          data: (state.data || []).filter(team => team.id !== id)
        }));
      } catch (error) {
        throw error;
      }
    },
    reset() {
      set({
        data: [],
        status: 'idle',
        error: undefined
      });
    }
  };
}

export const teams = createTeamsStore();

// Current team store
export const currentTeam = writable<Team | null>(null);

// Workspaces store
function createWorkspacesStore() {
  const { subscribe, set, update } = writable<ApiState<Workspace[]>>({
    data: [],
    status: 'idle',
    error: undefined
  });

  return {
    subscribe,
    async load(api: ApiService, params?: any) {
      update(state => ({ ...state, status: 'loading' }));
      try {
        const response = await api.listWorkspaces(params);
        set({
          data: response.data,
          status: 'success',
          error: undefined,
          lastFetch: new Date()
        });
      } catch (error) {
        set({
          data: [],
          status: 'error',
          error: error as any,
          lastFetch: new Date()
        });
      }
    },
    async create(api: ApiService, workspaceData: any) {
      try {
        const response = await api.createWorkspace(workspaceData);
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async update(api: ApiService, id: string, workspaceData: any) {
      try {
        const response = await api.updateWorkspace(id, workspaceData);
        update(state => ({
          ...state,
          data: (state.data || []).map(workspace => 
            workspace.id === id ? response.data : workspace
          )
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async delete(api: ApiService, id: string) {
      try {
        await api.deleteWorkspace(id);
        update(state => ({
          ...state,
          data: (state.data || []).filter(workspace => workspace.id !== id)
        }));
      } catch (error) {
        throw error;
      }
    },
    reset() {
      set({
        data: [],
        status: 'idle',
        error: undefined
      });
    }
  };
}

export const workspaces = createWorkspacesStore();

// Current workspace store
export const currentWorkspace = writable<Workspace | null>(null);

// Documents store
function createDocumentsStore() {
  const { subscribe, set, update } = writable<ApiState<Document[]>>({
    data: [],
    status: 'idle',
    error: undefined
  });

  return {
    subscribe,
    async load(api: ApiService, workspaceId?: string, params?: any) {
      update(state => ({ ...state, status: 'loading' }));
      try {
        const response = await api.listDocuments(workspaceId, params);
        set({
          data: response.data,
          status: 'success',
          error: undefined,
          lastFetch: new Date()
        });
      } catch (error) {
        set({
          data: [],
          status: 'error',
          error: error as any,
          lastFetch: new Date()
        });
      }
    },
    async create(api: ApiService, documentData: any) {
      try {
        const response = await api.createDocument(documentData);
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async update(api: ApiService, id: string, documentData: any) {
      try {
        const response = await api.updateDocument(id, documentData);
        update(state => ({
          ...state,
          data: (state.data || []).map(document => 
            document.id === id ? response.data : document
          )
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async delete(api: ApiService, id: string) {
      try {
        await api.deleteDocument(id);
        update(state => ({
          ...state,
          data: (state.data || []).filter(document => document.id !== id)
        }));
      } catch (error) {
        throw error;
      }
    },
    reset() {
      set({
        data: [],
        status: 'idle',
        error: undefined
      });
    }
  };
}

export const documents = createDocumentsStore();

// Notebooks store
function createNotebooksStore() {
  const { subscribe, set, update } = writable<ApiState<Notebook[]>>({
    data: [],
    status: 'idle',
    error: undefined
  });

  return {
    subscribe,
    async load(api: ApiService, workspaceId?: string, params?: any) {
      update(state => ({ ...state, status: 'loading' }));
      try {
        const response = await api.listNotebooks(workspaceId, params);
        set({
          data: response.data,
          status: 'success',
          error: undefined,
          lastFetch: new Date()
        });
      } catch (error) {
        set({
          data: [],
          status: 'error',
          error: error as any,
          lastFetch: new Date()
        });
      }
    },
    async create(api: ApiService, documentId: string, notebookData: any) {
      try {
        const response = await api.createNotebookFromDocument(documentId, notebookData);
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async update(api: ApiService, id: string, notebookData: any) {
      try {
        const response = await api.updateNotebook(id, notebookData);
        update(state => ({
          ...state,
          data: (state.data || []).map(notebook => 
            notebook.id === id ? response.data : notebook
          )
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async execute(api: ApiService, id: string, options?: any) {
      try {
        update(state => ({
          ...state,
          data: (state.data || []).map(notebook => 
            notebook.id === id ? { ...notebook, status: 'running' } : notebook
          )
        }));
        
        const response = await api.executeNotebook(id, options);
        
        update(state => ({
          ...state,
          data: (state.data || []).map(notebook => 
            notebook.id === id ? { ...notebook, status: response.data.status } : notebook
          )
        }));
        
        return response.data;
      } catch (error) {
        update(state => ({
          ...state,
          data: (state.data || []).map(notebook => 
            notebook.id === id ? { ...notebook, status: 'error' } : notebook
          )
        }));
        throw error;
      }
    },
    async delete(api: ApiService, id: string) {
      try {
        await api.deleteNotebook(id);
        update(state => ({
          ...state,
          data: (state.data || []).filter(notebook => notebook.id !== id)
        }));
      } catch (error) {
        throw error;
      }
    },
    reset() {
      set({
        data: [],
        status: 'idle',
        error: undefined
      });
    }
  };
}

export const notebooks = createNotebooksStore();

// Projects store (for loading directories/files)
function createProjectsStore() {
  const { subscribe, set, update } = writable<ApiState<Project[]>>({
    data: [],
    status: 'idle',
    error: undefined
  });

  return {
    subscribe,
    async loadDirectory(api: ApiService, path: string, options?: any) {
      try {
        const response = await api.post('/projects/load_directory', {
          path,
          ...options
        });
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    async loadFile(api: ApiService, path: string, options?: any) {
      try {
        const response = await api.post('/projects/load_file', {
          path,
          ...options
        });
        update(state => ({
          ...state,
          data: [...(state.data || []), response.data]
        }));
        return response.data;
      } catch (error) {
        throw error;
      }
    },
    reset() {
      set({
        data: [],
        status: 'idle',
        error: undefined
      });
    }
  };
}

export const projects = createProjectsStore();

// Notifications store
function createNotificationsStore() {
  const { subscribe, set, update } = writable<{
    notifications: Notification[];
    unreadCount: number;
    loading: boolean;
  }>({
    notifications: [],
    unreadCount: 0,
    loading: false
  });

  return {
    subscribe,
    async load(api: ApiService) {
      update(state => ({ ...state, loading: true }));
      try {
        const response = await api.getNotifications();
        set({
          notifications: response.data.notifications,
          unreadCount: response.data.unread_count,
          loading: false
        });
      } catch (error) {
        update(state => ({ ...state, loading: false }));
      }
    },
    async markRead(api: ApiService, id: string) {
      try {
        await api.markNotificationRead(id);
        update(state => ({
          ...state,
          notifications: state.notifications.map(notification =>
            notification.id === id ? { ...notification, read: true } : notification
          ),
          unreadCount: Math.max(0, state.unreadCount - 1)
        }));
      } catch (error) {
        throw error;
      }
    },
    async markAllRead(api: ApiService) {
      try {
        await api.markAllNotificationsRead();
        update(state => ({
          ...state,
          notifications: state.notifications.map(notification => ({
            ...notification,
            read: true
          })),
          unreadCount: 0
        }));
      } catch (error) {
        throw error;
      }
    },
    add(notification: Notification) {
      update(state => ({
        ...state,
        notifications: [notification, ...state.notifications],
        unreadCount: notification.read ? state.unreadCount : state.unreadCount + 1
      }));
    }
  };
}

export const notifications = createNotificationsStore();

// Search store
function createSearchStore() {
  const { subscribe, set, update } = writable<{
    query: string;
    results: SearchResult[];
    loading: boolean;
    filters: any;
  }>({
    query: '',
    results: [],
    loading: false,
    filters: {}
  });

  return {
    subscribe,
    async search(api: ApiService, query: string, filters?: any) {
      update(state => ({ ...state, query, loading: true }));
      try {
        const response = await api.search(query, [], filters);
        update(state => ({
          ...state,
          results: response.data,
          loading: false
        }));
      } catch (error) {
        update(state => ({ ...state, loading: false, results: [] }));
      }
    },
    setFilters(filters: any) {
      update(state => ({ ...state, filters }));
    },
    clear() {
      set({
        query: '',
        results: [],
        loading: false,
        filters: {}
      });
    }
  };
}

export const search = createSearchStore();

// Table state utilities
export function createTableStore<T>(initialData: T[] = []) {
  const { subscribe, set, update } = writable<TableState<T>>({
    data: initialData,
    loading: false,
    error: undefined,
    pagination: {
      page: 1,
      per_page: 20,
      total: 0,
      total_pages: 0
    },
    sort: {
      field: 'created_at',
      order: 'desc'
    },
    filters: {},
    selection: new Set()
  });

  return {
    subscribe,
    setData(data: T[], pagination?: any) {
      update(state => ({
        ...state,
        data,
        pagination: pagination || state.pagination,
        loading: false,
        error: undefined
      }));
    },
    setLoading(loading: boolean) {
      update(state => ({ ...state, loading }));
    },
    setError(error: string) {
      update(state => ({ ...state, error, loading: false }));
    },
    setSort(field: string, order: 'asc' | 'desc') {
      update(state => ({ ...state, sort: { field, order } }));
    },
    setFilters(filters: Record<string, any>) {
      update(state => ({ ...state, filters }));
    },
    setPagination(pagination: any) {
      update(state => ({ ...state, pagination }));
    },
    toggleSelection(id: string) {
      update(state => {
        const selection = new Set(state.selection);
        if (selection.has(id)) {
          selection.delete(id);
        } else {
          selection.add(id);
        }
        return { ...state, selection };
      });
    },
    clearSelection() {
      update(state => ({ ...state, selection: new Set() }));
    },
    selectAll(ids: string[]) {
      update(state => ({ ...state, selection: new Set(ids) }));
    }
  };
}

// Theme management
export const theme = writable<'light' | 'dark' | 'system'>('system');

// Loading states
export const loadingStates = writable<Record<string, LoadingState>>({});

// Error handling
export const errors = writable<string[]>([]);

// Derived stores
export const isAuthenticated = derived(auth, $auth => $auth.isAuthenticated);

export const currentTeamId = derived(currentTeam, $currentTeam => $currentTeam?.id);

export const currentWorkspaceId = derived(currentWorkspace, $currentWorkspace => $currentWorkspace?.id);

export const unreadNotificationCount = derived(
  notifications,
  $notifications => $notifications.unreadCount
);

// Local storage persistence for theme and UI state
if (browser) {
  theme.subscribe(value => {
    localStorage.setItem('kyozo-theme', value);
  });

  ui.subscribe(value => {
    localStorage.setItem('kyozo-ui-state', JSON.stringify({
      sidebarOpen: value.sidebarOpen,
      theme: value.theme
    }));
  });

  // Initialize from localStorage
  const savedTheme = localStorage.getItem('kyozo-theme') as 'light' | 'dark' | 'system';
  if (savedTheme) {
    theme.set(savedTheme);
  }

  const savedUIState = localStorage.getItem('kyozo-ui-state');
  if (savedUIState) {
    try {
      const parsed = JSON.parse(savedUIState);
      ui.update(state => ({ ...state, ...parsed }));
    } catch (e) {
      // Ignore parsing errors
    }
  }
}

// Utility functions
export function resetAllStores() {
  teams.reset();
  workspaces.reset();
  documents.reset();
  notebooks.reset();
  projects.reset();
  search.clear();
  
  auth.set({
    user: null,
    token: null,
    isAuthenticated: false,
    loading: false
  });
  
  currentTeam.set(null);
  currentWorkspace.set(null);
  
  ui.update(state => ({
    ...state,
    currentTeam: undefined,
    currentWorkspace: undefined,
    error: undefined
  }));
}

export function initializeApp(config: ApiConfig) {
  const api = new ApiService(config);
  apiService.set(api);
  
  // Set authenticated state
  auth.update(state => ({
    ...state,
    token: config.apiToken,
    isAuthenticated: !!config.apiToken
  }));
  
  return api;
}

// Media query utilities
export type Device = 'mobile' | 'sm' | 'tablet' | 'desktop' | null;
export type Dimensions = {
	width: number;
	height: number;
};

export type DeviceInformation = {
	device: Device;
	width: number;
	height: number;
	isMobile: boolean;
	isSm: boolean;
	isTablet: boolean;
	isDesktop: boolean;
};

// can be used in the following way:
// const screenInfo = useMediaQuery(browser);
// // Use a reactive statement to ensure `isTablet` updates with `screenInfo`
// $: isTablet = $screenInfo?.isTablet ?? false;
export const useMediaQuery = (browser: boolean) => {
	const { subscribe, set } = writable<DeviceInformation>(undefined, () => {
		if (!browser) {
			set({
				device: null,
				width: 0,
				height: 0,
				isMobile: false,
				isSm: false,
				isTablet: false,
				isDesktop: false
			});
			return () => {};
		} else {
			set(getDeviceInformation(window));

			const onchange = () => set(getDeviceInformation(window));

			// Add event listeners for window resize
			window.addEventListener('resize', onchange);
			window.addEventListener('orientationchange', onchange);

			// Cleanup function to remove event listeners
			return () => {
				window.removeEventListener('resize', onchange);
				window.removeEventListener('orientationchange', onchange);
			};
		}
	});

	return { subscribe };
};

function getDeviceInformation(window: Window) {
	let device: 'mobile' | 'sm' | 'tablet' | 'desktop' | null = null;
	let dimensions: {
		width: number;
		height: number;
	} | null = null;

	if (window.matchMedia('(max-width: 640px)').matches) {
		device = 'mobile';
	} else if (window.matchMedia('(max-width: 768px)').matches) {
		device = 'sm';
	} else if (window.matchMedia('(min-width: 641px) and (max-width: 1024px)').matches) {
		device = 'tablet';
	} else {
		device = 'desktop';
	}
	dimensions = { width: window.innerWidth, height: window.innerHeight };

	return {
		device,
		width: dimensions?.width,
		height: dimensions?.height,
		isMobile: device === 'mobile',
		isSm: device === 'sm',
		isTablet: device === 'tablet',
		isDesktop: device === 'desktop'
	};
}

export const useScroll = (threshold: number, browser: boolean) => {
	const { subscribe, set } = writable<boolean>(false, () => {
		if (!browser) {
			set(false);
			return () => {};
		} else {
			const onScroll = () => set(window.scrollY > threshold);

			// Add event listeners for window resize
			window.addEventListener('scroll', onScroll);

			// Cleanup function to remove event listeners
			return () => {
				window.removeEventListener('scroll', onScroll);
			};
		}
	});

	return { subscribe };
};