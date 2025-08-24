import Foundation

// MARK: - Teams Service

public class TeamsService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// List all teams the current user belongs to
    public func list() async throws -> [Team] {
        let request = try client.buildRequest(
            path: "teams",
            method: .get
        )
        let response: DataResponse<[Team]> = try await client.execute(request)
        return response.data
    }
    
    /// Create a new team
    public func create(name: String, description: String? = nil) async throws -> Team {
        let body = ["name": name, "description": description]
        let request = try client.buildRequest(
            path: "teams",
            method: .post,
            body: body
        )
        let response: DataResponse<Team> = try await client.execute(request)
        return response.data
    }
    
    /// Get a specific team
    public func get(id: String) async throws -> Team {
        let request = try client.buildRequest(
            path: "teams/\(id)",
            method: .get
        )
        let response: DataResponse<Team> = try await client.execute(request)
        return response.data
    }
    
    /// Update a team
    public func update(id: String, name: String? = nil, description: String? = nil) async throws -> Team {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        
        let request = try client.buildRequest(
            path: "teams/\(id)",
            method: .patch,
            body: body
        )
        let response: DataResponse<Team> = try await client.execute(request)
        return response.data
    }
    
    /// Delete a team
    public func delete(id: String) async throws {
        let request = try client.buildRequest(
            path: "teams/\(id)",
            method: .delete
        )
        try await client.executeEmpty(request)
    }
}

// MARK: - Workspaces Service

public class WorkspacesService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// List all workspaces in a team
    public func list(teamId: String) async throws -> [Workspace] {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces",
            method: .get
        )
        let response: DataResponse<[Workspace]> = try await client.execute(request)
        return response.data
    }
    
    /// Create a new workspace
    public func create(teamId: String, request: CreateWorkspaceRequest) async throws -> Workspace {
        let apiRequest = try client.buildRequest(
            path: "teams/\(teamId)/workspaces",
            method: .post,
            body: request
        )
        let response: DataResponse<Workspace> = try await client.execute(apiRequest)
        return response.data
    }
    
    /// Get a specific workspace
    public func get(teamId: String, id: String) async throws -> Workspace {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces/\(id)",
            method: .get
        )
        let response: DataResponse<Workspace> = try await client.execute(request)
        return response.data
    }
    
    /// Archive a workspace
    public func archive(teamId: String, id: String) async throws -> Workspace {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces/\(id)/archive",
            method: .post
        )
        let response: DataResponse<Workspace> = try await client.execute(request)
        return response.data
    }
    
    /// Restore an archived workspace
    public func restore(teamId: String, id: String) async throws -> Workspace {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces/\(id)/restore",
            method: .post
        )
        let response: DataResponse<Workspace> = try await client.execute(request)
        return response.data
    }
}

// MARK: - Files Service

public class FilesService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// List files
    public func list(
        teamId: String,
        workspaceId: String? = nil,
        parentFileId: String? = nil
    ) async throws -> [File] {
        var queryItems: [URLQueryItem] = []
        if let workspaceId = workspaceId {
            queryItems.append(URLQueryItem(name: "workspace_id", value: workspaceId))
        }
        if let parentFileId = parentFileId {
            queryItems.append(URLQueryItem(name: "parent_file_id", value: parentFileId))
        }
        
        let request = try client.buildRequest(
            path: "teams/\(teamId)/files",
            method: .get,
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        let response: DataResponse<[File]> = try await client.execute(request)
        return response.data
    }
    
    /// Create a new file
    public func create(teamId: String, request: CreateFileRequest) async throws -> File {
        let apiRequest = try client.buildRequest(
            path: "teams/\(teamId)/files",
            method: .post,
            body: request
        )
        let response: DataResponse<File> = try await client.execute(apiRequest)
        return response.data
    }
    
    /// Get a specific file
    public func get(teamId: String, id: String) async throws -> File {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/files/\(id)",
            method: .get
        )
        let response: DataResponse<File> = try await client.execute(request)
        return response.data
    }
    
    /// Update a file
    public func update(teamId: String, id: String, request: UpdateFileRequest) async throws -> File {
        let apiRequest = try client.buildRequest(
            path: "teams/\(teamId)/files/\(id)",
            method: .patch,
            body: request
        )
        let response: DataResponse<File> = try await client.execute(apiRequest)
        return response.data
    }
    
    /// Delete a file
    public func delete(teamId: String, id: String) async throws {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/files/\(id)",
            method: .delete
        )
        try await client.executeEmpty(request)
    }
    
    /// Get raw file content
    public func getContent(teamId: String, id: String) async throws -> String {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/files/\(id)/content",
            method: .get
        )
        let (data, _) = try await client.session.data(for: request)
        guard let content = String(data: data, encoding: .utf8) else {
            throw KyozoError.invalidResponse
        }
        return content
    }
    
    /// Duplicate a file
    public func duplicate(teamId: String, id: String, newName: String) async throws -> File {
        let body = ["name": newName]
        let request = try client.buildRequest(
            path: "teams/\(teamId)/files/\(id)/duplicate",
            method: .post,
            body: body
        )
        let response: DataResponse<File> = try await client.execute(request)
        return response.data
    }
}

