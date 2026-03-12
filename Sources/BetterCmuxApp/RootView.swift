import AppKit
import SwiftUI

struct RootView: View {
  let model: WindowStore

  var body: some View {
    NavigationSplitView {
      SidebarView(model: model)
        .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 340)
    } detail: {
      ContentAreaView(model: model)
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar { RootToolbarContent(model: model) }
    .background(
      WindowConfigurator(
        title: windowTitle,
        subtitle: windowSubtitle
      )
    )
  }

  private var windowTitle: String {
    model.selectedWindow?.title ?? "BetterCmux"
  }

  private var windowSubtitle: String {
    guard let workingDirectory = model.selectedWindow?.selectedTab?.workingDirectory else {
      return ""
    }

    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    guard workingDirectory.hasPrefix(homeDirectory) else { return workingDirectory }

    let suffix = workingDirectory.dropFirst(homeDirectory.count)
    return suffix.isEmpty ? "~" : "~\(suffix)"
  }
}

private struct RootToolbarContent: ToolbarContent {
  let model: WindowStore

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        model.splitSelectedWindow()
      } label: {
        Label("Split View", systemImage: "square.split.2x1")
      }
      .disabled((model.selectedWindow?.panes.count ?? 0) >= 2)

      Button {
        model.addTab()
      } label: {
        Label("New Tab", systemImage: "plus")
      }
      .disabled(model.selectedWindow?.selectedPane == nil)
    }

    ToolbarItem(placement: .automatic) {
      Button {
        model.addWindow()
      } label: {
        Label("New Pane", systemImage: "rectangle.split.1x2")
      }
    }
  }
}

private struct WindowConfigurator: NSViewRepresentable {
  let title: String
  let subtitle: String

  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      guard let window = nsView.window else { return }
      window.title = title
      window.subtitle = subtitle
      window.titleVisibility = .visible
      window.titlebarAppearsTransparent = false
      window.toolbarStyle = .unified
      window.backgroundColor = .windowBackgroundColor
      window.isMovableByWindowBackground = true
      window.tabbingMode = .disallowed
    }
  }
}
