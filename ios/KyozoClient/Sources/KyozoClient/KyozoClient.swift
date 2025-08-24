import Foundation

/// Main client for interacting with the Kyozo API
public class KyozoClient {
    public let baseURL: URL
    public let session: URLSession
    private let apiKey: String?
    private let bearerToken: String?
    
    // Service instances
    public lazy var teams = TeamsService(client: self)
    public lazy var workspaces = WorkspacesService(client: self)
    public lazy var files = FilesService(client: self)
    public lazy var notebooks = NotebooksService(client: self)
    public lazy var ai = AIService(client: self)
    public lazy var vfs = VFSService(client: self)
    
    /// Initialize with API key authentication
    public init(baseURL: URL = URL(string: "http://localhost:4000/api/v1")!, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.bearerToken = nil
        self.session = URLSession.shared
    }
    
    /// Initialize with Bearer token authentication
    public init(baseURL: URL = URL(string: "http://localhost:4000/api/v1")!, bearerToken: String) {
        self.baseURL = baseURL
        self.apiKey = nil
        self.bearerToken = bearerToken
        self.session = URLSession.shared
    }
    
    /// Initialize with custom URLSession
    public init(baseURL: URL = URL(string: "http://localhost:4000/api/v1")!, 
                bearerToken: String,
                session: URLSession) {
        self.baseURL = baseURL
        self.apiKey = nil
        self.bearerToken = bearerToken
        self.session = session
    }
    
    // MARK: - Internal Request Building
    
    func buildRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) throws -> URLRequest {
        // Build URL
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw KyozoError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add authentication
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        } else if let bearerToken = bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Add common headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add body if present
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.kyozo.encode(body)
        }
        
        return request
    }
    
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KyozoError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.kyozo.decode(T.self, from: data)
        case 401:
            throw KyozoError.unauthorized
        case 403:
            throw KyozoError.forbidden
        case 404:
            throw KyozoError.notFound
        case 429:
            throw KyozoError.rateLimited
        default:
            if let errorResponse = try? JSONDecoder.kyozo.decode(ErrorResponse.self, from: data) {
                throw KyozoError.serverError(errorResponse.error, details: errorResponse.details)
            }
            throw KyozoError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    func executeEmpty(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KyozoError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw KyozoError.unauthorized
        case 403:
            throw KyozoError.forbidden
        case 404:
            throw KyozoError.notFound
        case 429:
            throw KyozoError.rateLimited
        default:
            throw KyozoError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
    case put = "PUT"
}

// MARK: - Errors

public enum KyozoError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(String, details: [String: Any]?)
    case httpError(statusCode: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - check your API credentials"
        case .forbidden:
            return "Forbidden - you don't have access to this resource"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited - too many requests"
        case .serverError(let message, _):
            return "Server error: \(message)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}

// MARK: - JSON Coding

extension JSONEncoder {
    static let kyozo: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let kyozo: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Common Response Types

struct DataResponse<T: Decodable>: Decodable {
    let data: T
}

struct ErrorResponse: Decodable {
    let error: String
    let details: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case error
        case details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decode(String.self, forKey: .error)
        details = try container.decodeIfPresent([String: Any].self, forKey: .details)
    }
}