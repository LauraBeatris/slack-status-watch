import Foundation
import Testing

@testable import SlackStatusKit

struct DemoWorkspaceTests {
  /*
   Each test gets its own defaults suite, and a session that fails the test if the client reaches for the network
   */
  private let store = DemoStatusStore(suiteName: "demo-tests-" + UUID().uuidString)

  private var client: SlackClient {
    SlackClient(token: DemoWorkspace.token, session: StubSlack(response: "unreachable").session, demoStore: store)
  }

  @Test func `the demo token signs in to the demo workspace`() async throws {
    #expect(try await client.authTest() == DemoWorkspace.identity)
  }

  @Test func `a status set in the demo reads back`() async throws {
    let status = SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: Date(timeIntervalSince1970: 4_000_000_000))

    try await client.setStatus(status)

    #expect(try await client.currentStatus() == status)
  }

  @Test func `clearing the demo status reads back as cleared`() async throws {
    try await client.setStatus(SlackStatus(text: "Away", emoji: ":walking:", expiration: nil))

    try await client.clearStatus()

    #expect(try await client.currentStatus().isCleared)
  }

  @Test func `a demo status past its expiration reads as cleared`() {
    let expiration = Date(timeIntervalSince1970: 1_800_000_000)
    store.write(SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: expiration))

    #expect(store.read(at: expiration.addingTimeInterval(-1)).text == "Lunch")
    #expect(store.read(at: expiration).isCleared)
  }

  @Test func `a real token never uses the demo store`() async throws {
    let stub = StubSlack(response: #"{"ok":true,"profile":{"status_text":"","status_emoji":"","status_expiration":0}}"#)
    store.write(SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: nil))

    let status = try await SlackClient(token: stub.token, session: stub.session, demoStore: store).currentStatus()

    #expect(status.isCleared)
    #expect(stub.lastRequest() != nil)
  }
}
