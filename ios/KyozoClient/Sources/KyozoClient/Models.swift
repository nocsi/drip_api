import Foundation

// MARK: - Team Models

public struct Team: Identifiable, Codable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String?
    public let personal: Bool
    public let createdAt: Date
    public let updatedAt: Date
}

// MARK: - Workspace Models

public struct Workspace: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let status: WorkspaceStatus
    public let teamId: String
    public let createdAt: Date
    public let updatedAt: Date
}

public enum WorkspaceStatus: String, Codable {
    case active
    case archived
    case deleted
}

public struct CreateWorkspaceRequest: Codable {
    public let name: String
    public let description: String?
    
    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

// MARK: - File Models

public struct File: Identifiable, Codable {
    public let id: String
    public let name: String
    public let filePath: String
    public let contentType: String
    public let size: Int
    public let isDirectory: Bool
    public let workspaceId: String
    public let parentFileId: String?
    public let createdAt: Date
    public let updatedAt: Date
}

public struct CreateFileRequest: Codable {
    public let name: String
    public let content: String
    public let contentType: String
    public let parentFileId: String?
    
    public init(
        name: String,
        content: String,
        contentType: String = "text/markdown",
        parentFileId: String? = nil
    ) {
        self.name = name
        self.content = content
        self.contentType = contentType
        self.parentFileId = parentFileId
    }
}

public struct UpdateFileRequest: Codable {
    public let content: String?
    public let name: String?
    
    public init(content: String? = nil, name: String? = nil) {
        self.content = content
        self.name = name
    }
}

// MARK: - Notebook Models

public struct Notebook: Identifiable, Codable {
    public let id: String
    public let title: String
    public let content: String
    public let contentHtml: String
    public let status: NotebookStatus
    public let executionState: [String: Any]?
    public let extractedTasks: [Task]
    public let documentId: String
    public let workspaceId: String
    public let createdAt: Date
    public let updatedAt: Date
    
    public struct Task: Codable {
        public let id: String
        public let language: String
        public let code: String
        public let position: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, contentHtml, status
        case executionState, extractedTasks, documentId
        case workspaceId, createdAt, updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        contentHtml = try container.decode(String.self, forKey: .contentHtml)
        status = try container.decode(NotebookStatus.self, forKey: .status)
        executionState = try container.decodeIfPresent([String: Any].self, forKey: .executionState)
        extractedTasks = try container.decode([Task].self, forKey: .extractedTasks)
        documentId = try container.decode(String.self, forKey: .documentId)
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum NotebookStatus: String, Codable {
    case draft
    case running
    case completed
    case error
}

public struct CreateNotebookRequest: Codable {
    public let title: String?
    public let autoSaveEnabled: Bool
    
    public init(title: String? = nil, autoSaveEnabled: Bool = true) {
        self.title = title
        self.autoSaveEnabled = autoSaveEnabled
    }
}

public struct ExecuteNotebookRequest: Codable {
    public let environmentVariables: [String: String]?
    
    public init(environmentVariables: [String: String]? = nil) {
        self.environmentVariables = environmentVariables
    }
}

// MARK: - AI Models

public struct AISuggestRequest: Codable {
    public let text: String
    public let context: String?
    public let maxSuggestions: Int
    
    public init(text: String, context: String? = nil, maxSuggestions: Int = 5) {
        self.text = text
        self.context = context
        self.maxSuggestions = maxSuggestions
    }
}

public struct AISuggestResponse: Codable {
    public let suggestions: [Suggestion]
    
    public struct Suggestion: Codable {
        public let text: String
        public let confidence: Double
        public let explanation: String?
    }
}

public struct AIConfidenceRequest: Codable {
    public let text: String
    public let language: String
    
    public init(text: String, language: String) {
        self.text = text
        self.language = language
    }
}

public struct AIConfidenceResponse: Codable {
    public let confidenceScore: Double
    public let issues: [Issue]
    
    public struct Issue: Codable {
        public let type: String
        public let message: String
        public let line: Int?
        public let severity: Severity
        
        public enum Severity: String, Codable {
            case error
            case warning
            case info
        }
    }
}

// MARK: - VFS Models

public struct VFSFile: Codable {
    public let name: String
    public let path: String
    public let type: FileType
    public let virtual: Bool
    public let size: Int
    public let contentType: String
    public let icon: String?
    public let generator: String?
    
    public enum FileType: String, Codable {
        case file
        case directory
    }
}

public struct VFSListing: Codable {
    public let path: String
    public let files: [VFSFile]
    public let virtualCount: Int
}

public struct VFSContent: Codable {
    public let path: String
    public let content: String
    public let virtual: Bool
    public let contentType: String
}