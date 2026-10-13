import XCTest
import SwiftUI
@testable import ThirdSpace

final class DesignSystemTests: XCTestCase {
    func testCommunityAccentUsesSelectedPalette() {
        let actual = UIColor(FieldGuide.Brand.teal).resolvedColor(with: .init(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        actual.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 0x42 / 255.0, accuracy: 0.001)
        XCTAssertEqual(green, 0x8c / 255.0, accuracy: 0.001)
        XCTAssertEqual(blue, 0x6f / 255.0, accuracy: 0.001)
    }

    func testAllExactBrandPrimitives() {
        for (color, hex) in [(FieldGuide.Brand.forest, 0x488C42), (FieldGuide.Brand.moss, 0x698C46), (FieldGuide.Brand.leaf, 0x428C56), (FieldGuide.Brand.olive, 0x868C42), (FieldGuide.Brand.teal, 0x428C6F)] {
            let channels = components(color, style: .light)
            XCTAssertEqual(channels[0], Double((hex >> 16) & 255) / 255, accuracy: 0.001)
            XCTAssertEqual(channels[1], Double((hex >> 8) & 255) / 255, accuracy: 0.001)
            XCTAssertEqual(channels[2], Double(hex & 255) / 255, accuracy: 0.001)
        }
    }

    func testSemanticTextAndSelectedControlPairsInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for background in [FieldGuide.Palette.canvas, FieldGuide.Palette.surface, FieldGuide.Palette.selected] {
                for foreground in [FieldGuide.Palette.primary, FieldGuide.Palette.secondary, FieldGuide.Palette.action, FieldGuide.Palette.community, FieldGuide.Palette.warning, FieldGuide.Palette.destructive] {
                    XCTAssertGreaterThanOrEqual(contrast(foreground, background, style: style), 4.5)
                }
            }
            XCTAssertGreaterThanOrEqual(contrast(FieldGuide.Palette.onAction, FieldGuide.Palette.action, style: style), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(FieldGuide.Palette.controlBorder, FieldGuide.Palette.surface, style: style), 3)
        }
    }

    func testAdaptiveCanvasActuallyChanges() {
        XCTAssertNotEqual(components(FieldGuide.Palette.canvas, style: .light), components(FieldGuide.Palette.canvas, style: .dark))
    }

    private func components(_ color: Color, style: UIUserInterfaceStyle) -> [Double] {
        var result: [Double] = []
        UITraitCollection(userInterfaceStyle: style).performAsCurrent {
            let value = UIColor(color).resolvedColor(with: .init(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(value.getRed(&r, green: &g, blue: &b, alpha: &a))
            result = [Double(r), Double(g), Double(b)]
        }
        return result
    }
    private func contrast(_ foreground: Color, _ background: Color, style: UIUserInterfaceStyle) -> Double {
        func luminance(_ c: Color) -> Double {
            let rgb = components(c, style: style).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
        }
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
