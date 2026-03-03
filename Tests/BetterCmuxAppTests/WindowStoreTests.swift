import AppKit
import Testing

@testable import BetterCmuxApp

@MainActor
struct WindowStoreTests {
  @Test
  func restoresSnapshotAndSelection() throws {
    let firstWindowID = UUID()
    let secondWindowID = UUID()
    let selectedTabID = UUID()
    let snapshot = AppSnapshot(
      selectedWindowID: secondWindowID,
      windows: [
        .init(
          id: firstWindowID,
          title: "Design",
          selectedTabID: UUID(),
          tabs: [.init(id: UUID(), title: "ui", workingDirectory: "/tmp/design")]
        ),
        .init(
          id: secondWindowID,
          title: "Infra",
          selectedTabID: selectedTabID,
          tabs: [
            .init(id: selectedTabID, title: "deploy", workingDirectory: "/tmp/infra")
          ]
        ),
      ]
    )

    let store = WindowStore(
      persistence: .init(load: { snapshot }, save: { _ in }),
      sessionFactory: StubSessionFactory.makeSession
    )

    #expect(store.windows.count == 2)
    #expect(store.selectedWindow?.id == secondWindowID)
    #expect(store.selectedWindow?.selectedTab?.id == selectedTabID)
  }

  @Test
  func mutatingWindowStatePersistsChanges() throws {
    var savedSnapshots: [AppSnapshot] = []
    let store = WindowStore(
      persistence: .init(load: { nil }, save: { savedSnapshots.append($0) }),
      sessionFactory: StubSessionFactory.makeSession
    )

    let originalWindowID = try #require(store.selectedWindow?.id)

    store.renameWindow(originalWindowID, to: "API")
    store.addTab(to: originalWindowID)
    store.addWindow()

    let persisted = try #require(savedSnapshots.last)
    #expect(persisted.windows.count == 2)
    #expect(persisted.windows.first?.title == "API")
    #expect(persisted.windows.first?.tabs.count == 2)
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

  init(id: UUID) {
    self.id = id
  }

  func focus() {}
}
