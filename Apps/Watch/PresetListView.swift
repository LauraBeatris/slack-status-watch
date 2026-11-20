import SlackStatusKit
import SwiftUI

/*
 The watch stays true black with system rows. Green means "it worked". The brand
 reaches the wrist through the icon, not through colour on the screen
 */
struct PresetListView: View {
  @Environment(WatchModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var confirmed: Confirmation?

  var body: some View {
    NavigationStack {
      Group {
        if model.token == nil {
          NotConnectedView()
        } else {
          presetList
        }
      }
      .navigationTitle("Status")
    }
    .overlay {
      if let confirmed {
        ConfirmationView(confirmation: confirmed)
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
      }
    }
    .animation(.easeOut(duration: 0.2), value: confirmed)
    .task(id: model.token) { await model.refresh() }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await model.refresh() }
    }
  }

  private var presetList: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
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
          let isActive = model.isActive(preset, at: context.date)
          PresetRow(
            emoji: SlackEmoji.display(preset.emoji),
            title: preset.text,
            subtitle: isActive ? timeLeft(at: context.date) ?? preset.expiry.label : preset.expiry.label,
            state: rowState(for: .set(preset), isActive: isActive)
          ) {
            Task { await set(.set(preset), title: preset.text, emoji: SlackEmoji.display(preset.emoji), expiry: preset.expiry) }
          }
        }

        PresetRow(
          emoji: "✕",
          title: "Clear status",
          subtitle: nil,
          state: rowState(for: .clear, isActive: false)
        ) {
          Task { await set(.clear, title: "Cleared", emoji: "", expiry: nil) }
        }

        if let message = model.errorMessage {
          Section {
            Text(message).foregroundStyle(.red)
            Button("Retry") {
              Task { await model.retry() }
            }
          }
        }

        if model.isDemo {
          Section {
            Button("Exit demo", role: .destructive) { model.exitDemo() }
          } footer: {
            Text("Demo mode. Nothing is sent to Slack.")
          }
        }
      }
    }
  }

  /*
   Sets the status, then shows a short tick over the list. It never takes taps,
   so a second status can be picked straight away
   */
  private func set(_ action: StatusAction, title: String, emoji: String, expiry: StatusExpiry?) async {
    await model.perform(action)
    guard model.failed == nil else { return }
    let detail: String = switch expiry {
    case nil: "Nothing showing in Slack"
    case .never?: "Until you clear it"
    case let expiry?: expiry.expirationDate(from: .now).map { "Clears at " + $0.formatted(date: .omitted, time: .shortened) } ?? ""
    }
    let shown = Confirmation(id: UUID(), emoji: emoji, title: title, detail: detail)
    confirmed = shown
    try? await Task.sleep(for: .milliseconds(1100))
    if confirmed == shown { confirmed = nil }
  }

  private func timeLeft(at now: Date) -> String? {
    guard let until = model.activeUntil else { return nil }
    let minutes = Int(until.timeIntervalSince(now) / 60)
    guard minutes >= 1 else { return nil }
    if minutes < 60 { return "\(minutes) min left" }
    return minutes % 60 == 0 ? "\(minutes / 60)h left" : "\(minutes / 60)h \(minutes % 60)m left"
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
        .listRowBackground(background)
    } else {
      content
        .listRowBackground(background)
    }
  }

  private var background: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .fill(Color(hex: 0x1F1F21))
      .overlay {
        if state == .active {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
        }
      }
  }

  private var content: some View {
    HStack(spacing: 8) {
      Text(emoji).font(.title3)
      VStack(alignment: .leading) {
        Text(title)
        if let subtitle {
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(state == .active ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
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

struct Confirmation: Equatable {
  let id: UUID
  let emoji: String
  let title: String
  let detail: String
}

private struct ConfirmationView: View {
  let confirmation: Confirmation

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark")
        .font(.system(size: 30, weight: .bold))
        .foregroundStyle(.black)
        .frame(width: 60, height: 60)
        .background(.green, in: .circle)
        .shadow(color: .green.opacity(0.35), radius: 16)
      Text(confirmation.emoji.isEmpty ? confirmation.title : "\(confirmation.emoji) \(confirmation.title)")
        .font(.headline)
        .multilineTextAlignment(.center)
      Text(confirmation.detail)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
  }
}

private struct NotConnectedView: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        Image("BrandIcon")
          .resizable()
          .frame(width: 44, height: 44)
          .clipShape(.circle)
          .accessibilityHidden(true)
        Text("Not connected")
          .font(.headline)
        Text("Sign in with Slack on your iPhone.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Try the demo") { model.startDemo() }
          .padding(.top, 6)
      }
      .frame(maxWidth: .infinity)
    }
  }
}
