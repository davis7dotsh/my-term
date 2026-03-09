import SwiftUI

struct WorkspaceView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    if window.panes.count == 1, let pane = window.panes.first {
      PaneWorkspaceView(window: window, pane: pane, model: model)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HSplitView {
        ForEach(window.panes) { pane in
          PaneWorkspaceView(window: window, pane: pane, model: model)
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct PaneWorkspaceView: View {
  let window: WorkspaceWindow
  let pane: WorkspacePane
  let model: WindowStore

  var body: some View {
    VStack(spacing: 0) {
      TabStripView(window: window, pane: pane, model: model)
        .zIndex(1)
      terminalDeck
    }
    .background(Color.black.opacity(0.001))
    .overlay {
      RoundedRectangle(cornerRadius: 0)
        .strokeBorder(.white.opacity(isSelected ? 0.08 : 0), lineWidth: 1)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      model.selectPane(windowID: window.id, paneID: pane.id)
    }
  }

  private var terminalDeck: some View {
    ZStack {
      ForEach(pane.tabs) { tab in
        TerminalHostView(
          session: tab.session,
          isFocused: isSelected && pane.selectedTab?.id == tab.id,
          onActivate: { model.selectPane(windowID: window.id, paneID: pane.id) }
        )
        .opacity(pane.selectedTab?.id == tab.id ? 1 : 0)
        .allowsHitTesting(pane.selectedTab?.id == tab.id)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var isSelected: Bool {
    window.selectedPane?.id == pane.id
  }
}
