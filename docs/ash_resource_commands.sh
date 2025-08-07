# Core Workspace Resources

# Team
mix ash.gen.resource Kyozo.Teams.Team \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute name:string:required:public \
  --attribute shorthand:string:required:public \
  --attribute description:string:public \
  --attribute member_count:integer:public \
  --attribute workspace_count:integer:public \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Workspace
mix ash.gen.resource Kyozo.Workspaces.Workspace \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute name:string:required:public \
  --attribute description:string:public \
  --attribute git_url:string:public \
  --attribute git_branch:string:public \
  --attribute settings:map:public \
  --relationship belongs_to:team:Kyozo.Accounts.Team \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

mix ash.gen.resource Kyozo.Workspace.Notebook \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute name:string:required:public \
  --attribute cells:map:public \
  --relationship belongs_to:workspace:Kyozo.Workspace.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resourc

# File
mix ash.gen.domain Kyozo.Files
mix ash.gen.resource Kyozo.Files.File \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute filename:string:required:public \
  --attribute mime_type:string:required:public \
  --attribute file_type:atom:required:public \
  --attribute size:integer:required:public \
  --attribute encoding:atom:public \
  --attribute filesystem_path:string:required:public \
  --attribute workspace_path:string:required:public \
  --attribute download_url:string:required:public \
  --attribute preview_url:string:public \
  --attribute is_encrypted:boolean:public \
  --attribute encryption_method:atom:public \
  --attribute encryption_metadata:map:public \
  --attribute checksum:map:required:public \
  --attribute metadata:map:public \
  --attribute permissions:map:public \
  --attribute last_accessed:utc_datetime:public \
  --attribute version:integer:required:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --relationship has_many:stores:Kyozo.Storage.Store \
  --relationship belongs_to:user:Kyozo.Accounts.User \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Media (extends File)
mix ash.gen.resource Kyozo.Files.Media \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute media_type:atom:required:public \
  --attribute duration:decimal:public \
  --attribute dimensions:map:public \
  --attribute thumbnails:map:public \
  --attribute preview_formats:map:public \
  --attribute exif_data:map:public \
  --attribute processing_status:atom:required:public \
  --attribute processing_error:string:public \
  --relationship belongs_to:file:Kyozo.Files.File \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Storage Resources

# Store
mix ash.gen.resource Kyozo.Storage.Store \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute storage_type:atom:required:public \
  --attribute configuration:map:required:public \
  --attribute metadata:map:required:public \
  --attribute status:atom:required:public \
  --attribute access_count:integer:public \
  --attribute last_accessed:utc_datetime:public \
  --relationship belongs_to:file:Kyozo.Files.File \
  --timestamps \
  --extend postgres,json_api,graphql,AshAdmin.Resource

# Execution Resources

# ExecutionContext
mix ash.gen.resource Kyozo.Execution.ExecutionContext \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute name:string:required:public \
  --attribute status:atom:required:public \
  --attribute last_execution:utc_datetime:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# User State Resources

# UserWorkspaceState
mix ash.gen.resource Kyozo.UserState.UserWorkspaceState \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute user_id:uuid:required:public \
  --attribute open_files:map:public \
  --attribute active_file:string:public \
  --attribute layout:map:public \
  --attribute preferences:map:public \
  --attribute sidebar_state:map:public \
  --attribute panel_states:map:public \
  --attribute recent_files:map:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# FileTab
mix ash.gen.resource Kyozo.UserState.FileTab \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute file_path:string:required:public \
  --attribute position:integer:required:public \
  --attribute is_active:boolean:public \
  --attribute is_dirty:boolean:public \
  --attribute scroll_position:map:public \
  --attribute cursor_position:map:public \
  --attribute last_accessed:utc_datetime:public \
  --relationship belongs_to:user_workspace_state:Kyozo.UserState.UserWorkspaceState \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Sharing Resources

# SharedLink
mix ash.gen.resource Kyozo.Sharing.SharedLink \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute name:string:required:public \
  --attribute path:string:required:public \
  --attribute token:string:required:public \
  --attribute url:string:required:public \
  --attribute protection_type:atom:required:public \
  --attribute permissions:map:required:public \
  --attribute status:atom:required:public \
  --attribute created_by:uuid:required:public \
  --attribute expires_at:utc_datetime:public \
  --attribute max_downloads:integer:public \
  --attribute download_count:integer:public \
  --attribute view_count:integer:public \
  --attribute last_accessed:utc_datetime:public \
  --attribute file_metadata:map:required:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# GuestLink
mix ash.gen.resource Kyozo.Sharing.GuestLink \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute label:string:required:public \
  --attribute url_expires:utc_datetime:public \
  --attribute max_file_lifetime:integer:public \
  --attribute max_file_bytes:integer:required:public \
  --attribute max_file_uploads:integer:public \
  --attribute is_disabled:boolean:public \
  --attribute is_encrypted:boolean:public \
  --attribute files_uploaded:integer:public \
  --attribute hash:string:required:public \
  --attribute recipient:map:required:public \
  --attribute upload_path:string:required:public \
  --attribute created_by:uuid:required:public \
  --attribute status:atom:required:public \
  --attribute last_used:utc_datetime:public \
  --attribute total_bytes_uploaded:integer:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# GuestUpload
