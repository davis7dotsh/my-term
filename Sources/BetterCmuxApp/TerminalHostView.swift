import AppKit
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
  let session: any TerminalSessioning
  let isFocused: Bool
  let onActivate: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onActivate: onActivate)
  }

  func makeNSView(context: Context) -> TerminalMountView {
    let view = TerminalMountView()
    view.onActivate = context.coordinator.activate
    let remounted = view.mount(session.hostView, sessionID: session.id)
    view.updateFocus(isFocused: isFocused, session: session, remounted: remounted)
    return view
  }

  func updateNSView(_ nsView: TerminalMountView, context: Context) {
    nsView.onActivate = context.coordinator.activate
    let remounted = nsView.mount(session.hostView, sessionID: session.id)
    nsView.updateFocus(isFocused: isFocused, session: session, remounted: remounted)
  }

  final class Coordinator {
    private let onActivate: () -> Void

    init(onActivate: @escaping () -> Void) {
      self.onActivate = onActivate
    }

    @objc func activate() {
      onActivate()
    }
  }
}

final class TerminalMountView: NSView {
  var onActivate: (() -> Void)?
  private var mountedSessionID: UUID?
  private var wasFocused = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
    addGestureRecognizer(clickGesture)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func mount(_ hostedView: NSView, sessionID: UUID) -> Bool {
    guard hostedView.superview !== self || mountedSessionID != sessionID else { return false }

    hostedView.removeFromSuperview()
    hostedView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostedView)
    mountedSessionID = sessionID

    NSLayoutConstraint.activate([
      hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostedView.topAnchor.constraint(equalTo: topAnchor),
      hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    return true
  }

  func updateFocus(isFocused: Bool, session: any TerminalSessioning, remounted: Bool) {
    defer { wasFocused = isFocused }

    guard isFocused else { return }
    guard remounted || !wasFocused else { return }

    DispatchQueue.main.async {
      session.focus()
    }
  }

  @objc
  private func handleClick() {
    onActivate?()
  }
}
