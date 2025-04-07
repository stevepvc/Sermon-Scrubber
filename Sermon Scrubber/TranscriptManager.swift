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
    
    private let settings = AppSettings()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    func checkPermissions() async -> Bool {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        if authStatus != .authorized {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
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
        
        var fullTranscription = ""
        
        // Process each chunk
        for i in 0..<chunks {
            let startTime = Double(i) * chunkSize
            let endTime = min(startTime + chunkSize, durationSeconds)
            
            await MainActor.run {
                self.currentChunk = i + 1
                self.transcriptionProgress = Double(i) / Double(chunks)
            }
            
            let chunkTranscription = await transcribeChunk(url: url, startTime: startTime, endTime: endTime)
            fullTranscription += chunkTranscription + " "
            
            await MainActor.run {
                self.transcriptionText = fullTranscription
            }
        }
        
        await MainActor.run {
            self.isTranscribing = false
            self.transcriptionProgress = 1.0
        }
        
        return fullTranscription
    }
    
    private func transcribeChunk(url: URL, startTime: TimeInterval, endTime: TimeInterval) async -> String {
        return await withCheckedContinuation { continuation in
            // Create audio buffer for the specific time range
            let audioFileURL = createAudioChunk(from: url, startTime: startTime, endTime: endTime)
            
            guard let audioFileURL = audioFileURL else {
                continuation.resume(returning: "")
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
            request.shouldReportPartialResults = false
            
            // Set recognition task options for punctuation
            if settings.includePunctuation {
                if #available(iOS 16.0, macOS 13.0, *) {
                    request.addsPunctuation = true
                }
            }
            
            speechRecognizer?.recognitionTask(with: request) { result, error in
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
    
    private func createAudioChunk(from url: URL, startTime: TimeInterval, endTime: TimeInterval) -> URL? {
        let asset = AVURLAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .m4a
        
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 1000),
            end: CMTime(seconds: endTime, preferredTimescale: 1000)
        )
        
        exportSession?.timeRange = timeRange
        
        let semaphore = DispatchSemaphore(value: 0)
        exportSession?.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()
        
        return outputURL
    }
}
