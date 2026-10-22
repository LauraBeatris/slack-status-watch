import Foundation
import Synchronization
import Testing

@testable import SlackStatusKit

struct SlackClientTests {
  @Test func `set status sends the bearer token and Slack's profile shape`() async throws {
    let stub = StubSlack(response: #"{"ok":true}"#)
    let client = SlackClient(token: stub.token, session: stub.session)
    let expiration = Date(timeIntervalSince1970: 1_800_000_000)

    try await client.setStatus(SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: expiration))

    let request = try #require(stub.lastRequest())
    #expect(request.url?.absoluteString == "https://slack.com/api/users.profile.set")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(stub.token)")
    let body = try #require(try stub.lastBody())
    #expect(body["profile"]?["status_text"] as? String == "Lunch")
    #expect(body["profile"]?["status_emoji"] as? String == ":hamburger:")
    #expect(body["profile"]?["status_expiration"] as? Int == 1_800_000_000)
  }

  @Test func `clearing sends empty fields and a zero expiration`() async throws {
    let stub = StubSlack(response: #"{"ok":true}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    try await client.clearStatus()

    let body = try #require(try stub.lastBody())
    #expect(body["profile"]?["status_text"] as? String == "")
    #expect(body["profile"]?["status_emoji"] as? String == "")
    #expect(body["profile"]?["status_expiration"] as? Int == 0)
  }

  @Test func `a Slack error surfaces its code`() async throws {
    let stub = StubSlack(response: #"{"ok":false,"error":"token_revoked"}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    await #expect(throws: SlackClientError.slack("token_revoked")) {
      try await client.clearStatus()
    }
  }

  @Test func `a non JSON response is an invalid response`() async throws {
    let stub = StubSlack(response: "<html>gateway timeout</html>")
    let client = SlackClient(token: stub.token, session: stub.session)

    await #expect(throws: SlackClientError.invalidResponse) {
      try await client.clearStatus()
    }
  }

  @Test func `auth test returns the workspace and user`() async throws {
    let stub = StubSlack(response: #"{"ok":true,"team":"Resend","user":"laura","team_id":"T1","user_id":"U1"}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    let identity = try await client.authTest()

    #expect(identity == SlackIdentity(team: "Resend", user: "laura"))
  }
}

/*
 Each stub registers under its own token so parallel tests never see each other's requests
 */
struct StubSlack {
  let token = "xoxp-" + UUID().uuidString
  let session: URLSession

  init(response: String) {
    StubURLProtocol.register(token: token, response: Data(response.utf8))
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    session = URLSession(configuration: configuration)
  }

  func lastRequest() -> URLRequest? {
    StubURLProtocol.lastRequest(token: token)
  }

  func lastBody() throws -> [String: [String: Any]]? {
    guard let request = lastRequest(), let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let read = stream.read(buffer, maxLength: 4096)
      if read <= 0 { break }
      data.append(buffer, count: read)
    }
    return try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
  }
}

private final class StubURLProtocol: URLProtocol {
  private struct Entry {
    var response: Data
    var lastRequest: URLRequest?
  }

  private static let entries = Mutex<[String: Entry]>([:])

  static func register(token: String, response: Data) {
    entries.withLock { $0[token] = Entry(response: response) }
  }

  static func lastRequest(token: String) -> URLRequest? {
    entries.withLock { $0[token]?.lastRequest }
  }

  private static func token(of request: URLRequest) -> String? {
    request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let token = Self.token(of: request) else { return }
    let request = request
    let body = Self.entries.withLock { entries -> Data? in
      entries[token]?.lastRequest = request
      return entries[token]?.response
    }
    guard let body else { return }
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

struct CurrentStatusTests {
  @Test func `current status parses the profile and a zero expiration means none`() async throws {
    let stub = StubSlack(response: #"{"ok":true,"profile":{"status_text":"Lunch","status_emoji":":hamburger:","status_expiration":0}}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    let status = try await client.currentStatus()

    #expect(status == SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: nil))
    #expect(try #require(stub.lastRequest()).url?.absoluteString == "https://slack.com/api/users.profile.get")
  }

  @Test func `current status keeps a real expiration`() async throws {
    let stub = StubSlack(response: #"{"ok":true,"profile":{"status_text":"Away","status_emoji":":walking:","status_expiration":1800000000}}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    let status = try await client.currentStatus()

    #expect(status.expiration == Date(timeIntervalSince1970: 1_800_000_000))
  }

  @Test func `a cleared profile is recognised`() async throws {
    let stub = StubSlack(response: #"{"ok":true,"profile":{"status_text":"","status_emoji":"","status_expiration":0}}"#)
    let client = SlackClient(token: stub.token, session: stub.session)

    #expect(try await client.currentStatus().isCleared)
  }
}
