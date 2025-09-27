//
//  ProxyAPI.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public enum ProxyError: Error, LocalizedError {
    case insufficientBalance(message: String, headers: [AnyHashable: String])
    case conflictProcessing(message: String, headers: [AnyHashable: String]) // 409 duplicate in-flight
    case http(HTTPError)

    public var errorDescription: String? {
        switch self {
        case .insufficientBalance(let m, _): return "402 Payment Required – \(m)"
        case .conflictProcessing(let m, _):  return "409 Conflict – \(m)"
        case .http(let e):                   return e.localizedDescription
        }
    }
}

public struct GenerateResult {
    public let idempotencyKey: String
    public let replay: Bool
    public let statusCode: Int
    public let headers: [AnyHashable: String]
    public let bodyData: Data
    public var bodyString: String { String(data: bodyData, encoding: .utf8) ?? "" }
}

public enum ProxyAPI {

    // Preflight
    public static func preflight(
        http: HTTPClient,
        token: String
    ) async throws -> PreflightBalances {
        do {
            let res: HTTPResponse<PreflightBalances> = try await http.requestJSON(
                "GET",
                path: "/v1/preflight",
                token: token
            )
            return res.value
        } catch let e as HTTPError {
            throw ProxyError.http(e)
        } catch {
            throw ProxyError.http(.transport(error))
        }
    }

    // Generate (auto idempotency)
    public static func generate(
        http: HTTPClient,
        token: String,
        input: GenerateInput,
        explicitIdempotencyKey: String? = nil
    ) async throws -> GenerateResult {
        let key = explicitIdempotencyKey ?? UUID().uuidString
        do {
            let (_, raw) = try await http.requestRaw(
                "POST",
                path: "/v1/generate",
                token: token,
                headers: ["X-Idempotency-Key": key],
                bodyJSON: input
            )
            let replayHeader = raw.headers.first { ($0.key as? String)?.caseInsensitiveCompare("Idempotent-Replay") == .orderedSame }?.value
            let replay = (replayHeader?.lowercased() == "true")

            return GenerateResult(
                idempotencyKey: key,
                replay: replay,
                statusCode: raw.statusCode,
                headers: raw.headers,
                bodyData: raw.body
            )
        } catch let HTTPError.non2xx(status, body, headers) {
            if status == 402 {
                throw ProxyError.insufficientBalance(message: body, headers: headers)
            } else if status == 409 {
                throw ProxyError.conflictProcessing(message: body, headers: headers)
            } else {
                throw ProxyError.http(.non2xx(status: status, body: body, headers: headers))
            }
        } catch let e as HTTPError {
            throw ProxyError.http(e)
        } catch {
            throw ProxyError.http(.transport(error))
        }
    }
}

