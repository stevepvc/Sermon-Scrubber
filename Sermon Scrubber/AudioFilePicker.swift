//
//  AudioFilePicker.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
import MobileCoreServices

struct AudioFilePicker: UIViewControllerRepresentable {
    let onFileSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioFilePicker
        
        init(_ parent: AudioFilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onFileSelected(url)
        }
    }
}
#else
struct AudioFilePicker: View {
    let onFileSelected: (URL) -> Void
    
    var body: some View {
        Button("Select Audio File") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.audio]
            panel.allowsMultipleSelection = false
            
            if panel.runModal() == .OK, let url = panel.url {
                print("selected:", url)
                onFileSelected(url)
                
            }
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
}
#endif

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
