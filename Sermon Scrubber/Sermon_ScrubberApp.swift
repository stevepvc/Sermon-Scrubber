//
//  Sermon_ScrubberApp.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//

import SwiftUI

@main
struct SermonScrubApp: App {
    @StateObject private var sermonProxyViewModel = SermonProxyViewModel()

    var body: some Scene {
        DocumentGroup(newDocument: ScrubDocument()) { file in
            ScrubDocumentView(document: file.$document)
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(sermonProxyViewModel)
        }
        .commands {
            // Add custom commands for version management
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Add New Version...") {
                    NotificationCenter.default.post(name: Notification.Name("CreateNewVersion"), object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Import Video Audio…") {
                    NotificationCenter.default.post(name: Notification.Name("ImportVideoAudio"), object: nil)
                }

                Divider()

                Button("Transcribe Audio") {
                    NotificationCenter.default.post(name: Notification.Name("TranscribeAudio"), object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(sermonProxyViewModel)
        }
        #endif
    }
}
