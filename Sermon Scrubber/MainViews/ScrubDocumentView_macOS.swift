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
            HSplitView {
                sidebar
                    .frame(minWidth: 200)
                
                contentView
                
                if showInspector {
                    InspectorView(document: $document)
                        .frame(minWidth: 250, idealWidth: 300)
                }
            
            }.inspector(isPresented: $showInspector, content: InspectorView(document: $document))
        }
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                handleAudioFile(url)
            }
        }
        .sheet(isPresented: $showingNewVersionDialog) {
            createVersionDialog
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
