import SwiftUI

struct RootView: View {
  let model: WindowStore

  var body: some View {
    HStack(spacing: 0) {
      SidebarView(model: model)
        .frame(width: 280)
        .background(sidebarBackground)

      Rectangle()
        .fill(Color.white.opacity(0.08))
        .frame(width: 1)

      ContentAreaView(model: model)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentBackground)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(contentBackground)
  }

  private var sidebarBackground: some View {
    LinearGradient(
      colors: [
        Color(red: 0.08, green: 0.10, blue: 0.16),
        Color(red: 0.05, green: 0.07, blue: 0.12),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var contentBackground: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.03, green: 0.05, blue: 0.09),
          Color(red: 0.04, green: 0.08, blue: 0.14),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(Color(red: 0.11, green: 0.45, blue: 0.82).opacity(0.16))
        .frame(width: 420, height: 420)
        .blur(radius: 50)
        .offset(x: 280, y: -240)
    }
  }
}
