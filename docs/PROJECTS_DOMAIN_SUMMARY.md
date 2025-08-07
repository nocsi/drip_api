# Projects Domain Implementation Summary

This document summarizes the implementation of the Projects domain, which translates the `runme.project.v1` OpenAPI specification into Ash Framework resources.

## Overview

The Projects domain handles loading and parsing literate programming projects from directories or files, extracting executable code blocks (tasks) from markdown documents, and tracking the loading process through events.

## Architecture

### Domain Structure
```
lib/kyozo/projects/
├── projects.ex                    # Domain module
├── project.ex                     # Project resource
├── document.ex                    # Document resource
├── task.ex                        # Task resource
├── load_event.ex                  # LoadEvent resource
├── changes/
│   ├── load_project.ex           # Complex project loading logic
│   └── parse_document.ex         # Document parsing logic
├── services/
│   └── project_loader.ex         # Core business logic service
└── validations/
    ├── valid_path.ex             # Path validation
    └── valid_document_path.ex    # Document path validation
```

## Resources

### 1. Project Resource
**Purpose**: Represents a loaded project from either a directory or single file.

**Key Attributes**:
- `path`: Root path of the project
- `type`: `:directory` or `:file`
- `name`: Project name (derived from path)
- `status`: `:loading`, `:loaded`, or `:error`
- `identity_mode`: Controls unique identifier insertion
- `options`: Project-specific loading options
- `document_count`, `task_count`: Statistics

**Key Actions**:
- `load_directory`: Load project from directory with gitignore support
- `load_file`: Load project from single file
- `load_project`: Auto-detect directory vs file and load

**Relationships**:
- `has_many :documents`
- `has_many :tasks`
- `has_many :load_events`
- `belongs_to :user`

### 2. Document Resource
**Purpose**: Represents markdown files within a project.

**Key Attributes**:
- `path`: Relative path within project
- `absolute_path`: Full filesystem path
- `content`: Raw markdown content
- `parsed_content`: Structured markdown representation
- `status`: `:pending`, `:parsing`, `:parsed`, `:error`
- `size_bytes`, `line_count`: File statistics
- `task_count`: Number of executable tasks found

**Key Actions**:
- `create`: Create document with parsing
- `update_content`: Update content and re-parse
- `mark_parsed`, `mark_error`: Status updates

**Relationships**:
- `belongs_to :project`
- `has_many :tasks`
- `has_many :load_events`

### 3. Task Resource
**Purpose**: Represents executable code blocks within documents.

**Key Attributes**:
- `runme_id`: Unique identifier from runme parsing
- `name`: Task name (auto-generated if not provided)
- `language`: Programming language (python, javascript, etc.)
- `code`: Executable code content
- `line_start`, `line_end`: Position in document
- `order_index`: Order within document
- `execution_count`: Number of times executed
- `last_execution_status`: `:success`, `:error`, `:timeout`, `:cancelled`
- `is_executable`: Whether task can be executed
- `timeout_seconds`: Execution timeout

**Key Actions**:
- `create`: Create task from parsed code block
- `mark_successful_execution`: Record successful execution
- `mark_failed_execution`: Record failed execution
- `update_execution_result`: Update execution statistics

**Relationships**:
- `belongs_to :project`
- `belongs_to :document`
- `has_many :load_events`

### 4. LoadEvent Resource
**Purpose**: Tracks events during project loading process.

**Key Attributes**:
- `event_type`: Type of event (see Event Types below)
- `event_data`: Event-specific data payload
- `sequence_number`: Order in loading sequence
- `path`: Related file/directory path
- `error_message`: Error details if applicable
- `task_name`, `task_runme_id`: Task details for found_task events

**Event Types** (mapped from OpenAPI spec):
- `:started_walk`: Begin directory traversal
- `:found_dir`: Directory discovered
- `:found_file`: File discovered
- `:finished_walk`: Directory traversal complete
- `:started_parsing_doc`: Begin document parsing
- `:finished_parsing_doc`: Document parsing complete
- `:found_task`: Executable task discovered
- `:error`: Error occurred

**Relationships**:
- `belongs_to :project`
- `belongs_to :document` (optional)
- `belongs_to :task` (optional)

## Key Features

### 1. Directory Walking with Gitignore Support
The `ProjectLoader` service handles:
- Recursive directory traversal
- `.gitignore` pattern matching
- `.git/info/exclude` support
- Custom ignore patterns
- Repository lookup (can be disabled)

### 2. Markdown Parsing and Task Extraction
- Parses markdown structure (headings, paragraphs, code blocks)
- Extracts executable code blocks as tasks
- Auto-detects programming languages
- Generates task names and IDs
- Determines execution timeouts based on language

