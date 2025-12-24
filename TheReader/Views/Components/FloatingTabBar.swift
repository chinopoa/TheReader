import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 28)
        .padding(.horizontal, 24)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var foregroundColor: Color {
        if isSelected {
            return .blue
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.5)
            : Color.black.opacity(0.4)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .matchedGeometryEffect(id: "tabBackground", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(foregroundColor)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(width: 48, height: 48)

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(.library))
                .padding(.bottom, 20)
        }
    }
}
