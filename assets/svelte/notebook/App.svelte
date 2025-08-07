<script lang="ts">
 import type { LiveSvelteProps } from 'live_svelte';
 import { writable } from 'svelte/store';
 import { onMount, onDestroy } from 'svelte';
 import Editor from '../Editor.svelte';

 interface NotebookData {
  id: string;
  title: string;
  content: string;
  status: 'idle' | 'running' | 'completed' | 'error';
  extracted_tasks: Task[];
  execution_state: Record<string, TaskExecution>;
  collaborative_mode: boolean;
  kernel_status: 'idle' | 'busy' | 'starting' | 'stopping';
  environment_variables: Record<string, string>;
  execution_timeout: number;
  created_at: string;
  updated_at: string;
  user: {
   id: string;
   name: string;
  };
 }

 interface Task {
  id: string;
  language: string;
  code: string;
  executable: boolean;
 }

 interface TaskExecution {
  status: 'idle' | 'running' | 'completed' | 'error';
  output?: string;
  error?: string;
  started_at?: string;
  completed_at?: string;
 }

 interface NotebookModel {
  notebook: NotebookData;
 }

 type Props = LiveSvelteProps<NotebookModel>;

 let { notebook, socket } = $props<Props>();

 // Reactive stores
 let content = writable(notebook.content);
 let extractedTasks = writable<Task[]>(notebook.extracted_tasks || []);
 let executionState = writable<Record<string, TaskExecution>>(notebook.execution_state || {});
 let collaborativeMode = writable(notebook.collaborative_mode || false);
 let kernelStatus = writable(notebook.kernel_status || 'idle');
 let isDirty = writable(false);
 let saving = writable(false);
 let executing = writable(false);
 let connectedUsers = writable<any[]>([]);
 let taskOutputs = writable<Record<string, string>>({});

 // UI state
 let showSidebar = writable(true);
 let selectedLanguage = writable('python');
 let lastSaved = writable<Date | null>(null);

 // Autosave management
 let autoSaveTimeout: NodeJS.Timeout | null = null;
 let hasUnsavedChanges = writable(false);

 // Editor component from elim handles its own state
 // No direct editor reference needed

 function handleContentChange(event: CustomEvent<string>) {
  const newContent = event.detail;

  content.set(newContent);
  isDirty.set(true);
  hasUnsavedChanges.set(true);

  // Extract tasks from new content
  extractTasksFromContent(newContent);
 }

 // Remove unused handlers - Editor component handles saving internally
 // and we don't need direct editor access for this implementation

 function extractTasksFromContent(contentStr: string) {
  const tasks: Task[] = [];
  const codeBlocks = contentStr.split('```');

  for (let i = 1; i < codeBlocks.length; i += 2) {
   const block = codeBlocks[i];
   const lines = block.split('\n');
   const language = lines[0]?.trim() || 'text';
   const code = lines.slice(1).join('\n').trim();

   if (isExecutableLanguage(language) && code.length > 0) {
    tasks.push({
     id: generateTaskId(),
     language,
     code,
     executable: true
    });
   }
  }

  extractedTasks.set(tasks);
 }

 function isExecutableLanguage(lang: string): boolean {
  return ['python', 'elixir', 'javascript', 'typescript', 'bash', 'shell', 'sql', 'r', 'julia'].includes(lang.toLowerCase());
 }

 function generateTaskId(): string {
  return Math.random().toString(36).substring(2, 15);
 }

 async function saveNotebook(contentStr?: string, html?: string) {
  if ($saving) return;

  saving.set(true);

  try {
   const saveContent = contentStr || $content;

   if (socket) {
    socket.pushEvent('save_notebook', {
     content: saveContent,
     html: html || ''
    });
   }

   lastSaved.set(new Date());
   isDirty.set(false);
   hasUnsavedChanges.set(false);
  } catch (error) {
   console.error('Failed to save notebook:', error);
  } finally {
   saving.set(false);
  }
 }

 async function executeTask(task: Task) {
  if (!task || $executing) return;

  executing.set(true);

  try {
   // Update execution state
   executionState.update(state => ({
    ...state,
    [task.id]: {
     status: 'running',
     started_at: new Date().toISOString()
    }
   }));

   if (socket) {
    socket.pushEvent('execute_task', {
     task_id: task.id,
     code: task.code,
     language: task.language
    });
   }
  } catch (error) {
   console.error('Failed to execute task:', error);

   executionState.update(state => ({
    ...state,
    [task.id]: {
     status: 'error',
     error: error.message,
     completed_at: new Date().toISOString()
    }
   }));
  } finally {
   executing.set(false);
  }
 }

 async function toggleCollaborativeMode() {
  try {
   const newMode = !$collaborativeMode;

   if (socket) {
    socket.pushEvent('toggle_collaborative_mode', {
     enabled: newMode
    });
   }

   collaborativeMode.set(newMode);
  } catch (error) {
   console.error('Failed to toggle collaborative mode:', error);
  }
 }

 async function exportNotebook(format: 'html' | 'md' | 'ipynb') {
  try {
   if (socket) {
    socket.pushEvent('export_notebook', { format });
   }
  } catch (error) {
   console.error('Failed to export notebook:', error);
  }
 }

 function insertCodeBlock(language: string = 'python') {
  // TODO: Implement code block insertion with elim Editor
  // The elim Editor component handles its own toolbar and code insertion
  console.log('Code block insertion requested for language:', language);

  // For now, we'll append to the content directly
  const template = getCodeTemplate(language);
  const codeBlock = `\n\`\`\`${language}\n${template}\n\`\`\`\n`;
  content.update(current => current + codeBlock);
 }

 function getCodeTemplate(language: string): string {
  const templates: Record<string, string> = {
   python: '# Your Python code here\nprint("Hello, World!")',
   elixir: '# Your Elixir code here\nIO.puts("Hello, World!")',
   javascript: '// Your JavaScript code here\nconsole.log("Hello, World!");',
   bash: '# Your Bash script here\necho "Hello, World!"'
  };

  return templates[language] || '# Your code here';
 }

 function formatDate(date: Date | null): string {
  if (!date) return 'Never';
  return date.toLocaleTimeString();
 }

 // Socket event handlers
 onMount(() => {
  if (socket) {
   // Listen for task execution updates
   socket.addEventListener('task_execution_completed', (event: CustomEvent) => {
    const { task_id, output } = event.detail;

    executionState.update(state => ({
     ...state,
     [task_id]: {
      status: 'completed',
      output,
      completed_at: new Date().toISOString()
     }
    }));

    taskOutputs.update(outputs => ({
     ...outputs,
     [task_id]: output
    }));
   });

   socket.addEventListener('task_execution_failed', (event: CustomEvent) => {
    const { task_id, error } = event.detail;

    executionState.update(state => ({
     ...state,
     [task_id]: {
      status: 'error',
      error,
      completed_at: new Date().toISOString()
     }
    }));
   });

   socket.addEventListener('user_joined', (event: CustomEvent) => {
    const { user } = event.detail;
    connectedUsers.update(users => [...users, user]);
   });

   socket.addEventListener('user_left', (event: CustomEvent) => {
    const { user } = event.detail;
    connectedUsers.update(users => users.filter(u => u.id !== user.id));
   });

   socket.addEventListener('content_updated', (event: CustomEvent) => {
    const { content: newContent } = event.detail;
    content.set(newContent);
   });
  }
 });

 onDestroy(() => {
  if (autoSaveTimeout) {
   clearTimeout(autoSaveTimeout);
  }
 });
