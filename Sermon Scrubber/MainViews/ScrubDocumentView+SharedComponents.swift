//
//  ScrubDocumentView+SharedComponents.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView+SharedComponents.swift
import SwiftUI
import UniformTypeIdentifiers

extension ScrubDocumentView {
    // Sidebar View
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
    }
    
    // Content View
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
    }
    
    // Transcription Progress View
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
    
    // Drop Zone View
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
    
    // Create Version Dialog
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
}