// MARK: - Notebooks Service

public class NotebooksService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// Create a notebook from a markdown file
    public func createFromFile(
        teamId: String,
        fileId: String,
        request: CreateNotebookRequest = CreateNotebookRequest()
    ) async throws -> Notebook {
        let apiRequest = try client.buildRequest(
            path: "teams/\(teamId)/files/\(fileId)/notebooks",
            method: .post,
            body: ["notebook": request]
        )
        let response: DataResponse<Notebook> = try await client.execute(apiRequest)
        return response.data
    }
    
    /// Get a notebook
    public func get(teamId: String, id: String) async throws -> Notebook {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)",
            method: .get
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
    
    /// Delete (close) a notebook
    public func delete(teamId: String, id: String) async throws {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)",
            method: .delete
        )
        try await client.executeEmpty(request)
    }
    
    /// Execute all tasks in a notebook
    public func execute(
        teamId: String,
        id: String,
        environmentVariables: [String: String]? = nil
    ) async throws -> Notebook {
        let body = ExecuteNotebookRequest(environmentVariables: environmentVariables)
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)/execute",
            method: .post,
            body: body
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
    
    /// Execute a specific task
    public func executeTask(
        teamId: String,
        notebookId: String,
        taskId: String,
        environmentVariables: [String: String]? = nil
    ) async throws -> Notebook {
        let body = ["task_id": taskId, "environment_variables": environmentVariables ?? [:]]
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(notebookId)/execute/\(taskId)",
            method: .post,
            body: body
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
    
    /// Stop execution
    public func stopExecution(teamId: String, id: String) async throws -> Notebook {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)/stop",
            method: .post
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
    
    /// Reset execution state
    public func resetExecution(teamId: String, id: String) async throws -> Notebook {
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)/reset",
            method: .post
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
    
    /// Duplicate a notebook
    public func duplicate(teamId: String, id: String, newTitle: String) async throws -> Notebook {
        let body = ["options": ["title": newTitle]]
        let request = try client.buildRequest(
            path: "teams/\(teamId)/notebooks/\(id)/duplicate",
            method: .post,
            body: body
        )
        let response: DataResponse<Notebook> = try await client.execute(request)
        return response.data
    }
}

// MARK: - AI Service

public class AIService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// Get AI suggestions for text
    public func suggest(request: AISuggestRequest) async throws -> AISuggestResponse {
        let apiRequest = try client.buildRequest(
            path: "ai/suggest",
            method: .post,
            body: request
        )
        return try await client.execute(apiRequest)
    }
    
    /// Analyze code confidence
    public func analyzeConfidence(request: AIConfidenceRequest) async throws -> AIConfidenceResponse {
        let apiRequest = try client.buildRequest(
            path: "ai/confidence",
            method: .post,
            body: request
        )
        return try await client.execute(apiRequest)
    }
}

// MARK: - VFS Service

public class VFSService {
    private let client: KyozoClient
    
    init(client: KyozoClient) {
        self.client = client
    }
    
    /// List files including virtual ones
    public func list(
        teamId: String,
        workspaceId: String,
        path: String = "/"
    ) async throws -> VFSListing {
        let queryItems = [URLQueryItem(name: "path", value: path)]
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces/\(workspaceId)/storage/vfs",
            method: .get,
            queryItems: queryItems
        )
        return try await client.execute(request)
    }
    
    /// Read virtual file content
    public func readContent(
        teamId: String,
        workspaceId: String,
        path: String
    ) async throws -> VFSContent {
        let queryItems = [URLQueryItem(name: "path", value: path)]
        let request = try client.buildRequest(
            path: "teams/\(teamId)/workspaces/\(workspaceId)/storage/vfs/content",
            method: .get,
            queryItems: queryItems
        )
        return try await client.execute(request)
    }
}