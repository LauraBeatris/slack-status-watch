import Foundation

public struct StatusPreset: Codable, Hashable, Identifiable, Sendable {
  public var id: UUID
  public var emoji: String
  public var text: String
  public var expiry: StatusExpiry

  public init(id: UUID = UUID(), emoji: String, text: String, expiry: StatusExpiry) {
    self.id = id
    self.emoji = emoji
    self.text = text
    self.expiry = expiry
  }

  public func slackStatus(at now: Date = .now, calendar: Calendar = .current) -> SlackStatus {
    SlackStatus(
      text: text,
      emoji: SlackEmoji.shortcode(emoji),
      expiration: expiry.expirationDate(from: now, calendar: calendar)
    )
  }

  /*
   A preset is active when Slack shows its emoji and text, whatever the expiry
   */
  public func matches(_ status: SlackStatus) -> Bool {
    SlackEmoji.shortcode(emoji) == SlackEmoji.shortcode(status.emoji) && text == status.text
  }

  public static let defaults: [StatusPreset] = [
    StatusPreset(id: fixedID("1"), emoji: "hamburger", text: "Lunch", expiry: .duration(minutes: 60)),
    StatusPreset(id: fixedID("2"), emoji: "calendar", text: "In a meeting", expiry: .duration(minutes: 60)),
    StatusPreset(id: fixedID("3"), emoji: "headphones", text: "Focusing", expiry: .duration(minutes: 120)),
    StatusPreset(id: fixedID("4"), emoji: "walking", text: "Away", expiry: .timeOfDay(hour: 18, minute: 0)),
    StatusPreset(id: fixedID("5"), emoji: "palm_tree", text: "Out of office", expiry: .never),
  ]

  private static func fixedID(_ suffix: String) -> UUID {
    UUID(uuidString: "0000A1E0-0000-4000-8000-00000000000\(suffix)")!
  }
}

public struct SlackStatus: Hashable, Sendable {
  public var text: String
  public var emoji: String
  public var expiration: Date?

  public init(text: String, emoji: String, expiration: Date?) {
    self.text = text
    self.emoji = emoji
    self.expiration = expiration
  }

  public static let cleared = SlackStatus(text: "", emoji: "", expiration: nil)

  public var isCleared: Bool {
    text.isEmpty && emoji.isEmpty
  }
}
