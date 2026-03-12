import Foundation
import SwiftUI

struct TabStripView: View {
  let window: WorkspaceWindow
  let pane: WorkspacePane
  let model: WindowStore
  @State private var renameDraft = ""
  @State private var renamingTab: TerminalTab?

  var body: some View {
    HStack(spacing: 0) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 1) {
          ForEach(pane.tabs) { tab in
            TabButton(
              tab: tab,
              isSelected: pane.selectedTab?.id == tab.id,
              canClose: pane.tabs.count > 1,
              onSelect: {
                model.selectTab(windowID: window.id, paneID: pane.id, tabID: tab.id)
              },
              onClose: {
                model.closeTab(windowID: window.id, paneID: pane.id, tabID: tab.id)
              },
              onRename: {
                renameDraft = tab.title
                renamingTab = tab
              }
            )
          }
        }
        .padding(.horizontal, 6)
      }

      Divider()
        .padding(.vertical, 7)

      HStack(spacing: 0) {
        Button {
          model.addTab(to: window.id, paneID: pane.id)
        } label: {
          Image(systemName: "plus")
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("New Tab")

        if window.panes.count > 1 {
          Menu {
            Button("Close Pane", role: .destructive) {
              model.closePane(windowID: window.id, paneID: pane.id)
            }
          } label: {
            Image(systemName: "ellipsis")
              .frame(width: 24, height: 28)
              .contentShape(Rectangle())
          }
          .menuStyle(.borderlessButton)
          .menuIndicator(.hidden)
          .fixedSize()
        }
      }
      .padding(.trailing, 4)
    }
    .frame(height: 34)
    .controlSize(.small)
    .background(Color(nsColor: .windowBackgroundColor))
    .overlay(alignment: .bottom) {
      Divider()
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

private struct TabButton: View {
  let tab: TerminalTab
  let isSelected: Bool
  let canClose: Bool
  let onSelect: () -> Void
  let onClose: () -> Void
  let onRename: () -> Void
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 0) {
      // Select area
      Button(action: onSelect) {
        Text(tab.title)
          .font(.callout)
          .lineLimit(1)
          .fixedSize()
          .padding(.leading, 9)
          .padding(.trailing, canClose ? 5 : 9)
          .frame(height: 26)
      }
      .buttonStyle(.plain)

      // Close button — shown on hover or when selected
      if canClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering || isSelected ? 1 : 0)
        .padding(.trailing, 6)
      }
    }
    .background {
      RoundedRectangle(cornerRadius: 5)
        .fill(
          isSelected
            ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18)
            : isHovering
              ? Color(nsColor: .quaternaryLabelColor).opacity(0.6)
              : Color.clear
        )
    }
    .onHover { isHovering = $0 }
    .contextMenu {
      Button("Rename Tab…") { onRename() }
      if canClose {
        Divider()
        Button("Close Tab", role: .destructive) { onClose() }
      }
    }
  }
}
