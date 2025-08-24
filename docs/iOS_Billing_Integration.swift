//
//  KyozoSubscriptionManager.swift
//  Kyozo
//
//  Subscription management for iOS App Store integration
//  Works with Phoenix LiveView client for real-time updates
//

import Foundation
import StoreKit
import Combine
import os.log

@MainActor
class KyozoSubscriptionManager: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.kyozo.billing", category: "SubscriptionManager")
    private weak var phoenixClient: KyozoPhoenixClient?
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var currentPlan: SubscriptionPlan?
    @Published var usageLimits: UsageLimits?
    @Published var isProcessingPurchase = false
    @Published var purchaseError: Error?
    
    // Available plans (should match backend plan codes)
    let availablePlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            productId: "pro_monthly",
            displayName: "Pro Monthly",
            price: "$29.99",
            features: [
                "25,000 AI requests per month",
                "Real-time collaboration", 
                "Priority support",
                "Advanced Metal rendering"
            ],
            aiRequestsPerMonth: 25000,
            rateLimitPerMinute: 30
        ),
        SubscriptionPlan(
            productId: "pro_yearly", 
            displayName: "Pro Yearly",
            price: "$299.99",
            features: [
                "300,000 AI requests per month",
                "Real-time collaboration",
                "Priority support", 
                "Advanced Metal rendering",
                "17% savings vs monthly"
            ],
            aiRequestsPerMonth: 300000,
            rateLimitPerMinute: 30
        ),
        SubscriptionPlan(
            productId: "enterprise_monthly",
            displayName: "Enterprise",
            price: "$199.99", 
            features: [
                "Unlimited AI requests",
                "Custom models",
                "Dedicated instances",
                "SLA guarantee",
                "Phone support"
            ],
            aiRequestsPerMonth: nil, // Unlimited
            rateLimitPerMinute: 100
        )
    ]
    
    private var products: [Product] = []
    private var cancellables = Set<AnyCancellable>()
    
    enum SubscriptionStatus {
        case unknown, active, expired, inGracePeriod, pendingRenewal, error(String)
    }
    
    init(phoenixClient: KyozoPhoenixClient) {
        self.phoenixClient = phoenixClient
        super.init()
        
        setupStoreKit()
        setupPhoenixIntegration()
        
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - StoreKit Setup
    
    private func setupStoreKit() {
        // Listen for transaction updates
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await handleTransaction(transaction)
                } catch {
                    logger.error("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func setupPhoenixIntegration() {
        // Listen for subscription updates from Phoenix
        NotificationCenter.default.publisher(for: .subscriptionStatusUpdated)
            .sink { [weak self] notification in
                if let status = notification.userInfo?["status"] as? SubscriptionStatus {
                    self?.subscriptionStatus = status
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Product Loading
    
    private func loadProducts() async {
        do {
            let productIds = availablePlans.map { $0.productId }
            products = try await Product.products(for: Set(productIds))
            logger.info("Loaded \(products.count) products from App Store")
        } catch {
            logger.error("Failed to load products: \(error)")
            purchaseError = error
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ plan: SubscriptionPlan) async throws {
        guard let product = products.first(where: { $0.id == plan.productId }) else {
            throw SubscriptionError.productNotFound
        }
        
        isProcessingPurchase = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                
            case .pending:
                logger.info("Purchase pending approval")
                
            @unknown default:
                logger.warning("Unknown purchase result")
            }
        } catch {
            logger.error("Purchase failed: \(error)")
            purchaseError = error
            throw error
        } finally {
            isProcessingPurchase = false
        }
    }
    
    // MARK: - Transaction Handling
    
    private func handleTransaction(_ transaction: Transaction) async {
        logger.info("Handling transaction: \(transaction.id)")
        
        // Validate with backend
        await validateReceiptWithBackend(transaction)
        
        // Update local subscription status
        await checkSubscriptionStatus()
        
        // Sync with Phoenix for real-time updates across devices
        await syncSubscriptionWithPhoenix()
    }
    
    private func validateReceiptWithBackend(_ transaction: Transaction) async {
        guard let receiptData = await getAppStoreReceipt() else {
            logger.error("Could not get App Store receipt")
            return
        }
        
        // Find matching plan
        guard let plan = availablePlans.first(where: { $0.productId == transaction.productID }) else {
            logger.error("No matching plan found for product: \(transaction.productID)")
            return
        }
        
        do {
            // Call Kyozo API to validate receipt
            let response = try await validateReceiptWithKyozo(receiptData: receiptData, planCode: plan.productId)
            
            // Update local state with response
            updateSubscriptionFromAPI(response)
            
            logger.info("Receipt validated successfully with Kyozo backend")
        } catch {
            logger.error("Failed to validate receipt with backend: \(error)")
            subscriptionStatus = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Backend Integration
    
    private func validateReceiptWithKyozo(receiptData: String, planCode: String) async throws -> SubscriptionResponse {
        let url = URL(string: "https://api.kyozo.com/api/v1/billing/apple/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let body = [
            "receipt_data": receiptData,
            "plan_code": planCode
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SubscriptionError.validationFailed
        }
        
        return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
    }
    
    private func updateSubscriptionFromAPI(_ response: SubscriptionResponse) {
        let subscription = response.subscription
        
        // Update current plan
        if let plan = availablePlans.first(where: { $0.productId == subscription.plan.code }) {
            currentPlan = plan
        }
        
        // Update usage limits
        usageLimits = UsageLimits(
            aiRequestsPerMonth: response.usageLimits.aiRequestsPerMonth,
            currentUsage: response.usageLimits.currentUsage,
            remainingRequests: response.usageLimits.remainingRequests,
            rateLimitPerMinute: response.usageLimits.rateLimitPerMinute
        )
        
        // Update subscription status
        switch subscription.status {
        case "active":
            subscriptionStatus = .active
        case "expired":
            subscriptionStatus = .expired
        case "past_due":
            subscriptionStatus = .inGracePeriod
        default:
            subscriptionStatus = .unknown
        }
    }
    
    // MARK: - Phoenix Integration
    
    private func syncSubscriptionWithPhoenix() async {
        guard let phoenixClient = phoenixClient else { return }
        
        // Broadcast subscription update to other connected devices
        let payload: [String: Any] = [
            "type": "subscription_updated",
            "status": subscriptionStatusString(),
            "plan": currentPlan?.productId ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // This would be sent via Phoenix channel
        // phoenixClient.broadcastUserEvent("subscription_change", payload: payload)
    }
    
    // MARK: - Subscription Status Checking
    
    func checkSubscriptionStatus() async {
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let plan = availablePlans.first(where: { $0.productId == transaction.productID }) {
                    currentPlan = plan
                    
                    // Check if subscription is still valid
                    if transaction.expirationDate ?? Date.distantFuture > Date() {
                        subscriptionStatus = .active
                    } else {
                        subscriptionStatus = .expired
                    }
                }
            } catch {
                logger.error("Failed to verify current entitlement: \(error)")
            }
        }
        
        // Also sync with backend
        await fetchSubscriptionStatusFromBackend()
    }
    
    private func fetchSubscriptionStatusFromBackend() async {
        do {
            let url = URL(string: "https://api.kyozo.com/api/v1/billing/subscription")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
            
            updateSubscriptionFromAPI(response)
            
        } catch {
            logger.error("Failed to fetch subscription status: \(error)")
        }
    }
    
    // MARK: - Usage Tracking Integration
    
    func canMakeAIRequest() -> Bool {
        guard let limits = usageLimits else { return false }
        
        switch limits.remainingRequests {
        case .unlimited:
            return true
        case .limited(let remaining):
            return remaining > 0
        }
    }
    
    func recordAIRequest() async {
        // Decrement local counter
        if let limits = usageLimits {
            switch limits.remainingRequests {
            case .limited(let remaining) where remaining > 0:
                usageLimits?.remainingRequests = .limited(remaining - 1)
                usageLimits?.currentUsage += 1
            default:
                break
            }
        }
        
        // The actual usage recording happens on the backend via the AI API calls
        // This is just for immediate UI feedback
    }
    
    // MARK: - Helper Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func getAppStoreReceipt() async -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        
        return receiptData.base64EncodedString()
    }
    
    private func getAuthToken() -> String {
        // Get from your auth system
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
    }
    
    private func subscriptionStatusString() -> String {
        switch subscriptionStatus {
        case .active: return "active"
        case .expired: return "expired"
        case .inGracePeriod: return "grace_period"
        case .pendingRenewal: return "pending_renewal"
        case .unknown: return "unknown"
        case .error(_): return "error"
        }
    }
}

// MARK: - Data Models

struct SubscriptionPlan {
    let productId: String
    let displayName: String
    let price: String
    let features: [String]
    let aiRequestsPerMonth: Int?
    let rateLimitPerMinute: Int
}

struct UsageLimits {
    let aiRequestsPerMonth: RemainingRequests
    var currentUsage: Int
    var remainingRequests: RemainingRequests
    let rateLimitPerMinute: Int
    
    enum RemainingRequests {
        case unlimited
        case limited(Int)
    }
    
    init(aiRequestsPerMonth: Any, currentUsage: Int, remainingRequests: Any, rateLimitPerMinute: Int) {
        if let monthlyLimit = aiRequestsPerMonth as? Int {
            self.aiRequestsPerMonth = .limited(monthlyLimit)
        } else {
            self.aiRequestsPerMonth = .unlimited
        }
        
        self.currentUsage = currentUsage
        
        if let remaining = remainingRequests as? Int {
            self.remainingRequests = .limited(remaining)
        } else {
            self.remainingRequests = .unlimited
        }
        
        self.rateLimitPerMinute = rateLimitPerMinute
    }
}

struct SubscriptionResponse: Codable {
    let subscription: SubscriptionInfo
    let usageLimits: APIUsageLimits
    
    struct SubscriptionInfo: Codable {
        let id: String
        let provider: String
        let status: String
        let currentPeriodEnd: String
        let autoRenewEnabled: Bool
        let plan: PlanInfo
        
        struct PlanInfo: Codable {
            let code: String
            let name: String
            let features: [String: Any]
            
            private enum CodingKeys: String, CodingKey {
                case code, name, features
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                code = try container.decode(String.self, forKey: .code)
                name = try container.decode(String.self, forKey: .name)
                
                // Decode features as [String: Any]
                let featuresContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .features)
                features = try Self.decodeAnyDictionary(from: featuresContainer)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(code, forKey: .code)
                try container.encode(name, forKey: .name)
                
                var featuresContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .features)
                try Self.encodeAnyDictionary(features, to: &featuresContainer)
            }
            
            private static func decodeAnyDictionary(from container: KeyedDecodingContainer<AnyCodingKey>) throws -> [String: Any] {
                var result: [String: Any] = [:]
                
                for key in container.allKeys {
                    if let value = try? container.decode(String.self, forKey: key) {
                        result[key.stringValue] = value
                    } else if let value = try? container.decode(Int.self, forKey: key) {
                        result[key.stringValue] = value
                    } else if let value = try? container.decode(Bool.self, forKey: key) {
                        result[key.stringValue] = value
                    }
                }
                
                return result
            }
            
            private static func encodeAnyDictionary(_ dictionary: [String: Any], to container: inout KeyedEncodingContainer<AnyCodingKey>) throws {
                for (key, value) in dictionary {
                    let codingKey = AnyCodingKey(stringValue: key)!
                    
                    if let stringValue = value as? String {
                        try container.encode(stringValue, forKey: codingKey)
                    } else if let intValue = value as? Int {
                        try container.encode(intValue, forKey: codingKey)
                    } else if let boolValue = value as? Bool {
                        try container.encode(boolValue, forKey: codingKey)
                    }
                }
            }
        }
    }
    
    struct APIUsageLimits: Codable {
        let aiRequestsPerMonth: AnyCodable
        let currentUsage: Int
        let remainingRequests: AnyCodable
        let rateLimitPerMinute: Int
        
        private enum CodingKeys: String, CodingKey {
            case aiRequestsPerMonth = "ai_requests_per_month"
            case currentUsage = "current_usage"
            case remainingRequests = "remaining_requests"
            case rateLimitPerMinute = "rate_limit_per_minute"
        }
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else {
            value = ()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else {
            try container.encodeNil()
        }
    }
}

enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case failedVerification
    case validationFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in App Store"
        case .failedVerification:
            return "Failed to verify App Store transaction"
        case .validationFailed:
            return "Failed to validate receipt with server"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let subscriptionStatusUpdated = Notification.Name("SubscriptionStatusUpdated")
}

// MARK: - Integration with existing Metal engine

extension KyozoPhoenixClient {
    func setSubscriptionManager(_ subscriptionManager: KyozoSubscriptionManager) {
        // Store weak reference and integrate with AI requests
        
        // Override AI request methods to check subscription
        func requestAICompletionWithSubscriptionCheck(documentId: String, context: String, position: Int) -> AnyPublisher<AICompletion, Error> {
            
            guard subscriptionManager.canMakeAIRequest() else {
                return Fail(error: SubscriptionError.validationFailed)
                    .eraseToAnyPublisher()
            }
            
            // Record usage for immediate UI feedback
            Task {
                await subscriptionManager.recordAIRequest()
            }
            
            // Make the actual request
            return requestAICompletion(documentId: documentId, context: context, position: position)
        }
    }
}