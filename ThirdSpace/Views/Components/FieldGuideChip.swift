import SwiftUI

/// Short control chip. Selection is shown by check, fill and 2 pt outline, never tint alone.
struct FieldGuideChip: View {
    let title: String
    let systemImage: String
    var isSelected = false
    var showsMenuIndicator = false

    var body: some View {
        HStack(spacing: FieldGuide.Spacing.xs) {
            Image(systemName: isSelected ? "checkmark" : systemImage)
                .accessibilityHidden(true)
            Text(title)
            if showsMenuIndicator {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? FieldGuide.Palette.action : FieldGuide.Palette.primary)
        .padding(.horizontal, FieldGuide.Spacing.sm + 2)
        .padding(.vertical, FieldGuide.Spacing.xs)
        .frame(minHeight: 44)
        .background(isSelected ? FieldGuide.Palette.selected : FieldGuide.Palette.surface, in: shape)
        .overlay(shape.strokeBorder(isSelected ? FieldGuide.Palette.action : FieldGuide.Palette.controlBorder, lineWidth: isSelected ? 2 : 1))
        .contentShape(shape)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
}

/// Small honesty badge for synthetic content; quieter than a full-width banner.
struct SyntheticBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "flask")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FieldGuide.Palette.warning)
            .padding(.horizontal, FieldGuide.Spacing.sm)
            .padding(.vertical, FieldGuide.Spacing.xxs + 2)
            .background(FieldGuide.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(FieldGuide.Palette.warning, lineWidth: 1))
    }
}
