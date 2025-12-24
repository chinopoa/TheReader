import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    var placeholder: String = "Search manga..."
    var onSubmit: () -> Void = {}

    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.05))
            }

            if isEditing {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                        isEditing = false
                        isFocused = false
                    }
                }
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onChange(of: isFocused) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditing = newValue
            }
        }
    }
}

#Preview {
    VStack {
        SearchBar(text: .constant(""), isEditing: .constant(false))
        SearchBar(text: .constant("Solo"), isEditing: .constant(true))
    }
    .padding()
}
