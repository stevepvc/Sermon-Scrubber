//
//  ScrubDocumentView_iOS.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView_iOS.swift
import SwiftUI
import UniformTypeIdentifiers

struct ScrubDocumentView_iOS: View {
    @StateObject private var viewModel: DocumentViewModel
    
    init(document: Binding<ScrubDocument>) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
    }
    
    var body: some View {
        NavigationView {
            SidebarView(viewModel: viewModel)
            ContentView(viewModel: viewModel)
            
            // On iOS, inspector is conditionally displayed
            if viewModel.showInspector {
                InspectorView(document: viewModel.$document)
            }
        }
        .sheet(isPresented: $viewModel.showingFilePicker) {
            AudioFilePicker { url in
                viewModel.handleAudioFile(url)
            }
        }
        .sheet(isPresented: $viewModel.showingNewVersionDialog) {
            CreateVersionDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            if let content = viewModel.selectedVersion?.content {
                let contentToShare = viewModel.document.metadataHeader() + content
                ShareSheet(items: [contentToShare])
            }
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: Notification.Name("CreateNewVersion"), object: nil, queue: .main) { _ in
            viewModel.newVersionTitle = "New Version"
            viewModel.showingNewVersionDialog = true
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("TranscribeAudio"), object: nil, queue: .main) { _ in
            if viewModel.document.audioURL != nil && !viewModel.transcriptionManager.isTranscribing {
                viewModel.transcribeAudio()
            }
        }
    }
}
