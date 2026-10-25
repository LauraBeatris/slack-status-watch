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
      .navigationTitle("Status")
    }
    .task { await model.refreshIdentity() }
  }
}

private struct ConnectView: View {
  @Environment(PhoneModel.self) private var model
  @Environment(\.webAuthenticationSession) private var webSession
  @State private var token = ""
  @State private var showsTokenField = false

  var body: some View {
    Form {
      Section {
        Button {
          Task { await model.signIn(using: SlackSignIn(session: webSession)) }
        } label: {
          if model.isConnecting {
            ProgressView()
          } else {
            Text("Sign in with Slack")
          }
        }
        .disabled(model.isConnecting)
      } footer: {
        Text("Slack asks you to allow Status for Slack to read and set your status. Your token stays on this phone and your watch.")
      }

      if let error = model.connectionError {
        Section {
          Text(error).foregroundStyle(.red)
        }
      }

      #if DEBUG
      Section {
        DisclosureGroup("Use a token instead", isExpanded: $showsTokenField) {
          SecureField("xoxp-…", text: $token)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Button("Connect") {
            Task { await model.connect(token: token) }
          }
          .disabled(token.isEmpty || model.isConnecting)
        }
      } footer: {
        if showsTokenField {
          Text("For your own Slack app: create it from slack-app-manifest.json, install it, and paste the User OAuth Token.")
        }
      }
      #endif
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
