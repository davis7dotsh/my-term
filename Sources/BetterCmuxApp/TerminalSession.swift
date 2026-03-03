import AppKit
import Foundation
import SwiftTerm

@MainActor
enum LiveTerminalSessionFactory {
  static func makeSession(snapshot: TerminalTabSnapshot) -> any TerminalSessioning {
    TerminalSession(id: snapshot.id, workingDirectory: snapshot.workingDirectory)
  }
}

@MainActor
final class TerminalSession: TerminalSessioning {
  let id: UUID
  let hostView: NSView

  private let terminalView: LocalProcessTerminalView
  private let workingDirectory: String

  init(id: UUID, workingDirectory: String) {
    self.id = id
    self.workingDirectory = workingDirectory

    let terminal = LocalProcessTerminalView(frame: .zero)
    terminal.autoresizingMask = [.width, .height]
    terminal.font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
    terminal.nativeForegroundColor = NSColor(calibratedRed: 0.89, green: 0.92, blue: 0.98, alpha: 1)
    terminal.nativeBackgroundColor = NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.11, alpha: 1)
    terminal.caretColor = NSColor(calibratedRed: 0.42, green: 0.76, blue: 0.98, alpha: 1)
    terminal.caretTextColor = .white
    terminal.selectedTextBackgroundColor = NSColor(
      calibratedRed: 0.15, green: 0.27, blue: 0.42, alpha: 1)

    terminalView = terminal
    hostView = TerminalViewportView(terminalView: terminal)

    launchShell()
  }

  func focus() {
    hostView.window?.makeFirstResponder(terminalView)
  }

  private func launchShell() {
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var environment = ProcessInfo.processInfo.environment
    environment["TERM_PROGRAM"] = "better-cmux"
    environment["COLORTERM"] = "truecolor"

    terminalView.startProcess(
      executable: shell,
      args: ["-l"],
      environment: environment.map { "\($0.key)=\($0.value)" },
      execName: "-" + URL(fileURLWithPath: shell).lastPathComponent
    )

    terminalView.feed(text: #"cd "\#(shellEscaped(workingDirectory))" && clear"# + "\n")
  }

  private func shellEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: #"\""#)
  }
}

private final class TerminalViewportView: NSView {
  init(terminalView: NSView) {
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.11, alpha: 1).cgColor
    layer?.cornerRadius = 24
    layer?.cornerCurve = .continuous
    clipsToBounds = true

    terminalView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(terminalView)

    NSLayoutConstraint.activate([
      terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
      terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
      terminalView.topAnchor.constraint(equalTo: topAnchor),
      terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
