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
final class WorkspaceWindow: Identifiable {
  let id: UUID
  var title: String
  var selectedTabID: UUID?
  var tabs: [TerminalTab]

  init(
    id: UUID,
    title: String,
    selectedTabID: UUID?,
    tabs: [TerminalTab]
  ) {
    self.id = id
    self.title = title
    self.selectedTabID = selectedTabID ?? tabs.first?.id
    self.tabs = tabs
  }

  convenience init(snapshot: WorkspaceWindowSnapshot, tabs: [TerminalTab]) {
    self.init(
      id: snapshot.id,
      title: snapshot.title,
      selectedTabID: snapshot.selectedTabID,
      tabs: tabs
    )
  }

  var selectedTab: TerminalTab? {
    tabs.first { $0.id == selectedTabID } ?? tabs.first
  }

  var snapshot: WorkspaceWindowSnapshot {
    .init(
      id: id,
      title: title,
      selectedTabID: selectedTab?.id,
      tabs: tabs.map(\.snapshot)
    )
  }
}