</script>

<div class="notebook-app h-screen flex flex-col bg-gray-50">
 <!-- Header -->
 <div class="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
  <div class="flex items-center space-x-4">
   <h1 class="text-xl font-semibold text-gray-900">
    {notebook.title}
   </h1>

   {#if $hasUnsavedChanges}
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
     <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 8 8">
      <circle cx="4" cy="4" r="3" />
     </svg>
     Unsaved changes
    </span>
   {/if}

   {#if $saving}
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
     <svg class="animate-spin -ml-1 mr-2 h-3 w-3 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
     </svg>
     Saving...
    </span>
   {/if}

   {#if $executing}
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
     <svg class="animate-spin -ml-1 mr-2 h-3 w-3 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
     </svg>
     Executing...
    </span>
   {/if}

   <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
    {$kernelStatus}
   </span>
  </div>

  <div class="flex items-center space-x-3">
   <label class="inline-flex items-center">
    <input
     type="checkbox"
     checked={$collaborativeMode}
     onchange={toggleCollaborativeMode}
     class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
    />
    <span class="ml-2 text-sm text-gray-700">Collaborative</span>
   </label>

   {#if $collaborativeMode && $connectedUsers.length > 0}
    <div class="flex items-center space-x-1">
     <div class="flex -space-x-2">
      {#each $connectedUsers.slice(0, 3) as user}
       <div class="inline-block h-6 w-6 rounded-full bg-gray-300 ring-2 ring-white flex items-center justify-center text-xs font-medium text-gray-700">
        {user.name.charAt(0)}
       </div>
      {/each}
      {#if $connectedUsers.length > 3}
       <div class="inline-block h-6 w-6 rounded-full bg-gray-400 ring-2 ring-white flex items-center justify-center text-xs font-medium text-white">
        +{$connectedUsers.length - 3}
       </div>
      {/if}
     </div>
    </div>
   {/if}

   <div class="flex items-center space-x-2">
    <button
     onclick={() => exportNotebook('html')}
     class="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
    >
     <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12"></path>
     </svg>
     Export
    </button>

    <div class="relative">
     <button
      onclick={() => showSidebar.update(s => !s)}
      class="p-1.5 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded"
     >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7"></path>
      </svg>
     </button>
    </div>
   </div>
  </div>
 </div>

 <!-- Toolbar -->
 <div class="bg-white border-b border-gray-200 px-6 py-3">
  <div class="flex items-center justify-between">
   <div class="flex items-center space-x-4">
    <!-- Notebook controls will be handled by the Editor component from elim -->
   </div>

   <div class="flex items-center space-x-4">
    <button
     onclick={() => saveNotebook()}
     disabled={$saving || !$isDirty}
     class="px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
    >
     Save
    </button>

    <div class="text-sm text-gray-500">
     Last saved: {formatDate($lastSaved)}
    </div>
   </div>
  </div>
 </div>

 <!-- Main content -->
 <div class="flex-1 flex overflow-hidden">
  <!-- Editor -->
  <div class="flex-1 flex flex-col">
   <Editor
    initialContent={$content}
    editable={true}
    placeholder="Start writing your notebook..."
    className="flex-1"
    oncontentchange={handleContentChange}
   />
  </div>

  <!-- Sidebar -->
  {#if $showSidebar}
   <div class="w-80 bg-white border-l border-gray-200 flex flex-col">
    <div class="p-4 border-b border-gray-200">
     <h3 class="text-lg font-medium text-gray-900">Notebook Info</h3>
    </div>

    <div class="flex-1 p-4 space-y-6 overflow-y-auto">
     <!-- Tasks -->
     <div>
      <h4 class="text-sm font-medium text-gray-700 mb-3">Executable Tasks</h4>
      <div class="space-y-2">
       {#each $extractedTasks as task, index}
        <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
         <div class="flex items-center space-x-2">
          <div class="text-xs font-mono bg-gray-200 px-2 py-1 rounded">
           {task.language}
          </div>
          <span class="text-sm text-gray-600">Task {index + 1}</span>
         </div>

         <div class="flex items-center space-x-2">
          {#if $executionState[task.id]}
           {#if $executionState[task.id].status === 'running'}
            <div class="h-2 w-2 bg-yellow-400 rounded-full animate-pulse"></div>
            <span class="text-xs text-yellow-600">Running</span>
           {:else if $executionState[task.id].status === 'completed'}
            <div class="h-2 w-2 bg-green-400 rounded-full"></div>
            <span class="text-xs text-green-600">Done</span>
           {:else if $executionState[task.id].status === 'error'}
            <div class="h-2 w-2 bg-red-400 rounded-full"></div>
            <span class="text-xs text-red-600">Error</span>
           {/if}
          {:else}
           <div class="h-2 w-2 bg-gray-300 rounded-full"></div>
           <span class="text-xs text-gray-500">Ready</span>
          {/if}

          <button
           onclick={() => executeTask(task)}
           disabled={$executing}
           class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200 disabled:opacity-50"
          >
           Run
          </button>
         </div>
        </div>

        {#if $taskOutputs[task.id]}
         <div class="ml-4 p-2 bg-gray-100 rounded text-xs font-mono">
          <pre class="whitespace-pre-wrap">{$taskOutputs[task.id]}</pre>
         </div>
        {/if}
       {/each}

       {#if $extractedTasks.length === 0}
        <p class="text-sm text-gray-500">No executable tasks found</p>
       {/if}
      </div>
     </div>

     <!-- Connected Users -->
     {#if $collaborativeMode}
      <div>
       <h4 class="text-sm font-medium text-gray-700 mb-3">Connected Users</h4>
       <div class="space-y-2">
        {#each $connectedUsers as user}
         <div class="flex items-center space-x-2">
          <div class="h-6 w-6 rounded-full bg-green-500 flex items-center justify-center text-xs font-medium text-white">
           {user.name.charAt(0)}
          </div>
          <span class="text-sm text-gray-700">{user.name}</span>
          <div class="h-2 w-2 rounded-full bg-green-400"></div>
         </div>
        {/each}

        {#if $connectedUsers.length === 0}
         <p class="text-sm text-gray-500">No other users connected</p>
        {/if}
       </div>
      </div>
     {/if}

     <!-- Metadata -->
     <div>
      <h4 class="text-sm font-medium text-gray-700 mb-3">Metadata</h4>
      <div class="text-sm text-gray-600 space-y-1">
       <div>Created: {new Date(notebook.created_at).toLocaleString()}</div>
       <div>Updated: {new Date(notebook.updated_at).toLocaleString()}</div>
       <div>Author: {notebook.user.name}</div>
      </div>
     </div>
    </div>
   </div>
  {/if}
 </div>
</div>
