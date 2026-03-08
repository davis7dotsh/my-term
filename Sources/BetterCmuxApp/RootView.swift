import AppKit
import SwiftUI

struct RootView: View {
  let model: WindowStore

  var body: some View {
    HSplitView {
      SidebarView(model: model)
        .frame(minWidth: 200, maxWidth: 350)
      ContentAreaView(model: model)
    }
    .background(WindowTitleUpdater(title: windowTitle))
  }

  private var windowTitle: String {
    model.selectedWindow?.selectedTab?.session.currentWorkingDirectory
      ?? model.selectedWindow?.selectedTab?.workingDirectory
      ?? "BetterCmux"
  }
}

private struct WindowTitleUpdater: NSViewRepresentable {
  let title: String

  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      nsView.window?.title = title
    }
  }
}
