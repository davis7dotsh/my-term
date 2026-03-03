import SwiftUI

struct WorkspaceView: View {
  let window: WorkspaceWindow
  let model: WindowStore

  var body: some View {
    VStack(spacing: 18) {
      header
      TabStripView(window: window, model: model)
      terminalDeck
    }
    .foregroundStyle(.white)
  }

  private var header: some View {
    HStack(alignment: .bottom, spacing: 18) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Window")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.56))
          .textCase(.uppercase)

        TextField(
          "Window name",
          text: Binding(
            get: { window.title },
            set: { model.renameWindow(window.id, to: $0) }
          )
        )
        .textFieldStyle(.plain)
        .font(.system(size: 34, weight: .black, design: .rounded))
      }

      Spacer()

      HStack(spacing: 10) {
        actionButton(title: "New Tab", systemImage: "plus") {
          model.addTab(to: window.id)
        }

        actionButton(title: "Delete Window", systemImage: "trash") {
          model.removeWindow(window.id)
        }
      }
    }
  }

  private var terminalDeck: some View {
    ZStack {
      ForEach(window.tabs) { tab in
        TerminalCard(
          tab: tab,
          isActive: window.selectedTab?.id == tab.id
        )
        .opacity(window.selectedTab?.id == tab.id ? 1 : 0)
        .allowsHitTesting(window.selectedTab?.id == tab.id)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func actionButton(title: String, systemImage: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
          Capsule(style: .continuous)
            .fill(Color.white.opacity(0.08))
        )
    }
    .buttonStyle(.plain)
  }
}

private struct TerminalCard: View {
  let tab: TerminalTab
  let isActive: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(tab.title)
            .font(.system(size: 15, weight: .bold, design: .rounded))

          Text(tab.workingDirectory)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.58))
            .lineLimit(1)
        }

        Spacer()
      }

      TerminalHostView(session: tab.session, isFocused: isActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(Color.white.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 16)
  }
}