### 3. Multi-language Support
Supported languages for task execution:
- Python, JavaScript, TypeScript
- Ruby, Go, Rust, Java, C/C++
- Shell (bash, zsh, fish), PowerShell
- SQL, R, Scala, Kotlin, Swift, PHP

### 4. Event Streaming
All loading operations generate events that can be:
- Stored in the database
- Streamed to UI via Phoenix channels
- Used for progress tracking
- Analyzed for debugging

### 5. Path Security
Robust path validation prevents:
- Directory traversal attacks (`..`)
- Access to system directories
- Reading of dangerous files
- File size limits (50MB max)

## API Integration

### OpenAPI Mapping
The implementation maps the OpenAPI specification as follows:

| OpenAPI Concept | Ash Implementation |
|-----------------|-------------------|
| `LoadRequest` | Action arguments for load actions |
| `DirectoryProjectOptions` | Arguments for `load_directory` action |
| `FileProjectOptions` | Arguments for `load_file` action |
| `LoadResponse` events | `LoadEvent` records |
| `LoadEventFoundTask` | `Task` creation |
| `RunmeIdentity` | `identity_mode` attribute |

### JSON API Routes
- `GET /projects` - List projects
- `GET /projects/:id` - Get project
- `POST /projects/load_directory` - Load from directory
- `POST /projects/load_file` - Load from file
- `DELETE /projects/:id` - Delete project

### GraphQL Support
All resources are exposed via GraphQL with:
- Queries for reading data
- Mutations for creating/updating
- Proper authorization integration

## Code Interfaces

The domain provides clean code interfaces:

```elixir
# Load a directory project
Kyozo.Projects.load_directory!(path, %{
  skip_gitignore: false,
  ignore_file_patterns: ["*.tmp"],
  identity: :document
}, actor: user)

# Load a single file
Kyozo.Projects.load_file!(path, %{identity: :cell}, actor: user)

# Get project with loaded associations
Kyozo.Projects.get_project!(id, load: [:documents, :tasks])

# List project tasks
Kyozo.Projects.list_project_tasks!(project_id)
```

## Authorization

All resources include authorization policies:
- Users can only access their own projects
- All actions require authentication
- Fine-grained permissions for different operations

## Database Schema

### Tables Created
- `projects`: Main project records
- `project_documents`: Markdown files within projects
- `project_tasks`: Executable code blocks
- `project_load_events`: Loading process events

### Key Indexes
- Unique constraints on user/path combinations
- Sequence number ordering for events
- Document/task ordering within projects
- Foreign key indexes for performance

## Usage Examples

### Loading a Project
```elixir
# Load a project directory
{:ok, project} = Kyozo.Projects.load_directory("/path/to/project", %{
  skip_gitignore: false,
  ignore_file_patterns: ["node_modules/", "*.log"]
}, actor: current_user)

# Check loading status
project.status # :loading, :loaded, or :error
project.document_count # Number of markdown files found
project.task_count # Number of executable code blocks
```

### Accessing Project Contents
```elixir
# Get project with all content loaded
project = Kyozo.Projects.get_project!(project_id,
  load: [
    documents: [:tasks],
    load_events: []
  ]
)

# List executable tasks
tasks = Kyozo.Projects.list_project_tasks!(project_id)

# Get loading events for debugging
events = Kyozo.Projects.list_project_events!(project_id)
```

### Task Execution Tracking
```elixir
# Update task after execution
Kyozo.Projects.Task.mark_successful_execution!(task,
  output: "Hello World!",
  execution_time_ms: 150
)

# Record failed execution
Kyozo.Projects.Task.mark_failed_execution!(task,
  error: "Syntax error on line 5",
  execution_time_ms: 50
)
```

## Performance Considerations

1. **Async Loading**: Use `Ash.Oban` for large directory processing
2. **Streaming Events**: Real-time progress updates via Phoenix channels
3. **Incremental Parsing**: Only re-parse changed documents
4. **Index Optimization**: Proper indexes for common queries
5. **File Size Limits**: 50MB max per document to prevent memory issues

## Future Enhancements

1. **Caching**: Cache parsed content and task metadata
2. **Incremental Updates**: Detect file changes and update incrementally
3. **Parallel Processing**: Process multiple documents concurrently
4. **Dependency Tracking**: Track task dependencies and execution order
5. **Execution Engine**: Add actual code execution capabilities
6. **Collaboration**: Real-time multi-user editing and execution

## Integration Points

- **Phoenix LiveView**: Real-time UI updates during loading
- **Background Jobs**: Async processing with Oban
- **File System**: Monitoring for file changes
- **Git Integration**: Enhanced repository awareness
- **Code Execution**: Future integration with execution engines

This implementation provides a solid foundation for building a literate programming platform that can load, parse, and manage executable markdown documents with full event tracking and robust error handling.
