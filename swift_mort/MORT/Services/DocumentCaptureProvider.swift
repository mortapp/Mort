import Foundation

struct DocumentCaptureCapability: Sendable, Equatable {
    let collectionEnabled: Bool
    let supportsCamera: Bool
    let supportsEdgeDetection: Bool
    let supportsGlareWarning: Bool
    let supportsBlurWarning: Bool
    let supportsPDF417: Bool
    let supportsMRZ: Bool
    let reason: String

    static let disabled = DocumentCaptureCapability(
        collectionEnabled: false,
        supportsCamera: false,
        supportsEdgeDetection: false,
        supportsGlareWarning: false,
        supportsBlurWarning: false,
        supportsPDF417: false,
        supportsMRZ: false,
        reason: "Identity-document collection is disabled until an approved provider, retention policy, trained review workflow, deletion process, and legal/privacy review exist."
    )
}

protocol DocumentCaptureProvider: Sendable {
    func capability() async -> DocumentCaptureCapability
    func beginCapture() async throws -> Never
}

enum DocumentCaptureError: LocalizedError, Sendable {
    case collectionDisabled

    var errorDescription: String? {
        "MORT is not collecting identity documents. Document parsing would not authenticate a document."
    }
}

struct DisabledDocumentCaptureProvider: DocumentCaptureProvider {
    func capability() async -> DocumentCaptureCapability { .disabled }

    func beginCapture() async throws -> Never {
        throw DocumentCaptureError.collectionDisabled
    }
}
