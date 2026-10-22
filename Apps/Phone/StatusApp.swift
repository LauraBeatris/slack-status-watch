import SwiftUI

@main
struct StatusApp: App {
  @State private var model = PhoneModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(model)
    }
  }
}
