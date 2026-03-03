import SwiftUI

struct SidebarView: View {
  let model: WindowStore

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(model.windows) { window in
            SidebarWindowRow(
              window: window,
              isSelected: model.selectedWindow?.id == window.id,
              onSelect: { model.selectWindow(window.id) },
              onRemove: { model.removeWindow(window.id) }
            )
          }
        }
        .padding(.vertical, 4)
      }
    }
    .padding(18)
    .foregroundStyle(.white)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("better-cmux")
          .font(.system(size: 24, weight: .black, design: .rounded))

        Text("Window-first terminal draft")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.66))
      }

      Spacer()

      Button(action: { model.addWindow() }) {
        Image(systemName: "plus")
          .font(.system(size: 13, weight: .bold))
          .frame(width: 34, height: 34)
          .background(
            Circle()
              .fill(Color.white.opacity(0.11))
          )
      }
      .buttonStyle(.plain)
    }
  }
}

private struct SidebarWindowRow: View {
  let window: WorkspaceWindow
  let isSelected: Bool
  let onSelect: () -> Void
  let onRemove: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(alignment: .top, spacing: 12) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            LinearGradient(
              colors: isSelected
                ? [
                  Color(red: 0.19, green: 0.61, blue: 0.97),
                  Color(red: 0.12, green: 0.35, blue: 0.89),
                ]
                : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 40, height: 48)
          .overlay(
            Image(
              systemName: isSelected ? "rectangle.stack.fill.badge.person.crop" : "rectangle.stack"
            )
            .font(.system(size: 16, weight: .semibold))
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(window.title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.leading)
            .lineLimit(2)

          Text("\(window.tabs.count) \(window.tabs.count == 1 ? "tab" : "tabs")")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.62))
        }

        Spacer(minLength: 0)
      }
      .padding(14)
      .background(background)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(
            isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button("Delete Window", role: .destructive, action: onRemove)
    }
  }

  private var background: some ShapeStyle {
    LinearGradient(
      colors: isSelected
        ? [Color.white.opacity(0.16), Color(red: 0.07, green: 0.15, blue: 0.28)]
        : [Color.white.opacity(0.05), Color.white.opacity(0.03)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
