# Files API Implementation - Entrepôt Storage System

## Overview

This document describes the comprehensive Files API implementation that integrates Ash Framework with an Entrepôt-based storage system. The implementation provides enterprise-grade file storage with multiple backend support, version control, and flexible relationship management.

## Architecture

### Core Components

#### 1. Document Resource (`Kyozo.Workspaces.Document`)
- **Purpose**: Business logic and workspace context for files
- **Responsibilities**:
  - File metadata (title, description, tags)
  - Workspace and team relationships
  - User permissions and access control
  - Usage tracking (view counts, last accessed)
  - Soft deletion support

#### 2. StorageResource (`Kyozo.Storage.StorageResource`)
- **Purpose**: Entrepôt-compliant file storage backing
- **Responsibilities**:
  - Locator-based file access
  - Storage backend abstraction
  - File integrity (checksums, validation)
  - Access metrics and monitoring
  - Expiration and lifecycle management

#### 3. DocumentStorage (`Kyozo.Workspaces.DocumentStorage`)
- **Purpose**: Join resource connecting Documents to StorageResources
- **Responsibilities**:
  - Relationship type management (primary, version, backup, format, cache, attachment)
  - Primary storage designation
  - Relationship metadata
  - Storage synchronization tracking

### Storage Backends

The system supports multiple storage backends with intelligent routing:

- **Git Provider** - Version-controlled text files (Markdown, code, JSON)
- **S3 Provider** - Scalable binary storage (images, videos, large files)
- **Hybrid Provider** - Intelligent routing based on content type and size
- **Disk Provider** - Local file storage for development
- **RAM Provider** - In-memory storage for temporary files

## Key Features

### 1. Entrepôt Compliance
- **Locator-based Access**: Each file has a unique locator ID
- **Storage Abstraction**: Backend-agnostic file access
- **Metadata Consistency**: Synchronized metadata across systems
- **Resource Separation**: Clear separation between business logic and storage

### 2. Multiple Storage Relationships
A single Document can have multiple storage relationships:
- **Primary**: Main storage backing
- **Version**: Specific document versions
- **Backup**: Redundant storage for reliability
- **Format**: Alternative formats (e.g., HTML from Markdown)
- **Cache**: Processed/optimized versions
- **Attachment**: Related files

### 3. Intelligent Backend Selection
The system automatically selects appropriate storage backends based on:
- File extension analysis
- Content type detection
- File size considerations
- User preferences
- Performance requirements

### 4. Version Control
- Git-backed versioning for text files
- Version history tracking
- Commit message support
- Branch management capabilities
- Rollback functionality

### 5. Data Integrity
- SHA-256 checksum validation
- Referential integrity constraints
- Transaction safety
- Orphaned file detection
- Corruption detection and recovery

## API Integration

### JSON API Endpoints

#### Documents
```
GET /documents           - List documents with storage info
POST /documents          - Create document with file upload
GET /documents/:id       - Get document with relationships
PUT /documents/:id       - Update document content
PATCH /documents/:id     - Update document metadata
DELETE /documents/:id    - Delete document (soft/hard)
```

#### Storage Resources
```
GET /storage            - List storage entries
POST /storage           - Create storage entry
GET /storage/:id        - Get storage details
PUT /storage/:id        - Update storage metadata
DELETE /storage/:id     - Delete storage entry
```

#### Document Storage Relationships
```
GET /document_storages                    - List relationships
POST /document_storages                   - Create relationship
GET /document_storages/:id               - Get relationship details
PUT /document_storages/:id               - Update relationship
DELETE /document_storages/:id            - Remove relationship
```

### GraphQL Schema

#### Queries
```graphql
type Query {
  listDocuments(filter: DocumentFilter, sort: [DocumentSort!]): [Document!]!
  getDocument(id: ID!): Document
  listStorage(filter: StorageFilter): [StorageResource!]!
  getStorage(id: ID!): StorageResource
}
```

#### Mutations
```graphql
type Mutation {
  createDocument(input: CreateDocumentInput!): Document!
  updateDocument(id: ID!, input: UpdateDocumentInput!): Document!
  deleteDocument(id: ID!): Boolean!

  uploadFile(input: FileUploadInput!): StorageResource!
  addStorageBacking(documentId: ID!, storageId: ID!, type: RelationshipType!): DocumentStorage!
  switchPrimaryStorage(documentId: ID!, storageId: ID!): Document!
}
```

#### Types
```graphql
type Document {
  id: ID!
  title: String!
  contentType: String!
  description: String
  tags: [String!]!
  fileSize: Int!
  version: String
  checksum: String

  # Storage relationships
  documentStorages: [DocumentStorage!]!
  primaryStorage: StorageResource
  storages: [StorageResource!]!

  # Calculated fields
  fileMetadata: FileMetadata!
  storageInfo: StorageInfo!
  canRender: Boolean!
  hasMultipleStorages: Boolean!

  # Timestamps
  createdAt: DateTime!
  updatedAt: DateTime!
}

type StorageResource {
  id: ID!
  locatorId: String!
  storageBackend: StorageBackend!
  fileName: String!
  mimeType: String!
  fileSize: Int!
  checksum: String!
  version: String!
  isVersioned: Boolean!

  # Access tracking
  accessCount: Int!
  lastAccessedAt: DateTime

  # Timestamps
  createdAt: DateTime!
  updatedAt: DateTime!
}

type DocumentStorage {
  id: ID!
  isPrimary: Boolean!
  relationshipType: RelationshipType!
  metadata: JSON

  # Relationships
  document: Document!
  storage: StorageResource!

  # Timestamps
  createdAt: DateTime!
  updatedAt: DateTime!
}

enum RelationshipType {
  PRIMARY
  VERSION
  BACKUP
  FORMAT
  CACHE
  ATTACHMENT
}

enum StorageBackend {
  GIT
  S3
  HYBRID
  DISK
  RAM
}
```

