//
//  StorageService.swift
//  Kyozo
//
//  Service for managing storage and VFS operations
//

import Foundation
import Combine

public class StorageService: ObservableObject {
    private let api: KyozoAPI
    @Published public var currentListing: VFSListing?
    @Published public var isLoading = false
    @Published public var error: Error?
    
    public init(api: KyozoAPI) {
        self.api = api
    }
    
    /// Load directory listing with virtual files
    @MainActor
    public func loadDirectory(teamId: String, workspaceId: String, path: String = "/") async {
        isLoading = true
        error = nil
        
        do {
            let listing = try await api.storage.listVFS(
                teamId: teamId,
                workspaceId: workspaceId,
                path: path
            )
            currentListing = listing
        } catch {
            self.error = error
            print("Failed to load directory: \(error)")
        }
        
        isLoading = false
    }
    
    /// Read virtual file content
    @MainActor
    public func readVirtualFile(teamId: String, workspaceId: String, path: String) async -> VFSContent? {
        do {
            return try await api.storage.readVirtualFile(
                teamId: teamId,
                workspaceId: workspaceId,
                path: path
            )
        } catch {
            self.error = error
            print("Failed to read virtual file: \(error)")
            return nil
        }
    }
    
    /// Get file system items for display
    public func getFileSystemItems() -> [FileSystemItem] {
        guard let listing = currentListing else { return [] }
        
        return listing.files.map { file in
            if file.type == "directory" {
                return .directory(file)
            } else if file.virtual {
                return .virtual(file)
            } else {
                return .real(file)
            }
        }
    }
    
    /// Navigate to a subdirectory
    @MainActor
    public func navigateToDirectory(teamId: String, workspaceId: String, path: String) async {
        await loadDirectory(teamId: teamId, workspaceId: workspaceId, path: path)
    }
    
    /// Navigate to parent directory
    @MainActor
    public func navigateToParent(teamId: String, workspaceId: String) async {
        guard let currentPath = currentListing?.path else { return }
        
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        let normalizedPath = parentPath.isEmpty ? "/" : parentPath
        
        await loadDirectory(teamId: teamId, workspaceId: workspaceId, path: normalizedPath)
    }
    
    /// Check if we can navigate up
    public var canNavigateUp: Bool {
        guard let path = currentListing?.path else { return false }
        return path != "/" && !path.isEmpty
    }
    
    /// Get breadcrumb items for current path
    public func getBreadcrumbs() -> [(name: String, path: String)] {
        guard let currentPath = currentListing?.path else { return [] }
        
        if currentPath == "/" || currentPath.isEmpty {
            return [("Root", "/")]
        }
        
        var breadcrumbs = [("Root", "/")]
        var pathComponents = currentPath.split(separator: "/").map(String.init)
        var accumulatedPath = ""
        
        for component in pathComponents {
            accumulatedPath += "/\(component)"
            breadcrumbs.append((component, accumulatedPath))
        }
        
        return breadcrumbs
    }
}