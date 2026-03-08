import Foundation
import Observation

@Observable
@MainActor
final class WindowStore {
  typealias SessionFactory = @MainActor (TerminalTabSnapshot) -> any TerminalSessioning

  var windows: [WorkspaceWindow]
  var selectedWindowID: UUID?

  private let persistence: StatePersistence
  private let makeSession: SessionFactory

  init(
    persistence: StatePersistence = .live,
    sessionFactory: @escaping SessionFactory = LiveTerminalSessionFactory.makeSession
  ) {
    self.persistence = persistence
    makeSession = sessionFactory

    let restored = persistence.load()
    let restoredWindows = restored?.windows.compactMap(Self.sanitizedWindowSnapshot) ?? []
    let snapshots =
      restoredWindows.isEmpty
      ? [Self.seedWindowSnapshot(index: 1, workingDirectory: Self.homeDirectory)] : restoredWindows

    windows = snapshots.map { snapshot in
      let tabs = snapshot.tabs.map { tab in
        TerminalTab(snapshot: tab, session: sessionFactory(tab))
      }

      return WorkspaceWindow(snapshot: snapshot, tabs: tabs)
    }

    selectedWindowID =
      restored?.selectedWindowID.flatMap { id in
        windows.contains(where: { $0.id == id }) ? id : nil
      } ?? windows.first?.id

    persist()
  }

  var selectedWindow: WorkspaceWindow? {
    windows.first { $0.id == selectedWindowID } ?? windows.first
  }

  func addWindow() {
    let workingDirectory =
      selectedWindow?.selectedTab?.session.currentWorkingDirectory
      ?? selectedWindow?.selectedTab?.workingDirectory
      ?? Self.homeDirectory
    let nextIndex = windows.count + 1
    let snapshot = Self.seedWindowSnapshot(index: nextIndex, workingDirectory: workingDirectory)
    let tabs = snapshot.tabs.map { tab in
      TerminalTab(snapshot: tab, session: makeSession(tab))
    }
    let window = WorkspaceWindow(snapshot: snapshot, tabs: tabs)

    windows.append(window)
    selectedWindowID = window.id
    persist()
  }

  func removeWindow(_ windowID: UUID) {
    guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }

    if windows.count == 1 {
      let replacement = Self.seedWindowSnapshot(index: 1, workingDirectory: Self.homeDirectory)
      windows = [
        WorkspaceWindow(
          snapshot: replacement,
          tabs: replacement.tabs.map { tab in
            TerminalTab(snapshot: tab, session: makeSession(tab))
          }
        )
      ]
      selectedWindowID = windows.first?.id
      persist()
      return
    }

    windows.remove(at: index)

    if selectedWindowID == windowID {
      let fallbackIndex = min(index, windows.count - 1)
      selectedWindowID = windows[safe: fallbackIndex]?.id
    }

