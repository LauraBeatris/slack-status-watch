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

  func add(_ preset: StatusPreset) {
    presets.append(preset)
    savePresets()
  }

  func update(_ preset: StatusPreset) {
    guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
    presets[index] = preset
    savePresets()
  }

  func movePresets(from source: IndexSet, to destination: Int) {
    presets.move(fromOffsets: source, toOffset: destination)
    savePresets()
  }

  func deletePresets(at offsets: IndexSet) {
    presets.remove(atOffsets: offsets)
    savePresets()
  }

  private func savePresets() {
    try? presetFile.save(presets)
    session.sendPresets(presets)
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
