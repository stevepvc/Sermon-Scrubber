//
//  UsageExportControls.swift
//  Sermon Scrubber
//
//  Created by OpenAI on 2025-???.
//

import SwiftUI
import UniformTypeIdentifiers

struct UsageExportControls: View {
    @ObservedObject var usageLog: UsageLog
    @State private var isExportingCSV = false
    @State private var isExportingJSON = false
    @State private var exportError: String?

    private enum ExportType {
        case csv
        case json
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Export CSV") {
                    exportError = nil
                    isExportingCSV = true
                }
                Button("Export JSON") {
                    exportError = nil
                    isExportingJSON = true
                }
            }
            .buttonStyle(.borderedProminent)

            if let exportError {
                Text(exportError)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .fileExporter(
            isPresented: $isExportingCSV,
            document: EmptyExportDocument(),
            contentType: .commaSeparatedText,
            defaultFilename: "sermon-proxy-usage"
        ) { result in
            handleExport(result: result, type: .csv)
        }
        .fileExporter(
            isPresented: $isExportingJSON,
            document: EmptyExportDocument(),
            contentType: .json,
            defaultFilename: "sermon-proxy-usage"
        ) { result in
            handleExport(result: result, type: .json)
        }
    }

    private func handleExport(result: Result<URL, Error>, type: ExportType) {
        switch result {
        case .success(let url):
            do {
                switch type {
                case .csv:
                    try usageLog.exportCSV(to: url)
                case .json:
                    try usageLog.exportJSON(to: url)
                }
            } catch {
                exportError = error.localizedDescription
            }
        case .failure(let error):
            exportError = error.localizedDescription
        }
    }
}

private struct EmptyExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText, .json] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
