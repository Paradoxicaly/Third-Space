import XCTest
import UIKit

@MainActor final class RenderedInputContrastTests: JourneyTestCase {
    func testEmptySearchPromptHasReadableRenderedContrast() {
        let app = launch(["--reset-local-data"])
        let field = app.textFields["Search owned places"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        assertReadablePrompt(field, in: app, name: "Rendered empty search prompt")
    }

    func testEmptyDraftPromptHasReadableRenderedContrast() {
        let app = launch(["--reset-local-data"])
        app.buttons["Add or contribute"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "draft-text").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        assertReadablePrompt(field, in: app, name: "Rendered empty draft prompt")
    }

    private func assertReadablePrompt(_ field: XCUIElement, in app: XCUIApplication, name: String, file: StaticString = #filePath, line: UInt = #line) {
        capture(app, name)
        guard let image = app.screenshot().image.cgImage else { XCTFail("Missing framebuffer", file: file, line: line); return }
        let window = app.windows.firstMatch.frame
        let interior = field.frame.insetBy(dx: 8, dy: 2)
        let scaleX = CGFloat(image.width) / window.width
        let scaleY = CGFloat(image.height) / window.height
        let rect = CGRect(x: interior.minX * scaleX, y: interior.minY * scaleY, width: interior.width * scaleX, height: interior.height * scaleY).integral
        guard let crop = image.cropping(to: rect), crop.width > 0, crop.height > 0 else { XCTFail("Missing input crop", file: file, line: line); return }
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            return true
        }
        guard drawn else { XCTFail("Cannot decode rendered pixels", file: file, line: line); return }
        var counts: [Int: Int] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = Int(pixels[offset]) << 16 | Int(pixels[offset + 1]) << 8 | Int(pixels[offset + 2])
            counts[rgb, default: 0] += 1
        }
        func luminance(_ rgb: Int) -> Double {
            let channels = [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255].map { Double($0) / 255 }
            return zip(channels, [0.2126, 0.7152, 0.0722]).reduce(0) { result, item in
                let linear = item.0 <= 0.04045 ? item.0 / 12.92 : pow((item.0 + 0.055) / 1.055, 2.4)
                return result + linear * item.1
            }
        }
        guard let background = counts.max(by: { $0.value < $1.value })?.key,
              let ink = counts.filter({ $0.value >= 20 }).min(by: { luminance($0.key) < luminance($1.key) })?.key else { XCTFail("Missing repeated text/background samples", file: file, line: line); return }
        // The crop excludes the field border and other controls. Repeated core
        // glyph pixels avoid treating isolated antialiasing noise as readable ink.
        let contrast = (max(luminance(background), luminance(ink)) + 0.05) / (min(luminance(background), luminance(ink)) + 0.05)
        let measurement = XCTAttachment(string: "sRGB input interior: background=\(String(format: "%06x", background)); strongest repeated ink=\(String(format: "%06x", ink)); unrounded contrast=\(contrast); crop=\(rect)")
        measurement.name = "\(name) — composited pixel measurement"
        measurement.lifetime = .keepAlways
        add(measurement)
        XCTAssertGreaterThanOrEqual(contrast, 4.5, "Empty editable input prompt must have readable actual composited contrast", file: file, line: line)
    }
}
