import SwiftUI

struct ContentAreaView: View {
  let model: WindowStore

  var body: some View {
    Group {
      if let selectedWindow = model.selectedWindow {
        WorkspaceView(window: selectedWindow, model: model)
      } else {
        ContentUnavailableView {
          Label("No Pane Selected", systemImage: "rectangle.stack")
        } description: {
          Text("Create a pane to start a terminal workspace.")
        } actions: {
          Button("New Pane") {
            model.addWindow()
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
