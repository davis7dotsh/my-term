import AppKit
import SwiftUI

struct SidebarView: View {
  let model: WindowStore
  @State private var renameDraft = ""
  @State private var renamingWindow: WorkspaceWindow?

  var body: some View {
    List(selection: selectedWindowID) {
      ForEach(model.windows) { window in
        SidebarWindowRow(
          window: window,
          canClose: model.windows.count > 1,
          onRemove: { model.removeWindow(window.id) }
        )
        .tag(window.id)
        .contextMenu {
          Button("Rename Window") {
            renameDraft = window.title
            renamingWindow = window
          }

          Button("Delete Window", role: .destructive) {
            model.removeWindow(window.id)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .background {
      ZStack {
        ChromeMaterialView()
        Color.black.opacity(0.18)
        OverlayScrollerConfigurator()
      }
    }
    .sheet(item: $renamingWindow) { window in
      RenameSheet(
        title: "Rename Window",
        prompt: "Window name",
        value: renameDraft,
        onCancel: { renamingWindow = nil },
        onSave: { title in
          model.renameWindow(window.id, to: title)
          renamingWindow = nil
        }
      )
    }
  }

  private var selectedWindowID: Binding<UUID?> {
    .init(
      get: { model.selectedWindowID },
      set: {
        guard let id = $0 else { return }
        model.selectWindow(id)
      }
    )
  }
}

private struct SidebarWindowRow: View {
  let window: WorkspaceWindow
  let canClose: Bool
  let onRemove: () -> Void
  @State private var isHoveringClose = false

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "terminal")

      VStack(alignment: .leading, spacing: 2) {
        Text(window.title)
          .lineLimit(1)

        Text("\(window.tabs.count) \(window.tabs.count == 1 ? "tab" : "tabs")")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      if canClose {
        Button(action: onRemove) {
          Image(systemName: "xmark")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .background(
              Circle()
                .fill(.white.opacity(isHoveringClose ? 0.18 : 0))
            )
        }
        .buttonStyle(.borderless)
        .onHover { isHoveringClose = $0 }
      }
    }
  }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { ScrollerStyleView() }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ScrollerStyleView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    DispatchQueue.main.async { [weak self] in
      guard let scrollView = self?.enclosingScrollView else { return }
      scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
      scrollView.scrollerStyle = .overlay
      scrollView.scrollerKnobStyle = .light
    }
  }
}
