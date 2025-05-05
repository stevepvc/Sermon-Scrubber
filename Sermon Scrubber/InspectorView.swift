//
//  InspectorView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    @Binding var document: ScrubDocument
    @StateObject private var aiManager = AIManager()
    @State private var selectedTab = 0
    @State private var customPrompt = ""
    @State private var showingAPIKeyEntry = false
    @State private var temporaryAPIKey = ""
    @State private var serviceToSetup: AIService.APIType?
    @State private var selectedVersionID: UUID?
    
    // Get current selected version or nil if none selected
    private var selectedVersion: ContentVersion? {
        guard let id = selectedVersionID else {
            return document.versions.first
        }
        return document.versions.first { $0.id == id }
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
                Button(action: {
                    serviceToSetup = service.apiType
                    showingAPIKeyEntry = true
                }) {
                    HStack {
                        Image(systemName: service.icon)
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .font(.headline)
                            Text(service.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(8)
                    // With:
                    #if os(iOS)
                    .background(Color(UIColor.systemGray6))
                    #else
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    var aiInteractionView: some View {
        VStack {
            if document.versions.isEmpty {
                Text("Create a transcript first")
                    .foregroundColor(.secondary)
            } else {
                // Version selector
                Picker("Version", selection: $selectedVersionID) {
                    ForEach(document.versions) { version in
                        Text(version.title).tag(version.id as UUID?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.bottom)
                
                Divider()
                
                // AI Options
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
                                prompt: "Create a devotional based on this sermon content. Include a relevant scripture reference, reflection, and application questions."
                            )
                            
                            makePromptButton(
                                title: "Summary",
                                description: "Create a concise summary",
                                prompt: "Create a concise summary of this content highlighting the key points and main message in about 250 words."
                            )
                            
                            makePromptButton(
                                title: "Class Lesson Plan",
                                description: "Create a classroom lesson plan",
                                prompt: "Transform this content into a classroom lesson plan with objectives, activities, discussion questions, and application exercises suitable for teaching this material."
                            )
                            
                            makePromptButton(
                                title: "Growth Points",
                                description: "Identify areas for improvement",
                                prompt: "Analyze this sermon and identify potential areas for improvement in terms of clarity, structure, engagement, illustrations, application, and overall effectiveness. Provide constructive feedback that could help make this message more impactful."
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
                            .disabled(customPrompt.isEmpty || aiManager.isProcessing)
                        }
                    }
                }
                
                if aiManager.isProcessing {
                    VStack {
                        ProgressView(value: aiManager.progressPercentage)
                            .padding()
                        
                        if !aiManager.progressMessage.isEmpty {
                            Text(aiManager.progressMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let error = aiManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                // AI Service info
                let serviceName = aiManager.selectedService == .claude ? "Claude" : "ChatGPT"
                HStack {
                    Image(systemName: aiManager.selectedService == .claude ? "bubble.left.and.bubble.right" : "text.bubble")
                    Text("Using \(serviceName)")
                    
                    Spacer()
                    
                    Button("Change") {
                        aiManager.selectedService = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top)
            }
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
        .disabled(aiManager.isProcessing || selectedVersion == nil)
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
            let serviceName = serviceToSetup == .claude ? "Claude" : "ChatGPT"
            
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
            
            Link("Get an API key", destination: URL(string: serviceToSetup == .claude ? "https://console.anthropic.com/" : "https://platform.openai.com/")!)
                .font(.caption)
        }
        .padding()
        .frame(width: 400)
    }
    
    private func processWithAI(prompt: String) {
        guard let version = selectedVersion else { return }
        
        Task {
            // Determine if we should use caching based on the prompt type
            let usesCaching = prompt.contains("keeping the full length and all content intact")
            
            if let result = await aiManager.processWithAI(text: version.content, prompt: prompt, usesCaching: usesCaching) {
                await MainActor.run {
                    // Determine version type based on prompt
                    let versionType: ContentVersion.VersionType
                    
                    // Initialize versionType based on prompt content
                    if prompt.contains("Clean up") && prompt.contains("keeping the full length and all content intact") {
                        versionType = .cleanedUpUnabridged
                    } else if prompt.contains("Clean up") {
                        versionType = .cleanedUp
                    } else if prompt.contains("Add headings") {
                        versionType = .withHeadings
                    } else if prompt.contains("blog post series") {
                        versionType = .blogPostSeries
                    } else if prompt.contains("blog post") {
                        versionType = .blogPost
                    } else if prompt.contains("book chapter") {
                        versionType = .bookChapter
                    } else if prompt.contains("devotional") {
                        versionType = .devotional
                    } else if prompt.contains("summary") {
                        versionType = .summary
                    } else if prompt.contains("lesson plan") {
                        versionType = .classLessonPlan
                    } else if prompt.contains("Growth Points") || prompt.contains("improvement") {
                        versionType = .growthPoints
                    } else {
                        versionType = .custom
                    }
                    
                    // Add the new version with the appropriate caches flag
                    let serviceName = aiManager.selectedService == .claude ? "Claude" : "ChatGPT"
                    let title = "\(versionType.defaultTitle) (\(serviceName))"
                    var newVersion = ContentVersion(title: title, content: result, dateCreated: Date(), versionType: versionType)
                    newVersion.caches = usesCaching
                    document.versions.append(newVersion)
                    
                    // Select the new version
                    if let newVersionId = document.versions.last?.id {
                        selectedVersionID = newVersionId
                    }
                }
            }
        }
    }
}

struct InspectorView_Previews: PreviewProvider {
    static var previews: some View {
        InspectorView(document: .constant(ScrubDocument.sampleScrub()))
            .frame(width: 350)
    }
}
