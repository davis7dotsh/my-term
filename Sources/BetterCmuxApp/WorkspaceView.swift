import SwiftUI

struct WorkspaceView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)

      TabStripView(window: window, model: model)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)

      terminalDeck
    }
    .foregroundStyle(.white)
  }

  private var header: some View {
    HStack(alignment: .center) {
      TextField(
        "Window name",
        text: Binding(
          get: { window.title },
          set: { model.renameWindow(window.id, to: $0) }
        )
      )
      .textFieldStyle(.plain)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white.opacity(0.88))

      Spacer()

      compactButton(systemImage: "trash") {
        model.removeWindow(window.id)
      }
    }
  }

  private var terminalDeck: some View {
    ZStack {
      ForEach(window.tabs) { tab in
        TerminalHostView(session: tab.session, isFocused: window.selectedTab?.id == tab.id)
          .opacity(window.selectedTab?.id == tab.id ? 1 : 0)
          .allowsHitTesting(window.selectedTab?.id == tab.id)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
    )
    .padding(.horizontal, 14)
    .padding(.bottom, 14)
  }

  private func compactButton(systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.4))
        .frame(width: 28, height: 28)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.white.opacity(0.06))
        )
    }
    .buttonStyle(.plain)
  }
}
