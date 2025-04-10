//
//  ScrubDocumentView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView.swift - Updated
import SwiftUI

struct ScrubDocumentView: View {
    @Binding var document: ScrubDocument
    @StateObject var transcriptionManager = TranscriptionManager()
    @StateObject var settings = AppSettings()
    @State var showingFilePicker = false
    @State var selectedVersionID: UUID?
    @State var showingNewVersionDialog = false
    @State var newVersionTitle = ""
    @State var showingShareSheet = false
    @State var showInspector = false
    @State var showingRenameDialog = false
    @State var versionToRename: ContentVersion?
    
    // Computed properties
    var selectedVersion: ContentVersion? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.first { $0.id == id }
    }
    
    var selectedVersionIndex: Int? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.firstIndex { $0.id == id }
    }
    
    var body: some View {
        #if os(macOS)
        macOSDocumentView
        #else
        iOSDocumentView
        #endif
    }
    
    // Common functionality methods
    
    var currentWordCount: Int {
        if let index = selectedVersionIndex {
            return wordCount(text: document.versions[index].content)
        } else if !document.originalTranscription.isEmpty && document.versions.isEmpty {
            return wordCount(text: document.originalTranscription)
        }
        return 0
    }
    
    func handleAudioFile(_ url: URL) {
        document.audioURL = url
        if document.documentTitle.isEmpty {
            document.documentTitle = url.deletingPathExtension().lastPathComponent
        }
        // Dismiss the file picker
        showingFilePicker = false
        
        // Optionally auto-start transcription
        transcribeAudio()
    }
    
    func transcribeAudio() {
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
    
    func createCustomVersion() {
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
    
    func deleteVersion(id: UUID) {
        if selectedVersionID == id {
            selectedVersionID = nil
        }
        document.versions.removeAll { $0.id == id }
    }
    
   func duplicateVersion(_ version: ContentVersion) {
        var duplicate = version
        duplicate.id = UUID()
        duplicate.title = "Copy of \(version.title)"
        duplicate.dateCreated = Date()
        document.versions.append(duplicate)
        selectedVersionID = duplicate.id
    }
    
    func setupNotifications() {
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
}
