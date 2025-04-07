//
//  ContentView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Sermon_ScrubberDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(Sermon_ScrubberDocument()))
}
