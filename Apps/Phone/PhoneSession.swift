import Foundation
import SlackStatusKit
import WatchConnectivity

/*
 Presets travel as application context (latest wins, delivered when the watch
 is reachable). The token goes as a live message when the watch is reachable,
 and the watch asks for it when it opens without one. transferUserInfo is the
 fallback for an unreachable watch. An empty token tells the watch to forget its copy
 */
final class PhoneSession: NSObject {
  private let session: WCSession? = WCSession.isSupported() ? .default : nil

  func activate(presets: [StatusPreset]) {
    guard let session else { return }
    session.delegate = self
    session.activate()
    sendPresets(presets)
  }

  func sendPresets(_ presets: [StatusPreset]) {
    guard let session, session.activationState == .activated, let data = try? presets.encodedForSync()
    else { return }
    try? session.updateApplicationContext([SyncKeys.presets: data])
  }

  func sendToken(_ token: String) {
    guard let session, session.activationState == .activated else { return }
    Self.deliver([SyncKeys.token: token], over: session)
  }

  /*
   WatchConnectivity invokes the error handler on its own queue, so the closure
   must not be main actor isolated
   */
  private nonisolated static func deliver(_ payload: [String: String], over session: WCSession) {
    guard session.isReachable else {
      session.transferUserInfo(payload)
      return
    }
    session.sendMessage(payload, replyHandler: nil) { _ in
      session.transferUserInfo(payload)
    }
  }
}

extension PhoneSession: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
  ) {
    guard activationState == .activated else { return }
    Task { @MainActor in
      sendPresets(PresetFile().load())
      if let token = KeychainStore().read() {
        sendToken(token)
      }
    }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void
  ) {
    guard message[SyncKeys.request] as? String == SyncKeys.token else { return }
    replyHandler([SyncKeys.token: KeychainStore().read() ?? ""])
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
