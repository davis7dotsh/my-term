import AppKit
import SwiftUI

struct SidebarView: View {
  let model: WindowStore
  @State private var draft = ""
  @State private var sheetMode: SidebarSheetMode?

  var body: some View {
    VStack(spacing: 0) {
      profileShelf

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
              draft = window.title
              sheetMode = .renameWindow(window.id)
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
    }
    .sheet(item: $sheetMode) { mode in
      RenameSheet(
        title: mode.title,
        prompt: mode.prompt,
        value: draft,
        onCancel: { sheetMode = nil },
        onSave: { value in
          switch mode {
          case .renameWindow(let windowID):
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

  private var profileShelf: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Profiles")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)

        Spacer()

        Button {
          draft = model.activeProfile?.name ?? model.nextProfileName
          sheetMode = .saveProfile
        } label: {
          Label("Save Profile", systemImage: "plus.circle")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
      }

      if model.profiles.isEmpty {
        Text("Save the current workspace to keep its windows, tabs, and directories in sync.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(model.profiles) { profile in
              Button {
                model.activateProfile(profile.id)
              } label: {
                ProfileChip(
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
          .padding(.vertical, 1)
        }
      }

      Text(
        model.activeProfile.map { "Live syncing \($0.name)." }
          ?? "Open a profile to keep it updated automatically."
      )
      .font(.system(size: 11))
      .foregroundStyle(.secondary.opacity(0.9))
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 10)
    .background {
      ZStack {
        ChromeMaterialView()
        Color.black.opacity(0.14)
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.06))
        .frame(height: 1)
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

private enum SidebarSheetMode: Identifiable {
  case renameWindow(UUID)
  case saveProfile
  case renameProfile(UUID)

  var id: String {
    switch self {
    case .renameWindow(let windowID):
      "window-\(windowID.uuidString)"
    case .saveProfile:
      "save-profile"
    case .renameProfile(let profileID):
      "profile-\(profileID.uuidString)"
    }
  }

  var title: String {
    switch self {
    case .renameWindow:
      "Rename Window"
    case .saveProfile:
      "Save Profile"
    case .renameProfile:
      "Rename Profile"
    }
  }

  var prompt: String {
    switch self {
    case .renameWindow:
      "Window name"
    case .saveProfile, .renameProfile:
      "Profile name"
    }
  }
}

private struct ProfileChip: View {
  let profile: WorkspaceProfileSnapshot
  let isActive: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: isActive ? "circle.fill" : "circle")
        .font(.system(size: 7, weight: .bold))

      Text(profile.name)
        .lineLimit(1)
    }
    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
    .foregroundStyle(isActive ? .primary : .secondary)
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(
      Capsule()
        .fill(isActive ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
    )
    .overlay(
      Capsule()
        .strokeBorder(.white.opacity(isActive ? 0.08 : 0.03), lineWidth: 1)
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

        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
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

  private var subtitle: String {
    let tabCount = "\(window.tabs.count) \(window.tabs.count == 1 ? "tab" : "tabs")"
    guard let workingDirectory = window.selectedTab?.workingDirectory else { return tabCount }
    return "\(Self.displayPath(for: workingDirectory)) • \(tabCount)"
  }

  private static func displayPath(for path: String) -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    guard path.hasPrefix(homeDirectory) else { return path }

    let suffix = path.dropFirst(homeDirectory.count)
    return suffix.isEmpty ? "~" : "~\(suffix)"
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
