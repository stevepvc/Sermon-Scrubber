//
//  ScrubDocumentView_macOS.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView_macOS.swift
import SwiftUI
import UniformTypeIdentifiers

struct ScrubDocumentView_macOS: View {
    @StateObject private var viewModel: DocumentViewModel
    
    init(document: Binding<ScrubDocument>) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
    }
    
    var body: some View {
        NavigationView {
            HSplitView {
                SidebarView(viewModel: viewModel)
                    .frame(minWidth: 200)
                
                ContentView(viewModel: viewModel)
                
                if viewModel.showInspector {
                    InspectorView(document: viewModel.$document)
                        .frame(minWidth: 250, idealWidth: 300)
                }
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
