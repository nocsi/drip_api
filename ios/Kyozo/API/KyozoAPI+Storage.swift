//
//  KyozoAPI+Storage.swift
//  Kyozo
//
//  API client extension for VFS endpoints
//

import Foundation

extension KyozoAPI {
  public var storage: StorageAPI {
    StorageAPI(client: self)
  }
}

public struct StorageAPI {
  private let client: KyozoAPI

  init(client: KyozoAPI) {
    self.client = client
  }

  /// List files with virtual files included
  public func listVFS(teamId: String, workspaceId: String, path: String = "/") async throws
    -> VFSListing
  {
    let response: APIResponse<VFSListing> = try await client.request(
      .get,
      "/teams/\(teamId)/workspaces/\(workspaceId)/storage/vfs",
      queryItems: [
        URLQueryItem(name: "path", value: path)
      ]
    )
    return response.data
  }

  /// Read virtual file content
  public func readVirtualFile(teamId: String, workspaceId: String, path: String) async throws
    -> VFSContent
  {
    let response: APIResponse<VFSContent> = try await client.request(
      .get,
      "/teams/\(teamId)/workspaces/\(workspaceId)/storage/vfs/content",
      queryItems: [
        URLQueryItem(name: "path", value: path)
      ]
    )
    return response.data
  }
}

// MARK: - API Response Wrapper

private struct APIResponse<T: Codable>: Codable {
  let data: T
}
