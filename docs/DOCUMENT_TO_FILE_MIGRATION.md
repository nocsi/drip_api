# Document to File Migration - Generic File System Implementation

## Overview

This document outlines the migration from the restrictive "Document" resource to a more generic "File" resource that supports both files and folders, creating a complete file system hierarchy within Kyozo workspaces.

## Migration Rationale

### Problems with Document Resource
- **Too Restrictive**: "Document" implies text-based content only
- **No Folder Support**: Couldn't represent directories or file hierarchies
- **Limited File Types**: Didn't handle images, videos, binaries effectively
- **Poor Organization**: No way to organize files into folder structures

### Benefits of File Resource
- **Generic Design**: Can represent any file type (documents, images, videos, code, etc.)
- **Folder Support**: Full directory hierarchy with parent-child relationships
- **Complete File System**: Supports files, folders, symbolic links, etc.
- **Better Organization**: Natural file/folder browsing and management
- **Future-Proof**: Extensible for advanced file system features

## Core Changes

### 1. Resource Renaming
```
Document → File
DocumentStorage → FileStorage
document_id → file_id
documents table → files table
document_storages table → file_storages table
```

### 2. New File Attributes
```elixir
# Added for generic file support
attribute :name, :string            # More generic than "title"
attribute :is_directory, :boolean   # Distinguishes files from folders
attribute :parent_file_id, :uuid    # Enables folder hierarchy

# Updated attributes
attribute :title → :name            # More appropriate naming
```

### 3. Enhanced Relationships
```elixir
# File hierarchy
belongs_to :parent, __MODULE__      # Parent folder
has_many :children, __MODULE__      # Child files/folders

# Storage relationships (renamed)
has_many :file_storages             # Was document_storages
many_to_many :storages              # Through FileStorage
```

## New Features

### 1. Directory Support
- **Create Folders**: `create_folder` action for directory creation
- **Folder Hierarchy**: Parent-child relationships between files/folders
- **Folder Operations**: Move files between folders, list folder contents
- **Directory Constraints**: Folders must have `content_type: "application/x-directory"`

### 2. Enhanced File Operations
```elixir
# New actions
create_file         # Generic file creation (replaces create_document)
create_folder       # Directory creation
upload_file         # File upload (replaces upload_document)
move_file           # Move between folders
list_folder_contents # Browse folder contents
```

### 3. File System Calculations
```elixir
calculate :depth            # Folder nesting depth
calculate :full_path        # Complete file path from root
calculate :children_count   # Number of items in folder
```

### 4. Improved Path Handling
- **Flexible Paths**: Support both file and folder paths
- **Path Validation**: Enhanced security for file system operations
- **Hierarchy Navigation**: Efficient parent-child traversal

## API Changes

### JSON API Endpoints
```
OLD: /documents          NEW: /files
OLD: /document_storages  NEW: /file_storages
```

### GraphQL Schema Updates
```graphql
# Types renamed
Document → File
DocumentStorage → FileStorage

# New queries/mutations
listFiles           # Was listDocuments
createFile          # Was createDocument
createFolder        # New folder creation
moveFile            # New file organization
```

## Database Schema Changes

### New Tables
```sql
-- Renamed table
CREATE TABLE files (                 -- Was documents
  id uuid PRIMARY KEY,
  name varchar(255) NOT NULL,        -- Was title
  is_directory boolean DEFAULT false,
  parent_file_id uuid REFERENCES files(id),
  -- ... other existing fields
);

CREATE TABLE file_storages (         -- Was document_storages
  id uuid PRIMARY KEY,
  file_id uuid NOT NULL,             -- Was document_id
  storage_id uuid NOT NULL,
  -- ... other existing fields
);
```

### New Indexes
```sql
-- Hierarchy indexes
CREATE INDEX idx_files_parent ON files(parent_file_id);
CREATE INDEX idx_files_directory ON files(team_id, is_directory);
CREATE INDEX idx_files_hierarchy ON files(workspace_id, parent_file_id);
```

## Validation Enhancements

### Directory-Specific Validations
```elixir
# New validations
ValidateDirectoryConstraints  # Ensure directory content_type consistency
ValidateParentDirectory      # Validate parent is actually a directory
```

### Enhanced File Validations
```elixir
# Updated validations
ValidateFilePath            # Now supports both files and folders
ValidateContentType         # Enhanced for directory support
```

## Storage Backend Compatibility

### File Type Handling
- **Text Files** → Git backend (documents, code, markdown)
- **Binary Files** → S3 backend (images, videos, archives)
- **Directories** → Metadata-only (no content storage needed)
- **Hybrid Routing** → Intelligent backend selection

### Folder Storage Strategy
- **Metadata Only**: Folders don't have content, only metadata
- **Structure Preservation**: Maintain folder hierarchy in storage paths
- **Efficient Operations**: Bulk operations on folder contents

## Migration Path

### 1. Database Migration
```elixir
# Rename tables and columns
ALTER TABLE documents RENAME TO files;
ALTER TABLE documents RENAME COLUMN title TO name;
ALTER TABLE document_storages RENAME TO file_storages;
ALTER TABLE file_storages RENAME COLUMN document_id TO file_id;

# Add new columns
ALTER TABLE files ADD COLUMN is_directory boolean DEFAULT false;
ALTER TABLE files ADD COLUMN parent_file_id uuid REFERENCES files(id);
```

### 2. Code Updates
- Update all module names and references
- Migrate API endpoints and GraphQL schema
- Update frontend components for folder support
- Test file hierarchy operations

### 3. Data Migration
- Convert existing documents to files
- Create root folders for workspaces
- Establish folder hierarchies where appropriate

## Backward Compatibility

### API Compatibility
- Old endpoints redirected to new ones
- Response format maintained where possible
- Graceful deprecation warnings

### Code Compatibility
- Alias old module names during transition
- Maintain existing calculations and relationships
- Preserve storage resource integration

## Testing Strategy

### Unit Tests
- File vs folder creation and validation
- Hierarchy operations (move, copy, delete)
- Storage backend routing for directories
- Permission inheritance in folder structures

### Integration Tests
- Complete file system operations
- API endpoint functionality
- GraphQL schema compliance
- Storage system integration

## Performance Considerations

### Hierarchy Queries
- Efficient parent-child lookups
- Optimized depth calculations
- Folder content pagination

### Storage Optimization
- Lazy loading of folder contents
- Efficient bulk operations
- Minimal metadata overhead for folders

## Future Enhancements

### Advanced Features
- **Symbolic Links**: Reference files in other locations
- **File Versioning**: Track changes across folder moves
- **Bulk Operations**: Mass file operations within folders
- **Search & Indexing**: Content search within folder hierarchies
- **Permissions**: Folder-based access control

### UI Components
- **File Explorer**: Tree-view folder navigation
- **Drag & Drop**: Intuitive file organization
- **Breadcrumbs**: Path navigation
- **Context Menus**: Right-click file operations

## Conclusion

The migration from Document to File resource transforms Kyozo from a document management system into a comprehensive file system. This change provides:

- **Flexibility**: Support for any file type and folder structures
- **Scalability**: Efficient hierarchy management and storage routing
- **User Experience**: Intuitive file organization and navigation
- **Future-Proof**: Foundation for advanced file system features

The new File resource maintains all the powerful storage backend integration and Entrepôt compliance while adding the flexibility needed for a complete file management solution.
