//
//  ContentView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        VStack {
            if viewModel.transcriptionManager.isTranscribing {
                TranscriptionProgressView(viewModel: viewModel)
            } else if let version = viewModel.selectedVersion, let index = viewModel.selectedVersionIndex {
                // Editor for selected version
                TextEditor(text: $viewModel.document.versions[index].content)
                    .font(.body)
                    .padding()
            } else if viewModel.document.audioURL == nil && viewModel.document.originalTranscription.isEmpty {
                DropZoneView(viewModel: viewModel)
            } else if !viewModel.document.originalTranscription.isEmpty && viewModel.document.versions.isEmpty {
                // Show original transcription if there are no versions yet
                VStack {
                    Text("Original Transcription")
                        .font(.headline)
                        .padding([.top, .horizontal])
                    
                    TextEditor(text: $viewModel.document.originalTranscription)
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
                if !viewModel.document.versions.isEmpty {
                    // Toggle inspector
                    Button(action: {
                        viewModel.showInspector.toggle()
                    }) {
                        Label("Inspector", systemImage: viewModel.showInspector ? "sidebar.right" : "sidebar.right.fill")
                    }
                    
                    // New version button
                    Button(action: {
                        viewModel.newVersionTitle = "New Version"
                        viewModel.showingNewVersionDialog = true
                    }) {
                        Label("New Version", systemImage: "plus")
                    }
                    
                    // Share button
                    Button(action: {
                        if viewModel.selectedVersion != nil {
                            viewModel.showingShareSheet = true
                        }
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.selectedVersion == nil)
                }
            }
        }
    }
}
