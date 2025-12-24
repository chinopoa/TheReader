import SwiftUI

struct MangaCoverItem: View {
    let manga: Manga
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImageView(url: manga.coverURL)
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                if manga.unreadCount > 0 {
                    UnreadBadge(count: manga.unreadCount)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(manga.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let latestChapter = manga.latestChapter {
                    Text("Ch. \(latestChapter.formattedNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
    }
}

struct AsyncImageView: View {
    let url: String?
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let urlString = url, let imageURL = URL(string: urlString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            PlaceholderView()
                                .shimmer()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            PlaceholderView(showIcon: true)
                        @unknown default:
                            PlaceholderView()
                        }
                    }
                } else {
                    PlaceholderView(showIcon: true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

struct PlaceholderView: View {
    var showIcon: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Rectangle()
            .fill(
                colorScheme == .dark
                    ? Color(white: 0.15)
                    : Color(white: 0.9)
            )
            .overlay {
                if showIcon {
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
            }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    let manga = Manga(
        title: "Solo Leveling",
        author: "Chugong",
        status: .completed,
        coverURL: "https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg"
    )

    return MangaCoverItem(manga: manga)
        .frame(width: 120)
        .padding()
}
