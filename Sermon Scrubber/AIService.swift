//
//  AIService.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import Foundation
import SwiftUI

struct AIService: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let apiType: APIType

    enum APIType: String, CaseIterable, Identifiable {
        case byoClaude = "BYO-Claude"
        case byoChatGPT = "BYO-ChatGPT"
        case subscriberClaude = "Subscriber-Claude"
        case subscriberChatGPT = "Subscriber-ChatGPT"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .byoClaude: return "BYO – Claude"
            case .byoChatGPT: return "BYO – ChatGPT"
            case .subscriberClaude: return "Subscriber – Claude"
            case .subscriberChatGPT: return "Subscriber – ChatGPT"
            }
        }

        var shortDisplayName: String {
            switch self {
            case .byoClaude, .subscriberClaude: return "Claude"
            case .byoChatGPT, .subscriberChatGPT: return "ChatGPT"
            }
        }

        var iconName: String {
            switch self {
            case .byoClaude, .subscriberClaude:
                return "bubble.left.and.bubble.right"
            case .byoChatGPT, .subscriberChatGPT:
                return "text.bubble"
            }
        }

        var requiresAPIKey: Bool {
            switch self {
            case .byoClaude, .byoChatGPT:
                return true
            case .subscriberClaude, .subscriberChatGPT:
                return false
            }
        }

        var provider: AIProvider? {
            switch self {
            case .subscriberClaude: return .anthropic
            case .subscriberChatGPT: return .openai
            case .byoClaude, .byoChatGPT: return nil
            }
        }

        static func resolve(from storedValue: String) -> APIType {
            if let value = APIType(rawValue: storedValue) {
                return value
            }

            switch storedValue {
            case "Claude":
                return .byoClaude
            case "ChatGPT":
                return .byoChatGPT
            default:
                return .byoClaude
            }
        }
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false
    @Published var selectedService: AIService.APIType?
    @Published var errorMessage: String?
    @Published var progressMessage: String = ""
    @Published var progressPercentage: Double = 0
    @AppStorage("apiKeyOpenAI") var apiKeyOpenAI = ""
    @AppStorage("apiKeyAnthropic") var apiKeyAnthropic = ""
    @AppStorage("preferredAIService") var preferredAIServiceRaw = AIService.APIType.byoClaude.rawValue {
        didSet {
            applyPreferredServiceIfPossible()
        }
    }

    init() {
        // Initialize selected service from saved preferences
        initializeFromSavedSettings()
    }

    private func initializeFromSavedSettings() {
        applyPreferredServiceIfPossible()
    }

    let availableServices: [AIService] = [
        AIService(
            name: "BYO – Claude",
            description: "Use your personal Anthropic API key for Claude.",
            icon: "bubble.left.and.bubble.right",
            apiType: .byoClaude
        ),
        AIService(
            name: "BYO – ChatGPT",
            description: "Use your personal OpenAI API key for ChatGPT.",
            icon: "text.bubble",
            apiType: .byoChatGPT
        ),
        AIService(
            name: "Subscriber – Claude",
            description: "Route Claude requests through the Sermon Proxy (subscriber feature).",
            icon: "bubble.left.and.bubble.right",
            apiType: .subscriberClaude
        ),
        AIService(
            name: "Subscriber – ChatGPT",
            description: "Route ChatGPT requests through the Sermon Proxy (subscriber feature).",
            icon: "text.bubble",
            apiType: .subscriberChatGPT
        )
    ]

    func select(serviceType: AIService.APIType) {
        preferredAIServiceRaw = serviceType.rawValue
        selectedService = serviceType
    }

    func requiresAPIKey(for serviceType: AIService.APIType) -> Bool {
        serviceType.requiresAPIKey
    }

    private func applyPreferredServiceIfPossible() {
        let desired = AIService.APIType.resolve(from: preferredAIServiceRaw)

        switch desired {
        case .byoClaude:
            if !apiKeyAnthropic.isEmpty {
                selectedService = .byoClaude
            }
        case .byoChatGPT:
            if !apiKeyOpenAI.isEmpty {
                selectedService = .byoChatGPT
            }
        case .subscriberClaude, .subscriberChatGPT:
            selectedService = desired
        }
    }

    func processWithAI(text: String, prompt: String, usesCaching: Bool = false) async -> String? {
        guard let serviceType = selectedService else { return nil }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
            self.progressMessage = usesCaching ? "Preparing for unabridged processing..." : ""
            self.progressPercentage = usesCaching ? 0.05 : 0
        }
        
        do {
            let result = try await sendToAI(text: text, prompt: prompt, service: serviceType, usesCaching: usesCaching)
            
            await MainActor.run {
                self.isProcessing = false
                self.progressMessage = ""
                self.progressPercentage = 0
            }
            
            return result
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.progressMessage = ""
                self.progressPercentage = 0
            }
            print("AI processing error: \(error)")
            return nil
        }
    }
    
    func sendToAI(text: String, prompt: String, service: AIService.APIType, usesCaching: Bool = false) async throws -> String {
        switch service {
        case .byoClaude:
            if usesCaching {
                return try await callClaudeAPIWithCaching(text: text, prompt: prompt)
            } else {
                return try await callClaudeAPI(text: text, prompt: prompt)
            }
        case .byoChatGPT:
            return try await callChatGPTAPI(text: text, prompt: prompt)
        case .subscriberClaude, .subscriberChatGPT:
            throw NSError(domain: "AI Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscriber services are handled by SermonProxyViewModel."])
        }
    }

    func isConfigured(for serviceType: AIService.APIType) -> Bool {
        switch serviceType {
        case .byoClaude:
            return !apiKeyAnthropic.isEmpty
        case .byoChatGPT:
            return !apiKeyOpenAI.isEmpty
        case .subscriberClaude, .subscriberChatGPT:
            return true
        }
    }

    func configure(apiKey: String, for serviceType: AIService.APIType) {
        switch serviceType {
        case .byoClaude:
            apiKeyAnthropic = apiKey
            select(serviceType: .byoClaude)
        case .byoChatGPT:
            apiKeyOpenAI = apiKey
            select(serviceType: .byoChatGPT)
        case .subscriberClaude, .subscriberChatGPT:
            select(serviceType: serviceType)
        }
    }
}
