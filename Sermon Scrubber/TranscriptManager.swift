//
//  TranscriptManager.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import Speech
import AVFoundation

class TranscriptionManager: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0
    @Published var transcriptionText = ""
    @Published var currentChunk = 0
    @Published var totalChunks = 0
    @Published var currentActivityMessage = ""
    
    private let settings = AppSettings()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var activityTimer: Timer?
    private let activityMessages = [
        // Listening behaviors
        "Filtering out amens from the crowd",
        "Nodding along in approval",
        "Evaluating theology",
        "Considering implications",
        "Rethinking life choices",
        "Repressing desire to break out in applause",
        "Shouting 'that's right!'",
        "Experiencing conviction",
        "Looking up references",
        "Settling into a pew",
        "Amplifying transcendence",
        "Taking sermon notes",
        "Contemplating life choices",
        "Mentally bookmarking that point",
        "Pondering the metaphor",
        "Waiting for the third point",
        "Wishing I had brought a pen",
        "Wondering if this applies to me",
        "Connecting dots from last week",
        "Looking for application points",
        "Mouthing 'mmhmm' thoughtfully",
        "Checking if anyone else is crying",
        "Cross-referencing with Spurgeon",
        
        // Technical processing
        "Distinguishing pastor from organ",
        "Filtering background coughs",
        "Deciphering rapid sermon climax",
        "Parsing 'thee' and 'thou'",
        "Calculating sermon length",
        "Processing preacher cadence",
        "Calibrating theological algorithms",
        "Converting passion to text",
        "Detecting sermonic patterns",
        "Identifying Greek pronunciations",
        "Measuring emphasis patterns",
        "Converting hand gestures to punctuation",
        "Analyzing rhetorical techniques",
        "Quantifying enthusiasm levels",
        "Decoding denominational dialects",
        "Measuring syllabic sermon rhythm",
        "Isolating unintentional background music",
        "Differentiating illustration from point",
        "Calculating optimal 'selah' moments",
        "Removing microphone fumbling sounds",
        
        // Humorous observations
        "Counting 'in conclusion' statements",
        "Waiting for the altar call",
        "Timing the 'one more point'",
        "Wondering how many pages are left",
        "Hoping the baby doesn't start crying",
        "Figuring out if that joke landed",
        "Estimating crowd engagement level",
        "Detecting sermon rabbit trails",
        "Counting how many times Genesis was mentioned",
        "Noticing repeated phrases",
        "Logging unexpected mic drops",
        "Identifying preacher voice changes",
        "Cataloging animated gestures",
        "Detecting podium pounds",
        "Measuring voice crescendos",
        "Counting Bible page turns",
        "Tracking sermon tangents",
        "Logging when someone whispered 'amen'",
        "Tracking 'as we close' false endings",
        "Measuring pause-for-effect duration",
        
        // Spiritual processing
        "Digesting spiritual wisdom",
        "Meditating on that last point",
        "Contemplating eternal truths",
        "Processing divine insights",
        "Absorbing sacred teachings",
        "Connecting scriptural dots",
        "Recognizing Spirit-led moments",
        "Discerning prophetic implications",
        "Aligning with biblical principles",
        "Capturing moments of revelation",
        "Identifying kairos moments",
        "Sensing holy moments",
        "Detecting passion for the Word",
        "Converting exhortation to text",
        "Cataloging moments of illumination",
        "Capturing pastoral wisdom",
        "Detecting shifts in spiritual atmosphere",
        "Processing moments of clarity",
        "Indexing scriptural references",
        
        // Technical humor
        "Converting preacher pacing to bytes",
        "Parsing theological jargon",
        "Distinguishing between 'ah' and 'amen'",
        "Processing at 95% conviction level",
        "Analyzing sermonic structure",
        "Converting passion to Unicode",
        "Translating preacher dialect",
        "Compressing Sunday wisdom",
        "Extracting applicable principles",
        "Buffering divine inspiration",
        "Calculating spiritual ROI",
        "Optimizing sermon retention algorithms",
        "Deconstructing homiletical patterns",
        "Upgrading spiritual firewall",
        "Increasing theological bandwidth",
        "Calibrating eschatological sensors",
        "Detecting sermonic plot twists",
        "Running hermeneutical diagnostics",
        "Reticulating ecclesiastical splines"
    ]
    
    func checkPermissions() async -> Bool {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        if authStatus != .authorized {
            let isAuthorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            return isAuthorized
        }
        
        return authStatus == .authorized
    }
    
    func transcribeAudio(from url: URL) async -> String {
        guard await checkPermissions(), let recognizer = speechRecognizer, recognizer.isAvailable else {
            return "Speech recognition not available"
        }
        
        await MainActor.run {
            self.isTranscribing = true
            self.transcriptionProgress = 0
            self.transcriptionText = ""
            self.startActivityMessageTimer() // Start the timer when transcription begins
        }
        
        // Get audio length
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let durationSeconds = duration?.seconds ?? 0
        
        // Calculate chunks
        let chunkSize = TimeInterval(settings.chunkSizeInSeconds)
        let chunks = Int(ceil(durationSeconds / chunkSize))
        
        await MainActor.run {
            self.totalChunks = chunks
            self.currentChunk = 0
        }
        
        // Use an array to collect transcription parts
        var transcriptionParts: [String] = []
        
        // Process each chunk
        for i in 0..<chunks {
            let startTime = Double(i) * chunkSize
            let endTime = min(startTime + chunkSize, durationSeconds)
            
            await MainActor.run {
                self.currentChunk = i + 1
                self.transcriptionProgress = Double(i) / Double(chunks)
            }
            
            let chunkTranscription = await transcribeChunk(url: url, startTime: startTime, endTime: endTime)
            transcriptionParts.append(chunkTranscription)
            
            // Create a temporary combined text for UI update
            let currentText = transcriptionParts.joined(separator: " ")
            await MainActor.run {
                self.transcriptionText = currentText
            }
        }
        
        // Combine all parts into the final result
        let fullTranscription = transcriptionParts.joined(separator: " ")
        
        await MainActor.run {
            self.isTranscribing = false
            self.transcriptionProgress = 1.0
            self.stopActivityMessageTimer() // Stop the timer when transcription is done
        }
        
        return fullTranscription
    }
    
    private func startActivityMessageTimer() {
        // Set initial message
        self.currentActivityMessage = self.activityMessages.randomElement() ?? ""
        
        // Create timer to change message every 5 seconds
        self.activityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentActivityMessage = self.activityMessages.randomElement() ?? ""
        }
    }
    
    private func stopActivityMessageTimer() {
        activityTimer?.invalidate()
        activityTimer = nil
        currentActivityMessage = ""
    }
    
    private func transcribeChunk(url: URL, startTime: TimeInterval, endTime: TimeInterval) async -> String {
        return await withCheckedContinuation { continuation in
            // Create audio buffer for the specific time range
            Task {
                guard let audioFileURL = await createAudioChunk(from: url, startTime: startTime, endTime: endTime) else {
                    continuation.resume(returning: "")
                    return
                }
                
                let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
                request.shouldReportPartialResults = false
                
                // Set recognition task options for punctuation
                if self.settings.includePunctuation {
                    if #available(iOS 16.0, macOS 13.0, *) {
                        request.addsPunctuation = true
                    }
                }
                
                self.speechRecognizer?.recognitionTask(with: request) { result, error in
                    if let result = result, result.isFinal {
                        continuation.resume(returning: result.bestTranscription.formattedString)
                        
                        // Clean up temporary file
                        try? FileManager.default.removeItem(at: audioFileURL)
                    } else if error != nil {
                        continuation.resume(returning: "")
                    }
                }
            }
        }
    }
    
    private func createAudioChunk(from url: URL, startTime: TimeInterval, endTime: TimeInterval) async -> URL? {
        let asset = AVURLAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            // Create a timeRange
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 1000),
                end: CMTime(seconds: endTime, preferredTimescale: 1000)
            )
            
            // Create a composition with the asset
            let composition = AVMutableComposition()
            
            // Add audio track from the asset
            guard let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
                  let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                return nil
            }
            
            try compositionAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            
            // Use AVAssetExportSession
            let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)!
            exporter.outputURL = outputURL
            exporter.outputFileType = .m4a
            
            // Use a Task to await the export completion
            return await withCheckedContinuation { continuation in
                exporter.exportAsynchronously {
                    if exporter.status == .completed {
                        continuation.resume(returning: outputURL)
                    } else {
                        print("Export failed: \(String(describing: exporter.error))")
                        continuation.resume(returning: nil)
                    }
                }
            }
        } catch {
            print("Error creating audio chunk: \(error)")
            return nil
        }
    }
}
