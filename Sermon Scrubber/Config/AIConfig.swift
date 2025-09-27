//
//  AIConfig.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public enum AIProvider: String, Codable, CaseIterable {
    case openai
    case anthropic
}

public struct AIConfig {
    public static var BASE_URL = URL(string: "https://sermon-proxy-849642354380.us-central1.run.app")!
    public static var requestTimeout: TimeInterval = 60

    // Fast defaults; callers can override per request
    public static var defaultProvider: AIProvider = .openai
    public static var defaultModelOpenAI: String = "gpt-4o-mini"
    public static var defaultModelAnthropic: String = "claude-3-7-sonnet-20250219"
    public static var defaultMaxOutputTokens: Int = 800
    public static var defaultTemperature: Double = 0.2
}

