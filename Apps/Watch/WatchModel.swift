import Foundation
import SlackStatusKit
import WatchKit

enum StatusAction: Hashable {
  case set(StatusPreset)
  case clear
}

@Observable
final class WatchModel {
  private(set) var presets: [StatusPreset]
  private(set) var token: String?
  private(set) var inFlight: StatusAction?
  private(set) var failed: StatusAction?
  private(set) var errorMessage: String?
  private(set) var activePresetID: UUID?
  private(set) var activeUntil: Date?
  /*
   A status set somewhere else that matches no preset
   */
  private(set) var foreignStatus: SlackStatus?

  private let keychain = KeychainStore()
  private let presetFile = PresetFile()
  private let session = WatchSession()

  init() {
    presets = presetFile.load()
    token = keychain.read()
    session.activate(model: self)
  }

  func isActive(_ preset: StatusPreset, at now: Date = .now) -> Bool {
    guard preset.id == activePresetID else { return false }
    guard let activeUntil else { return true }
    return activeUntil > now
  }

  func perform(_ action: StatusAction) async {
    guard let token, inFlight == nil else { return }
    inFlight = action
    failed = nil
    errorMessage = nil
    defer { inFlight = nil }
    let client = SlackClient(token: token)
    do {
      switch action {
      case .set(let preset):
        let status = preset.slackStatus()
        try await client.setStatus(status)
        reconcile(with: status)
      case .clear:
        try await client.clearStatus()
        reconcile(with: .cleared)
      }
      WKInterfaceDevice.current().play(.success)
    } catch {
      failed = action
      errorMessage = Self.describe(error)
      WKInterfaceDevice.current().play(.failure)
    }
  }

  func retry() async {
    guard let failed else { return }
    await perform(failed)
  }

  /*
   Pulls the status from Slack so the active marker reflects changes made elsewhere.
   Failures are silent, the list still works for setting
   */
  func refresh() async {
    guard let token, inFlight == nil else { return }
    guard let status = try? await SlackClient(token: token).currentStatus() else { return }
    reconcile(with: status)
  }

  private func reconcile(with status: SlackStatus) {
    if let preset = presets.first(where: { $0.matches(status) }) {
      activePresetID = preset.id
      activeUntil = status.expiration
      foreignStatus = nil
      return
    }
    activePresetID = nil
    activeUntil = nil
    foreignStatus = status.isCleared ? nil : status
  }

  func receivePresets(_ presets: [StatusPreset]) {
    self.presets = presets
    try? presetFile.save(presets)
  }

  func receiveToken(_ token: String) {
    if token.isEmpty {
      keychain.delete()
      self.token = nil
      reconcile(with: .cleared)
    } else {
      try? keychain.write(token)
      self.token = token
    }
  }

  private static func describe(_ error: any Error) -> String {
    switch error {
    case SlackClientError.slack(let code):
      return "Slack said \(code)"
    case SlackClientError.invalidResponse:
      return "Unexpected reply"
    default:
      return "Couldn't reach Slack"
    }
  }
}
