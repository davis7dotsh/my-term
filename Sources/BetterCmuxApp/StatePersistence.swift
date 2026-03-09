import Foundation

@MainActor
struct StatePersistence {
  var load: () -> PersistedAppState?
  var save: (PersistedAppState) -> Void

  static let live = Self(
    load: {
      let decoder = JSONDecoder()
      guard let data = try? Data(contentsOf: storageURL) else { return nil }
      if let persistedState = try? decoder.decode(PersistedAppState.self, from: data) {
        return persistedState
      }

      guard let legacyWorkspace = try? decoder.decode(AppSnapshot.self, from: data) else {
        return nil
      }
      return .init(
        activeProfileID: nil,
        currentWorkspace: legacyWorkspace,
        profiles: []
      )
    },
    save: { state in
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

      guard let data = try? encoder.encode(state) else { return }

      let directory = storageURL.deletingLastPathComponent()
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try? data.write(to: storageURL, options: .atomic)
    }
  )

  private static var storageURL: URL {
    let baseDirectory =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    return
      baseDirectory
      .appendingPathComponent("better-cmux", isDirectory: true)
      .appendingPathComponent("state.json", isDirectory: false)
  }
}
