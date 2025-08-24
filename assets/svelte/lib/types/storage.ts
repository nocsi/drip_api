// Storage and VFS types

export interface VFSFile {
  id: string;
  name: string;
  path: string;
  type: 'file' | 'directory';
  size: number;
  content_type: string;
  created_at: string;
  updated_at: string;
  virtual: boolean;
  icon?: string;
  generator?: string;
}

export interface VFSListing {
  path: string;
  virtual_count: number;
  files: VFSFile[];
}

export interface VFSContent {
  path: string;
  content: string;
  virtual: boolean;
  content_type: string;
}

export type FileSystemItem = 
  | { type: 'real'; file: VFSFile }
  | { type: 'virtual'; file: VFSFile }
  | { type: 'directory'; file: VFSFile };

// Helper functions
export function createFileSystemItem(file: VFSFile): FileSystemItem {
  if (file.type === 'directory') {
    return { type: 'directory', file };
  } else if (file.virtual) {
    return { type: 'virtual', file };
  } else {
    return { type: 'real', file };
  }
}

export function getFileIcon(item: FileSystemItem): string {
  if (item.type === 'virtual') {
    return item.file.icon || '✨';
  }
  
  if (item.type === 'directory') {
    return '📁';
  }
  
  const ext = item.file.name.split('.').pop()?.toLowerCase() || '';
  
  const iconMap: Record<string, string> = {
    // Code files
    'ex': '💜', 'exs': '💜', // Elixir
    'js': '🟨', 'ts': '🟨', 'jsx': '🟨', 'tsx': '🟨', // JavaScript/TypeScript
    'py': '🐍', // Python
    'rb': '💎', // Ruby
    'rs': '🦀', // Rust
    'go': '🐹', // Go
    'swift': '🦉', // Swift
    
    // Config files
    'json': '⚙️', 'yaml': '⚙️', 'yml': '⚙️', 'toml': '⚙️',
    'env': '🔐',
    
    // Documentation
    'md': '📝', 'markdown': '📝',
    'txt': '📄',
    
    // Web files
    'html': '🌐', 'htm': '🌐',
    'css': '🎨', 'scss': '🎨', 'sass': '🎨',
    
    // Images
    'png': '🖼️', 'jpg': '🖼️', 'jpeg': '🖼️', 'gif': '🖼️', 'svg': '🖼️', 'webp': '🖼️',
    
    // Archives
    'zip': '📦', 'tar': '📦', 'gz': '📦', 'rar': '📦',
    
    // Docker
    'dockerfile': '🐳',
  };
  
  return iconMap[ext] || '📄';
}

export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}