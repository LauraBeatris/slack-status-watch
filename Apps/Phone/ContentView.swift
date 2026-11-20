import SlackStatusKit
import SwiftUI

struct ContentView: View {
  @Environment(PhoneModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      Group {
        if model.isConnected {
          ConnectedView()
        } else {
          ConnectView()
        }
      }
      .background(Color.brandPaper)
    }
    .tint(.brandPlum)
    .task(id: model.isConnected) {
      await model.refreshIdentity()
      await model.refreshStatus()
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await model.refreshStatus() }
    }
  }
}

// MARK: - Sign in

private struct ConnectView: View {
  @Environment(PhoneModel.self) private var model
  @Environment(\.webAuthenticationSession) private var webSession
  @State private var token = ""
  @State private var showsTokenField = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        GlowCard()

        VStack(alignment: .leading, spacing: 12) {
          Text("Your Slack status,\n\(Text("on your wrist.").foregroundStyle(Color.brandFaint))")
            .font(.largeTitle.weight(.semibold))
            .tracking(-1)
          Text("Sign in once here. Your presets show up on your Apple Watch a few seconds later.")
            .font(.body)
            .foregroundStyle(Color.brandMuted)
        }
        .foregroundStyle(Color.brandInk)
        .padding(.top, 32)
        .padding(.horizontal, 8)

        if let error = model.connectionError {
          Text(error)
            .font(.subheadline)
            .foregroundStyle(Color.brandDanger)
            .padding(.top, 16)
            .padding(.horizontal, 8)
        }

        #if DEBUG
        tokenField
        #endif
      }
      .padding(.horizontal, 16)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom) { actions }
    .toolbarVisibility(.hidden, for: .navigationBar)
  }

  private var actions: some View {
    VStack(spacing: 10) {
      Button {
        Task { await model.signIn(using: SlackSignIn(session: webSession)) }
      } label: {
        ZStack {
          Text("Sign in with Slack").opacity(model.isConnecting ? 0 : 1)
          if model.isConnecting { ProgressView().tint(.white) }
        }
      }
      .buttonStyle(PillButtonStyle(kind: .primary))

      Button("Try the demo") {
        Task { await model.startDemo() }
      }
      .buttonStyle(PillButtonStyle(kind: .secondary))

      Text("Your sign-in stays on this iPhone and your watch.")
        .font(.footnote)
        .foregroundStyle(Color.brandFaint)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }
    .disabled(model.isConnecting)
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(Color.brandPaper)
  }

  #if DEBUG
  private var tokenField: some View {
    DisclosureGroup("Use a token instead", isExpanded: $showsTokenField) {
      VStack(alignment: .leading, spacing: 10) {
        SecureField("xoxp-…", text: $token)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .padding(12)
          .background(Color.brandCard, in: .rect(cornerRadius: 12))
        Button("Connect") {
          Task { await model.connect(token: token) }
        }
        .disabled(token.isEmpty || model.isConnecting)
        Text("For your own Slack app: create it from slack-app-manifest.json, install it, and paste the User OAuth Token.")
          .font(.footnote)
          .foregroundStyle(Color.brandMuted)
      }
      .padding(.top, 8)
    }
    .font(.subheadline)
    .foregroundStyle(Color.brandMuted)
    .padding(.top, 24)
    .padding(.horizontal, 8)
  }
  #endif
}

/*
 The brand moment on first launch: the icon on the lilac glow, with a status pill
 showing what the app does before anyone reads a word
 */
private struct GlowCard: View {
  var body: some View {
    VStack(spacing: 28) {
      Image("BrandIcon")
        .resizable()
        .frame(width: 96, height: 96)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: Color(hex: 0x3C1446).opacity(0.3), radius: 20, y: 20)
        .accessibilityHidden(true)

      StatusPill(emoji: "🎧", title: "Focusing", subtitle: "Clears in 2h")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
    .frame(minHeight: 360)
    .background {
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(.brandGlow)
        .overlay {
          RadialGradient(colors: [.white.opacity(0.6), .clear], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 200)
            .clipShape(.rect(cornerRadius: 32, style: .continuous))
        }
    }
    .padding(.top, 8)
  }
}

