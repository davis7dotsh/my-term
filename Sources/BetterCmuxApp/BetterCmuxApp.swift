import AppKit
import SwiftUI

@main
struct BetterCmuxApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = WindowStore()

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
        .onAppear {
          appDelegate.activateAppIfNeeded()
        }
    }
    .defaultSize(width: 1480, height: 920)
    .commands {
      CommandGroup(after: .newItem) {
        Button("New Window") {
          model.addWindow()
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("New Tab") {
          model.addTab()
        }
        .keyboardShortcut("t", modifiers: .command)
      }
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    activateAppIfNeeded()
  }

  func activateAppIfNeeded() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      for window in NSApp.windows {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
      }
    }
  }
}
