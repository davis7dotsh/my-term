import AppKit
import SwiftUI

struct SidebarView: View {
  let model: WindowStore

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)

      ScrollView {
        LazyVStack(spacing: 2) {
          ForEach(model.windows) { window in
            SidebarWindowRow(
              window: window,
              isSelected: model.selectedWindow?.id == window.id,
              onSelect: { model.selectWindow(window.id) },
              onRemove: { model.removeWindow(window.id) }
            )
          }
        }
        .padding(.horizontal, 8)
        .background(OverlayScrollerConfigurator())
      }
    }
    .foregroundStyle(.white)
  }

  private var header: some View {
    HStack {
      Text("better-cmux")
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.4))

      Spacer()

      Button(action: { model.addWindow() }) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.white.opacity(0.5))
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(.white.opacity(0.06))
          )
      }
      .buttonStyle(.plain)
    }
  }
}

private struct SidebarWindowRow: View {
  let window: WorkspaceWindow
  let isSelected: Bool
  let onSelect: () -> Void
  let onRemove: () -> Void

  private let accent = Color(red: 0.35, green: 0.68, blue: 1.0)

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 1.5)
          .fill(isSelected ? accent : .clear)
          .frame(width: 3, height: 16)
          .padding(.trailing, 8)

        Image(systemName: "terminal")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isSelected ? accent : .white.opacity(0.35))
          .frame(width: 18)
          .padding(.trailing, 8)

        VStack(alignment: .leading, spacing: 1) {
          Text(window.title)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(.white.opacity(isSelected ? 0.92 : 0.65))
            .lineLimit(1)

          Text("\(window.tabs.count) \(window.tabs.count == 1 ? "tab" : "tabs")")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.28))
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(isSelected ? .white.opacity(0.07) : .clear)
      )
      .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button("Delete Window", role: .destructive, action: onRemove)
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
      scrollView.scrollerStyle = .overlay
      scrollView.scrollerKnobStyle = .light
    }
  }
}
