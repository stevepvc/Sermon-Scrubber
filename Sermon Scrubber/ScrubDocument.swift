//
//  Sermon_ScrubberDocument.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var scrubDocument: UTType {
        UTType(exportedAs: "com.stevenhovater.sermonscrub.scrub")
    }
}

struct ScrubDocument: FileDocument {
    var documentTitle: String = ""
    var preachDate: Date = Date()
    var audioURL: URL?
    var originalTranscription: String = ""
    var versions: [ContentVersion] = []
    
    // Added sermon metadata
    var preacher: String = ""
    var sermonTitle: String = ""
    var location: String = ""
    
    static var readableContentTypes: [UTType] { [.scrubDocument] }
    
    init() {}
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            // Decode the document data
            if let decoded = try? JSONDecoder().decode(ScrubDocumentData.self, from: data) {
                self.documentTitle = decoded.documentTitle
                self.preachDate = decoded.preachDate
                self.originalTranscription = decoded.originalTranscription
                self.versions = decoded.versions
                
                // Load sermon metadata
                self.preacher = decoded.preacher
                self.sermonTitle = decoded.sermonTitle
                self.location = decoded.location
                
                // Note: audioURL will need to be handled separately
            }
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(ScrubDocumentData(
            documentTitle: documentTitle,
            preachDate: preachDate,
            originalTranscription: originalTranscription,
            versions: versions,
            preacher: preacher,
            sermonTitle: sermonTitle,
            location: location
        ))
        return FileWrapper(regularFileWithContents: data)
    }
    
    // Helper to quickly add a new version
    mutating func addVersion(title: String, content: String, type: ContentVersion.VersionType) {
        let newVersion = ContentVersion(
            title: title,
            content: content,
            dateCreated: Date(),
            versionType: type
        )
        versions.append(newVersion)
    }
    
    // Helper to update transcription and create transcript version
    mutating func setTranscription(_ text: String) {
        originalTranscription = text
        // Create a transcript version if it doesn't exist yet
        if !versions.contains(where: { $0.versionType == .transcript }) {
            addVersion(title: "Original Transcript", content: text, type: .transcript)
        } else {
            // Update existing transcript version
            if let index = versions.firstIndex(where: { $0.versionType == .transcript }) {
                versions[index].content = text
                versions[index].dateCreated = Date()
            }
        }
    }
    
    // Helper to generate a formatted metadata header for sharing
    func metadataHeader() -> String {
        var header = ""
        
        if !sermonTitle.isEmpty {
            header += "# \(sermonTitle)\n\n"
        }
        
        var metaItems = [String]()
        
        if !preacher.isEmpty {
            metaItems.append("**Speaker:** \(preacher)")
        }
        
        // Format the date nicely
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        metaItems.append("**Date:** \(dateFormatter.string(from: preachDate))")
        
        if !location.isEmpty {
            metaItems.append("**Location:** \(location)")
        }
        
        if !metaItems.isEmpty {
            header += metaItems.joined(separator: " | ") + "\n\n---\n\n"
        }
        
        return header
    }
}

struct ScrubDocumentData: Codable {
    var documentTitle: String
    var preachDate: Date
    var originalTranscription: String
    var versions: [ContentVersion]
    var preacher: String
    var sermonTitle: String
    var location: String
}
