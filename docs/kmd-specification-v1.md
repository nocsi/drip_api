# Kyozo Markdown (KMD) Specification v1.0

## Overview

Kyozo Markdown (`.kmd`) is a powerful, extensible markdown format that combines:
- **Rich content authoring** with standard markdown
- **Multi-language code execution** with intelligent context
- **AI-powered enhancements** through our enlightenment system
- **Embedded data formats** (YAML, JSON, TOML)
- **Dynamic content generation** through our VFS system

Think of it as "Markdown on steroids" - not trying to be a notebook, but a flexible document format that can do almost anything.

## File Extension

- **Primary**: `.kmd` (Kyozo Markdown)
- **Legacy**: `.md` (standard markdown)

## Format Structure

### Document Header (Optional)

```markdown
<!-- kyozo:{"version": "1.0", "type": "executable", "enlightenment": true} -->
```

### Basic Structure

```markdown
# Document Title

Regular markdown content with **all** standard features.

## Executable Code Blocks

```elixir
# Code blocks can be executed in context
defmodule Example do
  def hello, do: "world"
end
```

## Data Blocks

```yaml
# YAML data is parsed and available
config:
  name: My Application
  version: 1.0.0
```

## Enlightenment Sections

<!-- kyozo:{"enlightenment": {"prompt": "Explain this code", "context": "elixir_module"}} -->

The AI will enhance this section with explanations.
```

## Core Features

### 1. Multi-Language Code Execution

Supported languages with native execution:
- **Elixir** - Full execution in Elixir runtime
- **SQL** - Execute against connected databases
- **Shell** - Run system commands
- **JavaScript** - Via embedded runtime
- **Python** - Via external runtime

```markdown
```elixir
# Elixir code with full access to your app
Kyozo.Workspaces.list_workspaces()
```

```sql
-- SQL queries run against your database
SELECT * FROM users WHERE created_at > NOW() - INTERVAL '7 days';
```

```bash
# Shell commands for system operations
ls -la | grep ".kmd"
```
```

### 2. Embedded Data Formats

Data blocks are parsed and made available to code:

```markdown
```yaml id="config"
database:
  host: localhost
  port: 5432
```

```elixir
# Access parsed data
config = KMD.data("config")
IO.inspect(config["database"]["host"])
```
```

### 3. AI Enlightenment

Sections can be enhanced by AI:

```markdown
<!-- kyozo:{"enlightenment": {
  "type": "explanation",
  "style": "beginner_friendly",
  "focus": "performance"
}} -->

## Complex Algorithm

This section will be automatically enhanced with AI-generated explanations.
```

### 4. Dynamic Content Injection

Reference external content or VFS files:

```markdown
<!-- kyozo:{"inject": {"type": "vfs", "path": "/guide.md"}} -->

<!-- kyozo:{"inject": {"type": "api", "endpoint": "/api/stats"}} -->
```

### 5. Conditional Rendering

Show content based on conditions:

```markdown
<!-- kyozo:{"if": {"env": "development"}} -->
## Development Instructions
This only shows in development.
<!-- kyozo:{"endif"} -->
```

### 6. Templates and Variables

Use template variables:

```markdown
<!-- kyozo:{"vars": {"project_name": "{{workspace.name}}"}} -->

# Welcome to {{project_name}}

Your project was created on {{workspace.created_at | date: "%B %d, %Y"}}.
```

## Metadata Specification

### Cell Metadata

```javascript
{
  "kyozo": {
    // Core metadata
    "version": "1.0",
    "type": "code|markdown|data|enlightenment",
    "id": "cell_abc123",
    
    // Execution control
    "executable": true,
    "depends_on": ["cell_xyz789"],
    "timeout": 30000,
    "run_on": "server|client|both",
    
    // Enlightenment
    "enlightenment": {
      "enabled": true,
      "prompt": "Explain this code",
      "style": "technical|beginner|tutorial",
      "context": {},
      "regenerate": true
    },
    
    // Display control
    "hidden": false,
    "collapsed": false,
    "output": "inline|modal|none",
    
    // Data handling
    "parse": true,
    "format": "yaml|json|toml",
    "schema": {},
    
    // Injection
    "inject": {
      "type": "vfs|api|file",
      "source": "path/to/source",
      "transform": "jq expression"
    }
  }
}
```

