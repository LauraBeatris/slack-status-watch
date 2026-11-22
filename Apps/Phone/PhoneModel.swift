import AuthenticationServices
import Foundation
import SlackStatusKit

@Observable
final class PhoneModel {
  private(set) var identity: SlackIdentity?
  private(set) var presets: [StatusPreset]
  private(set) var isConnecting = false
  private(set) var isConnected: Bool
  /*
   Connected to the simulated workspace instead of Slack
   */
  private(set) var isDemo = false
  /*
   What Slack shows right now, so the presets screen can say which one is live.
   Nil until the first read, or when nothing is set
   */
  private(set) var currentStatus: SlackStatus?
  var connectionError: String?

  private let keychain = KeychainStore()
  private let presetFile = PresetFile()
  private let session = PhoneSession()
  private var isScreenshotMode = false
  /*
   Screenshot mode pins the clock to 9:41, the time in the status bar, so the live
   card reads the same on every capture. Nil everywhere else
   */
  private(set) var frozenNow: Date?

  init() {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-screenshots") {
      presets = StatusPreset.defaults
      identity = SlackIdentity(team: "Acme", user: "laura")
      isConnected = true
      let nineFortyOne = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now) ?? .now
      frozenNow = nineFortyOne
      currentStatus = presets.first?.slackStatus(at: nineFortyOne.addingTimeInterval(-8 * 60))
      isScreenshotMode = true
      return
    }
    #endif
    presets = presetFile.load()
    let token = keychain.read()
    isConnected = token != nil
    isDemo = token == DemoWorkspace.token
    session.activate(presets: presets)
    StatusShortcuts.presetsChanged()
  }

  func signIn(using signIn: SlackSignIn) async {
    isConnecting = true
    connectionError = nil
    defer { isConnecting = false }
    do {
      try await store(token: try await signIn.run())
    } catch {
      connectionError = Self.describe(error)
    }
  }

  func connect(token: String) async {
    let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else { return }
    isConnecting = true
    connectionError = nil
    defer { isConnecting = false }
    do {
      try await store(token: token)
    } catch {
      connectionError = Self.describe(error)
    }
  }

  func startDemo() async {
    await connect(token: DemoWorkspace.token)
  }

  /*
   Signs in again from the presets screen. Slack lets you pick a workspace in that sheet,
   and the current one stays connected until the new sign-in succeeds. Cancelling is silent
   */
  func switchWorkspace(using signIn: SlackSignIn) async {
    isConnecting = true
    connectionError = nil
    defer { isConnecting = false }
    do {
      try await store(token: try await signIn.run())
      await refreshStatus()
    } catch ASWebAuthenticationSessionError.canceledLogin {
      return
    } catch {
      connectionError = Self.describe(error)
    }
  }

  /*
   Keeps one workspace at a time. A token this replaces is revoked, or for the demo, reset
   */
  private func store(token: String) async throws {
    let newIdentity = try await SlackClient(token: token).authTest()
    let previous = keychain.read()
    try keychain.write(token)
    if let previous, previous != token {
      if previous == DemoWorkspace.token {
        DemoWorkspace.reset()
      } else {
        Task { try? await SlackClient(token: previous).revoke() }
      }
    }
    identity = newIdentity
    currentStatus = nil
    isConnected = true
    isDemo = token == DemoWorkspace.token
    session.sendToken(token)
  }

  /*
   Forgets the token here and on the watch right away, then asks Slack to revoke it.
   Revoking is best effort: offline, the token stays valid until removed in Slack
   */
  func disconnect() {
    if isDemo { DemoWorkspace.reset() }
    if let token = keychain.read() {
      Task { try? await SlackClient(token: token).revoke() }
    }
    keychain.delete()
    isConnected = false
    isDemo = false
    identity = nil
    currentStatus = nil
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
    StatusShortcuts.presetsChanged()
  }

  func refreshIdentity() async {
    guard identity == nil, let token = keychain.read() else { return }
    identity = try? await SlackClient(token: token).authTest()
  }

  /*
   Reads the status from Slack. Failures keep the last known value, since the
   screen still works for editing presets without it
   */
  func refreshStatus() async {
    guard isConnected, !isScreenshotMode, let token = keychain.read() else { return }
    guard let status = try? await SlackClient(token: token).currentStatus() else { return }
    currentStatus = status.isCleared ? nil : status
  }

  /*
   The preset Slack is showing, if the current status is one of them and hasn't expired
   */
  func livePreset(at now: Date = .now) -> StatusPreset? {
    guard let currentStatus else { return nil }
    if let expiration = currentStatus.expiration, expiration <= now { return nil }
    return presets.first { $0.matches(currentStatus) }
  }

  private static func describe(_ error: Error) -> String {
    switch error {
    case SlackClientError.slack(let code):
      "Slack rejected the token (\(code))"
    case SlackClientError.invalidResponse:
      "Slack returned something unexpected"
    case SlackOAuthError.denied(let code):
      "Slack didn't authorize the app (\(code))"
    case SlackOAuthError.stateMismatch, SlackOAuthError.missingToken:
      "The sign-in response couldn't be verified. Try again."
    case SlackSignInError.notConfigured:
      "This build has no Slack client ID."
    case ASWebAuthenticationSessionError.canceledLogin:
      "Sign-in was cancelled."
    default:
      error.localizedDescription
    }
  }
}
