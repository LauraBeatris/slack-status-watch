import SlackStatusKit
import SwiftUI

struct PresetEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: PresetDraft
  private let isNew: Bool
  private let onSave: (StatusPreset) -> Void

  init(preset: StatusPreset?, onSave: @escaping (StatusPreset) -> Void) {
    _draft = State(initialValue: PresetDraft(preset: preset))
    isNew = preset == nil
    self.onSave = onSave
  }

  @FocusState private var focus: Field?
  private enum Field { case emoji, text }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        header
          .padding(.top, 24)
          .padding(.bottom, 36)

        VStack(alignment: .leading, spacing: 14) {
          SectionLabel("Clears")
          KindSwitch(selection: $draft.kind)
          expiryDetail
        }
        .padding(.horizontal, 24)

        VStack(alignment: .leading, spacing: 12) {
          SectionLabel("On your watch")
          WatchRowPreview(emoji: SlackEmoji.display(draft.emoji), title: draft.text, subtitle: draft.expiry.label)
        }
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 32)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color.brandPaper)
    .navigationTitle(isNew ? "New preset" : "Edit preset")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if isNew {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .tint(.brandMuted)
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          onSave(draft.preset)
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandInk)
        .disabled(!draft.isValid)
      }
    }
    .onAppear {
      if isNew { focus = .text }
    }
  }

  /*
   The preset as it will read: a big emoji tile you tap to change, then the text
   set at title size, so editing it feels like writing the status itself
   */
  private var header: some View {
    VStack(spacing: 18) {
      Button {
        focus = .emoji
      } label: {
        Text(draft.emoji.isEmpty ? "🙂" : SlackEmoji.display(draft.emoji))
          .font(.system(size: 52))
          .opacity(draft.emoji.isEmpty ? 0.35 : 1)
          .frame(width: 96, height: 96)
          .background(Color.brandCard, in: .rect(cornerRadius: 28, style: .continuous))
          .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pencil")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(Color.brandInk)
              .frame(width: 30, height: 30)
              .background(.white, in: .circle)
              .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
              .offset(x: 6, y: 6)
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Change emoji")

      VStack(spacing: 4) {
        TextField("Status text", text: $draft.text)
          .font(.largeTitle.weight(.semibold))
          .tracking(-1)
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.brandInk)
          .focused($focus, equals: .text)
          .submitLabel(.done)

        TextField(":emoji:", text: $draft.emoji)
          .font(.subheadline)
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.brandFaint)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focus, equals: .emoji)
          .accessibilityLabel("Emoji shortcode")
      }
      .padding(.horizontal, 24)
    }
  }

  @ViewBuilder
  private var expiryDetail: some View {
    switch draft.kind {
    case .never:
      Text("Stays until you clear it or set another status.")
        .font(.subheadline)
        .foregroundStyle(Color.brandMuted)
        .padding(.top, 4)
    case .duration:
      DurationChips(selection: $draft.minutes)
        .padding(.top, 4)
    case .timeOfDay:
      HStack {
        Text("Clears at")
          .font(.body.weight(.medium))
          .foregroundStyle(Color.brandInk)
        Spacer()
        DatePicker("Clears at", selection: $draft.time, displayedComponents: .hourAndMinute)
          .labelsHidden()
      }
      .padding(.top, 4)
    }
  }
}

/*
 Never / After / At a time as one capsule with a white thumb, the same shape as the pills
 */
private struct KindSwitch: View {
  @Binding var selection: PresetDraft.Kind
  @Namespace private var thumb

  var body: some View {
    HStack(spacing: 0) {
      ForEach(PresetDraft.Kind.allCases, id: \.self) { kind in
        let isOn = kind == selection
        Button {
          selection = kind
        } label: {
          Text(kind.label)
            .font(isOn ? .subheadline.weight(.semibold) : .subheadline.weight(.medium))
            .foregroundStyle(isOn ? Color.brandInk : Color.brandMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
              if isOn {
                Capsule()
                  .fill(.white)
                  .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                  .matchedGeometryEffect(id: "thumb", in: thumb)
              }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
      }
    }
    .padding(3)
    .background(Color.brandCard, in: .capsule)
    .animation(.spring(duration: 0.3, bounce: 0.15), value: selection)
  }
}

private struct DurationChips: View {
  @Binding var selection: Int

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(StatusExpiry.durationChoices, id: \.self) { minutes in
          let isOn = minutes == selection
          Button(StatusExpiry.duration(minutes: minutes).label) {
            selection = minutes
          }
          .font(isOn ? .subheadline.weight(.semibold) : .subheadline.weight(.medium))
          .foregroundStyle(isOn ? Color.white : Color.brandInk)
          .padding(.horizontal, 16)
          .frame(height: 40)
          .background {
            if isOn {
              Capsule().fill(Color.brandPlum)
            } else {
              Capsule().strokeBorder(Color.brandLine)
            }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isOn ? .isSelected : [])
        }
      }
    }
    .scrollClipDisabled()
  }
}

/*
 A preview of the row the watch will show, drawn the way the watch draws it
 */
private struct WatchRowPreview: View {
  let emoji: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      Text(emoji.isEmpty ? " " : emoji).font(.title3)
      VStack(alignment: .leading, spacing: 0) {
        Text(title.isEmpty ? "Status text" : title)
          .font(.system(.body, design: .rounded).weight(.medium))
          .foregroundStyle(title.isEmpty ? Color(hex: 0x98989F) : .white)
        Text(subtitle)
          .font(.system(.footnote, design: .rounded))
          .foregroundStyle(Color(hex: 0x98989F))
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .frame(height: 60)
    .background(Color(hex: 0x1F1F21), in: .rect(cornerRadius: 18, style: .continuous))
    .padding(10)
    .background(.black, in: .rect(cornerRadius: 28, style: .continuous))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Watch preview: \(title), \(subtitle)")
  }
}

/*
 Form state for a preset. The expiry kind and its values are kept separately so
 switching kinds in the picker doesn't lose what was typed
 */
private struct PresetDraft {
  enum Kind: CaseIterable {
    case never, duration, timeOfDay

    var label: String {
      switch self {
      case .never: "Never"
      case .duration: "After"
      case .timeOfDay: "At a time"
      }
    }
  }

  var id: UUID
  var emoji: String
  var text: String
  var kind: Kind
  var minutes = 60
  var time = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now

  init(preset: StatusPreset?) {
    id = preset?.id ?? UUID()
    emoji = preset?.emoji ?? ""
    text = preset?.text ?? ""
    switch preset?.expiry {
    case nil, .never:
      kind = .never
    case .duration(let minutes):
      kind = .duration
      self.minutes = minutes
    case .timeOfDay(let hour, let minute):
      kind = .timeOfDay
      time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? time
    }
  }

  var isValid: Bool {
    !text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var expiry: StatusExpiry {
    switch kind {
    case .never:
      return .never
    case .duration:
      return .duration(minutes: minutes)
    case .timeOfDay:
      let components = Calendar.current.dateComponents([.hour, .minute], from: time)
      return .timeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
  }

  var preset: StatusPreset {
    StatusPreset(
      id: id,
      emoji: SlackEmoji.shortcode(emoji).trimmingCharacters(in: CharacterSet(charactersIn: ":")),
      text: text.trimmingCharacters(in: .whitespaces),
      expiry: expiry
    )
  }
}
