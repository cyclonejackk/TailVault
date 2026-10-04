//
//  PDFExporter.swift
//  TailVault
//
//  Renders report text (vet report, sitter guide) into a paginated
//  US-letter PDF at a temp URL for the share sheet.
//
//  Cross-platform: pure Core Graphics + Core Text, so the same code
//  runs on iOS and macOS. Only the font/color types differ.
//

import Foundation
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PDFExporter {

    /// Renders plain text into a multipage PDF. Returns nil on failure.
    static func pdf(from text: String, filename: String) -> URL? {
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US letter @72dpi
        let inset: CGFloat = 48
        let textRect = pageRect.insetBy(dx: inset, dy: inset)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        #if canImport(UIKit)
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let textColor = UIColor.black
        #else
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let textColor = NSColor.black
        #endif
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph
            ]
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        guard let context = CGContext(url as CFURL, mediaBox: &pageRect, nil) else {
            return nil
        }

        var location = 0
        let length = attributed.length

        while location < length {
            context.beginPDFPage(nil)
            // CGContext PDF space has a bottom-left origin, which is what
            // Core Text expects — no flip transform needed here.
            context.textMatrix = .identity
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()

            let visible = CTFrameGetVisibleStringRange(frame)
            if visible.length == 0 { break } // safety: avoid infinite loop
            location += visible.length
        }

        context.closePDF()
        return url
    }
}
