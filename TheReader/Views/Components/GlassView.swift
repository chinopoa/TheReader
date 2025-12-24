import SwiftUI

struct GlassView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial
    var intensity: CGFloat = 1.0

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        view.alpha = intensity
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.alpha = intensity
    }
}

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var cornerRadius: CGFloat = 20
    var opacity: CGFloat = 1.0
    var showBorder: Bool = true

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.15)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    GlassView(
                        style: colorScheme == .dark
                            ? .systemUltraThinMaterialDark
                            : .systemUltraThinMaterialLight,
                        intensity: opacity
                    )

                    (colorScheme == .dark
                        ? Color.white.opacity(0.05)
                        : Color.white.opacity(0.3))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: 0.5)
                }
            }
            .shadow(color: shadowColor, radius: 20, x: 0, y: 10)
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 20,
        opacity: CGFloat = 1.0,
        showBorder: Bool = true
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            opacity: opacity,
            showBorder: showBorder
        ))
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .liquidGlass()
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Liquid Glass Effect")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding()
                .liquidGlass()

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a premium frosted glass card with adaptive theming.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(width: 300)
        }
    }
}
