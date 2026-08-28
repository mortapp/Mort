import Foundation
import ImageIO
import UIKit

enum ImagePurpose: Sendable, Equatable {
    case avatar
    case proof
    case verification

    var maximumSourceBytes: Int {
        switch self {
        case .avatar: 5 * 1_024 * 1_024
        case .proof, .verification: 10 * 1_024 * 1_024
        }
    }

    var maximumDimension: CGFloat {
        switch self {
        case .avatar: 1_024
        case .proof, .verification: 2_048
        }
    }

    var decodeDimension: CGFloat {
        switch self {
        case .avatar: 4_096
        case .proof, .verification: maximumDimension
        }
    }
}

struct PreparedImage: Sendable {
    let data: Data
    let width: Int
    let height: Int
}

enum ImageProcessingService {
    static func decodeSource(_ source: Data, purpose: ImagePurpose) throws -> UIImage {
        guard source.count <= purpose.maximumSourceBytes else {
            throw MortError.invalidInput("Choose an image smaller than \(purpose.maximumSourceBytes / 1_024 / 1_024) MB.")
        }
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil) else {
            throw MortError.invalidInput("Choose a valid image file.")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(purpose.decodeDimension),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw MortError.invalidInput("That image format could not be decoded.")
        }
        let image = UIImage(cgImage: cgImage)
        guard image.size.width > 0, image.size.height > 0 else {
            throw MortError.invalidInput("That image has invalid dimensions.")
        }
        return image
    }

    static func prepareCameraCapture(_ image: UIImage, purpose: ImagePurpose) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw MortError.invalidInput("The camera photo has invalid dimensions.")
        }
        let scale = min(1, purpose.decodeDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in [CGFloat(0.9), 0.82, 0.74, 0.66, 0.58] {
            if let data = rendered.jpegData(compressionQuality: quality),
               data.count <= purpose.maximumSourceBytes
            {
                return data
            }
        }
        throw MortError.invalidInput("The camera photo is too detailed to process. Try again with less zoom or use Photo Library.")
    }

    static func prepare(_ source: Data, purpose: ImagePurpose) throws -> PreparedImage {
        let image = try decodeSource(source, purpose: purpose)
        let sourceSize = image.size

        let targetSize: CGSize
        let drawRect: CGRect
        switch purpose {
        case .avatar:
            let edge = min(purpose.maximumDimension, min(sourceSize.width, sourceSize.height))
            targetSize = CGSize(width: edge, height: edge)
            let scale = max(edge / sourceSize.width, edge / sourceSize.height)
            let drawn = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            drawRect = CGRect(
                x: (edge - drawn.width) / 2,
                y: (edge - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            )
        case .proof, .verification:
            let scale = min(1, purpose.maximumDimension / max(sourceSize.width, sourceSize.height))
            targetSize = CGSize(width: floor(sourceSize.width * scale), height: floor(sourceSize.height * scale))
            drawRect = CGRect(origin: .zero, size: targetSize)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: drawRect)
        }

        let qualities: [CGFloat] = [0.88, 0.78, 0.68, 0.58]
        let maximumOutputBytes = purpose == .avatar ? 2 * 1_024 * 1_024 : 8 * 1_024 * 1_024
        for quality in qualities {
            if let data = rendered.jpegData(compressionQuality: quality), data.count <= maximumOutputBytes {
                return PreparedImage(data: data, width: Int(targetSize.width), height: Int(targetSize.height))
            }
        }
        throw MortError.invalidInput("The processed image is still too large. Choose a smaller photo.")
    }

    static func renderAvatarCrop(
        _ image: UIImage,
        viewport: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) throws -> Data {
        guard viewport > 0, image.size.width > 0, image.size.height > 0 else {
            throw MortError.invalidInput("That image cannot be cropped.")
        }

        let fillScale = AvatarCropGeometry.fillScale(imageSize: image.size, viewport: viewport)
        let visibleSourceEdge = viewport / (fillScale * max(zoom, 1))
        let outputEdge = min(CGFloat(1_024), max(1, floor(visibleSourceEdge)))
        let outputSize = CGSize(width: outputEdge, height: outputEdge)
        let drawRect = AvatarCropGeometry.drawRect(
            imageSize: image.size,
            viewport: viewport,
            outputEdge: outputEdge,
            zoom: zoom,
            offset: offset
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: drawRect)
        }
        guard let data = rendered.jpegData(compressionQuality: 0.94) else {
            throw MortError.invalidInput("The cropped photo could not be encoded.")
        }
        return data
    }
}

enum AvatarCropGeometry {
    static func fillScale(imageSize: CGSize, viewport: CGFloat) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, viewport > 0 else { return 0 }
        return max(viewport / imageSize.width, viewport / imageSize.height)
    }

    static func displaySize(imageSize: CGSize, viewport: CGFloat, zoom: CGFloat) -> CGSize {
        let scale = fillScale(imageSize: imageSize, viewport: viewport) * max(zoom, 1)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    static func clampedOffset(
        _ offset: CGSize,
        imageSize: CGSize,
        viewport: CGFloat,
        zoom: CGFloat
    ) -> CGSize {
        let displaySize = displaySize(imageSize: imageSize, viewport: viewport, zoom: zoom)
        let maximumX = max(0, (displaySize.width - viewport) / 2)
        let maximumY = max(0, (displaySize.height - viewport) / 2)
        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    static func drawRect(
        imageSize: CGSize,
        viewport: CGFloat,
        outputEdge: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) -> CGRect {
        guard viewport > 0, outputEdge > 0 else { return .zero }
        let displaySize = displaySize(imageSize: imageSize, viewport: viewport, zoom: zoom)
        let safeOffset = clampedOffset(
            offset,
            imageSize: imageSize,
            viewport: viewport,
            zoom: zoom
        )
        let outputScale = outputEdge / viewport
        return CGRect(
            x: (viewport / 2 + safeOffset.width - displaySize.width / 2) * outputScale,
            y: (viewport / 2 + safeOffset.height - displaySize.height / 2) * outputScale,
            width: displaySize.width * outputScale,
            height: displaySize.height * outputScale
        )
    }
}
