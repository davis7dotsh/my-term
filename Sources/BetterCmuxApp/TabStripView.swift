import Foundation
import SwiftUI

struct TabStripView: View {
  let window: WorkspaceWindow
  let pane: WorkspacePane
  let model: WindowStore
  @State private var renameDraft = ""
  @State private var renamingTab: TerminalTab?

  var body: some View {
    HStack(spacing: 8) {
      tabPicker
        .frame(maxWidth: pickerWidth, alignment: .leading)

      Spacer(minLength: 0)

      if let selectedTab = pane.selectedTab, pane.tabs.count == 1 {
        Text(Self.displayPath(for: selectedTab.workingDirectory))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Button {
        model.addTab(to: window.id, paneID: pane.id)
      } label: {
        Label("New Tab", systemImage: "plus")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)

      Menu {
        if let selectedTab = pane.selectedTab {
          Button("Rename Tab…") {
            renameDraft = selectedTab.title
            renamingTab = selectedTab
          }

          Button("Close Tab", role: .destructive) {
            model.closeTab(windowID: window.id, paneID: pane.id, tabID: selectedTab.id)
          }
        }

        if window.panes.count > 1 {
          Divider()

          Button("Close Pane", role: .destructive) {
            model.closePane(windowID: window.id, paneID: pane.id)
          }
        }

        Divider()

        ForEach(pane.tabs) { tab in
          Button {
            model.selectTab(windowID: window.id, paneID: pane.id, tabID: tab.id)
          } label: {
            if pane.selectedTab?.id == tab.id {
              Label(tab.title, systemImage: "checkmark")
            } else {
              Text(tab.title)
            }
          }
        }
      } label: {
        Label("Tab Options", systemImage: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .labelStyle(.iconOnly)
      .menuIndicator(.hidden)
      .fixedSize()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
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

  @ViewBuilder
  private var tabPicker: some View {
    if pane.tabs.count <= 1, let selectedTab = pane.selectedTab {
      Label(selectedTab.title, systemImage: "terminal")
        .font(.callout.weight(.medium))
        .foregroundStyle(.primary)
        .lineLimit(1)
    } else if pane.tabs.count <= 4 {
      Picker("Tab", selection: selectedTabID) {
        ForEach(pane.tabs) { tab in
          Text(tab.title)
            .tag(tab.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
    } else {
      Picker("Tab", selection: selectedTabID) {
        ForEach(pane.tabs) { tab in
          Text(tab.title)
            .tag(tab.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
    }
  }

  private var pickerWidth: CGFloat {
    if pane.tabs.count <= 1 {
      return 260
    }

    return pane.tabs.count <= 4 ? 320 : 220
  }

  private var selectedTabID: Binding<UUID> {
    .init(
      get: { pane.selectedTab?.id ?? pane.tabs.first?.id ?? UUID() },
      set: { tabID in
        model.selectTab(windowID: window.id, paneID: pane.id, tabID: tabID)
      }
    )
  }

  private static func displayPath(for path: String) -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    guard path.hasPrefix(homeDirectory) else { return path }

    let suffix = path.dropFirst(homeDirectory.count)
    return suffix.isEmpty ? "~" : "~\(suffix)"
  }
}
