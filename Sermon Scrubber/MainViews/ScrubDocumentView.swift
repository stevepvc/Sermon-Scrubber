//
//  ScrubDocumentView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI
import UniformTypeIdentifiers
import SwiftUI

struct ScrubDocumentView: View {
    @Binding var document: ScrubDocument
    
    var body: some View {
        #if os(macOS)
        ScrubDocumentView_macOS(document: $document)
        #else
        ScrubDocumentView_iOS(document: $document)
        #endif
    }
}

struct ScrubDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        ScrubDocumentView(document: .constant(ScrubDocument.sampleScrub()))
    }
}
