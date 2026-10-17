import Foundation
import Vision

/// On-device OCR through the Vision framework. No permission, nothing leaves the Mac.
enum ImageTextRecognizer {
    /// Returns recognized lines joined by newlines, or nil when nothing readable was found.
    static func recognize(_ png: Data) async -> String? {
        await Task.detached(priority: .utility) { () -> String? in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(data: png, options: [:])
            guard (try? handler.perform([request])) != nil,
                  let results = request.results else { return nil }
            let lines = results.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }.value
    }
}
