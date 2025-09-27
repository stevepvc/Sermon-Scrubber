//
//  InspectorView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct InspectorView: View {
    @Binding var document: ScrubDocument
    @StateObject private var aiManager = AIManager()
    @EnvironmentObject private var proxyViewModel: SermonProxyViewModel
    @State private var selectedTab = 0
    @State private var customPrompt = ""
    @State private var showingAPIKeyEntry = false
    @State private var temporaryAPIKey = ""
    @State private var serviceToSetup: AIService.APIType?
    @State private var selectedVersionID: UUID?
    @State private var lastPromptIssued: String = ""
    @State private var showLastOutputDisclosure: Bool = false

    @AppStorage("preferredAIService") private var preferredModelSourceRaw = AIService.APIType.byoClaude.rawValue
    @AppStorage("selectedOpenAIModel") private var selectedOpenAIModel = AIConfig.defaultModelOpenAI
    @AppStorage("selectedAnthropicModel") private var selectedAnthropicModel = AIConfig.defaultModelAnthropic
    @AppStorage("useCustomMaxTokens") private var useCustomMaxTokens = false
    @AppStorage("customMaxOutputTokens") private var customMaxOutputTokens = AIConfig.defaultMaxOutputTokens
    @AppStorage("customTemperature") private var customTemperature = AIConfig.defaultTemperature
    @AppStorage("appAccountToken") private var storedAppAccountToken = ""
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

    // Get current selected version or nil if none selected
    private var selectedVersion: ContentVersion? {
        guard let id = selectedVersionID else {
            return document.versions.first
        }
        return document.versions.first { $0.id == id }
    }

    private var selectedModelSource: AIService.APIType {
        if let current = aiManager.selectedService {
            return current
        }
        return AIService.APIType.resolve(from: preferredModelSourceRaw)
    }

    private var isSubscriberSelected: Bool {
        selectedModelSource.provider != nil && aiManager.selectedService == selectedModelSource
    }

    private var activeProviderDisplayName: String {
        if let provider = selectedModelSource.provider {
            return provider == .openai ? "OpenAI" : "Anthropic"
        }
        return selectedModelSource.shortDisplayName
    }

    private var selectedModelName: String {
        if selectedModelSource.provider == .openai {
            return selectedOpenAIModel
        } else if selectedModelSource.provider == .anthropic {
            return selectedAnthropicModel
        }
        return selectedModelSource.shortDisplayName
    }

    private var configuredMaxTokens: Int? {
        useCustomMaxTokens ? customMaxOutputTokens : nil
    }

    private var isServiceBusy: Bool {
        isSubscriberSelected ? proxyViewModel.isLoading : aiManager.isProcessing
    }

    private var currentErrorMessage: String? {
        isSubscriberSelected ? proxyViewModel.errorMessage : aiManager.errorMessage
    }

    private var currentRemainingBalance: Int? {
        proxyViewModel.preflightAfter?.remaining ?? proxyViewModel.preflightBefore?.remaining
    }

    private var lastTokensDelta: Int? {
        guard let before = proxyViewModel.preflightBefore?.remaining,
              let after = proxyViewModel.preflightAfter?.remaining else { return nil }
        return max(0, before - after)
    }
    
    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                aiAssistantView
                    .tabItem {
                        Label("AI Assistant", systemImage: "wand.and.stars")
                    }
                    .tag(0)
                
                markdownPreviewView
                    .tabItem {
                        Label("Preview", systemImage: "doc.richtext")
                    }
                    .tag(1)
            }
        }
        .sheet(isPresented: $showingAPIKeyEntry) {
            apiKeyEntryView
        }
        .task {
            synchronizeSelectedService(with: preferredModelSourceRaw)
            await handleServiceSelectionChange(aiManager.selectedService)
        }
        .onChange(of: preferredModelSourceRaw) { newValue in
            synchronizeSelectedService(with: newValue)
        }
        .onChange(of: aiManager.selectedService) { newValue in
            Task {
                await handleServiceSelectionChange(newValue)
            }
        }
    }
    
    var aiAssistantView: some View {
        VStack {
            if aiManager.selectedService == nil {
                serviceSelectionView
            } else {
                aiInteractionView
            }
        }
        .padding()
    }
    
    var serviceSelectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose an AI Assistant")
                .font(.headline)
            
            ForEach(aiManager.availableServices) { service in
                serviceOptionButton(
                    for: service,
                    isSelected: selectedModelSource == service.apiType,
                    action: { handleInitialServiceSelection(service.apiType) }
                )

            }
        }
    }
    
    var aiInteractionView: some View {
        VStack(alignment: .leading, spacing: 16) {

            modelSourceSelectionList
                .padding(.bottom, 8)



            if document.versions.isEmpty {
                Text("Create a transcript first")
                    .foregroundColor(.secondary)
            } else {
                Picker("Version", selection: $selectedVersionID) {
                    ForEach(document.versions) { version in
                        Text(version.title).tag(version.id as UUID?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.bottom, 8)

                if isSubscriberSelected {
                    subscriberConfigurationView
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Group {
                            makePromptButton(
                                title: "Clean Up and Condense",
                                description: "Improve readability and condense",
                                prompt: "Edit this text to improve readability. Fix grammar errors and remove filler words while condensing the content to about 1/3 of its original length."
                            )

                            makePromptButton(
                                title: "Clean Up (Unabridged)",
                                description: "Improve readability without condensing",
                                prompt: "Edit this text to improve readability. Fix grammar errors and remove filler words while keeping the full length and all content intact."
                            )

                            makePromptButton(
                                title: "Add Headings",
                                description: "Structure with section headings",
                                prompt: "Add appropriate section headings to structure this content into logical sections. Identify the main themes and create a clear hierarchical structure."
                            )

                            makePromptButton(
                                title: "Blog Post",
                                description: "Format as a publishable blog post",
                                prompt: "Transform this content into a well-structured blog post with an engaging title, introduction, body, and conclusion."
                            )

                            makePromptButton(
                                title: "Blog Post Series",
                                description: "Create a series of related blog posts",
                                prompt: "Transform this content into a series of 3-5 related blog posts. Each post should be focused on a different aspect of the sermon but work together as a cohesive series. Include titles for each post."
                            )

                            makePromptButton(
                                title: "Book Chapter",
                                description: "Format as a book chapter",
                                prompt: "Transform this content into a chapter suitable for a book. Add depth, examples, and narrative elements while maintaining the core message."
                            )
                        }

                        Group {
                            makePromptButton(
                                title: "Devotional",
                                description: "Create a daily devotional",
                                prompt: "Create a daily devotional entry based on this sermon content. Include a scripture reference, a short reflection, and an application."
                            )

                            makePromptButton(
                                title: "Summary",
                                description: "Summarize the sermon",
                                prompt: "Summarize this sermon transcript into a concise overview highlighting the main points, scripture references, and applications."
                            )

                            makePromptButton(
                                title: "Lesson Plan",
                                description: "Create a class lesson plan",
                                prompt: "Create a detailed lesson plan for a small group or Sunday school class based on this sermon. Include objectives, discussion questions, and activities."
                            )

                            makePromptButton(
                                title: "Growth Points",
                                description: "Identify improvement opportunities",
                                prompt: "Identify areas in this sermon that could be improved for clarity, engagement, or theological depth. Provide specific suggestions."
                            )

                            makePromptButton(
                                title: "Social Media",
                                description: "Create social media posts",
                                prompt: "Create a series of 5 social media posts (Twitter/X or Facebook) that capture key takeaways from this sermon. Each post should be concise and engaging."
                            )

                            makePromptButton(
                                title: "Key Quotes",
                                description: "Highlight quotable moments",
                                prompt: "Extract the most impactful quotes or short excerpts from this sermon that could be used for social media or promotional materials."
                            )
                        }

                        Divider()

                        VStack(alignment: .leading) {
                            Text("Custom Prompt:")
                                .font(.headline)

                            TextEditor(text: $customPrompt)
                                .frame(height: 100)
                                .border(Color.gray.opacity(0.2))

                            Button("Process with Custom Prompt") {
                                processWithAI(prompt: customPrompt)
                            }
                            .disabled(customPrompt.isEmpty || isServiceBusy)
                        }
                    }
                }

                if isServiceBusy {
                    progressSection
                }

                if let error = currentErrorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                }

                if isSubscriberSelected {
                    subscriberStatusFooter
                } else {
                    byoStatusFooter
                }
            }
        }
    }
    private var progressSection: some View {
        VStack {
            if isSubscriberSelected {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
            } else {
                ProgressView(value: aiManager.progressPercentage)
                    .padding()

                if !aiManager.progressMessage.isEmpty {
                    Text(aiManager.progressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var subscriberConfigurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriber Controls")
                .font(.headline)

            Picker("Provider", selection: .constant(activeProviderDisplayName)) {
                Text(activeProviderDisplayName).tag(activeProviderDisplayName)
            }
            .pickerStyle(.segmented)
            .disabled(true)

            if selectedModelSource.provider == .openai {
                Picker("Model", selection: $selectedOpenAIModel) {
                    ForEach(openAIModels, id: \.self) { model in
                        Text(model)
                    }
                }
            } else if selectedModelSource.provider == .anthropic {
                Picker("Model", selection: $selectedAnthropicModel) {
                    ForEach(anthropicModels, id: \.self) { model in
                        Text(model)
                    }
                }
            }

            Toggle("Specify Max Output Tokens", isOn: $useCustomMaxTokens)

            if useCustomMaxTokens {
                Stepper(value: $customMaxOutputTokens, in: 100...8000, step: 50) {
                    Text("Max Output Tokens: \(customMaxOutputTokens)")
                }
            } else {
                Text("Using proxy default max output tokens")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Slider(value: $customTemperature, in: 0...1, step: 0.05) {
                    Text("Temperature")
                }
                Text("Temperature: \(customTemperature, specifier: "%.2f")")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private var modelSourceSelectionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Source")
                .font(.headline)

            ForEach(aiManager.availableServices) { service in
                serviceOptionButton(
                    for: service,
                    isSelected: selectedModelSource == service.apiType,
                    action: { handleServiceSelection(service.apiType) }
                )
            }
        }
    }


    private var subscriberStatusFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let remaining = currentRemainingBalance {
                Text("Remaining balance: \(remaining.formatted()) tokens")
                    .font(.headline)
            }

            if let delta = lastTokensDelta {
                Text("Tokens used last call: \(delta)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Refresh Balance") {
                    Task { await proxyViewModel.refreshPreflight() }
                }
                .disabled(proxyViewModel.isLoading)

                if proxyViewModel.replayBanner {
                    Label("Replayed from cache", systemImage: "arrow.counterclockwise.circle")
                        .foregroundColor(.orange)
                }
            }

            if proxyViewModel.lastErrorCode == 402 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Out of balance. Add a booster to continue.")
                        .foregroundColor(.orange)
                    Button("Explore Boosters") {}
                        .buttonStyle(.bordered)
                }
            }

            if proxyViewModel.lastErrorCode == 409 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A matching request is still completing. Idempotency key: \(proxyViewModel.lastIdempotencyKey)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("Retry Last Request") {
                            processWithAI(prompt: lastPromptIssued)
                        }
                        .disabled(isServiceBusy || lastPromptIssued.isEmpty)

                        Button("Copy Request ID") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(proxyViewModel.lastIdempotencyKey, forType: .string)
                            #endif
                        }
                        .disabled(proxyViewModel.lastIdempotencyKey.isEmpty)
                    }
                }
            }

            if !proxyViewModel.lastOutputText.isEmpty {
                DisclosureGroup("Last Output", isExpanded: $showLastOutputDisclosure) {
                    ScrollView {
                        Text(proxyViewModel.lastOutputText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 160)
                }
            }

            if !proxyViewModel.lastIdempotencyKey.isEmpty {
                Text("Last request ID: \(proxyViewModel.lastIdempotencyKey)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            UsageExportControls(usageLog: proxyViewModel.usageLog)
        }
        .padding(.vertical)
    }

    private var defaultServiceBackground: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }

    @ViewBuilder
    private func serviceOptionButton(
        for service: AIService,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: service.apiType.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.headline)

                    Text(service.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if aiManager.requiresAPIKey(for: service.apiType) && !aiManager.isConfigured(for: service.apiType) {
                        Text("API key required")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : defaultServiceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }


    private var byoStatusFooter: some View {
        HStack {
            Image(systemName: selectedModelSource.iconName)
            Text("Using \(selectedModelSource.displayName)")

            Spacer()

            Button("Change") {
                aiManager.selectedService = nil
            }
            .buttonStyle(.borderless)
        }
        .padding(.top)
    }

    private func handleInitialServiceSelection(_ serviceType: AIService.APIType) {
        if aiManager.requiresAPIKey(for: serviceType) && !aiManager.isConfigured(for: serviceType) {
            serviceToSetup = serviceType
            showingAPIKeyEntry = true
        } else {
            aiManager.select(serviceType: serviceType)
        }
    }

    private func handleServiceSelection(_ serviceType: AIService.APIType) {
        if aiManager.requiresAPIKey(for: serviceType) && !aiManager.isConfigured(for: serviceType) {
            serviceToSetup = serviceType
            showingAPIKeyEntry = true
        } else if aiManager.selectedService != serviceType {
            aiManager.select(serviceType: serviceType)
        }
    }

    private func synchronizeSelectedService(with rawValue: String) {
        let resolved = AIService.APIType.resolve(from: rawValue)
        if aiManager.requiresAPIKey(for: resolved) && !aiManager.isConfigured(for: resolved) {
            aiManager.selectedService = nil
        } else if aiManager.selectedService != resolved {
            aiManager.selectedService = resolved
        }
    }

    private func handleServiceSelectionChange(_ newValue: AIService.APIType?) async {
        guard let newValue else { return }
        if newValue.provider != nil {
            await ensureProxySession()
        }
    }

    private func ensureProxySession() async {
        let token = ensureStableAppAccountToken()
        if proxyViewModel.token == nil {
            await proxyViewModel.authenticate(appAccountToken: token)
        }
        await proxyViewModel.refreshPreflight()
    }

    private func ensureStableAppAccountToken() -> String {
        if storedAppAccountToken.isEmpty {
            storedAppAccountToken = UUID().uuidString
        }
        return storedAppAccountToken
    }

    private func determineVersionType(for prompt: String) -> ContentVersion.VersionType {
        if prompt.contains("Clean up") && prompt.contains("keeping the full length and all content intact") {
            return .cleanedUpUnabridged
        } else if prompt.contains("Clean up") {
            return .cleanedUp
        } else if prompt.contains("Add headings") {
            return .withHeadings
        } else if prompt.contains("blog post series") {
            return .blogPostSeries
        } else if prompt.contains("blog post") {
            return .blogPost
        } else if prompt.contains("book chapter") {
            return .bookChapter
        } else if prompt.contains("devotional") {
            return .devotional
        } else if prompt.contains("summary") {
            return .summary
        } else if prompt.contains("lesson plan") {
            return .classLessonPlan
        } else if prompt.contains("Growth Points") || prompt.contains("improvement") {
            return .growthPoints
        }
        return .custom
    }

    private func appendVersion(content: String, versionType: ContentVersion.VersionType, serviceLabel: String, usesCaching: Bool) {
        let title = "\(versionType.defaultTitle) (\(serviceLabel))"
        var newVersion = ContentVersion(title: title, content: content, dateCreated: Date(), versionType: versionType)
        newVersion.caches = usesCaching
        document.versions.append(newVersion)
        if let newVersionId = document.versions.last?.id {
            selectedVersionID = newVersionId
        }
    }

    func makePromptButton(title: String, description: String, prompt: String) -> some View {
        Button(action: {
            processWithAI(prompt: prompt)
        }) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            // With:
            #if os(iOS)
            .background(Color(UIColor.systemGray6))
            #else
            .background(Color(NSColor.windowBackgroundColor))
            #endif
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isServiceBusy || selectedVersion == nil)
    }
    
    var markdownPreviewView: some View {
        VStack {
            if let version = selectedVersion {
                ScrollView {
                    markdownView(for: version.content)
                        .padding()
                }
            } else {
                Text("No content to preview")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func markdownView(for content: String) -> some View {
        // This is a placeholder. In a real app, you'd use a Markdown rendering library
        // or implement your own Markdown parser
        Text(content)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var apiKeyEntryView: some View {
        VStack(spacing: 20) {
            let serviceName = serviceToSetup?.shortDisplayName ?? "Service"
            let linkURL: URL? = {
                switch serviceToSetup {
                case .byoClaude?:
                    return URL(string: "https://console.anthropic.com/")
                case .byoChatGPT?:
                    return URL(string: "https://platform.openai.com/")
                default:
                    return nil
                }
            }()

            Text("Setup \(serviceName) API Key")
                .font(.headline)

            Text("Enter your API key to connect to \(serviceName)")
                .foregroundColor(.secondary)
            
            SecureField("API Key", text: $temporaryAPIKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button("Cancel") {
                    temporaryAPIKey = ""
                    showingAPIKeyEntry = false
                }
                
                Button("Save") {
                    if let serviceType = serviceToSetup {
                        aiManager.configure(apiKey: temporaryAPIKey, for: serviceType)
                    }
                    temporaryAPIKey = ""
                    showingAPIKeyEntry = false
                }
                .disabled(temporaryAPIKey.isEmpty)
            }
            
            if let linkURL {
                Link("Get an API key", destination: linkURL)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func processWithProxy(prompt: String, version: ContentVersion, usesCaching: Bool) async {
        guard let provider = selectedModelSource.provider else { return }
        await ensureProxySession()

        let modelName = provider == .openai ? selectedOpenAIModel : selectedAnthropicModel
        let promptBody = "\(prompt)\n\n\(version.content)"

        let result = await proxyViewModel.generate(
            prompt: promptBody,
            provider: provider,
            model: modelName,
            maxOutputTokens: configuredMaxTokens,
            temperature: customTemperature
        )

        if let result {
            let versionType = determineVersionType(for: prompt)
            await MainActor.run {
                let text = result.text.isEmpty ? proxyViewModel.lastOutputText : result.text
                appendVersion(
                    content: text,
                    versionType: versionType,
                    serviceLabel: selectedModelSource.shortDisplayName,
                    usesCaching: usesCaching
                )
                showLastOutputDisclosure = false
            }
        }
    }

    private func processWithAI(prompt: String) {
        guard let version = selectedVersion else { return }
        guard let service = aiManager.selectedService else { return }

        lastPromptIssued = prompt

        Task {
            let usesCaching = prompt.contains("keeping the full length and all content intact")

            if service.provider != nil {
                await processWithProxy(prompt: prompt, version: version, usesCaching: usesCaching)
            } else if let result = await aiManager.processWithAI(text: version.content, prompt: prompt, usesCaching: usesCaching) {
                let versionType = determineVersionType(for: prompt)
                await MainActor.run {
                    appendVersion(content: result, versionType: versionType, serviceLabel: service.shortDisplayName, usesCaching: usesCaching)
                    showLastOutputDisclosure = false
                }
            }
        }
    }
}

struct InspectorView_Previews: PreviewProvider {
    static var previews: some View {
        InspectorView(document: .constant(ScrubDocument.sampleScrub()))
            .frame(width: 350)
            .environmentObject(SermonProxyViewModel())
    }
}
