//
//  UsageLog.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public struct UsageLogEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let idempotencyKey: String
    public let provider: String
    public let model: String
    public let inputWordCount: Int
    public let outputWordCount: Int
    public let tokensUsed: Int?           // from server usage or delta pre/post
    public let replayFlag: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        idempotencyKey: String,
        provider: String,
        model: String,
        inputWordCount: Int,
        outputWordCount: Int,
        tokensUsed: Int?,
        replayFlag: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.idempotencyKey = idempotencyKey
        self.provider = provider
        self.model = model
        self.inputWordCount = inputWordCount
        self.outputWordCount = outputWordCount
        self.tokensUsed = tokensUsed
        self.replayFlag = replayFlag
    }
}

public final class UsageLog: ObservableObject {
    @Published public private(set) var entries: [UsageLogEntry] = []

    public init() {}

    public func append(_ e: UsageLogEntry) {
        entries.append(e)
    }

    public func toCSV() -> String {
        var rows: [String] = []
        rows.append("timestamp,idempotencyKey,provider,model,inputWordCount,outputWordCount,tokensUsed,replayFlag")
        let df = ISO8601DateFormatter()
        for e in entries {
            let ts = df.string(from: e.timestamp)
            let line = [
                ts,
                e.idempotencyKey,
                e.provider,
                e.model,
                "\(e.inputWordCount)",
                "\(e.outputWordCount)",
                e.tokensUsed.map(String.init) ?? "",
                "\(e.replayFlag)"
            ].map { $0.replacingOccurrences(of: "\"", with: "\"\"") }
             .map { $0.contains(",") ? "\"\($0)\"" : $0 }
             .joined(separator: ",")
            rows.append(line)
        }
        return rows.joined(separator: "\n")
    }

    public func toJSONData(pretty: Bool = true) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return (try? encoder.encode(entries)) ?? Data("[]".utf8)
    }

    public func exportCSV(to url: URL) throws {
        let csv = toCSV()
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    public func exportJSON(to url: URL) throws {
        let data = toJSONData(pretty: true)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Word count helper

public func wordCount(_ s: String) -> Int {
    let comps = s
        .replacingOccurrences(of: "\n", with: " ")
        .split { $0.isWhitespace || $0.isNewline }
    return comps.count
}

