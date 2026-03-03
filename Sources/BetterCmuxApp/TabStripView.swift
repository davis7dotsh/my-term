import SwiftUI

struct TabStripView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
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
            .font(.system(size: 12, weight: .bold))
            .frame(width: 34, height: 34)
            .background(
              Circle()
                .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
      }
      .padding(.vertical, 2)
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
    HStack(spacing: 10) {
      Button(action: onSelect) {
        HStack(spacing: 10) {
          Circle()
            .fill(
              isSelected ? Color(red: 0.40, green: 0.78, blue: 0.98) : Color.white.opacity(0.24)
            )
            .frame(width: 8, height: 8)

          if isRenaming {
            TextField("", text: $draftTitle, onCommit: commitRename)
              .textFieldStyle(.plain)
              .frame(minWidth: 90)
          } else {
            Text(tab.title)
              .lineLimit(1)
          }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(.leading, 14)
        .padding(.trailing, canClose ? 0 : 14)
        .padding(.vertical, 10)
      }
      .buttonStyle(.plain)

      if canClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white.opacity(0.66))
      }
    }
    .background(background)
    .overlay(
      Capsule(style: .continuous)
        .strokeBorder(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
    )
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

  private var background: some ShapeStyle {
    LinearGradient(
      colors: isSelected
        ? [Color.white.opacity(0.15), Color(red: 0.07, green: 0.17, blue: 0.30)]
        : [Color.white.opacity(0.06), Color.white.opacity(0.04)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func commitRename() {
    onRename(draftTitle)
    draftTitle = tab.title
    isRenaming = false
  }
}
