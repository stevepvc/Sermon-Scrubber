//
//  AppSettings.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("apiKeyOpenAI") var apiKeyOpenAI = ""
    @AppStorage("apiKeyAnthropic") var apiKeyAnthropic = ""
    @AppStorage("preferredAIService") var preferredAIService = AIService.APIType.byoClaude.rawValue
    @AppStorage("selectedOpenAIModel") var selectedOpenAIModel = AIConfig.defaultModelOpenAI
    @AppStorage("selectedAnthropicModel") var selectedAnthropicModel = AIConfig.defaultModelAnthropic
    @AppStorage("useCustomMaxTokens") var useCustomMaxTokens = false
    @AppStorage("customMaxOutputTokens") var customMaxOutputTokens = AIConfig.defaultMaxOutputTokens
    @AppStorage("customTemperature") var customTemperature = AIConfig.defaultTemperature
    @AppStorage("chunkSizeInSeconds") var chunkSizeInSeconds = 90
    @AppStorage("includePunctuation") var includePunctuation = true
}