## Execution Model

### Execution Context

Each document has access to:

```elixir
%KMD.Context{
  # Document info
  document: %{id: "...", path: "...", workspace_id: "..."},
  
  # User context
  user: %{id: "...", email: "...", permissions: []},
  
  # Workspace context  
  workspace: %{id: "...", name: "...", team_id: "..."},
  
  # Shared state between cells
  vars: %{},
  
  # Access to parsed data blocks
  data: %{},
  
  # Execution environment
  env: %{mode: :development, features: []}
}
```

### Cell Dependencies

Cells can depend on each other:

```markdown
```elixir id="setup"
# This runs first
{:ok, conn} = Database.connect()
```

```elixir depends_on="setup"
# This runs after setup
Database.query(conn, "SELECT * FROM users")
```
```

## API Integration

### Reading KMD

```elixir
# Parse KMD content
{:ok, document} = KMD.parse(content)

# Execute all cells
{:ok, results} = KMD.execute(document, context)

# Execute specific cell
{:ok, result} = KMD.execute_cell(document, "cell_id", context)
```

### Writing KMD

```elixir
# Build a document programmatically
document = 
  KMD.new()
  |> KMD.add_markdown("# Title")
  |> KMD.add_code(:elixir, "IO.puts(:hello)")
  |> KMD.add_data(:yaml, config)
  |> KMD.add_enlightenment("Explain this", %{style: :tutorial})

# Render to KMD format
content = KMD.render(document)
```

## File Structure Example

```markdown
<!-- kyozo:{"version": "1.0", "type": "tutorial"} -->

# Building a REST API

Let's build a simple REST API step by step.

## Setup

```elixir id="deps"
# First, let's add our dependencies
{:plug_cowboy, "~> 2.0"},
{:jason, "~> 1.4"}
```

<!-- kyozo:{"enlightenment": {"prompt": "Explain what these dependencies do"}} -->

## Define Router

```elixir depends_on="deps"
defmodule MyAPI.Router do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/health" do
    send_resp(conn, 200, "OK")
  end
end
```

## Configuration

```yaml id="config"
server:
  port: 4000
  host: localhost
database:
  url: postgresql://localhost/myapp
```

## Start Server

```elixir depends_on="deps,config"
# Access our configuration
config = KMD.data("config")
port = config["server"]["port"]

# Start the server
{:ok, _} = Plug.Cowboy.http(MyAPI.Router, [], port: port)
```

<!-- kyozo:{"inject": {"type": "vfs", "path": "/deploy.md"}} -->
```

## Benefits Over Traditional Formats

1. **Not Just a Notebook**: Unlike Jupyter or Livebook, KMD is document-first, execution-second
2. **Multi-Language**: Not tied to a single language runtime
3. **AI-Native**: Built-in enlightenment and content generation
4. **Extensible**: Easy to add new features via metadata
5. **VFS Integration**: Dynamic content from our virtual file system
6. **Context-Aware**: Full access to Kyozo's context (workspace, user, etc.)

## Migration from Markdown

```elixir
# Automatic migration
{:ok, kmd_content} = KMD.migrate_from_markdown(markdown_content)

# Or manual with options
{:ok, kmd_content} = KMD.migrate_from_markdown(markdown_content, %{
  preserve_metadata: true,
  add_version: "1.0",
  enhance_with_ai: true
})
```

## Future Extensions

The format is designed to be extended:

- **Web Components**: `<!-- kyozo:{"component": "chart", "data": "..."} -->`
- **Interactive Widgets**: `<!-- kyozo:{"widget": "slider", "min": 0, "max": 100} -->`
- **Real-time Collaboration**: `<!-- kyozo:{"collab": {"room": "..."}} -->`
- **External Tool Integration**: `<!-- kyozo:{"tool": "terraform", "action": "plan"} -->`