import AppIntents
import SlackStatusKit

struct PresetEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Slack status preset"
  static let defaultQuery = PresetQuery()

  let id: UUID
  let preset: StatusPreset

  init(_ preset: StatusPreset) {
    id = preset.id
    self.preset = preset
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(SlackEmoji.display(preset.emoji)) \(preset.text)",
      subtitle: "\(preset.expiry.label)"
    )
  }
}

struct PresetQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
    PresetFile().load().filter { identifiers.contains($0.id) }.map(PresetEntity.init)
  }

  func suggestedEntities() async throws -> [PresetEntity] {
    PresetFile().load().map(PresetEntity.init)
  }
}

struct SetSlackStatusIntent: AppIntent {
  static let title: LocalizedStringResource = "Set Slack Status"
  static let description = IntentDescription("Sets your Slack status to one of your presets.")

  @Parameter(title: "Preset")
  var preset: PresetEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Set Slack status to \(\.$preset)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let client = try connectedClient()
    try await client.setStatus(preset.preset.slackStatus())
    return .result(dialog: "Slack status set to \(preset.preset.text).")
  }
}

struct ClearSlackStatusIntent: AppIntent {
  static let title: LocalizedStringResource = "Clear Slack Status"
  static let description = IntentDescription("Clears your Slack status.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let client = try connectedClient()
    try await client.clearStatus()
    return .result(dialog: "Slack status cleared.")
  }
}

struct StatusShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SetSlackStatusIntent(),
      phrases: [
        "Set \(.applicationName) to \(\.$preset)",
        "Set my Slack status to \(\.$preset) in \(.applicationName)",
      ],
      shortTitle: "Set Slack status",
      systemImageName: "bubble.left.fill"
    )
    AppShortcut(
      intent: ClearSlackStatusIntent(),
      phrases: [
        "Clear \(.applicationName)",
        "Clear my Slack status in \(.applicationName)",
      ],
      shortTitle: "Clear Slack status",
      systemImageName: "xmark.circle"
    )
  }
}

private nonisolated func connectedClient() throws -> SlackClient {
  guard let token = KeychainStore().read() else {
    throw IntentError.notConnected
  }
  return SlackClient(token: token)
}

private enum IntentError: Error, CustomLocalizedStringResourceConvertible {
  case notConnected

  var localizedStringResource: LocalizedStringResource {
    "Status isn't connected to Slack yet. Open the Status app on your iPhone and paste your token."
  }
}
