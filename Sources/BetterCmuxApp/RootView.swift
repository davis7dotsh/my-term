import SwiftUI

struct RootView: View {
  let model: WindowStore

  var body: some View {
    HStack(spacing: 0) {
      SidebarView(model: model)
        .frame(width: 220)
        .background(Color(red: 0.086, green: 0.106, blue: 0.133))

      Color.white.opacity(0.06)
        .frame(width: 1)

      ContentAreaView(model: model)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.051, green: 0.067, blue: 0.090))
  }
}
