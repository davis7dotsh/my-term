import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class WindowStore {
  typealias SessionFactory = @MainActor (TerminalTabSnapshot) -> any TerminalSessioning

  var windows: [WorkspaceWindow]
  var selectedWindowID: UUID?
  var profiles: [WorkspaceProfileSnapshot]
  var activeProfileID: UUID?

  private let persistence: StatePersistence
  private let makeSession: SessionFactory
  private let metadataRefreshInterval: TimeInterval
  private let autosaveInterval: TimeInterval
  private var metadataRefreshTimer: Timer?
  private var autosaveTimer: Timer?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var workspaceLifecycleObservers: [NSObjectProtocol] = []
  private var lastPersistedState: PersistedAppState?

  init(
    persistence: StatePersistence = .live,
    sessionFactory: @escaping SessionFactory = LiveTerminalSessionFactory.makeSession,
    metadataRefreshInterval: TimeInterval = 0.75,
    autosaveInterval: TimeInterval = 2
  ) {
    self.persistence = persistence
    makeSession = sessionFactory
    self.metadataRefreshInterval = metadataRefreshInterval
    self.autosaveInterval = autosaveInterval

    let restoredState = persistence.load()
    let restoredWorkspace = Self.sanitizedAppSnapshot(restoredState?.currentWorkspace)
    let initialWorkspace = restoredWorkspace ?? Self.seedWorkspaceSnapshot()
    let initialWindows = Self.buildWindows(from: initialWorkspace, sessionFactory: sessionFactory)
    let initialProfiles = (restoredState?.profiles ?? []).compactMap(Self.sanitizedProfileSnapshot)

    windows = initialWindows
    selectedWindowID = Self.resolvedSelectedWindowID(
      initialWorkspace.selectedWindowID, in: initialWindows)
    profiles = initialProfiles
    activeProfileID =
      restoredState?.activeProfileID.flatMap { id in
        initialProfiles.contains(where: { $0.id == id }) ? id : nil
      }

    installLifecycleObservers()
    startMetadataRefresh()
    startAutosave()
    persist()
  }

  var selectedWindow: WorkspaceWindow? {
    windows.first { $0.id == selectedWindowID } ?? windows.first
  }

  var activeProfile: WorkspaceProfileSnapshot? {
    guard let activeProfileID else { return nil }
    return profiles.first { $0.id == activeProfileID }
  }

  var nextProfileName: String {
    "Profile \(profiles.count + 1)"
  }

  func addWindow() {
    let workingDirectory =
      selectedWindow?.selectedTab?.session.currentWorkingDirectory
      ?? selectedWindow?.selectedTab?.workingDirectory
      ?? Self.homeDirectory
    let nextIndex = windows.count + 1
    let snapshot = Self.seedWindowSnapshot(index: nextIndex, workingDirectory: workingDirectory)
    let window = Self.makeWindow(from: snapshot, sessionFactory: makeSession)

    windows.append(window)
    selectedWindowID = window.id
    persist()
  }

  func removeWindow(_ windowID: UUID) {
    guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }
    windows.remove(at: index)

    if selectedWindowID == windowID {
      if windows.isEmpty {
        selectedWindowID = nil
      } else {
        let fallbackIndex = min(index, windows.count - 1)
        selectedWindowID = windows[safe: fallbackIndex]?.id
      }
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

  func selectPane(windowID: UUID, paneID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      window.panes.contains(where: { $0.id == paneID })
    else { return }

    window.selectedPaneID = paneID
    persist()
  }

  func splitSelectedWindow() {
    guard let window = selectedWindow, window.panes.count == 1 else { return }

    let workingDirectory =
      window.selectedPane?.selectedTab?.session.currentWorkingDirectory
      ?? window.selectedPane?.selectedTab?.workingDirectory
      ?? Self.homeDirectory
    let snapshot = Self.seedPaneSnapshot(index: 1, workingDirectory: workingDirectory)
    let pane = Self.makePane(from: snapshot, sessionFactory: makeSession)

    window.panes.append(pane)
    window.selectedPaneID = pane.id
    persist()
  }

  func closePane(windowID: UUID, paneID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let paneIndex = window.panes.firstIndex(where: { $0.id == paneID }),
      window.panes.count > 1
    else { return }

    window.panes.remove(at: paneIndex)
    let fallbackIndex = min(paneIndex, window.panes.count - 1)
    window.selectedPaneID = window.panes[safe: fallbackIndex]?.id ?? window.panes.first?.id
    persist()
  }

  func addTab(to windowID: UUID? = nil, paneID: UUID? = nil) {
    guard let window = resolvedWindow(windowID),
      let pane = resolvedPane(in: window, paneID: paneID)
    else { return }

    let workingDirectory =
      pane.selectedTab?.session.currentWorkingDirectory
      ?? pane.selectedTab?.workingDirectory
      ?? Self.homeDirectory
    let snapshot = TerminalTabSnapshot(
      id: UUID(),
      title: Self.defaultTabTitle(index: pane.tabs.count + 1, workingDirectory: workingDirectory),
      workingDirectory: workingDirectory
    )

    let tab = TerminalTab(snapshot: snapshot, session: makeSession(snapshot))
    pane.tabs.append(tab)
    pane.selectedTabID = tab.id
    window.selectedPaneID = pane.id
    persist()
  }

  func closeTab(windowID: UUID, paneID: UUID, tabID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let pane = window.panes.first(where: { $0.id == paneID }),
      let tabIndex = pane.tabs.firstIndex(where: { $0.id == tabID })
    else { return }

    if pane.tabs.count == 1 {
      if window.panes.count > 1 {
        closePane(windowID: windowID, paneID: paneID)
      } else {
        removeWindow(windowID)
      }
      return
    }

    pane.tabs.remove(at: tabIndex)
    pane.selectedTabID = pane.tabs[safe: max(0, tabIndex - 1)]?.id ?? pane.tabs.first?.id
    window.selectedPaneID = pane.id
    persist()
  }

  func closeSelectedTab() {
    guard let window = selectedWindow,
      let pane = window.selectedPane,
      let tabID = pane.selectedTab?.id
    else { return }

    closeTab(windowID: window.id, paneID: pane.id, tabID: tabID)
  }

  func selectTab(windowID: UUID, paneID: UUID, tabID: UUID) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let pane = window.panes.first(where: { $0.id == paneID }),
      pane.tabs.contains(where: { $0.id == tabID })
    else { return }

    window.selectedPaneID = paneID
    pane.selectedTabID = tabID
    persist()
  }

  func selectTab(at index: Int, in windowID: UUID? = nil) {
    guard let window = resolvedWindow(windowID),
      let pane = window.selectedPane,
      let tab = pane.tabs[safe: index]
    else { return }

    selectTab(windowID: window.id, paneID: pane.id, tabID: tab.id)
  }

  func cycleSelectedTab(forward: Bool = true) {
    guard let window = selectedWindow,
      let pane = window.selectedPane,
      let selectedTabID = pane.selectedTab?.id,
      let currentIndex = pane.tabs.firstIndex(where: { $0.id == selectedTabID }),
      !pane.tabs.isEmpty
    else { return }

    let nextIndex =
      if forward {
        (currentIndex + 1) % pane.tabs.count
      } else {
        (currentIndex - 1 + pane.tabs.count) % pane.tabs.count
      }

    selectTab(windowID: window.id, paneID: pane.id, tabID: pane.tabs[nextIndex].id)
  }

  func renameTab(windowID: UUID, paneID: UUID, tabID: UUID, to title: String) {
    guard let window = windows.first(where: { $0.id == windowID }),
      let pane = window.panes.first(where: { $0.id == paneID }),
      let tab = pane.tabs.first(where: { $0.id == tabID })
    else { return }

    let sanitized = Self.sanitizedTitle(title, fallback: "Tab")
    guard tab.title != sanitized else { return }
    tab.title = sanitized
    tab.hasCustomTitle = true
    window.selectedPaneID = pane.id
    persist()
  }

  func saveProfile(named name: String) {
    let sanitizedName = Self.sanitizedTitle(name, fallback: nextProfileName)
    let profile = WorkspaceProfileSnapshot(
      id: UUID(),
      name: sanitizedName,
      workspace: currentWorkspaceSnapshot()
    )

    profiles.append(profile)
    activeProfileID = profile.id
    persist()
  }

  func activateProfile(_ profileID: UUID) {
    guard activeProfileID != profileID else { return }
    persist()

    guard let profile = profiles.first(where: { $0.id == profileID }),
      let workspace = Self.sanitizedAppSnapshot(profile.workspace)
    else { return }

    replaceWorkspace(with: workspace)
    activeProfileID = profile.id
    persist()
  }

  func renameProfile(_ profileID: UUID, to name: String) {
    guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
    let sanitizedName = Self.sanitizedTitle(name, fallback: "Profile")
    guard profiles[index].name != sanitizedName else { return }
    profiles[index].name = sanitizedName
    persist()
  }

  func deleteProfile(_ profileID: UUID) {
    guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
    profiles.remove(at: index)

    if activeProfileID == profileID {
      activeProfileID = nil
    }

    persist()
  }

  func refreshWorkspaceState() {
    persist()
  }

  private func resolvedWindow(_ windowID: UUID?) -> WorkspaceWindow? {
    if let windowID {
      return windows.first { $0.id == windowID }
    }

    return selectedWindow
  }

  private func resolvedPane(in window: WorkspaceWindow, paneID: UUID?) -> WorkspacePane? {
    if let paneID {
      return window.panes.first { $0.id == paneID }
    }

    return window.selectedPane
  }

  private func replaceWorkspace(with snapshot: AppSnapshot) {
    windows = Self.buildWindows(from: snapshot, sessionFactory: makeSession)
    selectedWindowID = Self.resolvedSelectedWindowID(snapshot.selectedWindowID, in: windows)
  }

  private func startAutosave() {
    autosaveTimer?.invalidate()
    autosaveTimer = Timer.scheduledTimer(withTimeInterval: autosaveInterval, repeats: true) {
      [weak self] _ in
      Task { @MainActor in
        self?.persist()
      }
    }
  }

  private func startMetadataRefresh() {
    metadataRefreshTimer?.invalidate()
    metadataRefreshTimer = Timer.scheduledTimer(
      withTimeInterval: metadataRefreshInterval,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        self?.refreshVisibleTabMetadata()
      }
    }
  }

  private func installLifecycleObservers() {
    let notificationCenter = NotificationCenter.default

    lifecycleObservers = [
      notificationCenter.addObserver(
        forName: NSApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.persist()
        }
      },
      notificationCenter.addObserver(
        forName: NSApplication.willTerminateNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.persist()
        }
      },
    ]

    let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    workspaceLifecycleObservers = [
      workspaceNotificationCenter.addObserver(
        forName: NSWorkspace.willSleepNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.persist()
        }
      }
    ]
  }

  private func persist() {
    let workspace = currentWorkspaceSnapshot()
    syncActiveProfile(with: workspace)

    let state = PersistedAppState(
      activeProfileID: activeProfileID,
      currentWorkspace: workspace,
      profiles: profiles
    )

    guard state != lastPersistedState else { return }
    persistence.save(state)
    lastPersistedState = state
  }

  private func currentWorkspaceSnapshot() -> AppSnapshot {
    syncAllTabMetadata()

    return .init(
      selectedWindowID: selectedWindowID,
      windows: windows.map(\.snapshot)
    )
  }

  private func refreshVisibleTabMetadata() {
    guard let selectedWindow else { return }

    for pane in selectedWindow.panes {
      guard let tab = pane.selectedTab,
        let index = pane.tabs.firstIndex(where: { $0.id == tab.id })
      else { continue }
      syncTabMetadata(for: tab, index: index + 1)
    }
  }

  private func syncAllTabMetadata() {
    for window in windows {
      for pane in window.panes {
        for (index, tab) in pane.tabs.enumerated() {
          syncTabMetadata(for: tab, index: index + 1)
        }
      }
    }
  }

  private func syncTabMetadata(for tab: TerminalTab, index: Int) {
    let workingDirectory =
      tab.session.currentWorkingDirectory?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let workingDirectory, !workingDirectory.isEmpty else { return }

    if tab.workingDirectory != workingDirectory {
      tab.workingDirectory = workingDirectory
    }

    guard !tab.hasCustomTitle else { return }

    let defaultTitle = Self.defaultTabTitle(index: index, workingDirectory: workingDirectory)
    if tab.title != defaultTitle {
      tab.title = defaultTitle
    }
  }

  private func syncActiveProfile(with workspace: AppSnapshot) {
    guard let activeProfileID,
      let index = profiles.firstIndex(where: { $0.id == activeProfileID })
    else { return }

    profiles[index].workspace = workspace
  }

  private static func buildWindows(
    from snapshot: AppSnapshot,
    sessionFactory: SessionFactory
  ) -> [WorkspaceWindow] {
    snapshot.windows.map { makeWindow(from: $0, sessionFactory: sessionFactory) }
  }

  private static func makeWindow(
    from snapshot: WorkspaceWindowSnapshot,
    sessionFactory: SessionFactory
  ) -> WorkspaceWindow {
    let panes = snapshot.panes.map { makePane(from: $0, sessionFactory: sessionFactory) }
    return WorkspaceWindow(snapshot: snapshot, panes: panes)
  }

  private static func makePane(
    from snapshot: WorkspacePaneSnapshot,
    sessionFactory: SessionFactory
  ) -> WorkspacePane {
    let tabs = snapshot.tabs.map { TerminalTab(snapshot: $0, session: sessionFactory($0)) }
    return WorkspacePane(snapshot: snapshot, tabs: tabs)
  }

  private static func resolvedSelectedWindowID(
    _ selectedWindowID: UUID?,
    in windows: [WorkspaceWindow]
  ) -> UUID? {
    selectedWindowID.flatMap { id in
      windows.contains(where: { $0.id == id }) ? id : nil
    } ?? windows.first?.id
  }

  private static func sanitizedAppSnapshot(_ snapshot: AppSnapshot?) -> AppSnapshot? {
    guard let snapshot else { return nil }
    let windows = snapshot.windows.compactMap(sanitizedWindowSnapshot)

    return .init(
      selectedWindowID: snapshot.selectedWindowID,
      windows: windows
    )
  }

  private static func sanitizedProfileSnapshot(_ profile: WorkspaceProfileSnapshot)
    -> WorkspaceProfileSnapshot?
  {
    guard let workspace = sanitizedAppSnapshot(profile.workspace) else { return nil }

    return .init(
      id: profile.id,
      name: sanitizedTitle(profile.name, fallback: "Profile"),
      workspace: workspace
    )
  }

  private static func sanitizedWindowSnapshot(_ snapshot: WorkspaceWindowSnapshot)
    -> WorkspaceWindowSnapshot?
  {
    let panes = snapshot.panes.compactMap(sanitizedPaneSnapshot)
    guard !panes.isEmpty else { return nil }

    return .init(
      id: snapshot.id,
      title: sanitizedTitle(snapshot.title, fallback: "Window"),
      selectedPaneID: snapshot.selectedPaneID,
      panes: panes
    )
  }

  private static func sanitizedPaneSnapshot(_ snapshot: WorkspacePaneSnapshot)
    -> WorkspacePaneSnapshot?
  {
    let tabs = snapshot.tabs.compactMap(sanitizedTabSnapshot)
    guard !tabs.isEmpty else { return nil }

    return .init(
      id: snapshot.id,
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
      workingDirectory: workingDirectory,
      hasCustomTitle: snapshot.hasCustomTitle
    )
  }

  private static func sanitizedTitle(_ title: String, fallback: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }

  private static func seedWorkspaceSnapshot() -> AppSnapshot {
    .init(
      selectedWindowID: nil,
      windows: [seedWindowSnapshot(index: 1, workingDirectory: homeDirectory)]
    )
  }

  private static func seedWindowSnapshot(index: Int, workingDirectory: String)
    -> WorkspaceWindowSnapshot
  {
    let pane = seedPaneSnapshot(index: 1, workingDirectory: workingDirectory)

    return .init(
      id: UUID(),
      title: "Window \(index)",
      selectedPaneID: pane.id,
      panes: [pane]
    )
  }

  private static func seedPaneSnapshot(index: Int, workingDirectory: String)
    -> WorkspacePaneSnapshot
  {
    let tab = TerminalTabSnapshot(
      id: UUID(),
      title: defaultTabTitle(index: index, workingDirectory: workingDirectory),
      workingDirectory: workingDirectory
    )

    return .init(
      id: UUID(),
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
