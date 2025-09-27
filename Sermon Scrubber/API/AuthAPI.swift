//
//  AuthAPI.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 9/26/25.
//
import Foundation

public struct AuthAnonymousBody: Encodable {
    public let appAccountToken: String
}

public struct AuthAnonymousResp: Decodable {
    public let jwt: String
    public let expires_in: Int
}

public enum AuthAPI {
    public static func anonymous(
        http: HTTPClient,
        appAccountToken: String
    ) async throws -> AuthAnonymousResp {
        let body = AuthAnonymousBody(appAccountToken: appAccountToken)
        let res: HTTPResponse<AuthAnonymousResp> = try await http.requestJSON(
            "POST",
            path: "/v1/auth/anonymous",
            bodyJSON: body
        )
        return res.value
    }
}
