import AppKit
import Testing

@testable import BetterCmuxApp

@MainActor
struct WindowStoreTests {
  @Test
  func restoresWorkspaceSelectionAndProfiles() throws {
    let selectedTabID = UUID()
    let paneID = UUID()
    let windowID = UUID()
    let profileID = UUID()
    let workspace = AppSnapshot(
      selectedWindowID: windowID,
      windows: [
        .init(
          id: windowID,
          title: "Design",
          selectedPaneID: paneID,
          panes: [
            .init(
              id: paneID,
              selectedTabID: selectedTabID,
              tabs: [.init(id: selectedTabID, title: "ui", workingDirectory: "/tmp/design")]
            )
          ]
        )
      ]
    )
    let persistedState = PersistedAppState(
      activeProfileID: profileID,
      currentWorkspace: workspace,
      profiles: [
        .init(
          id: profileID,
          name: "Design",
          workspace: workspace
        )
      ]
    )

    let store = WindowStore(
      persistence: .init(load: { persistedState }, save: { _ in }),
      sessionFactory: StubSessionFactory.makeSession,
      autosaveInterval: 60
    )

    #expect(store.windows.count == 1)
    #expect(store.selectedWindow?.selectedPane?.id == paneID)
    #expect(store.selectedWindow?.selectedTab?.id == selectedTabID)
    #expect(store.activeProfileID == profileID)
    #expect(store.activeProfile?.name == "Design")
  }

