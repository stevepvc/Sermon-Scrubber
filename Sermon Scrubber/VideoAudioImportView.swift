import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

struct VideoAudioImportView: View {
    @Binding var isPresented: Bool
    var onAudioExtracted: (URL) -> Void

    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var waveformSamples: [Float] = []
    @State private var duration: Double = 0
    @State private var selectionStart: Double = 0
    @State private var selectionEnd: Double = 0
    @State private var isTargeted: Bool = false
    @State private var isLoadingWaveform = false
    @State private var isExporting = false
    @State private var alertItem: ImportAlertItem?
    @State private var showFileImporter = false
    @State private var currentPlayTime: Double = 0

    @State private var waveformTask: Task<Void, Never>?
    @State private var playbackObserver: Any?

    private var minimumSelectionLength: Double {
        guard duration > 0 else { return 0.1 }
        let dynamic = max(0.1, duration / 20)
        return min(dynamic, duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Import Audio from Video")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") {
                    isPresented = false
                }
            }

            if videoURL == nil {
                dropZone
            }

            if let videoURL, let player {
                VStack(alignment: .leading, spacing: 12) {
                    Text(videoURL.lastPathComponent)
                        .font(.headline)

                    VideoPlayer(player: player)
                        .frame(height: 220)
                        .cornerRadius(8)
                    
                    HStack(spacing: 12) {
                        Button("Start selection here.") {
                            let time = player.currentTime().seconds
                            if duration <= minimumSelectionLength {
                                selectionStart = max(0, min(time, duration))
                            } else {
                                selectionStart = min(time, selectionEnd - minimumSelectionLength)
                            }
                        }
                        
                        Button("End selection here.") {
                            let time = player.currentTime().seconds
                            if duration <= minimumSelectionLength {
                                selectionEnd = max(0, min(time, duration))
                            } else {
                                selectionEnd = max(time, selectionStart + minimumSelectionLength)
                            }
                        }
                    }

                    waveformSection
                }
            }

