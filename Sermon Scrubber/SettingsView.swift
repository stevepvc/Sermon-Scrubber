//
//  SettingsView.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings()
    
    var body: some View {
        Form {
            Section(header: Text("AI Services")) {
                Picker("Preferred AI Service", selection: $settings.preferredAIService) {
                    Text("Claude").tag("Claude")
                    Text("ChatGPT").tag("ChatGPT")
                }
                
                SecureField("OpenAI API Key", text: $settings.apiKeyOpenAI)
                SecureField("Anthropic API Key", text: $settings.apiKeyAnthropic)
            }
            
            Section(header: Text("Transcription Settings")) {
                Slider(
                    value: Binding<Double>(
                        get: { Double(settings.chunkSizeInSeconds) },
                        set: { settings.chunkSizeInSeconds = Int($0) }
                    ),
                    in: 60...240,
                    step: 10
                ) {
                    Text("Chunk Size: \(settings.chunkSizeInSeconds) seconds")
                }
                
                Text("Chunk Size: \(settings.chunkSizeInSeconds) seconds")
                
                Toggle("Include Punctuation", isOn: $settings.includePunctuation)
                    .help("Adds punctuation to the transcript when available")
            }
        }
        .padding()
        .frame(width: 400)
        .frame(minHeight: 300)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
