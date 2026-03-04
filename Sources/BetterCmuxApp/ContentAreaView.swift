import SwiftUI

struct ContentAreaView: View {
  let model: WindowStore

  var body: some View {
    Group {
      if let selectedWindow = model.selectedWindow {
        WorkspaceView(window: selectedWindow, model: model)
      } else {
        emptyState
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "terminal")
        .font(.system(size: 32, weight: .thin))
        .foregroundStyle(.white.opacity(0.18))

      Text("No window selected")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(0.3))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