            Spacer()

            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }

                Spacer()

                Button(action: extractAudio) {
                    Label("Extract Audio", systemImage: "waveform")
                }
                .disabled(videoURL == nil || isExporting || selectionEnd <= selectionStart)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(minWidth: 680, minHeight: 560)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    prepareVideo(from: url)
                } else {
                    alertItem = ImportAlertItem(message: "No file selected.")
                }
            case .failure(let error):
                alertItem = ImportAlertItem(message: error.localizedDescription)
            }
        }
        .alert(item: $alertItem) { item in
            Alert(title: Text("Import Error"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            waveformTask?.cancel()
            if let observer = playbackObserver {
                player?.removeTimeObserver(observer)
            }
            player?.pause()
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(isTargeted ? .accentColor : .gray)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            VStack(spacing: 12) {
                Image(systemName: "film")
                    .font(.system(size: 44))
                    .foregroundColor(isTargeted ? .accentColor : .primary)

                Text("Drop a video file here")
                    .font(.headline)

                Button("Browse for Video…") {
                    showFileImporter = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .onDrop(of: [UTType.movie.identifier], isTargeted: $isTargeted) { providers, _ in
            guard let provider = providers.first else { return false }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error {
                    DispatchQueue.main.async {
                        alertItem = ImportAlertItem(message: error.localizedDescription)
                    }
                    return
                }

                guard let url else { return }

                do {
                    let destination = try copyToTemporary(url: url)
                    DispatchQueue.main.async {
                        prepareVideo(from: destination)
                    }
                } catch {
                    DispatchQueue.main.async {
                        alertItem = ImportAlertItem(message: error.localizedDescription)
                    }
                }
            }

            return true
        }
    }

    @ViewBuilder
    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingWaveform {
                ProgressView("Analyzing audio…")
            } else if waveformSamples.isEmpty {
                Text("No audio track detected in this video.")
                    .foregroundColor(.secondary)
            } else {
                WaveformTimelineView(
                    samples: waveformSamples,
                    duration: duration,
                    minimumSelectionLength: minimumSelectionLength,
                    currentPlayTime: currentPlayTime,
                    startTime: $selectionStart,
                    endTime: $selectionEnd
                )
                .frame(height: 120)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Start: \(formattedTime(selectionStart))")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { selectionStart },
                                set: { newValue in
                                    if duration <= minimumSelectionLength {
                                        selectionStart = max(0, min(newValue, duration))
                                    } else {
                                        selectionStart = min(newValue, selectionEnd - minimumSelectionLength)
                                    }
                                }
                            ),
                            in: 0...max(duration - minimumSelectionLength, 0)
                        )
                    }

                    HStack {
                        Text("End: \(formattedTime(selectionEnd))")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { selectionEnd },
                                set: { newValue in
                                    if duration <= minimumSelectionLength {
                                        selectionEnd = max(0, min(newValue, duration))
                                    } else {
                                        selectionEnd = max(newValue, selectionStart + minimumSelectionLength)
                                    }
                                }
                            ),
                            in: min(selectionStart + minimumSelectionLength, duration)...duration
                        )
                    }
                }
            }
        }
    }

    private func prepareVideo(from url: URL) {
        waveformTask?.cancel()
        if let observer = playbackObserver {
            player?.removeTimeObserver(observer)
            playbackObserver = nil
        }
        
        videoURL = url
        player = AVPlayer(url: url)
        currentPlayTime = 0
        isExporting = false
        let asset = AVAsset(url: url)
        duration = asset.duration.seconds
        selectionStart = 0
        selectionEnd = max(duration, 0)
        
        // Set up playback time observer
        if let player = player {
            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
            playbackObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                currentPlayTime = time.seconds
            }
        }

        if duration > 0 {
            isLoadingWaveform = true
            waveformSamples = []
            let targetAsset = asset

            waveformTask = Task.detached(priority: .userInitiated) {
                do {
                    let samples = try await WaveformGenerator.generateSamples(for: targetAsset, targetSamples: 600)
                    if Task.isCancelled { return }
                    await MainActor.run {
                        waveformSamples = samples
                        isLoadingWaveform = false
                    }
                } catch {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        waveformSamples = []
                        isLoadingWaveform = false
                        alertItem = ImportAlertItem(message: error.localizedDescription)
                    }
                }
            }
        } else {
            waveformSamples = []
            isLoadingWaveform = false
        }
    }

    private func extractAudio() {
        guard let videoURL else { return }
        guard selectionEnd > selectionStart else {
            alertItem = ImportAlertItem(message: "Select a valid time range before extracting.")
            return
        }

        isExporting = true
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
        } catch {
            alertItem = ImportAlertItem(message: error.localizedDescription)
            isExporting = false
            return
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            alertItem = ImportAlertItem(message: "Unable to create export session for this video.")
            isExporting = false
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        let startTime = CMTime(seconds: selectionStart, preferredTimescale: 600)
        let durationTime = CMTime(seconds: selectionEnd - selectionStart, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startTime, duration: durationTime)

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                isExporting = false

                switch exportSession.status {
                case .completed:
                    onAudioExtracted(outputURL)
                    isPresented = false
                case .failed, .cancelled:
                    let message = exportSession.error?.localizedDescription ?? "Export failed."
                    alertItem = ImportAlertItem(message: message)
                default:
                    break
                }
            }
        }
    }

    private func formattedTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00.000" }
        let totalMilliseconds = Int((time * 1000).rounded())
        let minutes = totalMilliseconds / 60000
        let seconds = (totalMilliseconds % 60000) / 1000
        let milliseconds = totalMilliseconds % 1000
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }

    private func copyToTemporary(url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
}

private struct ImportAlertItem: Identifiable {
    let id = UUID()
    let message: String
}

private enum WaveformGenerator {
    static func generateSamples(for asset: AVAsset, targetSamples: Int) async throws -> [Float] {
        guard targetSamples > 0 else { return [] }

        let _ = try await asset.load(.tracks)

        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            return []
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        var sampleRate: Double = 44100
        do {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first,
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
                sampleRate = asbd.mSampleRate
            }
        } catch {
            // Keep default sampleRate if loading format descriptions fails
        }

        let totalSamplesEstimate = max(1, Int(sampleRate * asset.duration.seconds))
        let samplesPerBucket = max(1, totalSamplesEstimate / targetSamples)

