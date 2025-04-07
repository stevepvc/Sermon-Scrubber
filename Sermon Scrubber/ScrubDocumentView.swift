//
//  ScrubDocumentView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct ScrubDocumentView: View {
    @Binding var document: ScrubDocument
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var settings = AppSettings()
    @State private var showingFilePicker = false
    @State private var selectedVersionID: UUID?
    @State private var showingNewVersionDialog = false
    @State private var newVersionTitle = ""
    @State private var showingShareSheet = false
    @State private var showInspector = true
    
    // Get current selected version or nil if none selected
    private var selectedVersion: ContentVersion? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.first { $0.id == id }
    }
    
    // Get index of selected version
    private var selectedVersionIndex: Int? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.firstIndex { $0.id == id }
    }
    
    var body: some View {
        NavigationView {
            #if os(iOS)
            sidebar
            contentView
            // On iOS, inspector is conditionally displayed
            if showInspector {
                InspectorView(document: document)
            }
            #else
            HSplitView {
                sidebar
                contentView
                if showInspector {
                    InspectorView(document: $document)
                        .frame(minWidth: 250, idealWidth: 300)
                }
            }
            #endif
        }
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                handleAudioFile(url)
            }
        }
        .sheet(isPresented: $showingNewVersionDialog) {
            createVersionDialog
        }
        .onAppear {
            // Existing code for selecting first version
            if !document.versions.isEmpty && selectedVersionID == nil {
                selectedVersionID = document.versions[0].id
            }
            
            // Add the notification observers
            NotificationCenter.default.addObserver(forName: Notification.Name("CreateNewVersion"), object: nil, queue: .main) { _ in
                newVersionTitle = "New Version"
                showingNewVersionDialog = true
            }
            NotificationCenter.default.addObserver(forName: Notification.Name("TranscribeAudio"), object: nil, queue: .main) { _ in
                if document.audioURL != nil && !transcriptionManager.isTranscribing {
                    transcribeAudio()
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    var sidebar: some View {
        List {
            Section("Document Info") {
                TextField("Title", text: $document.documentTitle)
                DatePicker("Date", selection: $document.preachDate, displayedComponents: .date)
                TextField("Preacher", text: $document.preacher)
                TextField("Sermon Title", text: $document.sermonTitle)
                TextField("Location", text: $document.location)
            }
            
            Section("Audio") {
                Button(document.audioURL == nil ? "Select Audio File" : "Change Audio File") {
                    showingFilePicker = true
                }
                
                if document.audioURL != nil {
                    Button("Transcribe Audio") {
                        transcribeAudio()
                    }
                    .disabled(transcriptionManager.isTranscribing)
                }
            }
            
            if !document.versions.isEmpty {
                Section("Versions") {
                    ForEach(document.versions) { version in
                        HStack {
                            Image(systemName: version.versionType.iconName)
                                .foregroundColor(.accentColor)
                            
                            Text(version.title)
                                .font(selectedVersionID == version.id ? .headline : .body)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVersionID = version.id
                        }
                        .contextMenu {
                            Button("Rename") {
                                newVersionTitle = version.title
                                showingNewVersionDialog = true
                            }
                            Button("Delete") {
                                deleteVersion(id: version.id)
                            }
                            Button("Duplicate") {
                                duplicateVersion(version)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        #if os(macOS)
        .frame(minWidth: 200)
        #endif
    }
    
    var contentView: some View {
        VStack {
            if transcriptionManager.isTranscribing {
                transcriptionProgressView
            } else if let version = selectedVersion, let index = selectedVersionIndex {
                // Editor for selected version
                TextEditor(text: $document.versions[index].content)
                    .font(.body)
                    .padding()
            } else if document.audioURL == nil && document.originalTranscription.isEmpty {
                dropZoneView
            } else if !document.originalTranscription.isEmpty && document.versions.isEmpty {
                // Show original transcription if there are no versions yet
                VStack {
                    Text("Original Transcription")
                        .font(.headline)
                        .padding([.top, .horizontal])
                    
                    TextEditor(text: $document.originalTranscription)
                        .font(.body)
                        .padding()
                }
            } else {
                // Show instruction to select a version
                Text("Select a version from the sidebar")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !document.versions.isEmpty {
                    // Toggle inspector
                    Button(action: {
                        showInspector.toggle()
                    }) {
                        Label("Inspector", systemImage: showInspector ? "sidebar.right" : "sidebar.right.fill")
                    }
                    
                    // New version button
                    Button(action: {
                        newVersionTitle = "New Version"
                        showingNewVersionDialog = true
                    }) {
                        Label("New Version", systemImage: "plus")
                    }
                    
                    // Share button
                    Button(action: {
                        if selectedVersion != nil {
                            showingShareSheet = true
                        }
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(selectedVersion == nil)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            #if os(iOS)
            if let content = selectedVersion?.content {
                // Add metadata header if available
                let contentToShare = document.metadataHeader() + content
                ShareSheet(items: [contentToShare])
            }
            #else
            // macOS sharing
            Text("Implement macOS sharing here")
                .frame(width: 300, height: 200)
            #endif
        }
    }
    
    var transcriptionProgressView: some View {
        VStack {
            ProgressView(value: transcriptionManager.transcriptionProgress) {
                Text("Transcribing...")
            }
            .padding()
            
            Text("Chunk \(transcriptionManager.currentChunk) of \(transcriptionManager.totalChunks)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Transcription metadata form
            Form {
                Section(header: Text("While you wait, enter sermon information:")) {
                    TextField("Sermon Title", text: $document.sermonTitle)
                    TextField("Preacher", text: $document.preacher)
                    TextField("Location", text: $document.location)
                    DatePicker("Date", selection: $document.preachDate, displayedComponents: .date)
                }
            }
            .padding()
            
            if !transcriptionManager.transcriptionText.isEmpty {
                ScrollView {
                    Text(transcriptionManager.transcriptionText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }
    }
    
    var dropZoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(.gray)
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 50))
                Text("Drop audio file here")
                    .font(.title2)
                Text("or click to browse")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onTapGesture {
            showingFilePicker = true
        }
#if os(macOS)
.onDrop(of: [UTType.audio.identifier], isTargeted: nil) { providers, _ in
    guard let provider = providers.first else { return false }
    
    provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { item, _ in
        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            DispatchQueue.main.async {
                handleAudioFile(url)
            }
        }
    }
    return true
}
#endif
    }
    
    var createVersionDialog: some View {
        VStack(spacing: 20) {
            Text("Create New Version")
                .font(.headline)
            
            TextField("Version Title", text: $newVersionTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    showingNewVersionDialog = false
                    newVersionTitle = ""
                }
                
                Button("Create") {
                    createCustomVersion()
                    showingNewVersionDialog = false
                    newVersionTitle = ""
                }
                .disabled(newVersionTitle.isEmpty)
            }
        }
        .padding()
    }
    
    private func handleAudioFile(_ url: URL) {
        document.audioURL = url
        if document.documentTitle.isEmpty {
            document.documentTitle = url.deletingPathExtension().lastPathComponent
        }
    }
    
    private func transcribeAudio() {
        guard let url = document.audioURL else { return }
        
        Task {
            let transcription = await transcriptionManager.transcribeAudio(from: url)
            await MainActor.run {
                document.setTranscription(transcription)
                if let id = document.versions.first(where: { $0.versionType == .transcript })?.id {
                    selectedVersionID = id
                }
            }
        }
    }
    
    private func createCustomVersion() {
        guard !newVersionTitle.isEmpty else { return }
        
        let content = document.originalTranscription.isEmpty ? "" : document.originalTranscription
        let newVersion = ContentVersion(
            title: newVersionTitle,
            content: content,
            dateCreated: Date(),
            versionType: .custom
        )
        document.versions.append(newVersion)
        selectedVersionID = newVersion.id
    }
    
    private func deleteVersion(id: UUID) {
        if selectedVersionID == id {
            selectedVersionID = nil
        }
        document.versions.removeAll { $0.id == id }
    }
    
    private func duplicateVersion(_ version: ContentVersion) {
        var duplicate = version
        duplicate.id = UUID()
        duplicate.title = "Copy of \(version.title)"
        duplicate.dateCreated = Date()
        document.versions.append(duplicate)
        selectedVersionID = duplicate.id
    }
}

struct ScrubDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        ScrubDocumentView(document: .constant(ScrubDocument.sampleScrub()))
    }
}
