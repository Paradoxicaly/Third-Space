import SwiftUI
import UIKit

// Named primitives are identity accents only; semantic tokens carry readable labels.
enum FieldGuide {
    enum Brand {
        static let forest = Color(hex: 0x488C42)
        static let moss = Color(hex: 0x698C46)
        static let leaf = Color(hex: 0x428C56)
        static let olive = Color(hex: 0x868C42)
        static let teal = Color(hex: 0x428C6F)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let base: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Palette {
        static let canvas = adaptive(light: 0xF7F5EC, dark: 0x151C17)
        static let surface = adaptive(light: 0xFFFDF7, dark: 0x202B23)
        static let primary = adaptive(light: 0x20291F, dark: 0xF2F3E9)
        static let secondary = adaptive(light: 0x576252, dark: 0xB5C0AF)
        static let action = adaptive(light: 0x285A2D, dark: 0xA8D49C)
        static let onAction = adaptive(light: 0xFFFFFF, dark: 0x151C17)
        static let community = adaptive(light: 0x235C48, dark: 0x98CEB4)
        static let warning = adaptive(light: 0x705D16, dark: 0xE4CE83)
        static let destructive = adaptive(light: 0xA63232, dark: 0xFFB4AB)
        static let controlBorder = Color(uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return UIColor(rgb: traits.userInterfaceStyle == .dark ? 0xF2F3E9 : 0x20291F)
            }
            return UIColor(rgb: traits.userInterfaceStyle == .dark ? 0x7E8976 : 0x798572)
        })
        static let divider = adaptive(light: 0xD7DDCF, dark: 0x566457)
        static let selected = adaptive(light: 0xE6EDDE, dark: 0x294434)

        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255,
                  green: CGFloat((rgb >> 8) & 0xff) / 255,
                  blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }

}

struct FieldGuideActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(FieldGuide.Palette.onAction)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, FieldGuide.Spacing.base)
            .padding(.vertical, FieldGuide.Spacing.md)
            .background(FieldGuide.Palette.action, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.primary, lineWidth: configuration.isPressed ? 2 : 0))
    }
}
