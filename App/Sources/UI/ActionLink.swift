import SwiftUI

/// Text call to action ("› Conserva solo l'audio"): readable at any width, unlike truncated buttons.
struct ActionLink: View {
    let title: String
    var detail: String?
    var role: ButtonRole?
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chevron.right").font(.caption.bold())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).fontWeight(isPrimary ? .semibold : .regular).multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
    }
}

/// Two columns of text actions.
struct ActionGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
            alignment: .leading, spacing: 10
        ) { content }
    }
}