mix ash.gen.resource Kyozo.Sharing.GuestUpload \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute filename:string:required:public \
  --attribute file_path:string:required:public \
  --attribute file_size:integer:required:public \
  --attribute mime_type:string:required:public \
  --attribute uploaded_at:utc_datetime:required:public \
  --attribute uploaded_by_email:string:public \
  --attribute client_ip:string:required:public \
  --attribute user_agent:string:required:public \
  --attribute is_encrypted:boolean:required:public \
  --attribute expires_at:utc_datetime:public \
  --attribute status:atom:required:public \
  --relationship belongs_to:guest_link:Kyozo.Sharing.GuestLink \
  --relationship belongs_to:file:Kyozo.Workspaces.File \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Audit Resources

# DownloadLog
mix ash.gen.resource Kyozo.Audit.DownloadLog \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute user_id:uuid:public \
  --attribute download_timestamp:utc_datetime:required:public \
  --attribute client_ip:string:required:public \
  --attribute user_agent:string:required:public \
  --attribute download_method:atom:required:public \
  --attribute shared_link_id:uuid:public \
  --attribute guest_link_id:uuid:public \
  --attribute referrer:string:public \
  --attribute file_size:integer:required:public \
  --attribute filename:string:required:public \
  --attribute file_path:string:required:public \
  --relationship belongs_to:file:Kyozo.Workspaces.File \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Ephemeral Resources

# EphemeralSettings
mix ash.gen.resource Kyozo.Ephemeral.EphemeralSettings \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute target_type:atom:required:public \
  --attribute target_id:string:required:public \
  --attribute expires_at:utc_datetime:required:public \
  --attribute lifetime_duration:integer:required:public \
  --attribute time_remaining:integer:required:public \
  --attribute auto_extend:boolean:public \
  --attribute extend_by:integer:public \
  --attribute extensions_used:integer:public \
  --attribute max_extensions:integer:public \
  --attribute warning_thresholds:map:public \
  --attribute warnings_sent:map:public \
  --attribute purge_policy:atom:required:public \
  --attribute archive_location:string:public \
  --attribute notify_users:map:public \
  --attribute inheritance_policy:atom:public \
  --attribute created_by:uuid:required:public \
  --attribute last_activity:utc_datetime:public \
  --attribute status:atom:required:public \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# ACL Resources

# WorkspaceAcl
mix ash.gen.resource Kyozo.ACL.WorkspaceAcl \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute default_permissions:map:required:public \
  --attribute roles:map:required:public \
  --attribute members:map:required:public \
  --attribute inheritance_policy:atom:public \
  --attribute access_policy:atom:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# WorkspaceMember
mix ash.gen.resource Kyozo.ACL.WorkspaceMember \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute user_id:uuid:required:public \
  --attribute role:atom:required:public \
  --attribute custom_permissions:map:public \
  --attribute joined_at:utc_datetime:required:public \
  --attribute expires_at:utc_datetime:public \
  --attribute added_by:uuid:required:public \
  --attribute status:atom:required:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# WorkspaceRole
mix ash.gen.resource Kyozo.ACL.WorkspaceRole \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute name:string:required:public \
  --attribute description:string:public \
  --attribute permissions:map:required:public \
  --attribute is_default:boolean:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# FileAcl
mix ash.gen.resource Kyozo.ACL.FileAcl \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute inherit_workspace_acl:boolean:public \
  --attribute specific_permissions:map:public \
  --attribute access_policy:atom:public \
  --relationship belongs_to:file:Kyozo.Workspaces.File \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Dropbox Resources

# DropboxFolder
mix ash.gen.resource Kyozo.Dropbox.DropboxFolder \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute name:string:required:public \
  --attribute path:string:required:public \
  --attribute is_enabled:boolean:required:public \
  --attribute max_file_size:integer:public \
  --attribute allowed_file_types:map:public \
  --attribute upload_limit:integer:public \
  --attribute current_uploads:integer:public \
  --attribute notification_settings:map:public \
  --attribute access_token:string:required:public \
  --attribute expires_at:utc_datetime:public \
  --attribute created_by:uuid:required:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# DropboxUpload
mix ash.gen.resource Kyozo.Dropbox.DropboxUpload \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute filename:string:required:public \
  --attribute original_filename:string:required:public \
  --attribute file_size:integer:required:public \
  --attribute mime_type:string:required:public \
  --attribute file_path:string:required:public \
  --attribute uploaded_at:utc_datetime:required:public \
  --attribute uploader_ip:string:required:public \
  --attribute uploader_user_agent:string:required:public \
  --attribute uploader_email:string:public \
  --attribute uploader_name:string:public \
  --attribute status:atom:required:public \
  --attribute processing_status:atom:public \
  --attribute notification_sent:boolean:public \
  --relationship belongs_to:dropbox_folder:Kyozo.Dropbox.DropboxFolder \
  --relationship belongs_to:file:Kyozo.Workspaces.File \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# File History Resources

# FileHistory
mix ash.gen.resource Kyozo.History.FileHistory \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute version_id:string:required:public \
  --attribute commit_hash:string:public \
  --attribute author:string:required:public \
  --attribute message:string:required:public \
  --attribute size:integer:required:public \
  --attribute changes:map:public \
  --attribute tags:map:public \
  --relationship belongs_to:file:Kyozo.Workspaces.File \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

# Snapshot
mix ash.gen.resource Kyozo.History.Snapshot \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute name:string:required:public \
  --attribute description:string:public \
  --attribute created_by:uuid:required:public \
  --attribute size:integer:required:public \
  --attribute file_count:integer:required:public \
  --attribute tags:map:public \
  --attribute git_commit:string:public \
  --attribute metadata:map:public \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource
