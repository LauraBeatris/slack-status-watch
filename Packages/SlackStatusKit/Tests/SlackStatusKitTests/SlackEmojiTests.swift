import Testing

@testable import SlackStatusKit

struct SlackEmojiTests {
  @Test(arguments: ["hamburger", ":hamburger:", " :Hamburger: "])
  func `shortcode normalizes to the colon form Slack stores`(input: String) {
    #expect(SlackEmoji.shortcode(input) == ":hamburger:")
  }

  @Test func `empty input produces an empty shortcode`() {
    #expect(SlackEmoji.shortcode("  ") == "")
  }

  @Test func `standard emoji render as their character`() {
    #expect(SlackEmoji.display(":hamburger:") == "🍔")
    #expect(SlackEmoji.display("palm_tree") == "🌴")
  }

  @Test func `skin tone modifiers are dropped`() {
    #expect(SlackEmoji.display(":wave::skin-tone-3:") == "👋")
  }

  @Test func `custom workspace emoji render as their shortcode`() {
    #expect(SlackEmoji.display(":resend-logo:") == ":resend-logo:")
  }
}
