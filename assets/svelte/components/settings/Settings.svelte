<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    auth, 
    ui, 
    apiService 
  } from '../../stores/index';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Separator } from '../../ui/separator';
  import { 
    User, 
    Bell, 
    Shield, 
    Palette, 
    Globe,
    Key,
    Database,
    Save,
    Settings as SettingsIcon
  } from '@lucide/svelte';

  let profileForm = $state({
    name: '',
    email: '',
    avatar: ''
  });

  let settingsForm = $state({
    theme: 'system' as 'light' | 'dark' | 'system',
    language: 'en',
    timezone: 'UTC',
    notifications_enabled: true,
    email_notifications: true
  });

  let loading = $state(false);

  $effect(() => {
    if ($auth.user) {
      profileForm.name = $auth.user.name || '';
      profileForm.email = $auth.user.email || '';
      profileForm.avatar = $auth.user.avatar || '';
      
      if ($auth.user.settings) {
        settingsForm.theme = $auth.user.settings.theme || 'system';
        settingsForm.language = $auth.user.settings.language || 'en';
        settingsForm.timezone = $auth.user.settings.timezone || 'UTC';
        settingsForm.notifications_enabled = $auth.user.settings.notifications_enabled ?? true;
        settingsForm.email_notifications = $auth.user.settings.email_notifications ?? true;
      }
    }
  });

  async function updateProfile() {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.updateProfile(profileForm);
      
      // Update auth state
      auth.update(state => ({
        ...state,
        user: state.user ? { ...state.user, ...profileForm } : null
      }));
    } catch (error) {
      console.error('Failed to update profile:', error);
    } finally {
      loading = false;
    }
  }

  async function updateSettings() {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.updateProfile({ settings: settingsForm });
      
      // Update UI theme
      ui.update(state => ({ ...state, theme: settingsForm.theme }));
      
      // Update auth state
      auth.update(state => ({
        ...state,
        user: state.user ? { 
          ...state.user, 
          settings: { ...state.user.settings, ...settingsForm }
        } : null
      }));
    } catch (error) {
      console.error('Failed to update settings:', error);
    } finally {
      loading = false;
    }
  }

  function setTheme(theme: 'light' | 'dark' | 'system') {
    settingsForm.theme = theme;
    updateSettings();
  }
</script>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-foreground">Settings</h1>
    <p class="text-muted-foreground">
      Manage your account settings and preferences
    </p>
  </div>

  <div class="grid gap-6">
    <!-- Profile Settings -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center space-x-2">
          <User class="h-5 w-5" />
          <span>Profile</span>
        </CardTitle>
        <CardDescription>
          Update your personal information
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <div class="space-y-2">
          <Label for="name">Name</Label>
          <Input
            id="name"
            bind:value={profileForm.name}
            placeholder="Your name"
          />
        </div>
        
        <div class="space-y-2">
          <Label for="email">Email</Label>
          <Input
            id="email"
            type="email"
            bind:value={profileForm.email}
            placeholder="your@email.com"
          />
        </div>
        
        <div class="space-y-2">
          <Label for="avatar">Avatar URL</Label>
          <Input
            id="avatar"
            bind:value={profileForm.avatar}
            placeholder="https://example.com/avatar.jpg"
          />
        </div>
        
        <Button onclick={updateProfile} disabled={loading}>
          <Save class="mr-2 h-4 w-4" />
          {loading ? 'Saving...' : 'Save Profile'}
        </Button>
      </CardContent>
    </Card>

    <!-- Appearance Settings -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center space-x-2">
          <Palette class="h-5 w-5" />
          <span>Appearance</span>
        </CardTitle>
        <CardDescription>
          Customize how the application looks
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <div class="space-y-2">
          <Label>Theme</Label>
          <div class="flex space-x-2">
            <Button
              variant={settingsForm.theme === 'light' ? 'default' : 'outline'}
              size="sm"
              onclick={() => setTheme('light')}
            >
              Light
            </Button>
            <Button
              variant={settingsForm.theme === 'dark' ? 'default' : 'outline'}
              size="sm"
              onclick={() => setTheme('dark')}
            >
              Dark
            </Button>
            <Button
              variant={settingsForm.theme === 'system' ? 'default' : 'outline'}
              size="sm"
              onclick={() => setTheme('system')}
            >
              System
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>

    <!-- Notification Settings -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center space-x-2">
          <Bell class="h-5 w-5" />
          <span>Notifications</span>
        </CardTitle>
        <CardDescription>
          Manage how you receive notifications
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <div class="flex items-center justify-between">
          <div class="space-y-0.5">
            <Label class="text-base">Push Notifications</Label>
            <p class="text-sm text-muted-foreground">
              Receive notifications in your browser
            </p>
          </div>
          <input
            type="checkbox"
            bind:checked={settingsForm.notifications_enabled}
            onchange={updateSettings}
            class="rounded border-gray-300"
          />
        </div>
        
        <Separator />
        
        <div class="flex items-center justify-between">
          <div class="space-y-0.5">
            <Label class="text-base">Email Notifications</Label>
            <p class="text-sm text-muted-foreground">
              Receive notifications via email
            </p>
          </div>
          <input
            type="checkbox"
            bind:checked={settingsForm.email_notifications}
            onchange={updateSettings}
            class="rounded border-gray-300"
          />
        </div>
      </CardContent>
    </Card>

    <!-- Localization Settings -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center space-x-2">
          <Globe class="h-5 w-5" />
          <span>Localization</span>
        </CardTitle>
        <CardDescription>
          Set your language and timezone preferences
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <div class="space-y-2">
          <Label for="language">Language</Label>
          <select
            id="language"
            bind:value={settingsForm.language}
            onchange={updateSettings}
            class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <option value="en">English</option>
            <option value="es">Español</option>
            <option value="fr">Français</option>
            <option value="de">Deutsch</option>
            <option value="ja">日本語</option>
            <option value="zh">中文</option>
          </select>
        </div>
        
        <div class="space-y-2">
          <Label for="timezone">Timezone</Label>
          <select
            id="timezone"
            bind:value={settingsForm.timezone}
            onchange={updateSettings}
            class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <option value="UTC">UTC</option>
            <option value="America/New_York">Eastern Time</option>
            <option value="America/Chicago">Central Time</option>
            <option value="America/Denver">Mountain Time</option>
            <option value="America/Los_Angeles">Pacific Time</option>
            <option value="Europe/London">London</option>
            <option value="Europe/Paris">Paris</option>
            <option value="Asia/Tokyo">Tokyo</option>
            <option value="Asia/Shanghai">Shanghai</option>
          </select>
        </div>
      </CardContent>
    </Card>

    <!-- Security Settings -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center space-x-2">
          <Shield class="h-5 w-5" />
          <span>Security</span>
        </CardTitle>
        <CardDescription>
          Manage your account security
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <Button variant="outline" disabled>
          <Key class="mr-2 h-4 w-4" />
          Change Password
        </Button>
        
        <Button variant="outline" disabled>
          <Shield class="mr-2 h-4 w-4" />
          Two-Factor Authentication
        </Button>
        
        <Button variant="outline" disabled>
          <Database class="mr-2 h-4 w-4" />
          API Keys
        </Button>
      </CardContent>
    </Card>

    <!-- Danger Zone -->
    <Card class="border-destructive">
      <CardHeader>
        <CardTitle class="text-destructive">Danger Zone</CardTitle>
        <CardDescription>
          These actions cannot be undone
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Button variant="destructive" disabled>
          Delete Account
        </Button>
      </CardContent>
    </Card>
  </div>
</div>