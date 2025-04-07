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
    @AppStorage("preferredAIService") var preferredAIService = "Claude"
    @AppStorage("chunkSizeInSeconds") var chunkSizeInSeconds = 90
    @AppStorage("includePunctuation") var includePunctuation = true
}
