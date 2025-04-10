//
//  ScrubDocumentView_macOS.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView_macOS.swift
// ScrubDocumentView+macOS.swift
import SwiftUI

#if os(macOS)
extension ScrubDocumentView {
    var macOSDocumentView: some View {
        NavigationView {
                sidebar
                    .frame(minWidth: 200)
                
                contentView

            
        }
        .toolbar {
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Toggle inspector
                Button(action: {
                    showInspector.toggle()
                }) {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                if !document.versions.isEmpty {
                   
                    
                    
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
        .inspector(isPresented: $showInspector){
            InspectorView(document: $document)
        }
        .sheet(isPresented: $showingFilePicker) {
            
            AudioFilePicker { url in
                handleAudioFile(url)
            }
        }
        .sheet(isPresented: $showingNewVersionDialog) {
            createVersionDialog
        }
        .sheet(isPresented: $showingRenameDialog) {
            renameVersionDialog
        }
        .onAppear {
            setupNotifications()
            
            // Default select first version
            if !document.versions.isEmpty && selectedVersionID == nil {
                selectedVersionID = document.versions[0].id
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
