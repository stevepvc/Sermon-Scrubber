import Foundation

struct AIUsageEntry: Codable, Identifiable {
    enum Provider: String, Codable, CaseIterable {
        case openAI
        case anthropic

        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .anthropic: return "Anthropic"
            }
        }
    }

    let id: UUID
    let timestamp: Date
    let provider: Provider
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let calculatedCostInUSD: Double?
    let metadata: [String: String]?
}

struct ProviderUsageSummary {
    let provider: AIUsageEntry.Provider
    let requestCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostInUSD: Double
}

struct MonthlyUsageSummary {
    let monthStartDate: Date
    let totalRequests: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let estimatedCostInUSD: Double
    let providerBreakdown: [ProviderUsageSummary]
}

final class AIUsageTracker {
    static let shared = AIUsageTracker()

    private let storageKey = "aiUsageHistory"
    private let queue = DispatchQueue(label: "com.sermonscrubber.aiUsageTracker")
    private var cachedEntries: [AIUsageEntry] = []

    private struct UsageRate {
        let inputCostPerThousandTokens: Double
        let outputCostPerThousandTokens: Double

        func costForUsage(inputTokens: Int, outputTokens: Int) -> Double {
            let inputCost = (Double(inputTokens) / 1000.0) * inputCostPerThousandTokens
            let outputCost = (Double(outputTokens) / 1000.0) * outputCostPerThousandTokens
            return inputCost + outputCost
        }
    }

    private let rateCard: [AIUsageEntry.Provider: [String: UsageRate]] = [
        .openAI: [
            "gpt-4o": UsageRate(inputCostPerThousandTokens: 0.005, outputCostPerThousandTokens: 0.015)
        ],
        .anthropic: [
            "claude-3-7-sonnet-20250219": UsageRate(inputCostPerThousandTokens: 0.003, outputCostPerThousandTokens: 0.015)
        ]
    ]

    private init() {
        loadEntriesFromStorage()
    }

    // MARK: - Public API

    @discardableResult
    func recordUsage(provider: AIUsageEntry.Provider,
                     model: String,
                     inputTokens: Int,
                     outputTokens: Int,
                     timestamp: Date = Date(),
                     metadata: [String: String]? = nil) -> AIUsageEntry {
        queue.sync {
            let cost = rateCard[provider]?[model]?.costForUsage(inputTokens: inputTokens, outputTokens: outputTokens)
            let entry = AIUsageEntry(
                id: UUID(),
                timestamp: timestamp,
                provider: provider,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                calculatedCostInUSD: cost,
                metadata: metadata
            )

            cachedEntries.append(entry)
            persistEntries()
            return entry
        }
    }

    func monthlySummary(containing date: Date = Date(), calendar: Calendar = .current) -> MonthlyUsageSummary? {
        queue.sync {
            let normalizedMonth = normalize(date: date, calendar: calendar)
            let entriesForMonth = cachedEntries.filter { entry in
                guard let monthStart = normalizedMonth else { return false }
                return calendar.isDate(entry.timestamp, equalTo: monthStart, toGranularity: .month)
            }

            guard let monthStart = normalizedMonth, !entriesForMonth.isEmpty else { return nil }
            return summarize(entries: entriesForMonth, monthStartDate: monthStart, calendar: calendar)
        }
    }

    func monthlySummaries(limit: Int? = nil, calendar: Calendar = .current) -> [MonthlyUsageSummary] {
        queue.sync {
            let grouped = Dictionary(grouping: cachedEntries) { entry -> Date in
                let components = calendar.dateComponents([.year, .month], from: entry.timestamp)
                return calendar.date(from: components) ?? entry.timestamp
            }

            let summaries = grouped.compactMap { (monthStart, entries) -> MonthlyUsageSummary? in
                summarize(entries: entries, monthStartDate: monthStart, calendar: calendar)
            }
            .sorted(by: { $0.monthStartDate > $1.monthStartDate })

            if let limit = limit {
                return Array(summaries.prefix(limit))
            }

            return summaries
        }
    }

    func usageEntries() -> [AIUsageEntry] {
        queue.sync { cachedEntries }
    }

    func clearHistory() {
        queue.sync {
            cachedEntries.removeAll()
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    // MARK: - Private helpers

    private func normalize(date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }

    private func summarize(entries: [AIUsageEntry], monthStartDate: Date, calendar: Calendar) -> MonthlyUsageSummary? {
        guard !entries.isEmpty else { return nil }

        var totalInput = 0
        var totalOutput = 0
        var totalCost: Double = 0

        var providerAggregation: [AIUsageEntry.Provider: (requests: Int, input: Int, output: Int, cost: Double)] = [:]

        for entry in entries {
            totalInput += entry.inputTokens
            totalOutput += entry.outputTokens
            totalCost += entry.calculatedCostInUSD ?? 0

            var providerData = providerAggregation[entry.provider] ?? (requests: 0, input: 0, output: 0, cost: 0)
            providerData.requests += 1
            providerData.input += entry.inputTokens
            providerData.output += entry.outputTokens
            providerData.cost += entry.calculatedCostInUSD ?? 0
            providerAggregation[entry.provider] = providerData
        }

        let providerBreakdown = providerAggregation.map { provider, data in
            ProviderUsageSummary(
                provider: provider,
                requestCount: data.requests,
                inputTokens: data.input,
                outputTokens: data.output,
                estimatedCostInUSD: data.cost
            )
        }.sorted(by: { $0.provider.displayName < $1.provider.displayName })

        return MonthlyUsageSummary(
            monthStartDate: monthStartDate,
            totalRequests: entries.count,
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            estimatedCostInUSD: totalCost,
            providerBreakdown: providerBreakdown
        )
    }

    private func loadEntriesFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cachedEntries = try decoder.decode([AIUsageEntry].self, from: data)
        } catch {
            print("Failed to decode AI usage history: \(error)")
            cachedEntries = []
        }
    }

    private func persistEntries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedEntries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to persist AI usage history: \(error)")
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    func integerValue(forKey key: String) -> Int? {
        if let intValue = self[key] as? Int {
            return intValue
        }

        if let numberValue = self[key] as? NSNumber {
            return numberValue.intValue
        }

        if let doubleValue = self[key] as? Double {
            return Int(doubleValue)
        }

        if let stringValue = self[key] as? String, let intValue = Int(stringValue) {
            return intValue
        }

        return nil
    }
}
