//
//  KyozoServiceProxy.swift
//  Kyozo
//
//  Service proxy pattern for unified iOS integration
//  All services accessed through Kyozo Phoenix channels
//

import Foundation
import Combine

extension KyozoPhoenixClient {
    
    // MARK: - Lang Service Proxy
    
    /// Request LSP completion through Kyozo (tracked for billing)
    func requestLSPCompletion(
        documentId: String,
        position: LSPPosition,
        language: String
    ) -> AnyPublisher<LSPCompletionResponse, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "service": "lang",
            "method": "textDocument/completion",
            "params": [
                "textDocument": ["uri": documentId],
                "position": [
                    "line": position.line,
                    "character": position.character
                ],
                "language": language
            ]
        ]
        
        return channel.push("service_request", payload: payload)
            .map { message in
                LSPCompletionResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    /// Request LSP diagnostics through Kyozo
    func requestLSPDiagnostics(
        documentId: String,
        content: String,
        language: String
    ) -> AnyPublisher<LSPDiagnosticResponse, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "service": "lang",
            "method": "textDocument/publishDiagnostics", 
            "params": [
                "textDocument": ["uri": documentId],
                "content": content,
                "language": language
            ]
        ]
        
        return channel.push("service_request", payload: payload)
            .map { message in
                LSPDiagnosticResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    /// Notify Lang service of document changes
    func notifyDocumentDidChange(
        documentId: String,
        changes: [DocumentChange],
        version: Int
    ) -> AnyPublisher<Void, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let changesData = changes.map { change in
            [
                "range": [
                    "start": ["line": change.range.start.line, "character": change.range.start.character],
                    "end": ["line": change.range.end.line, "character": change.range.end.character]
                ],
                "text": change.text
            ]
        }
        
        let payload: [String: Any] = [
            "service": "lang",
            "method": "textDocument/didChange",
            "params": [
                "textDocument": [
                    "uri": documentId,
                    "version": version
                ],
                "contentChanges": changesData
            ]
        ]
        
        return channel.push("service_request", payload: payload)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Build Service Proxy
    
    /// Request build/compilation through Kyozo
    func requestBuild(
        workspaceId: String,
        target: String? = nil,
        options: [String: Any] = [:]
    ) -> AnyPublisher<BuildResponse, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "service": "build",
            "method": "build",
            "params": [
                "workspace_id": workspaceId,
                "target": target ?? "default",
                "options": options
            ]
        ]
        
        return channel.push("service_request", payload: payload)
            .map { message in
                BuildResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Store Service Proxy
    
    /// Request file operations through Store service
    func requestFileOperation(
        operation: FileOperation,
        path: String,
        content: String? = nil
    ) -> AnyPublisher<FileOperationResponse, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        var params: [String: Any] = [
            "operation": operation.rawValue,
            "path": path
        ]
        
        if let content = content {
            params["content"] = content
        }
        
        let payload: [String: Any] = [
            "service": "store",
            "method": "file_operation",
            "params": params
        ]
        
        return channel.push("service_request", payload: payload)
            .map { message in
                FileOperationResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Proc Service Proxy
    
    /// Execute code through Proc service
    func executeCode(
        code: String,
        language: String,
        environment: [String: String] = [:]
    ) -> AnyPublisher<ExecutionResponse, Error> {
        
        guard let channel = syncChannel else {
            return Fail(error: PhoenixError.connectionFailed(NSError(domain: "No channel", code: 0)))
                .eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "service": "proc",
            "method": "execute",
            "params": [
                "code": code,
                "language": language,
                "environment": environment
            ]
        ]
        
        return channel.push("service_request", payload: payload)
            .map { message in
                ExecutionResponse(from: message.payload)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Unified Service Interface

extension KyozoPhoenixClient {
    
    /// High-level method that coordinates multiple services
    func performIntelligentCompletion(
        documentId: String,
        position: LSPPosition,
        context: String,
        language: String
    ) -> AnyPublisher<IntelligentCompletionResponse, Error> {
        
        // This method demonstrates how Kyozo can coordinate multiple services
        // for a single user action
        
        let lspRequest = requestLSPCompletion(
            documentId: documentId,
            position: position,
            language: language
        )
        
        let aiRequest = requestAICompletion(
            documentId: documentId,
            context: context,
            position: position.character
        )
        
        // Combine LSP and AI responses
        return Publishers.Zip(lspRequest, aiRequest)
            .map { lspResponse, aiResponse in
                IntelligentCompletionResponse(
                    lspCompletions: lspResponse.completions,
                    aiSuggestions: aiResponse.suggestions,
                    hybridRanking: self.rankCompletions(lsp: lspResponse, ai: aiResponse)
                )
            }
            .eraseToAnyPublisher()
    }
    
    /// Smart document analysis combining multiple services
    func analyzeDocument(
        documentId: String,
        content: String,
        language: String
    ) -> AnyPublisher<DocumentAnalysisResponse, Error> {
        
        let diagnosticsRequest = requestLSPDiagnostics(
            documentId: documentId,
            content: content,
            language: language
        )
        
        let aiAnalysisRequest = requestAICompletion(
            documentId: documentId,
            context: "analyze_code_quality",
            position: 0
        )
        
        return Publishers.Zip(diagnosticsRequest, aiAnalysisRequest)
            .map { diagnostics, aiAnalysis in
                DocumentAnalysisResponse(
                    lspDiagnostics: diagnostics.diagnostics,
                    aiInsights: aiAnalysis.suggestions,
                    overallScore: self.calculateCodeQuality(diagnostics: diagnostics, ai: aiAnalysis),
                    recommendations: self.generateRecommendations(diagnostics: diagnostics, ai: aiAnalysis)
                )
            }
            .eraseToAnyPublisher()
    }
    
    private func rankCompletions(lsp: LSPCompletionResponse, ai: AICompletion) -> [RankedCompletion] {
        // Intelligent ranking algorithm combining LSP accuracy with AI context
        var ranked: [RankedCompletion] = []
        
        // Add LSP completions with high precision weight
        for completion in lsp.completions {
            ranked.append(RankedCompletion(
                text: completion.text,
                source: .lsp,
                score: completion.confidence * 0.8, // LSP is precise but limited
                explanation: "Language server suggestion"
            ))
        }
        
        // Add AI completions with creativity weight
        for suggestion in ai.suggestions {
            ranked.append(RankedCompletion(
                text: suggestion.text,
                source: .ai,
                score: suggestion.confidence * 0.6, // AI is creative but less precise
                explanation: suggestion.explanation
            ))
        }
        
        // Sort by score and return top results
        return ranked.sorted { $0.score > $1.score }
    }
    
    private func calculateCodeQuality(diagnostics: LSPDiagnosticResponse, ai: AICompletion) -> Double {
        let errorWeight = diagnostics.diagnostics.filter { $0.severity == .error }.count * -10
        let warningWeight = diagnostics.diagnostics.filter { $0.severity == .warning }.count * -5
        let aiQualityScore = ai.suggestions.first?.confidence ?? 0.5
        
        return max(0, min(100, 70 + errorWeight + warningWeight + (aiQualityScore * 30)))
    }
    
    private func generateRecommendations(diagnostics: LSPDiagnosticResponse, ai: AICompletion) -> [String] {
        var recommendations: [String] = []
        
        // Add LSP-based recommendations
        if !diagnostics.diagnostics.isEmpty {
            recommendations.append("Fix \(diagnostics.diagnostics.count) code issues detected")
        }
        
        // Add AI-based recommendations
        for suggestion in ai.suggestions.prefix(2) {
            if suggestion.type == "improvement" {
                recommendations.append(suggestion.explanation)
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct LSPPosition {
    let line: Int
    let character: Int
}

struct DocumentChange {
    let range: LSPRange
    let text: String
    
    struct LSPRange {
        let start: LSPPosition
        let end: LSPPosition
    }
}

struct LSPCompletionResponse {
    let completions: [LSPCompletion]
    
    struct LSPCompletion {
        let text: String
        let kind: CompletionKind
        let detail: String?
        let documentation: String?
        let confidence: Double
        
        enum CompletionKind: String {
            case text, method, function, constructor, field, variable, `class`, interface, module, property, unit, value, `enum`, keyword, snippet, color, file, reference, folder, enumMember, constant, `struct`, event, operator, typeParameter
        }
    }
    
    init(from data: [String: Any]) {
        // Parse LSP completion response
        self.completions = [] // Implementation would parse actual LSP data
    }
}

struct LSPDiagnosticResponse {
    let diagnostics: [LSPDiagnostic]
    
    struct LSPDiagnostic {
        let range: DocumentChange.LSPRange
        let severity: Severity
        let message: String
        let source: String?
        
        enum Severity {
            case error, warning, information, hint
        }
    }
    
    init(from data: [String: Any]) {
        // Parse LSP diagnostic response
        self.diagnostics = [] // Implementation would parse actual LSP data
    }
}

struct BuildResponse {
    let success: Bool
    let output: String
    let errors: [String]
    let warnings: [String]
    let buildTime: TimeInterval
    
    init(from data: [String: Any]) {
        self.success = data["success"] as? Bool ?? false
        self.output = data["output"] as? String ?? ""
        self.errors = data["errors"] as? [String] ?? []
        self.warnings = data["warnings"] as? [String] ?? []
        self.buildTime = data["build_time"] as? TimeInterval ?? 0
    }
}

enum FileOperation: String {
    case read, write, delete, create, move, copy
}

struct FileOperationResponse {
    let success: Bool
    let content: String?
    let error: String?
    
    init(from data: [String: Any]) {
        self.success = data["success"] as? Bool ?? false
        self.content = data["content"] as? String
        self.error = data["error"] as? String
    }
}

struct ExecutionResponse {
    let output: String
    let error: String?
    let exitCode: Int
    let executionTime: TimeInterval
    
    init(from data: [String: Any]) {
        self.output = data["output"] as? String ?? ""
        self.error = data["error"] as? String
        self.exitCode = data["exit_code"] as? Int ?? 0
        self.executionTime = data["execution_time"] as? TimeInterval ?? 0
    }
}

struct IntelligentCompletionResponse {
    let lspCompletions: [LSPCompletionResponse.LSPCompletion]
    let aiSuggestions: [AICompletion.Completion]
    let hybridRanking: [RankedCompletion]
}

struct RankedCompletion {
    let text: String
    let source: Source
    let score: Double
    let explanation: String
    
    enum Source {
        case lsp, ai, hybrid
    }
}

struct DocumentAnalysisResponse {
    let lspDiagnostics: [LSPDiagnosticResponse.LSPDiagnostic]
    let aiInsights: [AICompletion.Completion]
    let overallScore: Double
    let recommendations: [String]
}