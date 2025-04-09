//
//  ScrubDocumentView_iOS.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
// ScrubDocumentView_iOS.swift
// ScrubDocumentView+iOS.swift
import SwiftUI

#if os(iOS)
extension ScrubDocumentView {
    var iOSDocumentView: some View {
        NavigationView {
            sidebar
            contentView
            
            if showInspector {
                InspectorView(document: $document)
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                handleAudioFile(url)
            }
        }
        .sheet(isPresented: $showingNewVersionDialog) {
            createVersionDialog
        }
        .sheet(isPresented: $showingShareSheet) {
            if let content = selectedVersion?.content {
                let contentToShare = document.metadataHeader() + content
                ShareSheet(items: [contentToShare])
            }
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
