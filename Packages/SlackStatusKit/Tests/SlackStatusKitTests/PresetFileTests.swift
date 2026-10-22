import Foundation
import Testing

@testable import SlackStatusKit

struct PresetFileTests {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("presets.json")

  @Test func `a missing file yields the default presets`() {
    #expect(PresetFile(url: url).load() == StatusPreset.defaults)
  }

  @Test func `saved presets load back in order`() throws {
    let file = PresetFile(url: url)
    let presets = [
      StatusPreset(emoji: "coffee", text: "Coffee", expiry: .duration(minutes: 15)),
      StatusPreset(emoji: "house", text: "Home", expiry: .timeOfDay(hour: 9, minute: 0)),
    ]

    try file.save(presets)

    #expect(file.load() == presets)
  }

  @Test func `a corrupt file falls back to the defaults`() throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)

    #expect(PresetFile(url: url).load() == StatusPreset.defaults)
  }

  @Test func `a preset resolves to the Slack status shape`() {
    let preset = StatusPreset(emoji: "hamburger", text: "Lunch", expiry: .duration(minutes: 60))
    let now = Date(timeIntervalSince1970: 1_000_000)

    let status = preset.slackStatus(at: now)

    #expect(status == SlackStatus(text: "Lunch", emoji: ":hamburger:", expiration: now.addingTimeInterval(3600)))
  }
}
