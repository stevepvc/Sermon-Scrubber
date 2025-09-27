//
//  SermonProxyViewModel.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//

import Foundation

@MainActor
public final class SermonProxyViewModel: ObservableObject {
    // Networking
    private let http = HTTPClient()
    @Published public private(set) var token: String? = nil
    @Published public private(set) var tokenExpiresIn: Int? = nil

    // Balances
    @Published public private(set) var preflightBefore: PreflightBalances?
    @Published public private(set) var preflightAfter: PreflightBalances?

    // UI State
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var replayBanner: Bool = false
    @Published public private(set) var lastOutputText: String = ""
    @Published public private(set) var lastIdempotencyKey: String = ""
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastErrorCode: Int?

    // Telemetry
    public let usageLog = UsageLog()

    public init() {}

    // MARK: - Auth

    /// You likely want to pass your app's stable per-user `appAccountToken` here.
    public func authenticate(appAccountToken: String) async {
        do {
            let resp = try await AuthAPI.anonymous(http: http, appAccountToken: appAccountToken)
            self.token = resp.jwt
            self.tokenExpiresIn = resp.expires_in
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Preflight

    public func refreshPreflight() async {
        guard let token else { self.errorMessage = "Not authenticated"; return }
        do {
            let balances = try await ProxyAPI.preflight(http: http, token: token)
            self.preflightBefore = balances
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Generate

    public struct GenerateResultUI {
        public let text: String
        public let replay: Bool
        public let idempotencyKey: String
        public let statusCode: Int
        public let headers: [AnyHashable: String]
        public let rawJSON: String
        public let tokensUsedDelta: Int?
    }

    public func generate(
        prompt: String,
        provider: AIProvider = AIConfig.defaultProvider,
        model: String? = nil,
        maxOutputTokens: Int? = AIConfig.defaultMaxOutputTokens,
        temperature: Double? = AIConfig.defaultTemperature
    ) async -> GenerateResultUI? {
        guard let token else { self.errorMessage = "Not authenticated"; return nil }

        isLoading = true
        replayBanner = false
        errorMessage = nil
        lastOutputText = ""
        lastErrorCode = nil

        // Snapshot before
        let before = (try? await ProxyAPI.preflight(http: http, token: token))
        self.preflightBefore = before

        let input = GenerateInput(
            prompt: prompt,
            provider: provider,
            model: model,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature
        )

        let idempotencyKey = UUID().uuidString
        self.lastIdempotencyKey = idempotencyKey

        do {
            let res = try await ProxyAPI.generate(http: http, token: token, input: input, explicitIdempotencyKey: idempotencyKey)
            self.lastIdempotencyKey = res.idempotencyKey
            self.replayBanner = res.replay

            // Attempt to extract display text in a provider-agnostic way
            let rawText = res.bodyString
            let extracted = Self.extractText(provider: provider, rawJSON: rawText) ?? ""
            self.lastOutputText = extracted

            // Snapshot after
            let after = (try? await ProxyAPI.preflight(http: http, token: token))
            self.preflightAfter = after

            // Compute token delta if available
            let delta: Int? = {
                guard let b = before?.remaining, let a = after?.remaining else { return nil }
                return max(0, b - a)
            }()

            // Log
            let entry = UsageLogEntry(
                idempotencyKey: res.idempotencyKey,
                provider: provider.rawValue,
                model: input.model,
                inputWordCount: wordCount(prompt),
                outputWordCount: wordCount(extracted),
                tokensUsed: delta,
                replayFlag: res.replay
            )
            usageLog.append(entry)

            isLoading = false
            lastErrorCode = nil
            return GenerateResultUI(
                text: extracted,
                replay: res.replay,
                idempotencyKey: res.idempotencyKey,
                statusCode: res.statusCode,
                headers: res.headers,
                rawJSON: rawText,
                tokensUsedDelta: delta
            )
        } catch let ProxyError.insufficientBalance(message, _) {
            isLoading = false
            self.errorMessage = "Balance is insufficient.\n\(message)\nConsider offering a Booster flow."
            self.lastErrorCode = 402
            return nil
        } catch let ProxyError.conflictProcessing(message, _) {
            isLoading = false
            self.errorMessage = "Another request with the same idempotency key is still processing.\n\(message)"
            self.lastErrorCode = 409
            return nil
        } catch {
            isLoading = false
            self.errorMessage = error.localizedDescription
            if case let HTTPError.non2xx(status, _, _) = error {
                self.lastErrorCode = status
            }
            return nil
        }
    }

    // MARK: - Extractors (best-effort)

    private static func extractText(provider: AIProvider, rawJSON: String) -> String? {
        // We keep it minimal & resilient to schema changes.
        // Try OpenAI chat completions first:
        if let text = extractOpenAIChat(rawJSON: rawJSON) { return text }
        // Fallback Anthropic Messages format:
        if let text = extractAnthropic(rawJSON: rawJSON) { return text }
        return nil
    }

    private static func extractOpenAIChat(rawJSON: String) -> String? {
        // Looks for choices[0].message.content
        struct ChoiceMsg: Decodable { let content: String? }
        struct Choice: Decodable { let message: ChoiceMsg? }
        struct Root: Decodable { let choices: [Choice]? }
        guard let data = rawJSON.data(using: .utf8) else { return nil }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return nil }
        return root.choices?.first?.message?.content
    }

    private static func extractAnthropic(rawJSON: String) -> String? {
        // Looks for content array with text items
        struct ContentItem: Decodable { let type: String?; let text: String? }
        struct Root: Decodable { let content: [ContentItem]? }
        guard let data = rawJSON.data(using: .utf8) else { return nil }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return nil }
        return root.content?.first(where: { ($0.type ?? "") == "text" })?.text
    }
}
