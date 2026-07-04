import SwiftUI

struct EmojiPicker: View {
    @Binding var selectedEmojis: [String]
    @Environment(\.dismiss) private var dismiss

    private let commonEmojis = [
        "😀", "😂", "🤣", "😍", "😎", "🥰", "😘", "😜",
        "🔥", "💯", "✅", "❤️", "👍", "🙌", "🤝", "💪",
        "😢", "😡", "🤯", "🥳", "😱", "🤔", "🙄", "😴",
        "🎉", "🌟", "💩", "👻", "🤖", "🐱", "🐶", "🦄",
        "🍕", "☕", "⚽", "🎮", "💸", "📱", "🚀", "🌈"
    ]

    var body: some View {
        NavigationStack {
            VStack {
                if !selectedEmojis.isEmpty {
                    HStack {
                        Text("Selecionados:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(selectedEmojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title2)
                                .onTapGesture {
                                    selectedEmojis.removeAll { $0 == emoji }
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button {
                            if selectedEmojis.contains(emoji) {
                                selectedEmojis.removeAll { $0 == emoji }
                            } else {
                                selectedEmojis.append(emoji)
                            }
                        } label: {
                            Text(emoji)
                                .font(.title)
                                .opacity(selectedEmojis.contains(emoji) ? 0.4 : 1.0)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Emojis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
