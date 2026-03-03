import AppKit
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
  let session: any TerminalSessioning
  let isFocused: Bool

  func makeNSView(context: Context) -> TerminalMountView {
    let view = TerminalMountView()
    view.mount(session.hostView)
    return view
  }

  func updateNSView(_ nsView: TerminalMountView, context: Context) {
    nsView.mount(session.hostView)

    guard isFocused else { return }

    DispatchQueue.main.async {
      session.focus()
    }
  }
}

final class TerminalMountView: NSView {
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
}
