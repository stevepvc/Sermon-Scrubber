//
//  DocumentViewModel.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// DocumentViewModel.swift
import SwiftUI
import UniformTypeIdentifiers

class DocumentViewModel: ObservableObject {
    @Binding var document: ScrubDocument
    @Published var transcriptionManager = TranscriptionManager()
    @Published var showingFilePicker = false
    @Published var selectedVersionID: UUID?
    @Published var showingNewVersionDialog = false
    @Published var newVersionTitle = ""
    @Published var showingShareSheet = false
    @Published var showInspector = true
    
    // Computed properties
    var selectedVersion: ContentVersion? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.first { $0.id == id }
    }
    
    var selectedVersionIndex: Int? {
        guard let id = selectedVersionID else { return nil }
        return document.versions.firstIndex { $0.id == id }
    }
    
    init(document: Binding<ScrubDocument>) {
        self._document = document
        
        // Select first version if available
        if !document.wrappedValue.versions.isEmpty && selectedVersionID == nil {
            selectedVersionID = document.wrappedValue.versions[0].id
        }
    }
    
    // Methods
    func handleAudioFile(_ url: URL) {
        document.audioURL = url
        if document.documentTitle.isEmpty {
            document.documentTitle = url.deletingPathExtension().lastPathComponent
        }
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
}