  @Test
  func splitWindowCreatesSecondPane() throws {
    let sessionFactory = MutableStubSessionFactory()
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { _ in }),
      sessionFactory: sessionFactory.makeSession,
      metadataRefreshInterval: 60,
      autosaveInterval: 60
    )

    let originalPaneID = try #require(store.selectedWindow?.selectedPane?.id)
    let originalTabID = try #require(store.selectedWindow?.selectedPane?.selectedTab?.id)

    store.splitSelectedWindow()

    let window = try #require(store.selectedWindow)
    #expect(window.panes.count == 2)
    #expect(window.selectedPane?.id != originalPaneID)
    #expect(window.panes.first(where: { $0.id == originalPaneID })?.tabs.first?.id == originalTabID)
    #expect(window.selectedPane?.tabs.count == 1)
  }

  @Test
  func closingLastTabInSplitPaneReturnsWindowToSinglePane() throws {
    let sessionFactory = MutableStubSessionFactory()
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { _ in }),
      sessionFactory: sessionFactory.makeSession,
      metadataRefreshInterval: 60,
      autosaveInterval: 60
    )

    let originalPaneID = try #require(store.selectedWindow?.selectedPane?.id)
    store.splitSelectedWindow()
    let splitPaneID = try #require(store.selectedWindow?.selectedPane?.id)

    let splitTabID = try #require(store.selectedWindow?.selectedPane?.selectedTab?.id)
    let windowID = try #require(store.selectedWindow?.id)
    store.closeTab(windowID: windowID, paneID: splitPaneID, tabID: splitTabID)

    let window = try #require(store.selectedWindow)
    #expect(window.panes.count == 1)
    #expect(window.selectedPane?.id == originalPaneID)
    #expect(window.panes.contains(where: { $0.id == splitPaneID }) == false)
  }

  @Test
  func closingLastTabInSinglePaneRemovesWindow() throws {
    let sessionFactory = MutableStubSessionFactory()
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { _ in }),
      sessionFactory: sessionFactory.makeSession,
      metadataRefreshInterval: 60,
      autosaveInterval: 60
    )

    let windowID = try #require(store.selectedWindow?.id)
    let paneID = try #require(store.selectedWindow?.selectedPane?.id)
    let tabID = try #require(store.selectedWindow?.selectedTab?.id)

    store.closeTab(windowID: windowID, paneID: paneID, tabID: tabID)

    #expect(store.windows.isEmpty)
    #expect(store.selectedWindow == nil)
  }

  @Test
  func savingAndActivatingProfilesRestoresWorkspace() throws {
    let alternatePaneID = UUID()
    let alternateWorkspace = AppSnapshot(
      selectedWindowID: UUID(),
      windows: [
        .init(
          id: UUID(),
          title: "Infra",
          selectedPaneID: alternatePaneID,
          panes: [
            .init(
              id: alternatePaneID,
              selectedTabID: UUID(),
              tabs: [.init(id: UUID(), title: "deploy", workingDirectory: "/tmp/infra")]
            )
          ]
        )
      ]
    )
    var savedStates: [PersistedAppState] = []
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { savedStates.append($0) }),
      sessionFactory: StubSessionFactory.makeSession,
      autosaveInterval: 60
    )

    let originalWindowID = try #require(store.selectedWindow?.id)
    store.renameWindow(originalWindowID, to: "API")
    store.saveProfile(named: "API")

    let savedProfileID = try #require(store.activeProfileID)
    store.profiles.append(
      .init(
        id: UUID(),
        name: "Infra",
        workspace: alternateWorkspace
      )
    )
    let alternateProfileID = try #require(store.profiles.last?.id)

    store.activateProfile(alternateProfileID)

    let persisted = try #require(savedStates.last)
    #expect(persisted.activeProfileID == alternateProfileID)
    #expect(store.selectedWindow?.title == "Infra")
    #expect(store.selectedWindow?.selectedTab?.workingDirectory == "/tmp/infra")
    #expect(persisted.profiles.contains(where: { $0.id == savedProfileID && $0.name == "API" }))
  }

  @Test
  func activeProfilesTrackLiveDirectoryChanges() throws {
    let sessionFactory = MutableStubSessionFactory()
    var savedStates: [PersistedAppState] = []
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { savedStates.append($0) }),
      sessionFactory: sessionFactory.makeSession,
      metadataRefreshInterval: 60,
      autosaveInterval: 60
    )

    let tabID = try #require(store.selectedWindow?.selectedTab?.id)
    store.saveProfile(named: "Ops")

    let session = try #require(sessionFactory.session(for: tabID))
    session.currentWorkingDirectory = "/tmp/ops"
    store.refreshWorkspaceState()

    let persisted = try #require(savedStates.last)
    let workingDirectory = try #require(
      persisted.currentWorkspace.windows.first?.panes.first?.tabs.first?.workingDirectory
    )
    let tabTitle = try #require(
      persisted.currentWorkspace.windows.first?.panes.first?.tabs.first?.title
    )
    let profileDirectory = try #require(
      persisted.profiles.first?.workspace.windows.first?.panes.first?.tabs.first?.workingDirectory
    )

    #expect(workingDirectory == "/tmp/ops")
    #expect(tabTitle == "ops")
    #expect(profileDirectory == "/tmp/ops")
  }

  @Test
  func manualTabNamesDoNotGetOverwrittenByDirectoryChanges() throws {
    let sessionFactory = MutableStubSessionFactory()
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { _ in }),
      sessionFactory: sessionFactory.makeSession,
      metadataRefreshInterval: 60,
      autosaveInterval: 60
    )

    let windowID = try #require(store.selectedWindow?.id)
    let paneID = try #require(store.selectedWindow?.selectedPane?.id)
    let tabID = try #require(store.selectedWindow?.selectedTab?.id)
    store.renameTab(windowID: windowID, paneID: paneID, tabID: tabID, to: "server")

    let session = try #require(sessionFactory.session(for: tabID))
    session.currentWorkingDirectory = "/tmp/ops"
    store.refreshWorkspaceState()

    #expect(store.selectedWindow?.selectedTab?.title == "server")
    #expect(store.selectedWindow?.selectedTab?.workingDirectory == "/tmp/ops")
    #expect(store.selectedWindow?.selectedTab?.hasCustomTitle == true)
  }
}

@MainActor
private enum StubSessionFactory {
  static func makeSession(snapshot: TerminalTabSnapshot) -> any TerminalSessioning {
    StubSession(id: snapshot.id)
  }
}

@MainActor
private final class StubSession: TerminalSessioning {
  let id: UUID
  let hostView = NSView()
  let currentWorkingDirectory: String? = nil

  init(id: UUID) {
    self.id = id
  }

  func focus() {}
}

@MainActor
private final class MutableStubSessionFactory {
  private var sessions: [UUID: MutableStubSession] = [:]

  func makeSession(snapshot: TerminalTabSnapshot) -> any TerminalSessioning {
    let session = MutableStubSession(
      id: snapshot.id,
      currentWorkingDirectory: snapshot.workingDirectory
    )
    sessions[snapshot.id] = session
    return session
  }

  func session(for id: UUID) -> MutableStubSession? {
    sessions[id]
  }
}

@MainActor
private final class MutableStubSession: TerminalSessioning {
  let id: UUID
  let hostView = NSView()
  var currentWorkingDirectory: String?

  init(id: UUID, currentWorkingDirectory: String?) {
    self.id = id
    self.currentWorkingDirectory = currentWorkingDirectory
  }

  func focus() {}
}
