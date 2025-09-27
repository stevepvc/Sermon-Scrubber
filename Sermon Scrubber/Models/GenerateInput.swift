//
//  GenerateInput.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public struct GenerateInput: Encodable, Equatable {
    public var prompt: String
    public var provider: String   // "openai" | "anthropic" (server expects a string)
    public var model: String
    public var maxOutputTokens: Int?
    public var temperature: Double?

    public init(
        prompt: String,
        provider: AIProvider = AIConfig.defaultProvider,
        model: String? = nil,
        maxOutputTokens: Int? = AIConfig.defaultMaxOutputTokens,
        temperature: Double? = AIConfig.defaultTemperature
    ) {
        self.prompt = prompt
        self.provider = provider.rawValue
        self.model = model ?? (provider == .openai ? AIConfig.defaultModelOpenAI : AIConfig.defaultModelAnthropic)
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
    }
}

