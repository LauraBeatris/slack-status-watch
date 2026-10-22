import SwiftUI

@main
struct StatusWatchApp: App {
  @State private var model = WatchModel()

  var body: some Scene {
    WindowGroup {
      PresetListView()
        .environment(model)
    }
  }
}
