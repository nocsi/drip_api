# Kyozo Notebook Features Documentation

This document provides comprehensive documentation for the advanced notebook features implemented in Kyozo, including TipTap editor integration, blob storage system, autosaving, and collaborative editing.

## Table of Contents

1. [Overview](#overview)
2. [TipTap Editor Integration](#tiptap-editor-integration)
3. [Blob Storage System](#blob-storage-system)
4. [Autosaving Features](#autosaving-features)
5. [Collaborative Editing](#collaborative-editing)
6. [Code Execution](#code-execution)
7. [Export & Import](#export--import)
8. [Testing](#testing)
9. [Development Setup](#development-setup)
10. [API Reference](#api-reference)

## Overview

Kyozo's notebook system provides a Jupyter-like experience with real-time collaboration, advanced editing capabilities, and efficient content storage. The system is built on:

- **Phoenix LiveView** for real-time communication
- **Svelte 5** for reactive frontend components
- **TipTap** for rich text editing
- **Content-addressable blob storage** for efficient data management
- **Ash Framework** for robust data layer

## TipTap Editor Integration

### Features

The TipTap editor provides a rich markdown editing experience with:

- **Syntax highlighting** for code blocks
- **Task lists** with checkboxes
- **Tables** with resizable columns
- **Images** and **links**
- **Typography** enhancements
- **Collaborative cursors** (when enabled)
- **Real-time synchronization**

### Editor Components

#### TipTapEditor.svelte

The main editor component with features:

```typescript
// Props
export let content: string = '';
export let placeholder: string = 'Start writing...';
export let editable: boolean = true;
export let autosave: boolean = true;
export let autosaveDelay: number = 2000;
export let socket: any = null;

// Events
dispatch('update', { content, html });
dispatch('save', { content, html });
dispatch('ready', { editor });
```

#### TipTapToolbar.svelte

Rich toolbar with formatting options:

- **Text formatting**: Bold, italic, strikethrough, highlight
- **Headings**: H1, H2, H3
- **Lists**: Bullet, numbered, task lists
- **Code blocks**: With language selection
- **Tables**: Insertable with custom dimensions
- **Media**: Images and links
- **History**: Undo/redo

### Usage Example

```svelte
<TipTapEditor
  bind:content={documentContent}
  editable={true}
  autosave={true}
  autosaveDelay={2000}
  placeholder="Start writing your notebook..."
  {socket}
  on:update={handleContentChange}
  on:save={handleSave}
  on:ready={handleEditorReady}
/>
```

### Supported Languages

Code blocks support syntax highlighting for:

- **Python** - Full execution support
- **Elixir** - Native execution in BEAM
- **JavaScript/TypeScript** - Execution via Node.js
- **Bash/Shell** - System command execution
- **SQL** - Query execution (with database connection)
- **R, Julia** - External runtime execution
- **HTML, CSS, JSON** - Syntax highlighting only

## Blob Storage System

### Architecture

The blob storage system uses content-addressable storage with SHA-256 hashing for deduplication:

```
Document -> DocumentBlobRef -> Blob -> Storage Backend
                    |
                    ├─ content (SHA-256: abc123...)
                    ├─ attachment (SHA-256: def456...)
                    └─ preview (SHA-256: ghi789...)
```

### Storage Backends

#### Disk Storage (Development)

```elixir
# Configuration
config :kyozo,
  blob_storage_backend: :disk,
  blob_storage_root: "priv/storage/blobs"
```

Storage path structure:
```
priv/storage/blobs/
├── ab/
│   └── cdef1234567890...
├── cd/
│   └── ef1234567890ab...
└── ...
```

#### S3 Storage (Production)

```elixir
# Configuration
config :kyozo, :s3_storage,
  bucket: "kyozo-production-storage",
  region: "us-east-1"

config :kyozo,
  blob_storage_backend: :s3
```

Features:
- **Automatic failover** between storage backends
- **Migration tools** for moving between storage types
- **Connection testing** and health checks
- **Configurable regions** and endpoints

### Blob Management

#### Creating Blobs

```elixir
# Direct blob creation
{:ok, blob} = Workspaces.create_blob(
  content: "Document content",
  content_type: "text/markdown"
)

# Find or create (deduplication)
{:ok, blob} = Workspaces.find_or_create_blob(
  content: "Document content",
  content_type: "text/markdown"
)
```

#### Document Integration

```elixir
# Link content to document
{:ok, ref} = DocumentBlobRef.create_content_ref(
  document.id,
  content,
  "text/markdown"
)

# Update document content
{:ok, ref} = DocumentBlobRef.update_document_content(
  document.id,
  new_content,
  "text/markdown"
)

# Retrieve document content
{:ok, content} = DocumentBlobRef.get_document_content(document.id)
```

### Deduplication Benefits

- **Storage efficiency**: Identical content stored once
- **Version control**: Track content changes via blob references
- **Caching**: Content-addressable caching strategies
- **Integrity**: SHA-256 ensures content integrity

## Autosaving Features

### Client-Side Autosave

The TipTap editor implements intelligent autosaving:

```typescript
function scheduleAutosave(content: string, html: string) {
  if (autosaveTimeout) {
    clearTimeout(autosaveTimeout);
  }

  autosaveTimeout = setTimeout(() => {
    saveContent(content, html);
  }, autosaveDelay);
}
```

### Server-Side Processing

LiveView handles autosave requests:

```elixir
def handle_event("save_content", %{"content" => content, "html" => html}, socket) do
  case save_notebook_content(socket, content, html) do
    {:ok, updated_notebook} ->
      socket =
        socket
        |> assign(:notebook, updated_notebook)
        |> assign(:last_saved_at, DateTime.utc_now())
        |> push_event("save_success", %{saved_at: DateTime.utc_now()})

      {:noreply, socket}

    {:error, reason} ->
      socket = push_event(socket, "save_error", %{error: reason})
      {:noreply, socket}
  end
end
```

### Save Indicators

Visual feedback for save status:

- 🟡 **Unsaved changes** - Yellow indicator
- 🔵 **Saving...** - Blue spinner
- 🟢 **Saved** - Success confirmation
- 🔴 **Error** - Save failure notification

## Collaborative Editing

### Real-Time Synchronization

Using Phoenix PubSub for collaboration:

```elixir
# Subscribe to notebook updates
Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook_id}")
Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook_id}:collaboration")

# Broadcast content changes
Phoenix.PubSub.broadcast(
  Kyozo.PubSub,
  "notebook:#{notebook.id}",
  {:content_updated, content}
)
```

### User Presence

Track connected users:

```typescript
// User joins collaborative session
socket.addEventListener('user_joined', (event) => {
  const { user } = event.detail;
  connectedUsers.update(users => [...users, user]);
});

// User leaves session
socket.addEventListener('user_left', (event) => {
  const { user } = event.detail;
  connectedUsers.update(users => users.filter(u => u.id !== user.id));
});
```

### Conflict Resolution

The system handles conflicts through:

1. **Last-write-wins** for simple conflicts
2. **Operational transformation** for concurrent edits
3. **Version vectors** for complex merge scenarios
4. **Manual resolution** UI for irreconcilable conflicts

## Code Execution

### Execution Pipeline

1. **Task Extraction**: Parse code blocks from markdown
2. **Language Detection**: Identify executable languages
3. **Sandbox Execution**: Run code in isolated environment
4. **Result Capture**: Stream output back to client
5. **UI Update**: Display results in notebook

### Execution Engines

#### Python Execution

```elixir
defp execute_task(%{language: "python", code: code}) do
  case System.cmd("python3", ["-c", code], stderr_to_stdout: true) do
    {output, 0} -> {:ok, output}
    {error, _} -> {:error, error}
  end
end
```

#### Elixir Execution

```elixir
defp execute_task(%{language: "elixir", code: code}) do
  try do
    {result, _} = Code.eval_string(code)
    {:ok, inspect(result)}
  rescue
    error -> {:error, Exception.message(error)}
  end
end
```

#### Bash Execution

```elixir
defp execute_task(%{language: language, code: code}) when language in ["bash", "shell"] do
  case System.cmd("bash", ["-c", code], stderr_to_stdout: true) do
    {output, 0} -> {:ok, output}
    {error, _} -> {:error, error}
  end
end
```

### Security Considerations

- **Sandboxed execution** environments
- **Resource limits** (CPU, memory, time)
- **Network restrictions** for untrusted code
- **File system isolation**
- **User permission** checks

## Export & Import

### Export Formats

#### HTML Export

```elixir
def export_notebook(notebook, "html") do
  case DocumentBlobRef.get_document_content(notebook.document_id) do
    {:ok, content} ->
      {:ok, html} = render_markdown_content(content)

      full_html = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>#{notebook.title}</title>
        <meta charset="utf-8">
        <style>#{export_styles()}</style>
      </head>
      <body>
        <h1>#{notebook.title}</h1>
        #{html}
      </body>
      </html>
      """

      {:ok, full_html}
  end
end
```

#### Jupyter Notebook Export

```elixir
def export_notebook(notebook, "ipynb") do
  {:ok, content} = DocumentBlobRef.get_document_content(notebook.document_id)

  cells = content
  |> parse_markdown_cells()
  |> Enum.map(&convert_to_jupyter_cell/1)

  notebook_json = %{
    "cells" => cells,
    "metadata" => %{
      "kernelspec" => %{
        "display_name" => "Python 3",
        "language" => "python",
        "name" => "python3"
      }
    },
    "nbformat" => 4,
    "nbformat_minor" => 4
  }

  {:ok, Jason.encode!(notebook_json, pretty: true)}
end
```

### Import Capabilities

- **Markdown files** (.md)
- **Jupyter notebooks** (.ipynb)
- **Plain text** files
- **Code files** (automatically wrapped in code blocks)

## Testing

### Test Structure

```
test/
├── kyozo/
│   └── workspaces/
│       ├── blob_test.exs
│       └── document_blob_ref_test.exs
└── kyozo_web/
    └── live/
        └── notebook/
            └── editor_test.exs
```

### Running Tests

```bash
# All tests
mix test

# Blob storage tests
mix test test/kyozo/workspaces/blob_test.exs

# LiveView integration tests
mix test test/kyozo_web/live/notebook/editor_test.exs

# S3 integration tests (requires setup)
S3_BUCKET=test-bucket mix test --only integration
```

### Test Fixtures

```elixir
# Create test notebook with content
notebook = notebook_with_content_fixture(%{
  user: user,
  workspace: workspace,
  content: sample_markdown_content()
})

# Create blob storage test data
blob = blob_fixture(%{
  content: "Test content",
  content_type: "text/markdown"
})
```

## Development Setup

### Prerequisites

- **Elixir** 1.15+
- **Phoenix** 1.7+
- **Node.js** 18+ (for Svelte/Vite)
- **PostgreSQL** 13+
- **Redis** (for PubSub, optional)

### Environment Setup

```bash
# Install dependencies
mix deps.get
cd assets && pnpm install

# Setup database
mix ecto.setup

# Generate development data
mix run priv/repo/seeds.exs

# Start development server
mix phx.server
```

### Environment Variables

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/kyozo_dev

# S3 Storage (optional)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=kyozo-dev-storage
AWS_REGION=us-east-1

# Blob storage backend
BLOB_STORAGE_BACKEND=disk  # or 's3'

# LiveSvelte
VITE_HOST=http://localhost:5173
```

### Development Workflow

1. **Make changes** to Elixir or Svelte code
2. **Auto-reload** handles most changes
3. **Run tests** for modified components
4. **Check integration** with `mix phx.server`
5. **Test blob storage** with different backends

## API Reference

### Workspaces Domain

#### Blob Management

```elixir
# Create blob
Workspaces.create_blob(content: content, content_type: type)

# Find or create blob (deduplication)
Workspaces.find_or_create_blob(content: content, content_type: type)

# Get blob content
Workspaces.get_blob_content(blob_id)

# Check if blob exists
Workspaces.blob_exists?(hash)
```

#### Document Operations

```elixir
# Create document
Workspaces.create_document(attrs, actor: user)

# Link content to document
DocumentBlobRef.create_content_ref(document_id, content, content_type)

# Update document content
DocumentBlobRef.update_document_content(document_id, content, content_type)

# Get document content
DocumentBlobRef.get_document_content(document_id)
```

#### Notebook Operations

```elixir
# Create notebook from document
Workspaces.create_from_document(document_id, actor: user)

# Update notebook
Workspaces.update_notebook(notebook, attrs, actor: user)

# Execute notebook code
Workspaces.execute_notebook(notebook_id, actor: user)
```

### LiveView Events

#### Client to Server

```javascript
// Save content
socket.pushEvent('save_content', {
  content: markdownContent,
  html: htmlContent
});

// Execute task
socket.pushEvent('execute_task', {
  task_id: taskId,
  code: codeString,
  language: languageName
});

// Toggle collaboration
socket.pushEvent('toggle_collaborative_mode', {
  enabled: boolean
});
```

#### Server to Client

```javascript
// Save success
socket.addEventListener('save_success', (event) => {
  const { saved_at } = event.detail;
  updateLastSavedTime(saved_at);
});

// Task execution result
socket.addEventListener('task_execution_completed', (event) => {
  const { task_id, output } = event.detail;
  displayTaskOutput(task_id, output);
});

// User collaboration events
socket.addEventListener('user_joined', (event) => {
  const { user } = event.detail;
  addConnectedUser(user);
});
```

## Performance Considerations

### Optimization Strategies

1. **Lazy loading** of blob content
2. **Debounced autosave** to reduce API calls
3. **Content deduplication** to minimize storage
4. **Efficient diff algorithms** for collaboration
5. **Streaming execution** for long-running tasks

### Monitoring

- **Blob storage utilization**
- **Save operation latency**
- **Collaboration session metrics**
- **Code execution timeouts**
- **Error rates and types**

## Security

### Data Protection

- **Content encryption** at rest (S3)
- **Transport security** (HTTPS/WSS)
- **Access control** via Ash policies
- **Audit logging** for all operations

### Code Execution Security

- **Sandboxed environments**
- **Resource limitations**
- **Network isolation**
- **User permission verification**
- **Code injection prevention**

## Troubleshooting

### Common Issues

#### Blob Storage

```elixir
# Test blob storage connection
Kyozo.Workspaces.Blob.test_s3_connection()

# Check storage configuration
Kyozo.Workspaces.Blob.s3_configured?()

# Migrate between storage backends
Kyozo.Workspaces.Blob.migrate_to_s3()
```

#### TipTap Editor

```javascript
// Check editor state
console.log('Editor ready:', editor.isReady);
console.log('Editor content:', editor.getJSON());

// Verify socket connection
console.log('Socket state:', socket.readyState);
```

#### Collaboration Issues

```elixir
# Check PubSub subscriptions
Phoenix.PubSub.subscribers(Kyozo.PubSub, "notebook:#{id}")

# Test broadcasting
Phoenix.PubSub.broadcast(Kyozo.PubSub, "notebook:#{id}", {:test})
```

---

## Contributing

When contributing to notebook features:

1. **Write tests** for new functionality
2. **Update documentation** for API changes
3. **Test blob storage** with both backends
4. **Verify collaboration** features work
5. **Check export/import** compatibility

For detailed development guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).
