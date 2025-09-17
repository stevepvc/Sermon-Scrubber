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
                                versionToRename = version
                                newVersionTitle = version.title
                                showingRenameDialog = true
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
                // Editor for selected version with improved styling
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $document.versions[index].content)
                        .sermonTextStyle()
                    
                    // Word count display
                    HStack {
                        Spacer()
                        Text("\(wordCount(text: document.versions[index].content)) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
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
                        .sermonTextStyle()
                        
                    // Word count for original transcription
                    HStack {
                        Spacer()
                        Text("\(wordCount(text: document.originalTranscription)) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
                .padding()
            } else {
                // Show instruction to select a version
                Text("Select a version from the sidebar")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // Add this helper function to count words
    func wordCount(text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let words = components.filter { !$0.isEmpty }
        return words.count
    }
    
    // Transcription Progress View
    var transcriptionProgressView: some View {
        VStack {
            ProgressView(value: transcriptionManager.transcriptionProgress) {
                Text("Transcribing...")
            }
            .padding()
            
            if transcriptionManager.usesModernTranscriber {
                Text("Progress: \(Int(transcriptionManager.transcriptionProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Chunk \(transcriptionManager.currentChunk) of \(transcriptionManager.totalChunks)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Add this to display the activity message
            if !transcriptionManager.currentActivityMessage.isEmpty {
                Text(transcriptionManager.currentActivityMessage)
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
                    .animation(.easeInOut, value: transcriptionManager.currentActivityMessage)
                    .padding(.vertical, 8)
            }
            
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
                .foregroundColor(isTargeted ? .accentColor : .gray)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )
            
            VStack(spacing: 20) {
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                    .font(.system(size: 50))
                    .foregroundColor(isTargeted ? .accentColor : .primary)
                Text("Drop audio file here")
                    .font(.title2)
                    .foregroundColor(isTargeted ? .accentColor : .primary)
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
        .onDrop(of: [UTType.audio.identifier], isTargeted: $isTargeted) { providers, _ in
            guard let provider = providers.first else { return false }
            
            // Use the NSItemProvider's loadFileRepresentation method which is more reliable
            provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, error in
                if let error = error {
                    print("Error loading dropped file: \(error)")
                    return
                }
                
                guard let url = url else { return }
                
                // Create a copy of the file in a location we can access
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                do {
                    // Remove any existing file
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Copy the file
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    // Now handle the file on the main thread
                    DispatchQueue.main.async {
                        self.handleAudioFile(destinationURL)
                    }
                } catch {
                    print("Error copying dropped file: \(error)")
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
    
    var renameVersionDialog: some View {
        VStack(spacing: 20) {
            Text("Rename Version")
                .font(.headline)
            
            TextField("Version Title", text: $newVersionTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    showingRenameDialog = false
                    newVersionTitle = ""
                    versionToRename = nil
                }
                
                Button("Rename") {
                    if let version = versionToRename,
                       let index = document.versions.firstIndex(where: { $0.id == version.id }) {
                        document.versions[index].title = newVersionTitle
                    }
                    showingRenameDialog = false
                    newVersionTitle = ""
                    versionToRename = nil
                }
                .disabled(newVersionTitle.isEmpty)
            }
        }
        .padding()
    }
}

extension TextEditor {
    func sermonTextStyle() -> some View {
        self
            .font(.system(.body, design: .serif))
            .lineSpacing(5)
            .padding()
            #if os(iOS) || os(visionOS)
            .background(Color(UIColor.secondarySystemBackground))
            #elseif os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #endif
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            #if os(macOS)
            .frame(minHeight: 300)
            #endif
    }
}


