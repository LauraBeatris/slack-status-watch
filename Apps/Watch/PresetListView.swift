import SlackStatusKit
import SwiftUI

struct PresetListView: View {
  @Environment(WatchModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      Group {
        if model.token == nil {
          ContentUnavailableView(
            "Not connected",
            systemImage: "iphone.and.applewatch",
            description: Text("Open Status for Slack on your iPhone and paste your Slack token.")
          )
        } else {
          presetList
        }
      }
      .navigationTitle("Status")
    }
    .task(id: model.token) { await model.refresh() }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await model.refresh() }
    }
  }

  private var presetList: some View {
    List {
      if let foreign = model.foreignStatus {
        Section {
          PresetRow(
            emoji: SlackEmoji.display(foreign.emoji),
            title: foreign.text,
            subtitle: foreign.expiration.map { "Until " + $0.formatted(date: .omitted, time: .shortened) } ?? "Set elsewhere",
            state: .active,
            action: nil
          )
        } header: {
          Text("Current")
        }
      }

      ForEach(model.presets) { preset in
        PresetRow(
          emoji: SlackEmoji.display(preset.emoji),
          title: preset.text,
          subtitle: preset.expiry.label,
          state: rowState(for: .set(preset), isActive: model.isActive(preset))
        ) {
          Task { await model.perform(.set(preset)) }
        }
      }

      PresetRow(
        emoji: "✕",
        title: "Clear status",
        subtitle: nil,
        state: rowState(for: .clear, isActive: false)
      ) {
        Task { await model.perform(.clear) }
      }

      if let message = model.errorMessage {
        Section {
          Text(message).foregroundStyle(.red)
          Button("Retry") {
            Task { await model.retry() }
          }
        }
      }
    }
  }

  private func rowState(for action: StatusAction, isActive: Bool) -> PresetRow.State {
    if model.inFlight == action { return .loading }
    if isActive { return .active }
    return .idle
  }
}

struct PresetRow: View {
  enum State { case idle, loading, active }

  let emoji: String
  let title: String
  let subtitle: String?
  let state: State
  let action: (() -> Void)?

  var body: some View {
    if let action {
      Button(action: action) { content }
    } else {
      content
    }
  }

  private var content: some View {
      HStack(spacing: 8) {
        Text(emoji).font(.title3)
        VStack(alignment: .leading) {
          Text(title)
          if let subtitle {
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
          }
        }
        Spacer()
        switch state {
        case .idle:
          EmptyView()
        case .loading:
          ProgressView()
        case .active:
          Image(systemName: "checkmark").foregroundStyle(.green)
        }
      }
  }
}
