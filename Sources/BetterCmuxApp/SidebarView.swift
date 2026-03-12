import Foundation
import SwiftUI

struct SidebarView: View {
  let model: WindowStore
  @State private var draft = ""
  @State private var sheetMode: SidebarSheetMode?

  var body: some View {
    List(selection: selectedWindowID) {
      Section {
        ForEach(model.windows) { window in
          SidebarPaneRow(
            window: window,
            canClose: model.windows.count > 1,
            onRemove: { model.removeWindow(window.id) }
          )
          .tag(window.id)
          .contextMenu {
            Button("Rename Pane") {
              draft = window.title
              sheetMode = .renamePane(window.id)
            }

            Button("Delete Pane", role: .destructive) {
              model.removeWindow(window.id)
            }
          }
        }
      } header: {
        SidebarSectionHeader(title: "Panes", helpText: "New Pane") {
          model.addWindow()
        }
      }

      Section {
        if model.profiles.isEmpty {
          SidebarHintRow(
            title: "No saved profiles yet",
            message: "Save the current workspace to switch back to it later."
          )
          .listRowSeparator(.hidden)
        } else {
          ForEach(model.profiles) { profile in
            Button {
              model.activateProfile(profile.id)
            } label: {
              SidebarProfileRow(
                profile: profile,
                isActive: model.activeProfileID == profile.id
              )
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button("Rename Profile") {
                draft = profile.name
                sheetMode = .renameProfile(profile.id)
              }

              Button("Delete Profile", role: .destructive) {
                model.deleteProfile(profile.id)
              }
            }
          }
        }
      } header: {
        SidebarSectionHeader(title: "Profiles", helpText: "Save Current Workspace") {
          draft = model.activeProfile?.name ?? model.nextProfileName
          sheetMode = .saveProfile
        }
      }
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom) {
      SidebarStatusBar(activeProfile: model.activeProfile)
    }
    .sheet(item: $sheetMode) { mode in
      RenameSheet(
        title: mode.title,
        prompt: mode.prompt,
        value: draft,
        onCancel: { sheetMode = nil },
        onSave: { value in
          switch mode {
          case .renamePane(let windowID):
            model.renameWindow(windowID, to: value)
          case .saveProfile:
            model.saveProfile(named: value)
          case .renameProfile(let profileID):
            model.renameProfile(profileID, to: value)
          }

          sheetMode = nil
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

private struct SidebarSectionHeader: View {
  let title: String
  let helpText: String
  let onAdd: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text(title)

      Spacer()

      Button(action: onAdd) {
        Image(systemName: "plus")
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .help(helpText)
    }
  }
}

private enum SidebarSheetMode: Identifiable {
  case renamePane(UUID)
  case saveProfile
  case renameProfile(UUID)

  var id: String {
    switch self {
    case .renamePane(let windowID):
      "pane-\(windowID.uuidString)"
    case .saveProfile:
      "save-profile"
    case .renameProfile(let profileID):
      "profile-\(profileID.uuidString)"
    }
  }

  var title: String {
    switch self {
    case .renamePane:
      "Rename Pane"
    case .saveProfile:
      "Save Profile"
    case .renameProfile:
      "Rename Profile"
    }
  }

  var prompt: String {
    switch self {
    case .renamePane:
      "Pane name"
    case .saveProfile, .renameProfile:
      "Profile name"
    }
  }
}

private struct SidebarHintRow: View {
  let title: String
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)

      Text(message)
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
  }
}

private struct SidebarProfileRow: View {
  let profile: WorkspaceProfileSnapshot
  let isActive: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: isActive ? "checkmark.circle.fill" : "square.stack")
        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(profile.name)
          .lineLimit(1)

        Text(isActive ? "Live sync enabled" : "Saved workspace")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      if isActive {
        Text("Live")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Color.accentColor.opacity(0.8))
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(Color.accentColor.opacity(0.1), in: Capsule())
      }
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
  }
}

private struct SidebarPaneRow: View {
  let window: WorkspaceWindow
  let canClose: Bool
  let onRemove: () -> Void
  @State private var isHoveringClose = false

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "terminal")
        .foregroundStyle(.secondary)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(window.title)
          .lineLimit(1)

        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      if canClose {
        Button(action: onRemove) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(isHoveringClose ? Color.secondary : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.borderless)
        .onHover { isHoveringClose = $0 }
      }
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
  }

  private var subtitle: String {
    let tabCount = "\(window.tabCount) \(window.tabCount == 1 ? "tab" : "tabs")"
    guard let workingDirectory = window.selectedTab?.workingDirectory else { return tabCount }
    return "\(Self.displayPath(for: workingDirectory)) · \(tabCount)"
  }

  private static func displayPath(for path: String) -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    guard path.hasPrefix(homeDirectory) else { return path }

    let suffix = path.dropFirst(homeDirectory.count)
    return suffix.isEmpty ? "~" : "~\(suffix)"
  }
}

private struct SidebarStatusBar: View {
  let activeProfile: WorkspaceProfileSnapshot?

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: activeProfile == nil ? "circle.dashed" : "checkmark.circle.fill")
        .foregroundStyle(activeProfile == nil ? Color.secondary : Color.accentColor)

      Text(
        activeProfile.map { "Syncing \($0.name)" }
          ?? "Working locally"
      )
      .foregroundStyle(.secondary)
      .lineLimit(1)

      Spacer()
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}
