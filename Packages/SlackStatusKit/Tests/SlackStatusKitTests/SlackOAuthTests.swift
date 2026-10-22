import Foundation
import SlackStatusKit
import Testing

struct SlackOAuthTests {
  let oauth = SlackOAuth(clientID: "123.456", redirectURL: URL(string: "https://example.vercel.app/api/slack/callback")!)

  @Test func `authorize URL requests user scopes on the v2 endpoint`() throws {
    let url = oauth.authorizeURL(state: "abc")
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
    #expect(components.host == "slack.com")
    #expect(components.path == "/oauth/v2/authorize")
    #expect(query["client_id"] == "123.456")
    #expect(query["user_scope"] == "users.profile:read,users.profile:write")
    #expect(query["redirect_uri"] == "https://example.vercel.app/api/slack/callback")
    #expect(query["state"] == "abc")
    #expect(query["scope"] == nil)
  }

  @Test func `token is read from the callback fragment`() throws {
    let callback = URL(string: "statusforslack://connected#token=xoxp-1-2&state=abc")!
    #expect(try SlackOAuth.token(from: callback, expectedState: "abc") == "xoxp-1-2")
  }

  @Test func `callback with another state is rejected before anything else is read`() {
    let callback = URL(string: "statusforslack://connected#token=xoxp-1-2&state=other")!
    #expect(throws: SlackOAuthError.stateMismatch) {
      try SlackOAuth.token(from: callback, expectedState: "abc")
    }
  }

  @Test func `denied authorization surfaces the Slack error code`() {
    let callback = URL(string: "statusforslack://connected#error=access_denied&state=abc")!
    #expect(throws: SlackOAuthError.denied("access_denied")) {
      try SlackOAuth.token(from: callback, expectedState: "abc")
    }
  }

  @Test func `callback without a token fails`() {
    let callback = URL(string: "statusforslack://connected#state=abc")!
    #expect(throws: SlackOAuthError.missingToken) {
      try SlackOAuth.token(from: callback, expectedState: "abc")
    }
  }
}
