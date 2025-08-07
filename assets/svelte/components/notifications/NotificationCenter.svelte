<script lang="ts">
  import { onMount } from 'svelte';
  import {
    notifications,
    auth,
    apiService
  } from '../../stores/index';
  import type { Notification } from '../../types';
  import { Button } from '../../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Badge } from '../../ui/badge';
  import { Separator } from '../../ui/separator';
  import {
    Bell,
    Check,
    CheckCheck,
    Trash2,
    Info,
    CheckCircle,
    AlertTriangle,
    XCircle,
    Clock,
    User,
    Settings,
    Zap,
    FileText,
    BookOpen,
    Users,
    Building
  } from '@lucide/svelte';

  let loading = $state(false);
  let filter = $state('all'); // all, unread, read

  const notificationsData = $derived($notifications.notifications || []);
  const filteredNotifications = $derived(notificationsData.filter(notification => {
    if (filter === 'unread') return !notification.read;
    if (filter === 'read') return notification.read;
    return true;
  }));

  onMount(async () => {
    if ($apiService) {
      await loadNotifications();
    }
  });

  async function loadNotifications() {
    if (!$apiService) return;
    await notifications.load($apiService);
  }

  async function markAsRead(notification: Notification) {
    if (!$apiService || notification.read) return;

    try {
      loading = true;
      await notifications.markRead($apiService, notification.id);
    } catch (error) {
      console.error('Failed to mark notification as read:', error);
    } finally {
      loading = false;
    }
  }

  async function markAllAsRead() {
    if (!$apiService) return;

    try {
      loading = true;
      await notifications.markAllRead($apiService);
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error);
    } finally {
      loading = false;
    }
  }

  function getNotificationIcon(type: string) {
    switch (type) {
      case 'info':
        return Info;
      case 'success':
        return CheckCircle;
      case 'warning':
        return AlertTriangle;
      case 'error':
        return XCircle;
      default:
        return Bell;
    }
  }

  function getNotificationBadgeVariant(type: string) {
    switch (type) {
      case 'info':
        return 'secondary';
      case 'success':
        return 'default';
      case 'warning':
        return 'outline';
      case 'error':
        return 'destructive';
      default:
        return 'outline';
    }
  }

  function getResourceIcon(data: any) {
    if (!data) return Bell;

    const resourceType = data.resource_type || data.type;
    switch (resourceType) {
      case 'team':
        return Building;
      case 'workspace':
        return Users;
      case 'document':
        return FileText;
      case 'notebook':
        return BookOpen;
      case 'user':
        return User;
      case 'execution':
        return Zap;
      default:
        return Bell;
    }
  }

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60);

    if (diffInHours < 1) {
      const diffInMinutes = Math.floor(diffInHours * 60);
      return diffInMinutes <= 0 ? 'Just now' : `${diffInMinutes}m ago`;
    } else if (diffInHours < 24) {
      return `${Math.floor(diffInHours)}h ago`;
    } else if (diffInHours < 48) {
      return 'Yesterday';
    } else {
      return date.toLocaleDateString();
    }
  }

  function isExpired(notification: Notification): boolean {
    if (!notification.expires_at) return false;
    return new Date(notification.expires_at) < new Date();
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
    <div>
      <h1 class="text-2xl font-bold text-foreground">Notifications</h1>
      <p class="text-muted-foreground">
        Stay updated with your team's activity
      </p>
    </div>

    <div class="flex items-center gap-2">
      {#if $notifications.unreadCount > 0}
        <Button variant="outline" onclick={markAllAsRead} disabled={loading}>
          <CheckCheck class="mr-2 h-4 w-4" />
          Mark All Read
        </Button>
      {/if}

      <Button variant="outline" onclick={loadNotifications} disabled={loading}>
        <Bell class="mr-2 h-4 w-4" />
        Refresh
      </Button>
    </div>
  </div>

  <!-- Filters -->
  <Card>
    <CardContent class="p-4">
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium">Filter:</span>
        <div class="flex rounded-md border border-input">
          <Button
            variant={filter === 'all' ? 'default' : 'ghost'}
            size="sm"
            class="rounded-r-none"
            onclick={() => filter = 'all'}
          >
            All ({notificationsData.length})
          </Button>
          <Button
            variant={filter === 'unread' ? 'default' : 'ghost'}
            size="sm"
            class="rounded-none"
            onclick={() => filter = 'unread'}
          >
            Unread ({$notifications.unreadCount})
          </Button>
          <Button
            variant={filter === 'read' ? 'default' : 'ghost'}
            size="sm"
            class="rounded-l-none"
            onclick={() => filter = 'read'}
          >
            Read ({notificationsData.length - $notifications.unreadCount})
          </Button>
        </div>
      </div>
    </CardContent>
  </Card>

  <!-- Notifications List -->
  <div class="space-y-2">
    {#each filteredNotifications as notification (notification.id)}
      <Card
        class="cursor-pointer transition-all hover:shadow-md {!notification.read ? 'bg-muted/20' : ''} {isExpired(notification) ? 'opacity-60' : ''}"
      >
        <CardContent class="p-4">
          <div class="flex items-start space-x-4">
            <!-- Icon -->
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10">
              <svelte:component
                this={notification.data ? getResourceIcon(notification.data) : getNotificationIcon(notification.type)}
                class="h-5 w-5 text-primary"
              />
            </div>

            <!-- Content -->
            <div class="flex-1 min-w-0">
              <div class="flex items-start justify-between">
                <div class="min-w-0 flex-1">
                  <h3 class="font-medium text-foreground">{notification.title}</h3>
                  <p class="text-sm text-muted-foreground mt-1">{notification.message}</p>

                  <!-- Metadata -->
                  <div class="flex items-center space-x-4 mt-2 text-xs text-muted-foreground">
                    <div class="flex items-center">
                      <Clock class="mr-1 h-3 w-3" />
                      {formatDate(notification.created_at)}
                    </div>

                    {#if notification.expires_at}
                      <div class="flex items-center">
                        <AlertTriangle class="mr-1 h-3 w-3" />
                        Expires {formatDate(notification.expires_at)}
                      </div>
                    {/if}
                  </div>
                </div>

                <div class="flex items-center space-x-2 ml-4">
                  <Badge variant={getNotificationBadgeVariant(notification.type)} class="text-xs">
                    {notification.type}
                  </Badge>

                  {#if !notification.read}
                    <Button
                      variant="ghost"
                      size="sm"
                      onclick={() => markAsRead(notification)}
                      disabled={loading}
                    >
                      <Check class="h-4 w-4" />
                    </Button>
                  {/if}
                </div>
              </div>

              <!-- Additional Data -->
              {#if notification.data && Object.keys(notification.data).length > 0}
                <div class="mt-3 p-2 rounded-md bg-muted/50">
                  <div class="text-xs text-muted-foreground">
                    {#if notification.data.resource_title}
                      <div class="font-medium">{notification.data.resource_title}</div>
                    {/if}
                    {#if notification.data.workspace_name}
                      <div>Workspace: {notification.data.workspace_name}</div>
                    {/if}
                    {#if notification.data.team_name}
                      <div>Team: {notification.data.team_name}</div>
                    {/if}
                  </div>
                </div>
              {/if}
            </div>
          </div>
        </CardContent>
      </Card>
    {:else}
      <Card>
        <CardContent class="flex flex-col items-center justify-center py-12">
          <Bell class="h-12 w-12 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">
            {filter === 'unread' ? 'No unread notifications' :
             filter === 'read' ? 'No read notifications' :
             'No notifications'}
          </h3>
          <p class="text-muted-foreground text-center">
            {filter === 'unread'
              ? 'You\'re all caught up! New notifications will appear here.'
              : filter === 'read'
              ? 'No notifications have been read yet.'
              : 'You don\'t have any notifications yet. Activity will appear here.'
            }
          </p>
        </CardContent>
      </Card>
    {/each}
  </div>

  <!-- Notification Settings -->
  <Card>
    <CardHeader>
      <CardTitle class="flex items-center space-x-2">
        <Settings class="h-5 w-5" />
        <span>Notification Preferences</span>
      </CardTitle>
      <CardDescription>
        Manage how you receive notifications
      </CardDescription>
    </CardHeader>
    <CardContent class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <div class="font-medium">Push Notifications</div>
          <div class="text-sm text-muted-foreground">
            Receive notifications in your browser
          </div>
        </div>
        <input
          type="checkbox"
          checked
          disabled
          class="rounded border-gray-300"
        />
      </div>

      <Separator />

      <div class="flex items-center justify-between">
        <div>
          <div class="font-medium">Email Notifications</div>
          <div class="text-sm text-muted-foreground">
            Receive important notifications via email
          </div>
        </div>
        <input
          type="checkbox"
          checked
          disabled
          class="rounded border-gray-300"
        />
      </div>

      <Separator />

      <div class="flex items-center justify-between">
        <div>
          <div class="font-medium">Team Activity</div>
          <div class="text-sm text-muted-foreground">
            Get notified about team member activity
          </div>
        </div>
        <input
          type="checkbox"
          checked
          disabled
          class="rounded border-gray-300"
        />
      </div>

      <div class="flex items-center justify-between">
        <div>
          <div class="font-medium">Execution Alerts</div>
          <div class="text-sm text-muted-foreground">
            Get notified when notebook executions complete
          </div>
        </div>
        <input
          type="checkbox"
          checked
          disabled
          class="rounded border-gray-300"
        />
      </div>
    </CardContent>
  </Card>
</div>