    persist()
  }

  func selectWindow(_ windowID: UUID) {
    selectedWindowID = windowID
    persist()
  }

  func renameWindow(_ windowID: UUID, to title: String) {
    guard let window = windows.first(where: { $0.id == windowID }) else { return }
    let sanitized = Self.sanitizedTitle(title, fallback: "Window")
    guard window.title != sanitized else { return }
    window.title = sanitized
    persist()
  }

  func selectWindow(at index: Int) {
    guard let window = windows[safe: index] else { return }
    selectWindow(window.id)
  }

  func addTab(to windowID: UUID? = nil) {
    guard let window = resolvedWindow(windowID) else { return }

    let workingDirectory =
      window.selectedTab?.session.currentWorkingDirectory
      ?? window.selectedTab?.workingDirectory
      ?? Self.homeDirectory
    let snapshot = TerminalTabSnapshot(
      id: UUID(),
      title: Self.defaultTabTitle(index: window.tabs.count + 1, workingDirectory: workingDirectory),
      workingDirectory: workingDirectory
    )

    let tab = TerminalTab(snapshot: snapshot, session: makeSession(snapshot))
    window.tabs.append(tab)
    window.selectedTabID = tab.id
    persist()
  }

  func closeTab(windowID: UUID, tabID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let tabIndex = window.tabs.firstIndex(where: { $0.id == tabID }),
      window.tabs.count > 1
    else { return }

    window.tabs.remove(at: tabIndex)
    window.selectedTabID = window.tabs[safe: max(0, tabIndex - 1)]?.id ?? window.tabs.first?.id
    persist()
  }

  func closeSelectedTab() {
    guard let window = selectedWindow, let tabID = window.selectedTab?.id else { return }
    closeTab(windowID: window.id, tabID: tabID)
  }

  func selectTab(windowID: UUID, tabID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      window.tabs.contains(where: { $0.id == tabID })
    else { return }

    window.selectedTabID = tabID
    persist()
  }

  func selectTab(at index: Int, in windowID: UUID? = nil) {
    guard let window = resolvedWindow(windowID), let tab = window.tabs[safe: index] else { return }
    selectTab(windowID: window.id, tabID: tab.id)
  }

  func cycleSelectedTab(forward: Bool = true) {
    guard let window = selectedWindow,
      let selectedTabID = window.selectedTab?.id,
      let currentIndex = window.tabs.firstIndex(where: { $0.id == selectedTabID }),
      !window.tabs.isEmpty
    else { return }

    let nextIndex =
      if forward {
        (currentIndex + 1) % window.tabs.count
      } else {
        (currentIndex - 1 + window.tabs.count) % window.tabs.count
      }

    selectTab(windowID: window.id, tabID: window.tabs[nextIndex].id)
  }

  func renameTab(windowID: UUID, tabID: UUID, to title: String) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let tab = window.tabs.first(where: { $0.id == tabID })
    else { return }

    let sanitized = Self.sanitizedTitle(title, fallback: "Tab")
    guard tab.title != sanitized else { return }
    tab.title = sanitized
    persist()
  }

  private func resolvedWindow(_ windowID: UUID?) -> WorkspaceWindow? {
    if let windowID {
      return windows.first { $0.id == windowID }
    }

    return selectedWindow
  }

  private func persist() {
    persistence.save(
      AppSnapshot(
        selectedWindowID: selectedWindowID,
        windows: windows.map(\.snapshot)
      )
    )
  }

  private static func sanitizedWindowSnapshot(_ snapshot: WorkspaceWindowSnapshot)
    -> WorkspaceWindowSnapshot?
  {
    let tabs = snapshot.tabs.compactMap(sanitizedTabSnapshot)
    guard !tabs.isEmpty else { return nil }

    return .init(
      id: snapshot.id,
      title: sanitizedTitle(snapshot.title, fallback: "Window"),
      selectedTabID: snapshot.selectedTabID,
      tabs: tabs
    )
  }

  private static func sanitizedTabSnapshot(_ snapshot: TerminalTabSnapshot) -> TerminalTabSnapshot?
  {
    let workingDirectory = snapshot.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !workingDirectory.isEmpty else { return nil }

    return .init(
      id: snapshot.id,
      title: sanitizedTitle(snapshot.title, fallback: "Tab"),
      workingDirectory: workingDirectory
    )
  }

  private static func sanitizedTitle(_ title: String, fallback: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }

  private static func seedWindowSnapshot(index: Int, workingDirectory: String)
    -> WorkspaceWindowSnapshot
  {
    let tab = TerminalTabSnapshot(
      id: UUID(),
      title: defaultTabTitle(index: 1, workingDirectory: workingDirectory),
      workingDirectory: workingDirectory
    )

    return .init(
      id: UUID(),
      title: "Window \(index)",
      selectedTabID: tab.id,
      tabs: [tab]
    )
  }

  private static func defaultTabTitle(index: Int, workingDirectory: String) -> String {
    let lastComponent = URL(fileURLWithPath: workingDirectory).lastPathComponent
    if !lastComponent.isEmpty, lastComponent != "/" {
      return lastComponent
    }

    return "Tab \(index)"
  }

  private static var homeDirectory: String {
    FileManager.default.homeDirectoryForCurrentUser.path
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