/*
 How a status looks in Slack: white pill, emoji, and the green tick that says it worked
 */
struct StatusPill: View {
  let emoji: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      Text(emoji).font(.title)
      VStack(alignment: .leading, spacing: 0) {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandInk)
        Text(subtitle).font(.footnote).foregroundStyle(Color.brandMuted)
      }
      LiveTick(size: 24)
    }
    .padding(.vertical, 10)
    .padding(.leading, 12)
    .padding(.trailing, 14)
    .background(.white, in: .capsule)
    .shadow(color: Color(hex: 0x3C1446).opacity(0.22), radius: 20, y: 16)
    .accessibilityElement(children: .combine)
  }
}

struct LiveTick: View {
  let size: CGFloat

  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: size * 0.5, weight: .heavy))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Color.brandLive, in: .circle)
      .accessibilityHidden(true)
  }
}

struct PillButtonStyle: ButtonStyle {
  enum Kind { case primary, secondary }
  let kind: Kind
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.body.weight(.semibold))
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(kind == .primary ? Color.white : Color.brandInk)
      .background {
        switch kind {
        case .primary:
          Capsule().fill(configuration.isPressed ? Color(hex: 0x2C2C2F) : .brandInk)
        case .secondary:
          Capsule().fill(.white).strokeBorder(Color.brandLine)
        }
      }
      .opacity(isEnabled ? 1 : 0.5)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

// MARK: - Presets

private struct ConnectedView: View {
  @Environment(PhoneModel.self) private var model
  @State private var isAdding = false

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      list(now: context.date)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.brandPaper)
    .navigationTitle("Status")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) { WorkspaceChip().fixedSize() }
        .sharedBackgroundVisibility(.hidden)
      ToolbarItem(placement: .topBarTrailing) { EditButton() }
    }
    .navigationDestination(for: StatusPreset.self) { preset in
      PresetEditorView(preset: preset) { model.update($0) }
    }
    .sheet(isPresented: $isAdding) {
      NavigationStack {
        PresetEditorView(preset: nil) { model.add($0) }
      }
    }
  }

  private func list(now: Date) -> some View {
    let live = model.livePreset(at: now)
    return List {
      if let live, let status = model.currentStatus {
        LiveCard(preset: live, status: status, now: now)
          .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
      }

      Section {
        ForEach(model.presets) { preset in
          NavigationLink(value: preset) {
            PresetRow(preset: preset, isLive: preset.id == live?.id)
          }
          .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preset.id == live?.id ? Color.brandPlumTint : .clear)
              .padding(.horizontal, 16)
              .padding(.vertical, 2)
          )
          .listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
          .listRowSeparator(.hidden)
        }
        .onMove { model.movePresets(from: $0, to: $1) }
        .onDelete { model.deletePresets(at: $0) }

        Button {
          isAdding = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "plus")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(Color.brandInk)
              .frame(width: 26, height: 26)
              .background(Color.brandCard, in: .circle)
              .frame(width: 28)
            Text("Add preset")
              .font(.body.weight(.medium))
              .foregroundStyle(Color.brandMuted)
          }
          .frame(minHeight: 56)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      } header: {
        SectionLabel("Presets")
          .padding(.leading, 14)
          .padding(.bottom, 6)
      }

      AccountFooter()
        .listRowInsets(EdgeInsets(top: 32, leading: 24, bottom: 24, trailing: 24))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
  }
}

private struct WorkspaceChip: View {
  @Environment(PhoneModel.self) private var model

  var body: some View {
    let team = model.isDemo ? "Demo workspace" : (model.identity?.team ?? "Connected")
    HStack(spacing: 8) {
      Text(String(team.prefix(1)).uppercased())
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Color.brandPlum, in: .rect(cornerRadius: 6, style: .continuous))
      Text(team)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.brandInk)
        .lineLimit(1)
    }
    .padding(.vertical, 6)
    .padding(.leading, 6)
    .padding(.trailing, 12)
    .background(Color.brandCard, in: .capsule)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Connected to \(team)")
  }
}

