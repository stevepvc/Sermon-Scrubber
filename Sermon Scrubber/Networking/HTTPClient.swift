//
//  HTTPClient.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public struct HTTPResponse<T> {
    public let statusCode: Int
    public let headers: [AnyHashable: String]
    public let value: T
}

public enum HTTPError: Error, LocalizedError {
    case invalidURL
    case non2xx(status: Int, body: String, headers: [AnyHashable: String])
    case decoding(Error)
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .non2xx(let status, let body, _): return "HTTP \(status): \(body)"
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        case .transport(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

public final class HTTPClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = AIConfig.BASE_URL, timeout: TimeInterval = AIConfig.requestTimeout) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    public func requestJSON<T: Decodable>(
        _ method: String,
        path: String,
        token: String? = nil,
        headers: [String: String] = [:],
        bodyJSON: Encodable? = nil,
        decoder: JSONDecoder = .init()
    ) async throws -> HTTPResponse<T> {
        let (data, raw) = try await requestRaw(method, path: path, token: token, headers: headers, bodyJSON: bodyJSON)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            return .init(statusCode: raw.statusCode, headers: raw.headers, value: decoded)
        } catch {
            throw HTTPError.decoding(error)
        }
    }

    public struct Raw {
        public let statusCode: Int
        public let headers: [AnyHashable: String]
        public let body: Data
        public var bodyString: String { String(data: body, encoding: .utf8) ?? "" }
    }

    public func requestRaw(
        _ method: String,
        path: String,
        token: String? = nil,
        headers: [String: String] = [:],
        bodyJSON: Encodable? = nil
    ) async throws -> (Data, Raw) {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw HTTPError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        var allHeaders = headers
        if let token { allHeaders["Authorization"] = "Bearer \(token)" }
        if bodyJSON != nil { allHeaders["Content-Type"] = "application/json; charset=utf-8" }
        for (k, v) in allHeaders { req.setValue(v, forHTTPHeaderField: k) }

        if let bodyJSON {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            req.httpBody = try encoder.encode(AnyEncodable(bodyJSON))
        }

        do {
            let (data, resp) = try await session.data(for: req)
            let http = resp as? HTTPURLResponse
            let status = http?.statusCode ?? -1
            let headers = http?.allHeaderFields.reduce(into: [AnyHashable: String]()) { result, kv in
                result[kv.key] = "\(kv.value)"
            } ?? [:]

            let raw = Raw(statusCode: status, headers: headers, body: data)

            guard (200...299).contains(status) else {
                throw HTTPError.non2xx(status: status, body: raw.bodyString, headers: headers)
            }
            return (data, raw)
        } catch {
            throw HTTPError.transport(error)
        }
    }
}

// MARK: - Helpers

/// Wraps any Encodable so we can pass heterogeneous bodies nicely
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self._encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

