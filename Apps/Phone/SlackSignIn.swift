import AuthenticationServices
import SlackStatusKit
import SwiftUI

enum SlackSignInError: Error {
  case notConfigured
}

/*
 Runs the Slack OAuth flow in the system sign-in sheet. The Vercel function
 at SlackOAuthRedirectURL exchanges the code and bounces back on our scheme
 */
struct SlackSignIn {
  private let session: WebAuthenticationSession

  init(session: WebAuthenticationSession) {
    self.session = session
  }

  static var configuration: SlackOAuth? {
    let info = Bundle.main.infoDictionary ?? [:]
    guard
      let clientID = info["SlackClientID"] as? String, !clientID.isEmpty, !clientID.hasPrefix("$"),
      let redirect = info["SlackOAuthRedirectURL"] as? String, let redirectURL = URL(string: redirect)
    else { return nil }
    return SlackOAuth(clientID: clientID, redirectURL: redirectURL)
  }

  func run() async throws -> String {
    guard let oauth = Self.configuration else { throw SlackSignInError.notConfigured }
    let state = SlackOAuth.makeState()
    let callback = try await session.authenticate(
      using: oauth.authorizeURL(state: state),
      callback: .customScheme(SlackOAuth.callbackScheme),
      preferredBrowserSession: .ephemeral,
      additionalHeaderFields: [:]
    )
    return try SlackOAuth.token(from: callback, expectedState: state)
  }
}
