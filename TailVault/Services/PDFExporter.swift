//
//  PDFExporter.swift
//  TailVault
//
//  Renders report text (vet report, sitter guide) into a paginated
//  US-letter PDF at a temp URL for the share sheet.
//

import UIKit

enum PDFExporter {

    /// Renders plain text into a multipage PDF. Returns nil on failure.
    static func pdf(from text: String, filename: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US letter @72dpi
        let inset: CGFloat = 48
        let textRect = pageRect.insetBy(dx: inset, dy: inset)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        do {
            try renderer.writePDF(to: url) { context in
                var location = 0
                let length = attributed.length

                while location < length {
                    context.beginPage()
                    let cgContext = context.cgContext

                    // Core Text draws flipped; set up the transform.
                    cgContext.textMatrix = .identity
                    cgContext.translateBy(x: 0, y: pageRect.height)
                    cgContext.scaleBy(x: 1, y: -1)

                    let path = CGPath(rect: textRect, transform: nil)
                    let frame = CTFramesetterCreateFrame(
                        framesetter, CFRange(location: location, length: 0), path, nil)
                    CTFrameDraw(frame, cgContext)

                    let visible = CTFrameGetVisibleStringRange(frame)
                    if visible.length == 0 { break } // safety: avoid infinite loop
                    location += visible.length
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
