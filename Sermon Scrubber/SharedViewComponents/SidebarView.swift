//
//  SidebarView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        List {
            Section("Document Info") {
                TextField("Title", text: $viewModel.document.documentTitle)
                DatePicker("Date", selection: $viewModel.document.preachDate, displayedComponents: .date)
                TextField("Preacher", text: $viewModel.document.preacher)
                TextField("Sermon Title", text: $viewModel.document.sermonTitle)
                TextField("Location", text: $viewModel.document.location)
            }
            
            Section("Audio") {
                Button(viewModel.document.audioURL == nil ? "Select Audio File" : "Change Audio File") {
                    viewModel.showingFilePicker = true
                }
                
                if viewModel.document.audioURL != nil {
                    Button("Transcribe Audio") {
                        viewModel.transcribeAudio()
                    }
                    .disabled(viewModel.transcriptionManager.isTranscribing)
                }
            }
            
            if !viewModel.document.versions.isEmpty {
                Section("Versions") {
                    ForEach(viewModel.document.versions) { version in
                        VersionRow(viewModel: viewModel, version: version)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct VersionRow: View {
    @ObservedObject var viewModel: DocumentViewModel
    let version: ContentVersion
    
    var body: some View {
        HStack {
            Image(systemName: version.versionType.iconName)
                .foregroundColor(.accentColor)
            
            Text(version.title)
                .font(viewModel.selectedVersionID == version.id ? .headline : .body)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedVersionID = version.id
        }
        .contextMenu {
            Button("Rename") {
                viewModel.newVersionTitle = version.title
                viewModel.showingNewVersionDialog = true
            }
            Button("Delete") {
                viewModel.deleteVersion(id: version.id)
            }
            Button("Duplicate") {
                viewModel.duplicateVersion(version)
            }
        }
    }
}
