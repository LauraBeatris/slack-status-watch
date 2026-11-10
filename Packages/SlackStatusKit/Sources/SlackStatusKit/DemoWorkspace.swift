import Foundation

/*
 A simulated workspace for trying the app without a Slack account. A client
 created with the demo token keeps the status on the device and never
 touches the network
 */
public enum DemoWorkspace {
  public static let token = "demo"
  public static let identity = SlackIdentity(team: "Demo workspace", user: "Demo user")

  /*
   Forgets the simulated status, so the next demo starts clean
   */
  public static func reset() {
    DemoStatusStore().write(.cleared)
  }
}

struct DemoStatusStore: Sendable {
  var suiteName: String?

  private var defaults: UserDefaults {
    suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
  }

  /*
   Like Slack, a status past its expiration reads as cleared
   */
  func read(at now: Date = .now) -> SlackStatus {
    let defaults = defaults
    let seconds = defaults.double(forKey: Keys.expiration)
    let expiration = seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    if let expiration, expiration <= now { return .cleared }
    return SlackStatus(
      text: defaults.string(forKey: Keys.text) ?? "",
      emoji: defaults.string(forKey: Keys.emoji) ?? "",
      expiration: expiration
    )
  }

  func write(_ status: SlackStatus) {
    let defaults = defaults
    defaults.set(status.text, forKey: Keys.text)
    defaults.set(status.emoji, forKey: Keys.emoji)
    defaults.set(status.expiration?.timeIntervalSince1970 ?? 0, forKey: Keys.expiration)
  }

  private enum Keys {
    static let text = "demo.status.text"
    static let emoji = "demo.status.emoji"
    static let expiration = "demo.status.expiration"
  }
}
