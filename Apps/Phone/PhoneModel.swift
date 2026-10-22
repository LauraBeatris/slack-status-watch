import Foundation
import SlackStatusKit

@Observable
final class PhoneModel {
  private(set) var identity: SlackIdentity?
  private(set) var presets: [StatusPreset]
  private(set) var isConnecting = false
  private(set) var isConnected: Bool
  var connectionError: String?

  private let keychain = KeychainStore()
  private let presetFile = PresetFile()
  private let session = PhoneSession()

  init() {
    presets = presetFile.load()
    isConnected = keychain.read() != nil
    session.activate(presets: presets)
  }

  func connect(token: String) async {
    let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else { return }
    isConnecting = true
    connectionError = nil
    defer { isConnecting = false }
    do {
      identity = try await SlackClient(token: token).authTest()
      try keychain.write(token)
      isConnected = true
      session.sendToken(token)
    } catch let error as SlackClientError {
      connectionError = Self.describe(error)
    } catch {
      connectionError = error.localizedDescription
    }
  }

  func disconnect() {
    keychain.delete()
    isConnected = false
    identity = nil
    session.sendToken("")
  }

  func refreshIdentity() async {
    guard identity == nil, let token = keychain.read() else { return }
    identity = try? await SlackClient(token: token).authTest()
  }

  private static func describe(_ error: SlackClientError) -> String {
    switch error {
    case .slack(let code):
      return "Slack rejected the token (\(code))"
    case .invalidResponse:
      return "Slack returned something unexpected"
    }
  }
}