/*
 The one plum moment on this screen: what Slack shows right now and how long it has left
 */
private struct LiveCard: View {
  let preset: StatusPreset
  let status: SlackStatus
  let now: Date
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Live in Slack")
        .font(.footnote.weight(.semibold))
        .tracking(0.5)
        .textCase(.uppercase)
        .foregroundStyle(Color.brandPlum)

      // At accessibility text sizes the emoji tile sits above the text so the text gets the full width
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        : AnyLayout(HStackLayout(spacing: 14))
      layout {
        Text(SlackEmoji.display(preset.emoji))
          .font(.system(size: 28))
          .frame(width: 52, height: 52)
          .background(.white, in: .rect(cornerRadius: 16, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          Text(preset.text)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color.brandInk)
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(Color.brandMuted)
        }
        if !typeSize.isAccessibilitySize {
          Spacer(minLength: 0)
          LiveTick(size: 28)
        }
      }

      if let progress {
        GeometryReader { proxy in
          Capsule()
            .fill(.white.opacity(0.7))
            .overlay(alignment: .leading) {
              Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xB37AC0), .brandPlum], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(6, proxy.size.width * progress))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
      }
    }
    .padding(20)
    .background {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.brandGlow)
        .overlay {
          RadialGradient(colors: [.white.opacity(0.6), .clear], center: UnitPoint(x: 0.2, y: 0), startRadius: 0, endRadius: 220)
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
        }
    }
    .accessibilityElement(children: .combine)
  }

  private var detail: String {
    guard let expiration = status.expiration else { return "Until you clear it" }
    let clock = expiration.formatted(date: .omitted, time: .shortened)
    let minutes = max(1, Int(expiration.timeIntervalSince(now) / 60))
    let left = minutes < 60 ? "\(minutes) min left"
      : minutes % 60 == 0 ? "\(minutes / 60)h left"
      : "\(minutes / 60)h \(minutes % 60)m left"
    return "Clears at \(clock) · \(left)"
  }

  /*
   How much of a timed status has passed. Only durations have a known start
   */
  private var progress: Double? {
    guard case .duration(let minutes) = preset.expiry, let expiration = status.expiration else { return nil }
    let total = Double(minutes * 60)
    let left = expiration.timeIntervalSince(now)
    return min(1, max(0, 1 - left / total))
  }
}

private struct PresetRow: View {
  let preset: StatusPreset
  let isLive: Bool

  @Environment(\.dynamicTypeSize) private var typeSize

  /*
   At accessibility text sizes the expiry moves under the name, so a name is never
   broken mid-word to make room for it
   */
  var body: some View {
    HStack(spacing: 12) {
      Text(SlackEmoji.display(preset.emoji))
        .font(.title3)
        .fixedSize()
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 2) {
          name
          detail
        }
      } else {
        name
        Spacer()
        detail
      }
    }
    .padding(.vertical, 8)
    .frame(minHeight: 56)
  }

  private var name: some View {
    Text(preset.text)
      .font(.body.weight(.medium))
      .foregroundStyle(Color.brandInk)
  }

  private var detail: some View {
    Text(isLive ? "Live" : preset.expiry.label)
      .font(isLive ? .subheadline.weight(.semibold) : .subheadline)
      .foregroundStyle(isLive ? Color.brandPlum : Color.brandFaint)
  }
}

private struct AccountFooter: View {
  @Environment(PhoneModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider().overlay(Color.brandLine)
      HStack {
        Text(signedIn)
          .font(.footnote)
          .foregroundStyle(Color.brandFaint)
        Spacer()
        Button(model.isDemo ? "Exit demo" : "Disconnect", role: .destructive) {
          model.disconnect()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.brandDanger)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(.rect)
      }
      if model.isDemo {
        Text("Demo mode. Statuses you set on your watch or with Siri are simulated, and nothing is sent to Slack.")
          .font(.footnote)
          .foregroundStyle(Color.brandFaint)
      }
    }
  }

  private var signedIn: String {
    guard let identity = model.identity, !identity.user.isEmpty else { return "Signed in" }
    return "Signed in as \(identity.user)"
  }
}
