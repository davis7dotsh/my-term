import AppKit
import Foundation
import Observation

struct PersistedAppState: Codable, Equatable {
  var activeProfileID: UUID?
  var currentWorkspace: AppSnapshot
  var profiles: [WorkspaceProfileSnapshot]
}

struct AppSnapshot: Codable, Equatable {
  var selectedWindowID: UUID?
  var windows: [WorkspaceWindowSnapshot]
}

struct WorkspaceProfileSnapshot: Codable, Equatable, Identifiable {
  var id: UUID
  var name: String
  var workspace: AppSnapshot
}

struct WorkspaceWindowSnapshot: Codable, Equatable, Identifiable {
  var id: UUID
  var title: String
  var selectedPaneID: UUID?
  var panes: [WorkspacePaneSnapshot]

  init(
    id: UUID,
    title: String,
    selectedPaneID: UUID?,
    panes: [WorkspacePaneSnapshot]
  ) {
    self.id = id
    self.title = title
    self.selectedPaneID = selectedPaneID
    self.panes = panes
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)

    if let panes = try container.decodeIfPresent([WorkspacePaneSnapshot].self, forKey: .panes) {
      self.panes = panes
      selectedPaneID =
        try container.decodeIfPresent(UUID.self, forKey: .selectedPaneID) ?? panes.first?.id
      return
    }

    let tabs = try container.decodeIfPresent([TerminalTabSnapshot].self, forKey: .tabs) ?? []
    let paneID = UUID()
    panes =
      tabs.isEmpty
      ? []
      : [
        .init(
          id: paneID,
          selectedTabID: try container.decodeIfPresent(UUID.self, forKey: .selectedTabID),
          tabs: tabs
        )
      ]
    selectedPaneID = panes.first?.id
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(selectedPaneID, forKey: .selectedPaneID)
    try container.encode(panes, forKey: .panes)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case selectedPaneID
    case panes
    case selectedTabID
    case tabs
  }
}

struct WorkspacePaneSnapshot: Codable, Equatable, Identifiable {
  var id: UUID
  var selectedTabID: UUID?
  var tabs: [TerminalTabSnapshot]
}

struct TerminalTabSnapshot: Codable, Equatable, Identifiable {
  var id: UUID
  var title: String
  var workingDirectory: String
  var hasCustomTitle: Bool

  init(id: UUID, title: String, workingDirectory: String, hasCustomTitle: Bool = false) {
    self.id = id
    self.title = title
    self.workingDirectory = workingDirectory
    self.hasCustomTitle = hasCustomTitle
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
    hasCustomTitle = try container.decodeIfPresent(Bool.self, forKey: .hasCustomTitle) ?? false
  }
}

@MainActor
protocol TerminalSessioning: AnyObject {
  var id: UUID { get }
  var hostView: NSView { get }
  var currentWorkingDirectory: String? { get }
  func focus()
}

@Observable
@MainActor
final class TerminalTab: Identifiable {
  let id: UUID
  var title: String
  var workingDirectory: String
  var hasCustomTitle: Bool
  let session: any TerminalSessioning

  init(
    id: UUID,
    title: String,
    workingDirectory: String,
    hasCustomTitle: Bool,
    session: any TerminalSessioning
  ) {
    self.id = id
    self.title = title
    self.workingDirectory = workingDirectory
    self.hasCustomTitle = hasCustomTitle
    self.session = session
  }

  convenience init(snapshot: TerminalTabSnapshot, session: any TerminalSessioning) {
    self.init(
      id: snapshot.id,
      title: snapshot.title,
      workingDirectory: snapshot.workingDirectory,
      hasCustomTitle: snapshot.hasCustomTitle,
      session: session
    )
  }

  var snapshot: TerminalTabSnapshot {
    .init(id: id, title: title, workingDirectory: workingDirectory, hasCustomTitle: hasCustomTitle)
  }
}

@Observable
@MainActor
final class WorkspacePane: Identifiable {
  let id: UUID
  var selectedTabID: UUID?
  var tabs: [TerminalTab]

  init(id: UUID, selectedTabID: UUID?, tabs: [TerminalTab]) {
    self.id = id
    self.selectedTabID = selectedTabID ?? tabs.first?.id
    self.tabs = tabs
  }

  convenience init(snapshot: WorkspacePaneSnapshot, tabs: [TerminalTab]) {
    self.init(
      id: snapshot.id,
      selectedTabID: snapshot.selectedTabID,
      tabs: tabs
    )
  }

  var selectedTab: TerminalTab? {
    tabs.first { $0.id == selectedTabID } ?? tabs.first
  }

  var snapshot: WorkspacePaneSnapshot {
    .init(
      id: id,
      selectedTabID: selectedTab?.id,
      tabs: tabs.map(\.snapshot)
    )
  }
}

@Observable
@MainActor
final class WorkspaceWindow: Identifiable {
  let id: UUID
  var title: String
  var selectedPaneID: UUID?
  var panes: [WorkspacePane]

  init(
    id: UUID,
    title: String,
    selectedPaneID: UUID?,
    panes: [WorkspacePane]
  ) {
    self.id = id
    self.title = title
    self.selectedPaneID = selectedPaneID ?? panes.first?.id
    self.panes = panes
  }

  convenience init(snapshot: WorkspaceWindowSnapshot, panes: [WorkspacePane]) {
    self.init(
      id: snapshot.id,
      title: snapshot.title,
      selectedPaneID: snapshot.selectedPaneID,
      panes: panes
    )
  }

  var selectedPane: WorkspacePane? {
    panes.first { $0.id == selectedPaneID } ?? panes.first
  }

  var selectedTab: TerminalTab? {
    selectedPane?.selectedTab
  }

  var tabCount: Int {
    panes.reduce(into: 0) { $0 += $1.tabs.count }
  }

  var snapshot: WorkspaceWindowSnapshot {
    .init(
      id: id,
      title: title,
      selectedPaneID: selectedPane?.id,
      panes: panes.map(\.snapshot)
    )
  }
}