        guard reader.startReading() else {
            if let error = reader.error { throw error }
            throw WaveformError.unableToStartReader
        }

        var buckets: [Float] = []
        var bucketSampleCount = 0
        var bucketSum: Float = 0

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
            }

            let sampleCount = length / MemoryLayout<Int16>.size
            data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                let int16Pointer = pointer.bindMemory(to: Int16.self)
                for index in 0..<sampleCount {
                    let normalized = Float(int16Pointer[index]) / Float(Int16.max)
                    bucketSum += abs(normalized)
                    bucketSampleCount += 1

                    if bucketSampleCount >= samplesPerBucket {
                        let average = bucketSum / Float(bucketSampleCount)
                        buckets.append(average)
                        bucketSum = 0
                        bucketSampleCount = 0
                    }
                }
            }

            CMSampleBufferInvalidate(sampleBuffer)
        }

        if bucketSampleCount > 0 {
            let average = bucketSum / Float(bucketSampleCount)
            buckets.append(average)
        }

        if let error = reader.error {
            throw error
        }

        guard !buckets.isEmpty else { return [] }

        let normalizedBuckets = normalize(buckets)

        if normalizedBuckets.count == targetSamples {
            return normalizedBuckets
        }

        return resample(normalizedBuckets, targetCount: targetSamples)
    }

    private static func normalize(_ samples: [Float]) -> [Float] {
        guard let maxSample = samples.max(), maxSample > 0 else { return samples }
        return samples.map { min($0 / maxSample, 1) }
    }

    private static func resample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 1, samples.count > 1 else {
            return Array(samples.prefix(targetCount))
        }

        var result: [Float] = []
        result.reserveCapacity(targetCount)

        for index in 0..<targetCount {
            let position = Double(index) / Double(targetCount - 1) * Double(samples.count - 1)
            let lowerIndex = Int(floor(position))
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let interpolationFactor = Float(position - Double(lowerIndex))
            let lowerValue = samples[lowerIndex]
            let upperValue = samples[upperIndex]
            let interpolated = lowerValue + (upperValue - lowerValue) * interpolationFactor
            result.append(interpolated)
        }

        return normalize(result)
    }

    private enum WaveformError: Error {
        case unableToStartReader
    }
}

private struct WaveformTimelineView: View {
    var samples: [Float]
    var duration: Double
    var minimumSelectionLength: Double
    var currentPlayTime: Double
    @Binding var startTime: Double
    @Binding var endTime: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))

                Path { path in
                    guard !samples.isEmpty else { return }
                    let midY = height / 2
                    let step = width / CGFloat(samples.count)

                    for (index, sample) in samples.enumerated() {
                        let x = CGFloat(index) * step
                        let clamped = max(0, min(1, CGFloat(sample)))
                        let sampleHeight = clamped * (height / 2)
                        path.move(to: CGPoint(x: x, y: midY - sampleHeight))
                        path.addLine(to: CGPoint(x: x, y: midY + sampleHeight))
                    }
                }
                .stroke(Color.accentColor, lineWidth: 1)

                if duration > 0 {
                    let startX = CGFloat(startTime / duration) * width
                    let endX = CGFloat(endTime / duration) * width
                    let selectionWidth = max(endX - startX, 0)

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: selectionWidth)
                        .offset(x: min(startX, endX))

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: height)
                        .offset(x: startX - 1.5)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: height)
                        .offset(x: endX - 1.5)
                    
                    // Playhead indicator
                    let playheadX = CGFloat(currentPlayTime / duration) * width
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: height)
                        .offset(x: playheadX - 1)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / width))
                        let time = Double(fraction) * duration
                        if abs(time - startTime) < abs(time - endTime) {
                            if duration <= minimumSelectionLength {
                                startTime = max(0, min(time, duration))
                            } else {
                                startTime = min(time, endTime - minimumSelectionLength)
                            }
                        } else {
                            if duration <= minimumSelectionLength {
                                endTime = max(0, min(time, duration))
                            } else {
                                endTime = max(time, startTime + minimumSelectionLength)
                            }
                        }
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
