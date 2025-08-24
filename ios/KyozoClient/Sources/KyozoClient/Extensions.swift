import Foundation

// MARK: - Dictionary Extension for JSON

extension Dictionary where Key == String, Value == Any {
    static func decode(from decoder: Decoder) throws -> [String: Any] {
        let container = try decoder.singleValueContainer()
        return try container.decode([String: Any].self)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any] {
        let container = try nestedContainer(keyedBy: JSONCodingKey.self, forKey: key)
        return try container.decode(type)
    }
    
    func decodeIfPresent(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any]? {
        guard contains(key) else { return nil }
        return try decode(type, forKey: key)
    }
    
    func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        var dictionary = [String: Any]()
        
        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode([String: Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode([Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        
        return dictionary
    }
}

// MARK: - Array Extension for JSON

extension UnkeyedDecodingContainer {
    mutating func decode(_ type: [Any].Type) throws -> [Any] {
        var array: [Any] = []
        
        while isAtEnd == false {
            if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode([String: Any].self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode([Any].self) {
                array.append(nestedArray)
            }
        }
        
        return array
    }
}

// MARK: - JSON Coding Key

struct JSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }
    
    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Async/Await Helpers

@available(iOS 13.0, macOS 10.15, *)
public extension URLSession {
    /// Convenience method for async data tasks
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
    }
}

// MARK: - File Creation Helpers

public extension CreateFileRequest {
    /// Create a markdown file with code blocks
    static func markdown(
        name: String,
        title: String,
        codeBlocks: [(language: String, code: String)]
    ) -> CreateFileRequest {
        var content = "# \(title)\n\n"
        
        for (index, block) in codeBlocks.enumerated() {
            if index > 0 {
                content += "\n"
            }
            content += "```\(block.language)\n"
            content += block.code
            content += "\n```\n"
        }
        
        return CreateFileRequest(
            name: name,
            content: content,
            contentType: "text/markdown"
        )
    }
    
    /// Create a simple markdown document
    static func simpleMarkdown(name: String, content: String) -> CreateFileRequest {
        CreateFileRequest(
            name: name,
            content: content,
            contentType: "text/markdown"
        )
    }
}

// MARK: - Notebook Execution Helpers

public extension Notebook {
    /// Check if notebook has any executable tasks
    var hasExecutableTasks: Bool {
        !extractedTasks.isEmpty
    }
    
    /// Get task by ID
    func task(withId id: String) -> Task? {
        extractedTasks.first { $0.id == id }
    }
    
    /// Check if notebook is currently executing
    var isExecuting: Bool {
        status == .running
    }
    
    /// Check if notebook has completed execution
    var hasCompleted: Bool {
        status == .completed
    }
    
    /// Check if notebook execution resulted in error
    var hasError: Bool {
        status == .error
    }
}

// MARK: - VFS Helpers

public extension VFSFile {
    /// Check if this is a markdown file
    var isMarkdown: Bool {
        contentType == "text/markdown" || 
        name.hasSuffix(".md") || 
        name.hasSuffix(".markdown")
    }
    
    /// Check if this is a virtual guide file
    var isGuide: Bool {
        virtual && (name == "guide.md" || name == "deploy.md" || name == "overview.md")
    }
}

// MARK: - Error Helpers

public extension KyozoError {
    /// Check if error is due to authentication
    var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .forbidden:
            return true
        default:
            return false
        }
    }
    
    /// Check if error is temporary and request can be retried
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .httpError(let code) where code >= 500:
            return true
        default:
            return false
        }
    }
}