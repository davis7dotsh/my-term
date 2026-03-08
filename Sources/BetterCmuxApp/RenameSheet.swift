import SwiftUI

struct RenameSheet: View {
  let title: String
  let prompt: String
  let value: String
  let onCancel: () -> Void
  let onSave: (String) -> Void

  @State private var draft: String

  init(
    title: String,
    prompt: String,
    value: String,
    onCancel: @escaping () -> Void,
    onSave: @escaping (String) -> Void
  ) {
    self.title = title
    self.prompt = prompt
    self.value = value
    self.onCancel = onCancel
    self.onSave = onSave
    _draft = State(initialValue: value)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .font(.title3.weight(.semibold))

      TextField(prompt, text: $draft)
        .textFieldStyle(.roundedBorder)
        .onSubmit(save)

      HStack {
        Spacer()

        Button("Cancel", action: onCancel)
        Button("Save", action: save)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 320)
  }

  private func save() {
    onSave(draft)
  }
}
