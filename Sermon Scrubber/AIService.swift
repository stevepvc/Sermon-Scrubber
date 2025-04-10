//
//  AIService.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
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
    @AppStorage("apiKeyOpenAI") private var apiKeyOpenAI = ""
    @AppStorage("apiKeyAnthropic") private var apiKeyAnthropic = ""
    @AppStorage("preferredAIService") private var preferredAIService = "Claude"
    
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
    
    func callClaudeAPI(text: String, prompt: String) async throws -> String {
        guard !apiKeyAnthropic.isEmpty else {
            throw NSError(domain: "AI Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        // Create the request URL
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKeyAnthropic, forHTTPHeaderField: "x-api-key")
        
        // Prepare the message payload
        let payload: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "user",
                    "content": "Here's a sermon transcript:\n\n\(text)\n\n\(prompt)"
                ]
            ]
        ]
        
        // Serialize to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AI Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        // Add this before checking status code in callClaudeAPI
        print("API token: \(apiKeyAnthropic)")
        print("Response status code: \(httpResponse.statusCode)")
        print("Response headers: \(httpResponse.allHeaderFields)")
        let responseText = String(data: data, encoding: .utf8) ?? "Could not decode response"
        print("Response body: \(responseText)")
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AI Error", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API error: \(errorText)"])
        }
        
        // Parse the response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? [[String: Any]],
           let firstItem = content.first(where: { ($0["type"] as? String) == "text" }),
           let text = firstItem["text"] as? String {
            return text
        } else {
            // Try to extract error message if possible
            let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
            throw NSError(domain: "AI Error", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
        }
    }
    
    func callChatGPTAPI(text: String, prompt: String) async throws -> String {
        guard !apiKeyOpenAI.isEmpty else {
            throw NSError(domain: "AI Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        // Create the request URL
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKeyOpenAI)", forHTTPHeaderField: "Authorization")
        
        // Prepare the message payload
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that processes sermon transcripts."
                ],
                [
                    "role": "user",
                    "content": "Here's a sermon transcript:\n\n\(text)\n\n\(prompt)"
                ]
            ]
        ]
        
        // Serialize to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AI Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AI Error", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API error: \(errorText)"])
        }
        
        // Parse the response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        } else {
            // Try to extract error message if possible
            let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
            throw NSError(domain: "AI Error", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
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
