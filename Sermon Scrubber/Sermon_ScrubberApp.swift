//
//  Sermon_ScrubberApp.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//

import SwiftUI

@main
struct Sermon_ScrubberApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Sermon_ScrubberDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
