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

  private let terminalView: BetterTerminalView
  private let processDelegate: TerminalProcessDelegate
  private let workingDirectory: String
  private var reportedWorkingDirectory: String?
  private static let scrollbackLines = 10_000
  private static let termName = "xterm-256color"
  private static let terminalSessionEnvironmentKeysToRemove: Set<String> = [
    "COLORTERM",
    "GHOSTTY_BIN_DIR",
    "GHOSTTY_RESOURCES_DIR",
    "ITERM_PROFILE",
    "ITERM_SESSION_ID",
    "KITTY_LISTEN_ON",
    "KITTY_WINDOW_ID",
    "STY",
    "TERM",
    "TERM_PROGRAM",
    "TERM_PROGRAM_VERSION",
    "TERM_SESSION_ID",
    "TERMINAL_EMULATOR",
    "TMUX",
    "TMUX_PANE",
    "VTE_VERSION",
    "WEZTERM_EXECUTABLE",
    "WEZTERM_PANE",
    "WINDOW",
    "WINDOWID",
  ]

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

    let terminal = BetterTerminalView(frame: .zero)
    let processDelegate = TerminalProcessDelegate()
    terminal.autoresizingMask = [.width, .height]
    terminal.disableFullRedrawOnAnyChanges = false
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

    processDelegate.onProcessTerminated = { [weak self] in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.launchShell()
      }
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
    let environment = Self.shellEnvironment()
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

  private static func shellEnvironment(base: [String: String] = ProcessInfo.processInfo.environment)
    -> [String: String]
  {
    var environment = base
    terminalSessionEnvironmentKeysToRemove.forEach { environment.removeValue(forKey: $0) }

    environment["TERM"] = termName
    environment["TERM_PROGRAM"] = "better-cmux"
    environment["COLORTERM"] = "truecolor"

    if environment["LANG"] == nil, environment["LC_ALL"] == nil, environment["LC_CTYPE"] == nil {
      environment["LANG"] = "en_US.UTF-8"
    }

    return environment
  }
}

private final class TerminalViewportView: NSView {
  private static let hPad: CGFloat = 12
  private static let vPad: CGFloat = 8
  private static let trackpadPointsPerLine: CGFloat = 12
  private let terminalView: BetterTerminalView
  private var scrollMonitor: Any?
  private var pendingScrollDelta: CGFloat = 0

  init(terminalView: BetterTerminalView, backgroundColor: NSColor) {
    self.terminalView = terminalView
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = backgroundColor.cgColor
    if #available(macOS 14, *) {
      clipsToBounds = true
    }

    let tv = terminalView as NSView
    tv.translatesAutoresizingMaskIntoConstraints = false
    addSubview(tv)

