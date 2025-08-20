<script>
  import { onMount, onDestroy } from 'svelte';
  import { slide } from 'svelte/transition';
  import { 
    RefreshCw, 
    Filter, 
    Download, 
    Search,
    Clock,
    CheckCircle,
    AlertCircle,
    XCircle,
    ChevronRight,
    ChevronDown,
    Terminal,
    Eye,
    EyeOff
  } from '@lucide/svelte';

  let { 
    events = [], 
    services = [], 
    onRefresh = () => {} 
  } = $props();

  let searchQuery = $state('');
  let selectedService = $state('all');
  let selectedEventType = $state('all');
  let selectedLogLevel = $state('all');
  let autoRefresh = $state(false);
  let expandedEvents = $state(new Set());
  let showRealTimeLogs = $state(false);

  let autoRefreshInterval = null;

  const filteredEvents = $derived(() => {
    let filtered = events;

    // Filter by search query
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(event => 
        event.attributes.message?.toLowerCase().includes(query) ||
        event.attributes.event_type?.toLowerCase().includes(query) ||
        event.attributes.service_name?.toLowerCase().includes(query)
      );
    }

    // Filter by service
    if (selectedService !== 'all') {
      filtered = filtered.filter(event => 
        event.attributes.service_instance_id === selectedService
      );
    }

    // Filter by event type
    if (selectedEventType !== 'all') {
      filtered = filtered.filter(event => 
        event.attributes.event_type === selectedEventType
      );
    }

    // Filter by log level
    if (selectedLogLevel !== 'all') {
      filtered = filtered.filter(event => 
        event.attributes.level === selectedLogLevel
      );
    }

    return filtered.sort((a, b) => 
      new Date(b.attributes.timestamp) - new Date(a.attributes.timestamp)
    );
  });

  const eventTypes = $derived(() => {
    const types = new Set();
    events.forEach(event => {
      if (event.attributes.event_type) {
        types.add(event.attributes.event_type);
      }
    });
    return Array.from(types).sort();
  });

  const logLevels = $derived(() => {
    const levels = new Set();
    events.forEach(event => {
      if (event.attributes.level) {
        levels.add(event.attributes.level);
      }
    });
    return Array.from(levels).sort();
  });

  onMount(() => {
    if (autoRefresh) {
      startAutoRefresh();
    }
  });

  onDestroy(() => {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
    }
  });

  function startAutoRefresh() {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
    }
    autoRefreshInterval = setInterval(() => {
      onRefresh();
    }, 5000); // Refresh every 5 seconds
  }

  function stopAutoRefresh() {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
      autoRefreshInterval = null;
    }
  }

  function toggleAutoRefresh() {
    autoRefresh = !autoRefresh;
    if (autoRefresh) {
      startAutoRefresh();
    } else {
      stopAutoRefresh();
    }
  }

  function toggleEventExpansion(eventId) {
    const newSet = new Set(expandedEvents);
    if (newSet.has(eventId)) {
      newSet.delete(eventId);
    } else {
      newSet.add(eventId);
    }
    expandedEvents = newSet;
  }

  function clearFilters() {
    searchQuery = '';
    selectedService = 'all';
    selectedEventType = 'all';
    selectedLogLevel = 'all';
  }

  function exportLogs() {
    const logsData = filteredEvents.map(event => ({
      timestamp: event.attributes.timestamp,
      level: event.attributes.level,
      service: event.attributes.service_name,
      event_type: event.attributes.event_type,
      message: event.attributes.message,
      details: event.attributes.details
    }));

    const blob = new Blob([JSON.stringify(logsData, null, 2)], { 
      type: 'application/json' 
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `deployment-logs-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function getEventIcon(eventType) {
    switch (eventType) {
      case 'deployment_started': return Clock;
      case 'deployment_completed': return CheckCircle;
      case 'deployment_failed': return XCircle;
      case 'container_started': return CheckCircle;
      case 'container_stopped': return AlertCircle;
      case 'health_check_passed': return CheckCircle;
      case 'health_check_failed': return XCircle;
      default: return Terminal;
    }
  }

  function getEventColor(eventType, level) {
    if (level === 'error') return 'error';
    if (level === 'warning') return 'warning';
    
    switch (eventType) {
      case 'deployment_completed':
      case 'container_started':
      case 'health_check_passed':
        return 'success';
      case 'deployment_failed':
      case 'container_stopped':
      case 'health_check_failed':
        return 'error';
      case 'deployment_started':
        return 'info';
      default:
        return 'neutral';
    }
  }

  function formatTimestamp(timestamp) {
    if (!timestamp) return 'Unknown';
    return new Date(timestamp).toLocaleString();
  }

  function formatDuration(startTime, endTime) {
    if (!startTime || !endTime) return null;
    const diff = new Date(endTime) - new Date(startTime);
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    
    if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    }
    return `${seconds}s`;
  }
</script>

<div class="deployment-logs">
  <!-- Header -->
  <div class="logs-header">
    <div>
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        Deployment Logs
      </h3>
      <p class="text-gray-600 dark:text-gray-300">
        Real-time deployment events and container logs
      </p>
    </div>

    <div class="header-actions">
      <button 
        class="btn btn-outline btn-sm"
        onclick={toggleAutoRefresh}
        class:active={autoRefresh}
      >
        {#if autoRefresh}
          <EyeOff class="w-4 h-4 mr-2" />
          Stop Auto-Refresh
        {:else}
          <Eye class="w-4 h-4 mr-2" />
          Auto-Refresh
        {/if}
      </button>

      <button class="btn btn-outline btn-sm" onclick={onRefresh}>
        <RefreshCw class="w-4 h-4 mr-2" />
        Refresh
      </button>

      <button class="btn btn-outline btn-sm" onclick={exportLogs}>
        <Download class="w-4 h-4 mr-2" />
        Export
      </button>
    </div>
  </div>

  <!-- Filters -->
  <div class="filters-section">
    <div class="search-bar">
      <Search class="search-icon" />
      <input
        type="text"
        placeholder="Search logs..."
        bind:value={searchQuery}
        class="search-input"
      />
    </div>

    <div class="filter-controls">
      <select bind:value={selectedService} class="filter-select">
        <option value="all">All Services</option>
        {#each services as service}
          <option value={service.id}>{service.attributes.name}</option>
        {/each}
      </select>

      <select bind:value={selectedEventType} class="filter-select">
        <option value="all">All Event Types</option>
        {#each eventTypes as type}
          <option value={type}>{type.replace('_', ' ')}</option>
        {/each}
      </select>

      <select bind:value={selectedLogLevel} class="filter-select">
        <option value="all">All Log Levels</option>
        {#each logLevels as level}
          <option value={level}>{level.toUpperCase()}</option>
        {/each}
      </select>

      <button class="btn btn-outline btn-sm" onclick={clearFilters}>
        Clear Filters
      </button>
    </div>
  </div>

  <!-- Logs List -->
  <div class="logs-list">
    {#if filteredEvents.length === 0}
      <div class="empty-state">
        <Terminal class="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <p class="text-gray-600 dark:text-gray-400">
          {events.length === 0 
            ? 'No deployment events yet. Deploy a service to see logs here.'
            : 'No events match your current filters.'}
        </p>
      </div>
    {:else}
      <div class="events-container">
        {#each filteredEvents as event (event.id)}
          {@const isExpanded = expandedEvents.has(event.id)}
          {@const EventIcon = getEventIcon(event.attributes.event_type)}
          {@const eventColor = getEventColor(event.attributes.event_type, event.attributes.level)}
          
          <div class="event-item" class:expanded={isExpanded}>
            <div class="event-header" onclick={() => toggleEventExpansion(event.id)}>
              <div class="event-main">
                <div class="event-icon icon-{eventColor}">
                  <EventIcon class="w-4 h-4" />
                </div>
                
                <div class="event-info">
                  <div class="event-title">
                    <span class="event-type">
                      {event.attributes.event_type?.replace('_', ' ') || 'Unknown Event'}
                    </span>
                    {#if event.attributes.service_name}
                      <span class="service-name">
                        {event.attributes.service_name}
                      </span>
                    {/if}
                    <span class="log-level level-{event.attributes.level}">
                      {event.attributes.level?.toUpperCase() || 'INFO'}
                    </span>
                  </div>
                  
                  <div class="event-message">
                    {event.attributes.message || 'No message available'}
                  </div>
                  
                  <div class="event-timestamp">
                    {formatTimestamp(event.attributes.timestamp)}
                  </div>
                </div>
              </div>

              <div class="expand-button">
                {#if isExpanded}
                  <ChevronDown class="w-4 h-4" />
                {:else}
                  <ChevronRight class="w-4 h-4" />
                {/if}
              </div>
            </div>

            {#if isExpanded && event.attributes.details}
              <div class="event-details" transition:slide={{ duration: 200 }}>
                <div class="details-content">
                  {#if typeof event.attributes.details === 'object'}
                    <pre class="json-details">{JSON.stringify(event.attributes.details, null, 2)}</pre>
                  {:else}
                    <div class="text-details">{event.attributes.details}</div>
                  {/if}
                </div>
                
                {#if event.attributes.duration}
                  <div class="event-meta">
                    <span class="meta-label">Duration:</span>
                    <span class="meta-value">{event.attributes.duration}</span>
                  </div>
                {/if}
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Real-time Logs Toggle -->
  {#if showRealTimeLogs}
    <div class="realtime-logs" transition:slide={{ duration: 300 }}>
      <div class="realtime-header">
        <h4>Real-time Container Logs</h4>
        <button onclick={() => showRealTimeLogs = false}>×</button>
      </div>
      <div class="log-stream">
        <div class="log-line">
          <span class="log-timestamp">2024-01-15 10:30:45</span>
          <span class="log-content">Starting application server...</span>
        </div>
        <div class="log-line">
          <span class="log-timestamp">2024-01-15 10:30:46</span>
          <span class="log-content">Database connection established</span>
        </div>
        <div class="log-line">
          <span class="log-timestamp">2024-01-15 10:30:47</span>
          <span class="log-content">Server listening on port 3000</span>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .deployment-logs {
    @apply space-y-6;
  }

  .logs-header {
    @apply flex items-start justify-between;
  }

  .header-actions {
    @apply flex gap-2;
  }

  .btn {
    @apply px-3 py-2 rounded-md font-medium transition-colors duration-200 inline-flex items-center text-sm;
  }

  .btn-sm {
    @apply px-2 py-1 text-xs;
  }

  .btn-outline {
    @apply border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700;
  }

  .btn-outline.active {
    @apply bg-blue-50 border-blue-300 text-blue-700 dark:bg-blue-900/20 dark:border-blue-600 dark:text-blue-400;
  }

  .filters-section {
    @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
    @apply space-y-4;
  }

  .search-bar {
    @apply relative;
  }

  .search-icon {
    @apply absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400;
  }

  .search-input {
    @apply w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md;
    @apply focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white;
  }

  .filter-controls {
    @apply flex flex-wrap gap-3;
  }

  .filter-select {
    @apply px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md;
    @apply focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white;
    @apply text-sm;
  }

  .logs-list {
    @apply min-h-96;
  }

  .empty-state {
    @apply text-center py-12;
  }

  .events-container {
    @apply space-y-2;
  }

  .event-item {
    @apply bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700;
    @apply hover:shadow-sm transition-shadow duration-200;
  }

  .event-item.expanded {
    @apply ring-1 ring-blue-200 dark:ring-blue-800;
  }

  .event-header {
    @apply flex items-center justify-between p-4 cursor-pointer;
  }

  .event-main {
    @apply flex items-start gap-3 flex-1;
  }

  .event-icon {
    @apply flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center;
  }

  .icon-success {
    @apply bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400;
  }

  .icon-error {
    @apply bg-red-100 text-red-600 dark:bg-red-900/20 dark:text-red-400;
  }

  .icon-warning {
    @apply bg-yellow-100 text-yellow-600 dark:bg-yellow-900/20 dark:text-yellow-400;
  }

  .icon-info {
    @apply bg-blue-100 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400;
  }

  .icon-neutral {
    @apply bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400;
  }

  .event-info {
    @apply flex-1 space-y-1;
  }

  .event-title {
    @apply flex items-center gap-2 flex-wrap;
  }

  .event-type {
    @apply font-medium text-gray-900 dark:text-white capitalize;
  }

  .service-name {
    @apply text-sm text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 px-2 py-0.5 rounded;
  }

  .log-level {
    @apply text-xs font-medium px-2 py-0.5 rounded;
  }

  .level-error {
    @apply bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400;
  }

  .level-warning {
    @apply bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400;
  }

  .level-info {
    @apply bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400;
  }

  .level-debug {
    @apply bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300;
  }

  .event-message {
    @apply text-sm text-gray-700 dark:text-gray-300;
  }

  .event-timestamp {
    @apply text-xs text-gray-500 dark:text-gray-400 font-mono;
  }

  .expand-button {
    @apply flex-shrink-0 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300;
  }

  .event-details {
    @apply border-t border-gray-100 dark:border-gray-700 p-4;
  }

  .details-content {
    @apply mb-4;
  }

  .json-details {
    @apply bg-gray-50 dark:bg-gray-700 rounded-md p-3 text-sm font-mono overflow-x-auto;
    @apply text-gray-800 dark:text-gray-200;
  }

  .text-details {
    @apply text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap;
  }

  .event-meta {
    @apply flex gap-4 text-sm;
  }

  .meta-label {
    @apply font-medium text-gray-600 dark:text-gray-400;
  }

  .meta-value {
    @apply text-gray-900 dark:text-white;
  }

  .realtime-logs {
    @apply bg-gray-900 text-green-400 rounded-lg p-4 font-mono text-sm;
    @apply border border-gray-700;
  }

  .realtime-header {
    @apply flex justify-between items-center mb-3 pb-2 border-b border-gray-700;
  }

  .realtime-header h4 {
    @apply text-white font-medium;
  }

  .realtime-header button {
    @apply text-gray-400 hover:text-white text-lg;
  }

  .log-stream {
    @apply space-y-1 max-h-48 overflow-y-auto;
  }

  .log-line {
    @apply flex gap-3;
  }

  .log-timestamp {
    @apply text-gray-500 flex-shrink-0;
  }

  .log-content {
    @apply text-green-400;
  }
</style>