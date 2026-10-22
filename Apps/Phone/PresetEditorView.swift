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

  var body: some View {
    Form {
      Section("Status") {
        HStack {
          TextField("Emoji shortcode", text: $draft.emoji)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Text(SlackEmoji.display(draft.emoji))
        }
        TextField("Text", text: $draft.text)
      }

      Section("Expires") {
        Picker("Expires", selection: $draft.kind) {
          ForEach(PresetDraft.Kind.allCases, id: \.self) { kind in
            Text(kind.label).tag(kind)
          }
        }
        .pickerStyle(.segmented)

        switch draft.kind {
        case .never:
          EmptyView()
        case .duration:
          Picker("Duration", selection: $draft.minutes) {
            ForEach(StatusExpiry.durationChoices, id: \.self) { minutes in
              Text(StatusExpiry.duration(minutes: minutes).label).tag(minutes)
            }
          }
        case .timeOfDay:
          DatePicker("Until", selection: $draft.time, displayedComponents: .hourAndMinute)
        }
      }
    }
    .navigationTitle(isNew ? "New preset" : "Edit preset")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if isNew {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          onSave(draft.preset)
          dismiss()
        }
        .disabled(!draft.isValid)
      }
    }
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
      case .timeOfDay: "At"
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
