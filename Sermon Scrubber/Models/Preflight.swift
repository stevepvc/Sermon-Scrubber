//
//  Preflight.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public struct PreflightBalances: Decodable, Equatable {
    // Match server-side fields (all optional for forward-compat)
    public let monthKey: String?
    public let tokensQuota: Int?
    public let tokensUsed: Int?
    public let boostersBalance: Int?

    public init(monthKey: String? = nil, tokensQuota: Int? = nil, tokensUsed: Int? = nil, boostersBalance: Int? = nil) {
        self.monthKey = monthKey
        self.tokensQuota = tokensQuota
        self.tokensUsed = tokensUsed
        self.boostersBalance = boostersBalance
    }

    public var remaining: Int? {
        guard let q = tokensQuota, let u = tokensUsed else { return nil }
        return max(0, q - u) + (boostersBalance ?? 0)
    }
}

