import { mount } from 'svelte';
import ContainerDashboard from '../../svelte/services/ContainerDashboard.svelte';

export default {
  mounted() {
    console.log('SvelteContainerDashboard hook mounted');
    
    // Get initial data from Phoenix assigns
    const teamId = this.el.dataset.teamId;
    const workspaceId = this.el.dataset.workspaceId;

    // Configure API for this hook
    const apiConfig = {
      baseUrl: '/api/v1',
      apiToken: window.userToken || '',
      csrfToken: document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
      teamId: teamId
    };

    // Import and configure the API
    import('../../svelte/services/api.ts').then(({ configureDefaultApi }) => {
      configureDefaultApi(apiConfig);
    }).catch(console.error);

    // Create the Svelte 5 component using mount
    this.app = mount(ContainerDashboard, {
      target: this.el,
      props: {
        teamId,
        workspaceId,
        // Event handlers as props for Svelte 5
        onserviceaction: (action, serviceId, params) => {
          this.pushEvent('service_action', {
            action,
            service_id: serviceId,
            ...params
          });
        },
        onloadservices: () => {
          this.pushEvent('load_services', {});
        },
        onfilterchange: (filter) => {
          this.pushEvent('filter_services', {
            filter: filter
          });
        },
        ondeployservice: (serviceData) => {
          this.pushEvent('deploy_service', serviceData);
        }
      }
    });

    // Handle real-time updates from Phoenix
    this.handleEvent('service_update', (payload) => {
      console.log('Received service update:', payload);
      
      // Update component props if needed
      if (this.app && payload) {
        // In Svelte 5, we would update reactive state through the component's exposed methods
        // or by updating the props if the component supports it
        console.log('Service update received:', payload);
      }
    });

    this.handleEvent('stats_update', (payload) => {
      console.log('Received stats update:', payload);
      
      if (this.app && payload.stats) {
        // Handle stats update
        console.log('Stats update received:', payload.stats);
      }
    });

    // Handle errors from Phoenix
    this.handleEvent('container_error', (payload) => {
      console.error('Container error:', payload);
      
      if (this.app && payload.error) {
        // Handle error state
        console.error('Container error received:', payload.error);
      }
    });

    console.log('SvelteContainerDashboard initialized with:', {
      teamId,
      workspaceId
    });
  },

  updated() {
    console.log('SvelteContainerDashboard hook updated');
    
    if (!this.app) {
      console.warn('Svelte component not found during update');
      return;
    }

    // Get updated data from Phoenix assigns
    const services = JSON.parse(this.el.dataset.services || '[]');
    const stats = JSON.parse(this.el.dataset.stats || '{}');
    const loading = this.el.dataset.loading === 'true';
    const error = this.el.dataset.error;
    const filter = JSON.parse(this.el.dataset.filter || '{}');

    console.log('Updating component with new data:', {
      servicesCount: services.length,
      stats,
      loading,
      error,
      filter
    });
  },

  reconnected() {
    console.log('SvelteContainerDashboard hook reconnected');
    
    // Reload services when reconnected to ensure data consistency
    this.pushEvent('load_services', {});
  },

  destroyed() {
    console.log('SvelteContainerDashboard hook destroyed');
    
    // Clean up Svelte 5 component
    if (this.app) {
      try {
        this.app.$destroy();
        this.app = null;
      } catch (e) {
        console.warn('Error destroying Svelte component:', e);
      }
    }
  }
};