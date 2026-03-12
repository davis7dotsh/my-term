import AppKit
import SwiftUI

@main
struct BetterCmuxApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = WindowStore()

  var body: some Scene {
    Window("BetterCmux", id: "main") {
      RootView(model: model)
        .onAppear {
          appDelegate.activateAppIfNeeded()
        }
    }
    .defaultSize(width: 1480, height: 920)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Pane") {
          model.addWindow()
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("Split View") {
          model.splitSelectedWindow()
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled((model.selectedWindow?.panes.count ?? 0) >= 2)

        Button("New Tab") {
          model.addTab()
        }
        .keyboardShortcut("t", modifiers: .command)

        Button("Close Tab") {
          model.closeSelectedTab()
        }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(model.selectedWindow?.selectedPane == nil)
      }

      CommandMenu("Panes") {
        ForEach(Array(model.windows.prefix(9).enumerated()), id: \.element.id) { index, window in
          Button(window.title) {
            model.selectWindow(at: index)
          }
          .keyboardShortcut(Self.numberShortcut(for: index), modifiers: .command)
        }
      }

      CommandMenu("Tabs") {
        Button("Next Tab") {
          model.cycleSelectedTab()
        }
        .keyboardShortcut(.tab, modifiers: .control)
        .disabled((model.selectedWindow?.selectedPane?.tabs.count ?? 0) <= 1)

        ForEach(
          Array((model.selectedWindow?.selectedPane?.tabs ?? []).prefix(9).enumerated()),
          id: \.element.id
        ) {
          index,
          tab in
          Button(tab.title) {
            model.selectTab(at: index)
          }
          .keyboardShortcut(Self.numberShortcut(for: index), modifiers: .control)
        }
      }
    }
  }

  private static func numberShortcut(for index: Int) -> KeyEquivalent {
    KeyEquivalent(Character(String(index + 1)))
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
        window.makeKeyAndOrderFront(nil)
      }
    }
  }
}
