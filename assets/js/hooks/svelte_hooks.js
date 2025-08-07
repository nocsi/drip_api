import { mount } from 'svelte'
import WorkspacesApp from '../../svelte/apps/WorkspacesApp.svelte'
import TeamsApp from '../../svelte/apps/TeamsApp.svelte'
import PortalApp from '../../svelte/apps/PortalApp.svelte'

export const SvelteWorkspaces = {
  mounted() {
    const currentUser = JSON.parse(this.el.dataset.currentUser)
    const teams = JSON.parse(this.el.dataset.teams)
    const apiToken = this.el.dataset.apiToken
    const csrfToken = this.el.dataset.csrfToken

    this.app = mount(WorkspacesApp, {
      target: this.el,
      props: {
        currentUser,
        teams,
        apiToken,
        csrfToken,
        apiBaseUrl: '/api/v1'
      }
    })
  },

  destroyed() {
    if (this.app) {
      this.app.$destroy()
    }
  }
}

export const SvelteTeams = {
  mounted() {
    const currentUser = JSON.parse(this.el.dataset.currentUser)
    const teams = JSON.parse(this.el.dataset.teams)
    const apiToken = this.el.dataset.apiToken
    const csrfToken = this.el.dataset.csrfToken

    this.app = mount(TeamsApp, {
      target: this.el,
      props: {
        currentUser,
        teams,
        apiToken,
        csrfToken,
        apiBaseUrl: '/api/v1'
      }
    })
  },

  destroyed() {
    if (this.app) {
      this.app.$destroy()
    }
  }
}

export const SveltePortal = {
  mounted() {
    const currentUser = JSON.parse(this.el.dataset.currentUser)
    const teams = JSON.parse(this.el.dataset.teams)
    const invitations = JSON.parse(this.el.dataset.invitations)
    const apiToken = this.el.dataset.apiToken
    const csrfToken = this.el.dataset.csrfToken

    this.app = mount(PortalApp, {
      target: this.el,
      props: {
        currentUser,
        teams,
        invitations,
        apiToken,
        csrfToken,
        apiBaseUrl: '/api/v1'
      }
    })
  },

  destroyed() {
    if (this.app) {
      this.app.$destroy()
    }
  }
}

// LiveView hooks for Svelte components
export const SvelteWorkspaceIndex = {
  mounted() {
    const workspaces = JSON.parse(this.el.dataset.workspaces || '[]')
    const teams = JSON.parse(this.el.dataset.teams || '[]')
    const currentTeam = JSON.parse(this.el.dataset.currentTeam || 'null')
    
    // Create mock live object for existing components
    const mockLive = {
      pushEvent: (event, data) => {
        this.pushEvent(event, data)
      }
    }
    
    // For now, we can use the existing workspace components
    // but in the future they should be replaced with the full app
    this.liveSocket = mockLive
  },

  destroyed() {
    // Cleanup if needed
  }
}

export const SvelteWorkspaceDashboard = {
  mounted() {
    // Similar to above, create mock live object
    const mockLive = {
      pushEvent: (event, data) => {
        this.pushEvent(event, data)
      }
    }
    
    this.liveSocket = mockLive
  },

  destroyed() {
    // Cleanup if needed
  }
}

// Helper function to create mock live objects for existing components
function createMockLive(hook) {
  return {
    pushEvent: (event, data) => {
      hook.pushEvent(event, data)
    },
    pushPatch: (path) => {
      window.history.pushState({}, '', path)
      // Could trigger route handling here
    },
    pushNavigate: (url) => {
      window.location.href = url
    }
  }
}

// Export all hooks
export default {
  SvelteWorkspaces,
  SvelteTeams,
  SveltePortal,
  SvelteWorkspaceIndex,
  SvelteWorkspaceDashboard
}