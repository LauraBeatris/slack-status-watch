import SlackStatusKit
import SwiftUI

struct ContentView: View {
  @Environment(PhoneModel.self) private var model

  var body: some View {
    NavigationStack {
      Group {
        if model.isConnected {
          ConnectedView()
        } else {
          ConnectView()
        }
      }
      .navigationTitle("Slack Status")
    }
    .task { await model.refreshIdentity() }
  }
}

private struct ConnectView: View {
  @Environment(PhoneModel.self) private var model
  @State private var token = ""

  var body: some View {
    Form {
      Section {
        SecureField("xoxp-…", text: $token)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      } header: {
        Text("Slack user token")
      } footer: {
        Text("Create a Slack app from slack-app-manifest.json, install it to your workspace, then paste the User OAuth Token here. It only leaves this phone to reach your watch.")
      }

      if let error = model.connectionError {
        Section {
          Text(error).foregroundStyle(.red)
        }
      }

      Section {
        Button {
          Task { await model.connect(token: token) }
        } label: {
          if model.isConnecting {
            ProgressView()
          } else {
            Text("Connect")
          }
        }
        .disabled(token.isEmpty || model.isConnecting)
      }
    }
  }
}

private struct ConnectedView: View {
  @Environment(PhoneModel.self) private var model

  var body: some View {
    List {
      Section("Workspace") {
        if let identity = model.identity {
          LabeledContent("Connected to", value: identity.team)
          LabeledContent("As", value: identity.user)
        } else {
          Text("Connected")
        }
        Button("Disconnect", role: .destructive) {
          model.disconnect()
        }
      }

      Section("Presets") {
        ForEach(model.presets) { preset in
          NavigationLink(value: preset) {
            HStack {
              Text(SlackEmoji.display(preset.emoji))
              Text(preset.text)
              Spacer()
              Text(preset.expiry.label).foregroundStyle(.secondary)
            }
          }
        }
        .onMove { model.movePresets(from: $0, to: $1) }
        .onDelete { model.deletePresets(at: $0) }

        Button("Add preset", systemImage: "plus") {
          isAdding = true
        }
      }
    }
    .toolbar { EditButton() }
    .navigationDestination(for: StatusPreset.self) { preset in
      PresetEditorView(preset: preset) { model.update($0) }
    }
    .sheet(isPresented: $isAdding) {
      NavigationStack {
        PresetEditorView(preset: nil) { model.add($0) }
      }
    }
  }

  @State private var isAdding = false
}
