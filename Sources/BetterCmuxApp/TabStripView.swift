import SwiftUI

struct TabStripView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 2) {
        ForEach(window.tabs) { tab in
          TabChip(
            tab: tab,
            isSelected: window.selectedTab?.id == tab.id,
            canClose: window.tabs.count > 1,
            onSelect: { model.selectTab(windowID: window.id, tabID: tab.id) },
            onRename: { model.renameTab(windowID: window.id, tabID: tab.id, to: $0) },
            onClose: { model.closeTab(windowID: window.id, tabID: tab.id) }
          )
        }

        Button(action: { model.addTab(to: window.id) }) {
          Image(systemName: "plus")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .background(
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct TabChip: View {
  let tab: TerminalTab
  let isSelected: Bool
  let canClose: Bool
  let onSelect: () -> Void
  let onRename: (String) -> Void
  let onClose: () -> Void

  @State private var draftTitle = ""
  @State private var isRenaming = false

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onSelect) {
        HStack(spacing: 0) {
          if isRenaming {
            TextField("", text: $draftTitle, onCommit: commitRename)
              .textFieldStyle(.plain)
              .frame(minWidth: 60)
          } else {
            Text(tab.title)
              .lineLimit(1)
          }
        }
        .padding(.leading, 12)
        .padding(.trailing, canClose ? 4 : 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if canClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(isSelected ? 0.35 : 0.2))
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
      }
    }
    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
    .foregroundStyle(.white.opacity(isSelected ? 0.88 : 0.4))
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(isSelected ? .white.opacity(0.1) : .clear)
    )
    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .contextMenu {
      Button("Rename Tab") {
        draftTitle = tab.title
        isRenaming = true
      }

      if canClose {
        Button("Close Tab", role: .destructive, action: onClose)
      }
    }
    .onChange(of: isSelected) { _, selected in
      guard selected, !isRenaming else { return }
      draftTitle = tab.title
    }
  }

  private func commitRename() {
    onRename(draftTitle)
    draftTitle = tab.title
    isRenaming = false
  }
}