    NSLayoutConstraint.activate([
      tv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.hPad),
      tv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.hPad),
      tv.topAnchor.constraint(equalTo: topAnchor, constant: Self.vPad),
      tv.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vPad),
    ])

    terminalView.onViewportChange = { [weak self] in
      self?.updateScrollerVisibility()
    }
  }

  @MainActor
  deinit {
    removeScrollMonitor()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil else {
      removeScrollMonitor()
      return
    }
    configureContainingScrollView()
    configureTerminalScroller()
    installScrollMonitor()
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    super.viewWillMove(toWindow: newWindow)
    guard newWindow == nil else { return }
    removeScrollMonitor()
  }

  private func configureContainingScrollView() {
    DispatchQueue.main.async { [weak self] in
      guard let scrollView = self?.enclosingScrollView else { return }
      scrollView.hasVerticalScroller = false
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true
      scrollView.drawsBackground = false
      scrollView.verticalScrollElasticity = .none
      scrollView.horizontalScrollElasticity = .none
    }
  }

  private func configureTerminalScroller() {
    DispatchQueue.main.async { [weak self] in
      guard let self, let scroller = self.terminalScroller else { return }
      scroller.scrollerStyle = .legacy
      scroller.knobStyle = .light
      scroller.controlSize = .small
      self.updateScrollerVisibility()
    }
  }

  private func updateScrollerVisibility() {
    DispatchQueue.main.async { [weak self] in
      guard let self, let scroller = self.terminalScroller else { return }
      scroller.isHidden = !self.terminalView.canScroll
      scroller.alphaValue = self.terminalView.canScroll ? 0.9 : 0
    }
  }

  private var terminalScroller: NSScroller? {
    walkSubviews(terminalView).compactMap { $0 as? NSScroller }.first
  }

  private func walkSubviews(_ root: NSView) -> [NSView] {
    root.subviews.flatMap { [$0] + walkSubviews($0) }
  }

  private func installScrollMonitor() {
    guard scrollMonitor == nil else { return }
    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      guard let self else { return event }
      guard event.window === self.window else { return event }

      let point = self.convert(event.locationInWindow, from: nil)
      guard self.bounds.contains(point) else { return event }
      guard self.shouldInterceptScroll(event) else { return event }

      self.handleMouseReportingScroll(event)
      return nil
    }
  }

  private func removeScrollMonitor() {
    guard let scrollMonitor else { return }
    NSEvent.removeMonitor(scrollMonitor)
    self.scrollMonitor = nil
  }

  private func shouldInterceptScroll(_ event: NSEvent) -> Bool {
    event.scrollingDeltaY != 0
      && !terminalView.canScroll
      && terminalView.allowMouseReporting
      && terminalView.terminal.mouseMode != .off
  }

  private func handleMouseReportingScroll(_ event: NSEvent) {
    resetPendingScrollDeltaIfNeeded(for: event)

    let delta = event.scrollingDeltaY
    let lines = resolvedScrollLines(for: event)
    guard lines > 0 else { return }

    sendMouseWheelEvent(lines: lines, delta: delta, event: event)
    resetPendingScrollDeltaIfEnded(for: event)
  }

  private func resetPendingScrollDeltaIfNeeded(for event: NSEvent) {
    guard event.phase == .began || event.momentumPhase == .began else { return }
    pendingScrollDelta = 0
  }

  private func resetPendingScrollDeltaIfEnded(for event: NSEvent) {
    guard
      event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended
        || event.momentumPhase == .cancelled
    else { return }
    pendingScrollDelta = 0
  }

  private func resolvedScrollLines(for event: NSEvent) -> Int {
    if event.hasPreciseScrollingDeltas {
      pendingScrollDelta += event.scrollingDeltaY
      let lines = Int(abs(pendingScrollDelta) / Self.trackpadPointsPerLine)
      guard lines > 0 else { return 0 }

      let direction: CGFloat = pendingScrollDelta > 0 ? 1 : -1
      pendingScrollDelta -= CGFloat(lines) * Self.trackpadPointsPerLine * direction
      return lines
    }

    pendingScrollDelta = 0
    return max(Int(abs(event.scrollingDeltaY.rounded(.towardZero))), 1)
  }

  private func sendMouseWheelEvent(lines: Int, delta: CGFloat, event: NSEvent) {
    let (cols, rows) = terminalView.terminal.getDims()
    guard cols > 0, rows > 0 else { return }

    let point = terminalView.convert(event.locationInWindow, from: nil)
    let scrollerWidth = terminalScroller?.frame.width ?? 0
    let contentWidth = max(terminalView.bounds.width - scrollerWidth, 1)
    let cellWidth = contentWidth / CGFloat(cols)
    let cellHeight = max(terminalView.bounds.height / CGFloat(rows), 1)

    let col = min(max(Int(point.x / cellWidth), 0), cols - 1)
    let row = min(max(Int((terminalView.bounds.height - point.y) / cellHeight), 0), rows - 1)
    let pixelX = min(max(Int(point.x.rounded(.towardZero)), 0), Int(terminalView.bounds.width))
    let pixelY = min(
      max(Int((terminalView.bounds.height - point.y).rounded(.towardZero)), 0),
      Int(terminalView.bounds.height)
    )
    let baseButton = delta > 0 ? 64 : 65
    let buttonFlags = baseButton + mouseModifierFlags(for: event)

    for _ in 0..<lines {
      terminalView.terminal.sendEvent(
        buttonFlags: buttonFlags,
        x: col,
        y: row,
        pixelX: pixelX,
        pixelY: pixelY
      )
    }
  }

  private func mouseModifierFlags(for event: NSEvent) -> Int {
    guard terminalView.terminal.mouseMode.sendsModifiers() else { return 0 }

    var flags = 0
    if event.modifierFlags.contains(.shift) {
      flags += 4
    }
    if event.modifierFlags.contains(.option) {
      flags += 8
    }
    if event.modifierFlags.contains(.control) {
      flags += 16
    }
    return flags
  }
}

private final class BetterTerminalView: LocalProcessTerminalView {
  var onViewportChange: (() -> Void)?

  override func bufferActivated(source: Terminal) {
    super.bufferActivated(source: source)
    onViewportChange?()
  }

  override func scrolled(source: TerminalView, position: Double) {
    super.scrolled(source: source, position: position)
    onViewportChange?()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    onViewportChange?()
  }
}

private final class TerminalProcessDelegate: NSObject, LocalProcessTerminalViewDelegate {
  var onCurrentDirectory: ((String?) -> Void)?
  var onProcessTerminated: (() -> Void)?

  func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

  func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    onCurrentDirectory?(directory)
  }

  func processTerminated(source: TerminalView, exitCode: Int32?) {
    onProcessTerminated?()
  }
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