## Implementation Details

### Document Actions

#### Create Document
```elixir
Kyozo.Workspaces.create_document(%{
  title: "example.md",
  content_type: "text/markdown",
  content: "# Example\nThis is an example document.",
  team_id: team_id,
  workspace_id: workspace_id
}, actor: user)
```

Flow:
1. Create Document record
2. Create StorageResource with content
3. Create primary DocumentStorage relationship
4. Sync metadata between resources

#### Update Content
```elixir
Kyozo.Workspaces.update_content(document_id, %{
  content: "Updated content",
  commit_message: "Update document content"
}, actor: user)
```

Flow:
1. Update content in primary storage
2. Generate new version
3. Update checksums
4. Sync metadata to Document

#### Add Storage Backing
```elixir
Kyozo.Workspaces.add_storage_backing(document_id, %{
  storage_id: backup_storage_id,
  relationship_type: :backup
}, actor: user)
```

### Storage Operations

#### Create Storage Entry
```elixir
Kyozo.Storage.create_storage_entry(%{
  file_upload: %{content: content, filename: "file.txt"},
  storage_backend: :s3,
  team_id: team_id,
  description: "Backup storage"
}, actor: user)
```

#### Get Content
```elixir
{:ok, %{content: content, metadata: metadata}} =
  Kyozo.Storage.get_content(storage_id, actor: user)
```

#### List Versions
```elixir
{:ok, versions} = Kyozo.Storage.list_versions(storage_id, actor: user)
```

### Validation and Security

#### Storage Resource Validations
- Locator ID format and uniqueness
- Storage backend availability
- File size limits per backend
- Checksum format validation
- File name security checks
- MIME type validation
- Team access verification

#### Document Storage Validations
- Unique primary per document
- Relationship metadata validation
- Storage compatibility checks
- Circular reference prevention
- Relationship limits enforcement
- Metadata size constraints

### Performance Optimizations

#### Calculations
- Smart calculations that prefer primary storage data
- Fallback to document attributes for backward compatibility
- Efficient relationship loading
- Cached aggregations

#### Access Patterns
- Async access metrics updates
- Lazy loading of storage relationships
- Efficient primary storage lookup
- Batch operations support

## Migration Path

### Backward Compatibility
1. Existing Document attributes maintained
2. Calculations fallback to old attributes
3. API compatibility preserved
4. Gradual migration support

### Migration Steps
1. Run database migrations
2. Create DocumentStorage relationships for existing documents
3. Migrate file content to StorageResources
4. Update client code to use new relationships
5. Remove deprecated attributes (future release)

## Monitoring and Observability

### Metrics
- Storage backend usage statistics
- File access patterns
- Version control activity
- Storage efficiency metrics
- Performance benchmarks

### Health Checks
- Storage backend availability
- Data integrity validation
- Orphaned file detection
- Checksum verification
- Relationship consistency

### Logging
- File operations (create, read, update, delete)
- Backend selection decisions
- Relationship changes
- Access pattern analysis
- Error tracking and recovery

## Future Enhancements

### Planned Features
1. **File Explorer UI Components**
   - Svelte-based file browser
   - Drag-and-drop uploads
   - Preview capabilities
   - Bulk operations

2. **Advanced Search and Indexing**
   - Full-text search
   - Metadata indexing
   - Content analysis
   - Smart categorization

3. **Storage Analytics**
   - Usage dashboards
   - Cost optimization
   - Performance insights
   - Capacity planning

4. **Bulk Operations**
   - Batch file uploads
   - Storage migrations
   - Relationship management
   - Cleanup utilities

5. **Performance Monitoring**
   - Real-time metrics
   - Performance profiling
   - Bottleneck identification
   - Optimization recommendations

### Extensibility Points
- Custom storage providers
- Additional relationship types
- Metadata extensions
- Content processors
- Access control policies

## Conclusion

The Files API implementation provides a robust, enterprise-grade file storage solution that combines the flexibility of multiple storage backends with the reliability of the Entrepôt pattern. The architecture supports complex document management scenarios while maintaining simplicity for common use cases.

Key achievements:
- ✅ Entrepôt compliance for enterprise use
- ✅ Multiple storage backends with intelligent routing
- ✅ Flexible relationship management
- ✅ Comprehensive validation and security
- ✅ Version control and backup strategies
- ✅ High-performance APIs with excellent developer experience
- ✅ Future-proof extensibility and scalability

This implementation establishes a solid foundation for advanced document management features while maintaining the clean, declarative approach that makes Ash Framework so powerful.
