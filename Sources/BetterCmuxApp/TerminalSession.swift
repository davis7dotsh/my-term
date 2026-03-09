import AppKit
import Darwin
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
  private let processDelegate: TerminalProcessDelegate
  private let workingDirectory: String
  private var reportedWorkingDirectory: String?
  private static let scrollbackLines = 10_000

  private static let bgColor = NSColor(srgbRed: 0.051, green: 0.067, blue: 0.090, alpha: 1)
  private static let fgColor = NSColor(srgbRed: 0.902, green: 0.929, blue: 0.953, alpha: 1)
  private static let selectionColor = NSColor(srgbRed: 0.149, green: 0.310, blue: 0.471, alpha: 1)

  private static func c(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> Color {
    Color(red: r &* 257, green: g &* 257, blue: b &* 257)
  }

  private static let ghDarkPalette: [Color] = [
    c(0x48, 0x4f, 0x58), c(0xff, 0x7b, 0x72), c(0x3f, 0xb9, 0x50), c(0xd2, 0x99, 0x22),
    c(0x58, 0xa6, 0xff), c(0xbc, 0x8c, 0xff), c(0x39, 0xc5, 0xcf), c(0xb1, 0xba, 0xc4),
    c(0x6e, 0x76, 0x81), c(0xff, 0xa1, 0x98), c(0x56, 0xd3, 0x64), c(0xe3, 0xb3, 0x41),
    c(0x79, 0xc0, 0xff), c(0xd2, 0xa8, 0xff), c(0x56, 0xd4, 0xdd), c(0xf0, 0xf6, 0xfc),
  ]

  init(id: UUID, workingDirectory: String) {
    self.id = id
    self.workingDirectory = workingDirectory

    let font =
      NSFont(name: "Berkeley Mono", size: 15)
      ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)

    let terminal = LocalProcessTerminalView(frame: .zero)
    let processDelegate = TerminalProcessDelegate()
    terminal.autoresizingMask = [.width, .height]
    terminal.font = font
    terminal.nativeForegroundColor = Self.fgColor
    terminal.nativeBackgroundColor = Self.bgColor
    terminal.caretColor = Self.fgColor
    terminal.caretTextColor = Self.bgColor
    terminal.selectedTextBackgroundColor = Self.selectionColor
    terminal.installColors(Self.ghDarkPalette)
    terminal.processDelegate = processDelegate

    terminalView = terminal
    self.processDelegate = processDelegate
    hostView = TerminalViewportView(terminalView: terminal, backgroundColor: Self.bgColor)

    processDelegate.onCurrentDirectory = { [weak self] directory in
      self?.reportedWorkingDirectory = Self.sanitizedWorkingDirectory(directory)
    }

    launchShell()
  }

  func focus() {
    hostView.window?.makeFirstResponder(terminalView)
  }

  var currentWorkingDirectory: String? {
    reportedWorkingDirectory ?? Self.currentWorkingDirectory(for: terminalView.process.shellPid)
  }

  private func launchShell() {
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var environment = ProcessInfo.processInfo.environment
    environment["TERM_PROGRAM"] = "better-cmux"
    environment["COLORTERM"] = "truecolor"
    terminalView.terminal.changeHistorySize(Self.scrollbackLines)

    terminalView.startProcess(
      executable: shell,
      args: ["-i"],
      environment: environment.map { "\($0.key)=\($0.value)" },
      execName: URL(fileURLWithPath: shell).lastPathComponent,
      currentDirectory: workingDirectory
    )
  }

  private static func currentWorkingDirectory(for pid: pid_t) -> String? {
    guard pid > 0 else { return nil }

    var info = proc_vnodepathinfo()
    let bufferSize = Int32(MemoryLayout.size(ofValue: info))
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: UInt8.self, capacity: Int(bufferSize)) {
        proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, $0, bufferSize)
      }
    }

    guard result == bufferSize else { return nil }

    return withUnsafePointer(to: info.pvi_cdir.vip_path) {
      $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
        String(cString: $0)
      }
    }
  }

  private static func sanitizedWorkingDirectory(_ directory: String?) -> String? {
    directory?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty
  }
}

private final class TerminalViewportView: NSView {
  private static let hPad: CGFloat = 12
  private static let vPad: CGFloat = 8

  init(terminalView: LocalProcessTerminalView, backgroundColor: NSColor) {
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = backgroundColor.cgColor

    let tv = terminalView as NSView
    tv.translatesAutoresizingMaskIntoConstraints = false
    addSubview(tv)

    NSLayoutConstraint.activate([
      tv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.hPad),
      tv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.hPad),
      tv.topAnchor.constraint(equalTo: topAnchor, constant: Self.vPad),
      tv.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vPad),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil else { return }
    configureScrollers()
  }

  private func configureScrollers() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
      guard let self else { return }
      self.walkSubviews(self) { view in
        guard let scroller = view as? NSScroller else { return }
        scroller.scrollerStyle = .overlay
        scroller.knobStyle = .light
      }
    }
  }

  private func walkSubviews(_ root: NSView, _ visitor: (NSView) -> Void) {
    for sub in root.subviews {
      visitor(sub)
      walkSubviews(sub, visitor)
    }
  }
}

private final class TerminalProcessDelegate: NSObject, LocalProcessTerminalViewDelegate {
  var onCurrentDirectory: ((String?) -> Void)?

  func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

  func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    onCurrentDirectory?(directory)
  }

  func processTerminated(source: TerminalView, exitCode: Int32?) {}
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
