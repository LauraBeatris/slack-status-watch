import Foundation

public enum SlackOAuthError: Error, Equatable, Sendable {
  case denied(String)
  case stateMismatch
  case missingToken
}

public struct SlackOAuth: Sendable {
  public static let callbackScheme = "statusforslack"
  public static let scopes = ["users.profile:read", "users.profile:write"]

  public let clientID: String
  public let redirectURL: URL

  public init(clientID: String, redirectURL: URL) {
    self.clientID = clientID
    self.redirectURL = redirectURL
  }

  public static func makeState() -> String {
    UUID().uuidString
  }

  public func authorizeURL(state: String) -> URL {
    var components = URLComponents(string: "https://slack.com/oauth/v2/authorize")!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "user_scope", value: Self.scopes.joined(separator: ",")),
      URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
      URLQueryItem(name: "state", value: state),
    ]
    return components.url!
  }

  /*
   The callback is statusforslack://connected#token=…&state=… so the token
   travels in the fragment and never reaches a server log
   */
  public static func token(from callback: URL, expectedState: String) throws(SlackOAuthError) -> String {
    let fragment = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.fragment ?? ""
    var fragmentComponents = URLComponents()
    fragmentComponents.percentEncodedQuery = fragment
    let values = Dictionary(
      (fragmentComponents.queryItems ?? []).map { ($0.name, $0.value ?? "") },
      uniquingKeysWith: { first, _ in first }
    )
    guard values["state"] == expectedState else { throw .stateMismatch }
    if let error = values["error"] { throw .denied(error) }
    guard let token = values["token"], !token.isEmpty else { throw .missingToken }
    return token
  }
}
