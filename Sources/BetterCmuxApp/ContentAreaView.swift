import SwiftUI

struct ContentAreaView: View {
  let model: WindowStore

  var body: some View {
    if let selectedWindow = model.selectedWindow {
      WorkspaceView(window: selectedWindow, model: model)
    } else {
      ContentUnavailableView {
        Label("No Window Selected", systemImage: "rectangle.stack")
      } description: {
        Text("Create a window to start a terminal workspace.")
      } actions: {
        Button("New Window") {
          model.addWindow()
        }
      }
    }
  }
}
