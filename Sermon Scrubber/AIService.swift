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
    
    enum APIType {
        case claude
        case chatGPT
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false
    @Published var selectedService: AIService.APIType?
    @Published var errorMessage: String?
    @AppStorage("apiKeyOpenAI") var apiKeyOpenAI = ""
    @AppStorage("apiKeyAnthropic") var apiKeyAnthropic = ""
    @AppStorage("preferredAIService") var preferredAIService = "Claude"
    
    init() {
        // Initialize selected service from saved preferences
        initializeFromSavedSettings()
    }
    
    private func initializeFromSavedSettings() {
        // Check if we have API keys stored and set the selected service accordingly
        if preferredAIService == "Claude" && !apiKeyAnthropic.isEmpty {
            selectedService = .claude
        } else if preferredAIService == "ChatGPT" && !apiKeyOpenAI.isEmpty {
            selectedService = .chatGPT
        }
        // Otherwise, leave selectedService as nil so the user selects it
    }
    
    let availableServices = [
        AIService(
            name: "Claude",
            description: "Anthropic's Claude AI excels at thoughtful analysis and creative content generation.",
            icon: "bubble.left.and.bubble.right",
            apiType: .claude
        ),
        AIService(
            name: "ChatGPT",
            description: "OpenAI's ChatGPT is great for general tasks and has strong coding capabilities.",
            icon: "text.bubble",
            apiType: .chatGPT
        )
    ]
    
    func processWithAI(text: String, prompt: String) async -> String? {
        guard let serviceType = selectedService else { return nil }
        
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }
        
        do {
            let result = try await sendToAI(text: text, prompt: prompt, service: serviceType)
            
            await MainActor.run {
                self.isProcessing = false
            }
            
            return result
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func sendToAI(text: String, prompt: String, service: AIService.APIType) async throws -> String {
        switch service {
        case .claude:
            return try await callClaudeAPI(text: text, prompt: prompt)
        case .chatGPT:
            return try await callChatGPTAPI(text: text, prompt: prompt)
        }
    }
    
    func isConfigured(for serviceType: AIService.APIType) -> Bool {
        switch serviceType {
        case .claude:
            return !apiKeyAnthropic.isEmpty
        case .chatGPT:
            return !apiKeyOpenAI.isEmpty
        }
    }
    
    func configure(apiKey: String, for serviceType: AIService.APIType) {
        switch serviceType {
        case .claude:
            apiKeyAnthropic = apiKey
            preferredAIService = "Claude"
        case .chatGPT:
            apiKeyOpenAI = apiKey
            preferredAIService = "ChatGPT"
        }
        
        selectedService = serviceType
    }
}
