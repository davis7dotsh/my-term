import SwiftUI

struct ContentAreaView: View {
  let model: WindowStore

  var body: some View {
    Group {
      if let selectedWindow = model.selectedWindow {
        WorkspaceView(window: selectedWindow, model: model)
      } else {
        EmptyStateView()
      }
    }
    .padding(26)
  }
}

private struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "sidebar.left")
        .font(.system(size: 48, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.72))

      Text("No window selected")
        .font(.system(size: 28, weight: .bold, design: .rounded))

      Text("Create a window in the sidebar to spin up its own terminal stack.")
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
  }
}
