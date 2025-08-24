//
//  FileBrowserView.swift
//  Kyozo
//
//  File browser with VFS support
//

import SwiftUI

struct FileBrowserView: View {
  let teamId: String
  let workspaceId: String

  @StateObject private var storageService: StorageService
  @State private var selectedFile: VFSFile?
  @State private var showingVirtualContent = false
  @State private var virtualContent: VFSContent?

  init(teamId: String, workspaceId: String, api: KyozoAPI) {
    self.teamId = teamId
    self.workspaceId = workspaceId
    _storageService = StateObject(wrappedValue: StorageService(api: api))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Breadcrumb navigation
        if storageService.currentListing != nil {
          BreadcrumbView(
            breadcrumbs: storageService.getBreadcrumbs(),
            onNavigate: { path in
              Task {
                await storageService.navigateToDirectory(
                  teamId: teamId,
                  workspaceId: workspaceId,
                  path: path
                )
              }
            }
          )
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(Color(.systemGray6))
        }

        // File list
        if storageService.isLoading {
          ProgressView("Loading files...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = storageService.error {
          ErrorView(error: error) {
            Task {
              await storageService.loadDirectory(
                teamId: teamId,
                workspaceId: workspaceId
              )
            }
          }
        } else {
          FileListView(
            items: storageService.getFileSystemItems(),
            onSelectFile: handleFileSelection,
            onSelectDirectory: { directory in
              Task {
                await storageService.navigateToDirectory(
                  teamId: teamId,
                  workspaceId: workspaceId,
                  path: directory.path
                )
              }
            }
          )
        }
      }
      .navigationTitle("Files")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        if storageService.canNavigateUp {
          ToolbarItem(placement: .navigationBarLeading) {
            Button(action: navigateUp) {
              Label("Up", systemImage: "arrow.up.circle")
            }
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: refresh) {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
        }
      }
      .sheet(isPresented: $showingVirtualContent) {
        if let content = virtualContent {
          MDViewer(content: content)
        }
      }
    }
    .task {
      await storageService.loadDirectory(
        teamId: teamId,
        workspaceId: workspaceId
      )
    }
  }

  private func handleFileSelection(_ file: VFSFile) {
    if file.virtual {
      // Load and display virtual file content
      Task {
        if let content = await storageService.readVirtualFile(
          teamId: teamId,
          workspaceId: workspaceId,
          path: file.path
        ) {
          virtualContent = content
          showingVirtualContent = true
        }
      }
    } else {
      // Handle regular file selection
      selectedFile = file
      // Navigate to file viewer or editor
    }
  }

  private func navigateUp() {
    Task {
      await storageService.navigateToParent(
        teamId: teamId,
        workspaceId: workspaceId
      )
    }
  }

  private func refresh() {
    Task {
      await storageService.loadDirectory(
        teamId: teamId,
        workspaceId: workspaceId,
        path: storageService.currentListing?.path ?? "/"
      )
    }
  }
}

// MARK: - Supporting Views

struct BreadcrumbView: View {
  let breadcrumbs: [(name: String, path: String)]
  let onNavigate: (String) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
          Button(action: { onNavigate(crumb.path) }) {
            Text(crumb.name)
              .font(.caption)
              .foregroundColor(.accentColor)
          }

          if index < breadcrumbs.count - 1 {
            Image(systemName: "chevron.right")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
      .padding(.vertical, 4)
    }
  }
}

struct FileListView: View {
  let items: [FileSystemItem]
  let onSelectFile: (VFSFile) -> Void
  let onSelectDirectory: (VFSFile) -> Void

  var body: some View {
    List(items, id: \.file.id) { item in
      FileRowView(
        item: item,
        onTap: {
          if item.isDirectory {
            onSelectDirectory(item.file)
          } else {
            onSelectFile(item.file)
          }
        }
      )
    }
    .listStyle(.plain)
  }
}

struct FileRowView: View {
  let item: FileSystemItem
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        Text(item.icon)
          .font(.title2)

        VStack(alignment: .leading, spacing: 2) {
          Text(item.file.name)
            .font(.body)
            .foregroundColor(.primary)

          if item.isVirtual {
            HStack(spacing: 4) {
              Image(systemName: "sparkles")
                .font(.caption2)
              Text("Virtual • \(item.file.generator ?? "Generated")")
                .font(.caption)
            }
            .foregroundColor(.secondary)
          } else if !item.isDirectory {
            Text(formatFileSize(item.file.size))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        if item.isDirectory {
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }

  private func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

struct ErrorView: View {
  let error: Error
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.orange)

      Text("Failed to load files")
        .font(.headline)

      Text(error.localizedDescription)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      Button("Try Again", action: onRetry)
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
