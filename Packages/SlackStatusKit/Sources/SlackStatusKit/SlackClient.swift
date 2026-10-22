import Foundation

public struct SlackIdentity: Hashable, Sendable {
  public var team: String
  public var user: String
}

public enum SlackClientError: Error, Equatable, Sendable {
  case slack(String)
  case invalidResponse
}

public struct SlackClient: Sendable {
  private let token: String
  private let session: URLSession

  public init(token: String, session: URLSession = .shared) {
    self.token = token
    self.session = session
  }

  public func authTest() async throws -> SlackIdentity {
    let response = try await call("auth.test", body: Optional<EmptyBody>.none, as: AuthTestResponse.self)
    return SlackIdentity(team: response.team ?? "", user: response.user ?? "")
  }

  public func setStatus(_ status: SlackStatus) async throws {
    let expiration = status.expiration.map { Int($0.timeIntervalSince1970) } ?? 0
    let body = SetProfileBody(
      profile: .init(status_text: status.text, status_emoji: status.emoji, status_expiration: expiration)
    )
    _ = try await call("users.profile.set", body: body, as: OKResponse.self)
  }

  public func clearStatus() async throws {
    try await setStatus(.cleared)
  }

  private func call<Body: Encodable, Response: SlackResponse>(
    _ method: String, body: Body?, as _: Response.Type
  ) async throws -> Response {
    var request = URLRequest(url: URL(string: "https://slack.com/api/\(method)")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
    }
    let (data, _) = try await session.data(for: request)
    guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
      throw SlackClientError.invalidResponse
    }
    if !response.ok {
      throw SlackClientError.slack(response.error ?? "unknown_error")
    }
    return response
  }
}

private protocol SlackResponse: Decodable {
  var ok: Bool { get }
  var error: String? { get }
}

private struct OKResponse: SlackResponse {
  let ok: Bool
  let error: String?
}

private struct AuthTestResponse: SlackResponse {
  let ok: Bool
  let error: String?
  let team: String?
  let user: String?
}

private struct SetProfileBody: Encodable {
  struct Profile: Encodable {
    let status_text: String
    let status_emoji: String
    let status_expiration: Int
  }
  let profile: Profile
}

private struct EmptyBody: Encodable {}
