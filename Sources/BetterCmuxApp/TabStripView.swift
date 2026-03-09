import SwiftUI

struct TabStripView: View {
  let window: WorkspaceWindow
  let pane: WorkspacePane
  let model: WindowStore
  @State private var renameDraft = ""
  @State private var renamingTab: TerminalTab?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 2) {
        ForEach(pane.tabs) { tab in
          TabChip(
            tab: tab,
            isSelected: pane.selectedTab?.id == tab.id,
            canClose: true,
            onSelect: { model.selectTab(windowID: window.id, paneID: pane.id, tabID: tab.id) },
            onRename: {
              renameDraft = tab.title
              renamingTab = tab
            },
            onClose: { model.closeTab(windowID: window.id, paneID: pane.id, tabID: tab.id) }
          )
        }
      }
      .padding(.horizontal, 6)
      .padding(.top, 6)
    }
    .frame(height: 38)
    .background {
      ZStack {
        ChromeMaterialView()
        Color.black.opacity(0.12)
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.06))
        .frame(height: 1)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      model.selectPane(windowID: window.id, paneID: pane.id)
    }
    .sheet(item: $renamingTab) { tab in
      RenameSheet(
        title: "Rename Tab",
        prompt: "Tab name",
        value: renameDraft,
        onCancel: { renamingTab = nil },
        onSave: { title in
          model.renameTab(windowID: window.id, paneID: pane.id, tabID: tab.id, to: title)
          renamingTab = nil
        }
      )
    }
  }
}

private struct TabChip: View {
  let tab: TerminalTab
  let isSelected: Bool
  let canClose: Bool
  let onSelect: () -> Void
  let onRename: () -> Void
  let onClose: () -> Void
  @State private var isHovering = false
  @State private var isHoveringClose = false

  var body: some View {
    HStack(spacing: 4) {
      Text(tab.title)
        .lineLimit(1)
        .padding(.leading, 12)
        .padding(.trailing, canClose ? 0 : 12)

      if canClose {
        Image(systemName: "xmark")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.primary.opacity(0.6))
          .frame(width: 20, height: 20)
          .background(
            Circle()
              .fill(.primary.opacity(isHoveringClose ? 0.12 : 0))
          )
          .contentShape(Circle())
          .onHover { isHoveringClose = $0 }
          .onTapGesture { onClose() }
          .padding(.trailing, 6)
      }
    }
    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
    .foregroundStyle(isSelected ? .primary : .secondary)
    .frame(height: 28)
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(chipBackground)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(.white.opacity(isSelected ? 0.08 : 0), lineWidth: 1)
    )
    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .onTapGesture { onSelect() }
    .onHover { isHovering = $0 }
    .contextMenu {
      Button("Rename Tab") { onRename() }
      if canClose {
        Button("Close Tab", role: .destructive, action: onClose)
      }
    }
  }

  private var chipBackground: some ShapeStyle {
    if isSelected {
      return AnyShapeStyle(Color.white.opacity(0.10))
    }
    return AnyShapeStyle(Color.white.opacity(isHovering ? 0.05 : 0))
  }
}
