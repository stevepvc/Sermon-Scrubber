//
//  SettingsView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings()
    @EnvironmentObject private var proxyViewModel: SermonProxyViewModel
    @State private var selectedTab: SettingsTab = .general

    private enum SettingsTab: Hashable {
        case general
        case models
        case usage
    }

    private var modelUsageSummaries: [ModelUsageSummary] { AIUsageTracker.shared.modelUsageBreakdown() }
    private let openAIModels = [
        "gpt-4o-mini",
        "gpt-4o-mini-128k",
        "gpt-4.1-mini",
        "gpt-4o"
    ]
    private let anthropicModels = [
        "claude-3-7-sonnet-20250219",
        "claude-3-5-haiku-20241022",
        "claude-3-5-sonnet-20241022"
    ]

    private var selectedModelSource: AIService.APIType {
        AIService.APIType.resolve(from: settings.preferredAIService)
    }

    private var providerDisplayName: String {
        if let provider = selectedModelSource.provider {
            return provider == .openai ? "OpenAI" : "Anthropic"
        }
        return "Direct (User API Key)"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            modelTab
                .tabItem { Label("AI Models", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.models)

            usageTab
                .tabItem { Label("Usage", systemImage: "chart.bar") }
                .tag(SettingsTab.usage)
        }
        .padding()
        .frame(width: 460)
        .frame(minHeight: 360)
    }

    private var generalTab: some View {
        Form {
            Section(header: Text("Transcription Settings")) {
                Slider(
                    value: Binding<Double>(
                        get: { Double(settings.chunkSizeInSeconds) },
                        set: { settings.chunkSizeInSeconds = Int($0) }
                    ),
                    in: 60...240,
                    step: 10
                ) {
                    Text("Chunk Size")
                }

                Text("Current chunk size: \(settings.chunkSizeInSeconds) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Include Punctuation", isOn: $settings.includePunctuation)
                    .help("Adds punctuation to the transcript when available")
            }
        }
    }

    private var modelTab: some View {
        Form {
            Section(header: Text("Model Source")) {
                Picker("Model Source", selection: $settings.preferredAIService) {
                    ForEach(AIService.APIType.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(description(for: selectedModelSource))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if selectedModelSource.requiresAPIKey {
                Section(header: Text("API Credentials")) {
                    if selectedModelSource == .byoClaude {
                        SecureField("Anthropic API Key", text: $settings.apiKeyAnthropic)
                        Link("Get an Anthropic API key", destination: URL(string: "https://console.anthropic.com/")!)
                    } else if selectedModelSource == .byoChatGPT {
                        SecureField("OpenAI API Key", text: $settings.apiKeyOpenAI)
                        Link("Get an OpenAI API key", destination: URL(string: "https://platform.openai.com/")!)
                    }
                }
            }

            Section(header: Text("Provider")) {
                Picker("Provider", selection: .constant(providerDisplayName)) {
                    Text(providerDisplayName).tag(providerDisplayName)
                }
                .pickerStyle(.segmented)
                .disabled(true)
            }

            Section(header: Text("Model Configuration")) {
                if selectedModelSource.provider == .openai {
                    Picker("Model", selection: $settings.selectedOpenAIModel) {
                        ForEach(openAIModels, id: \.self) { model in
                            Text(model)
                        }
                    }
                } else if selectedModelSource.provider == .anthropic {
                    Picker("Model", selection: $settings.selectedAnthropicModel) {
                        ForEach(anthropicModels, id: \.self) { model in
                            Text(model)
                        }
                    }
                } else {
                    Text("Model selection is controlled by the provider you configure directly.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Toggle("Specify Max Output Tokens", isOn: $settings.useCustomMaxTokens)

                if settings.useCustomMaxTokens {
                    Stepper(value: $settings.customMaxOutputTokens, in: 100...8000, step: 50) {
                        Text("Max Output Tokens: \(settings.customMaxOutputTokens)")
                    }
                }

                VStack(alignment: .leading) {
                    Slider(value: $settings.customTemperature, in: 0...1, step: 0.05) {
                        Text("Temperature")
                    }
                    Text("Temperature: \(settings.customTemperature, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var usageTab: some View {
        Form {
            Section(header: Text("Proxy Usage")) {
                if proxyViewModel.usageLog.entries.isEmpty {
                    Text("No proxy usage recorded yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(proxyViewModel.usageLog.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.timestamp.formatted(date: .numeric, time: .shortened))
                                .font(.headline)
                            Text("Idempotency Key: \(entry.idempotencyKey)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("\(entry.provider) – \(entry.model)")
                                Spacer()
                                if let tokens = entry.tokensUsed {
                                    Text("Tokens: \(tokens)")
                                }
                            }
                            Text("Input words: \(entry.inputWordCount) • Output words: \(entry.outputWordCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if entry.replayFlag {
                                Label("Replayed from cache", systemImage: "arrow.counterclockwise.circle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(header: Text("Export")) {
                UsageExportControls(usageLog: proxyViewModel.usageLog)
            }

            Section(header: Text("Direct API Usage")) {
                if modelUsageSummaries.isEmpty {
                    Text("No direct API usage recorded yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(modelUsageSummaries) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(summary.providerDisplayName) – \(summary.model)")
                                .font(.headline)

                            HStack {
                                Text("Requests: \(summary.requestCount)")
                                Spacer()
                                Text("Input Tokens: \(summary.inputTokens.formatted())")
                            }

                            HStack {
                                Text("Output Tokens: \(summary.outputTokens.formatted())")
                                Spacer()
                                Text("Estimated Cost: $ \(summary.estimatedCostInUSD)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func description(for source: AIService.APIType) -> String {
        switch source {
        case .byoClaude:
            return "Connect using your Anthropic API key to call Claude directly."
        case .byoChatGPT:
            return "Connect using your OpenAI API key to call ChatGPT directly."
        case .subscriberClaude:
            return "Use your Sermon Scrubber subscription to route Claude requests through our proxy."
        case .subscriberChatGPT:
            return "Use your Sermon Scrubber subscription to route ChatGPT requests through our proxy."
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
