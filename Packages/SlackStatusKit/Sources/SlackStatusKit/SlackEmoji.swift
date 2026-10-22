public enum SlackEmoji {
  /*
   Normalizes user input like "hamburger", ":hamburger:" or " :Hamburger: "
   to the colon-wrapped form Slack stores
   */
  public static func shortcode(_ input: String) -> String {
    let name = normalizedName(input)
    return name.isEmpty ? "" : ":\(name):"
  }

  /*
   The Unicode character for a standard emoji, or the shortcode itself for
   custom workspace emoji we have no image for. Skin tone modifiers are dropped
   */
  public static func display(_ input: String) -> String {
    let name = normalizedName(input)
    if name.isEmpty { return "" }
    let base = name.split(separator: ":").first.map(String.init) ?? name
    return slackEmojiTable[base] ?? ":\(base):"
  }

  private static func normalizedName(_ input: String) -> String {
    input
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
      .lowercased()
  }
}

import Foundation
