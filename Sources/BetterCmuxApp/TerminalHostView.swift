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
    view.mount(session.hostView)
    return view
  }

  func updateNSView(_ nsView: TerminalMountView, context: Context) {
    nsView.onActivate = context.coordinator.activate
    nsView.mount(session.hostView)

    guard isFocused else { return }

    DispatchQueue.main.async {
      session.focus()
    }
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

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
    addGestureRecognizer(clickGesture)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func mount(_ hostedView: NSView) {
    guard hostedView.superview !== self else { return }

    hostedView.removeFromSuperview()
    hostedView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostedView)

    NSLayoutConstraint.activate([
      hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostedView.topAnchor.constraint(equalTo: topAnchor),
      hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @objc
  private func handleClick() {
    onActivate?()
  }
}
