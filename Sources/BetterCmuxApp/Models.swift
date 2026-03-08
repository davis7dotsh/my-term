import AppKit
import Foundation
import Observation

struct AppSnapshot: Codable {
  var selectedWindowID: UUID?
  var windows: [WorkspaceWindowSnapshot]
}

struct WorkspaceWindowSnapshot: Codable, Identifiable {
  var id: UUID
  var title: String
  var selectedTabID: UUID?
  var tabs: [TerminalTabSnapshot]
}

struct TerminalTabSnapshot: Codable, Identifiable {
  var id: UUID
  var title: String
  var workingDirectory: String
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
  let session: any TerminalSessioning

  init(
    id: UUID,
    title: String,
    workingDirectory: String,
    session: any TerminalSessioning
  ) {
    self.id = id
    self.title = title
    self.workingDirectory = workingDirectory
    self.session = session
  }

  convenience init(snapshot: TerminalTabSnapshot, session: any TerminalSessioning) {
    self.init(
      id: snapshot.id,
      title: snapshot.title,
      workingDirectory: snapshot.workingDirectory,
      session: session
    )
  }

  var snapshot: TerminalTabSnapshot {
    .init(id: id, title: title, workingDirectory: workingDirectory)
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
