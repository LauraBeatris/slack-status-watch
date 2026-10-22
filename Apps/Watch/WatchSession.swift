import Foundation
import SlackStatusKit
import WatchConnectivity

final class WatchSession: NSObject {
  private weak var model: WatchModel?
  private let session: WCSession? = WCSession.isSupported() ? .default : nil

  func activate(model: WatchModel) {
    self.model = model
    guard let session else { return }
    session.delegate = self
    session.activate()
  }

  /*
   Asks the phone for the token when the watch has none and the phone is reachable
   */
  func requestTokenIfMissing() {
    guard let session, session.activationState == .activated, session.isReachable, model?.token == nil
    else { return }
    Self.requestToken(from: session) { [weak self] token in
      Task { @MainActor in self?.model?.receiveToken(token) }
    }
  }

  /*
   WatchConnectivity invokes reply and error handlers on its own queue, so the
   closures must not be main actor isolated
   */
  private nonisolated static func requestToken(from session: WCSession, onToken: @escaping @Sendable (String) -> Void) {
    session.sendMessage([SyncKeys.request: SyncKeys.token]) { reply in
      guard let token = reply[SyncKeys.token] as? String, !token.isEmpty else { return }
      onToken(token)
    } errorHandler: { _ in }
  }

  private nonisolated static func presets(in context: [String: Any]) -> [StatusPreset]? {
    guard let data = context[SyncKeys.presets] as? Data else { return nil }
    return try? [StatusPreset].decodedFromSync(data)
  }

  private nonisolated func receive(_ payload: [String: Any]) {
    guard let token = payload[SyncKeys.token] as? String else { return }
    Task { @MainActor in model?.receiveToken(token) }
  }
}

extension WatchSession: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
  ) {
    guard activationState == .activated else { return }
    let presets = Self.presets(in: session.receivedApplicationContext)
    Task { @MainActor in
      if let presets { model?.receivePresets(presets) }
      requestTokenIfMissing()
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in requestTokenIfMissing() }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    guard let presets = Self.presets(in: context) else { return }
    Task { @MainActor in model?.receivePresets(presets) }
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    receive(userInfo)
  }
}
