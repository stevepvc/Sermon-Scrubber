//
//  OtherSharedComponents.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers


struct TranscriptionProgressView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        // Implementation from original file...
        VStack {
            ProgressView(value: viewModel.transcriptionManager.transcriptionProgress) {
                Text("Transcribing...")
            }
            .padding()
            
            Text("Chunk \(viewModel.transcriptionManager.currentChunk) of \(viewModel.transcriptionManager.totalChunks)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Form content...
        }
    }
}

struct DropZoneView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        // Implementation from original file...
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
            viewModel.showingFilePicker = true
        }
        #if os(macOS)
        .onDrop(of: [UTType.audio.identifier], isTargeted: nil) { providers, _ in
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        viewModel.handleAudioFile(url)
                    }
                }
            }
            return true
        }
        #endif
    }
}

struct CreateVersionDialog: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        // Implementation from original file...
        VStack(spacing: 20) {
            Text("Create New Version")
                .font(.headline)
            
            TextField("Version Title", text: $viewModel.newVersionTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    viewModel.showingNewVersionDialog = false
                    viewModel.newVersionTitle = ""
                }
                
                Button("Create") {
                    viewModel.createCustomVersion()
                    viewModel.showingNewVersionDialog = false
                    viewModel.newVersionTitle = ""
                }
                .disabled(viewModel.newVersionTitle.isEmpty)
            }
        }
        .padding()
    }
}
