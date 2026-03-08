import SwiftUI

struct WorkspaceView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    VStack(spacing: 0) {
      TabStripView(window: window, model: model)
        .zIndex(1)
      terminalDeck
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var terminalDeck: some View {
    ZStack {
      ForEach(window.tabs) { tab in
        TerminalHostView(session: tab.session, isFocused: window.selectedTab?.id == tab.id)
          .opacity(window.selectedTab?.id == tab.id ? 1 : 0)
          .allowsHitTesting(window.selectedTab?.id == tab.id)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
