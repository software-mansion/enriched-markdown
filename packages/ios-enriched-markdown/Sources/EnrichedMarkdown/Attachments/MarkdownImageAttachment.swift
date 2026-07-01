import UIKit

final class MarkdownImageAttachment: NSTextAttachment {
    static let originalImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()

    private static let processedImageCache = NSCache<NSString, UIImage>()
    private static let registry = NSMapTable<NSString, MarkdownImageAttachment>.strongToWeakObjects()

    let imageURL: String
    let isInline: Bool
    let cachedHeight: CGFloat
    let cachedBorderRadius: CGFloat

    private var originalImage: UIImage?
    private var loadedImage: UIImage?
    private weak var textContainer: NSTextContainer?
    private var lastProcessedKey: String?

    static func attachment(
        for url: String,
        config: MarkdownStyleConfig,
        isInline: Bool,
        altText: String
    ) -> MarkdownImageAttachment {
        let key = "\(url)_\(isInline)" as NSString
        if let existing = registry.object(forKey: key), existing.loadedImage != nil {
            return existing
        }

        let attachment = MarkdownImageAttachment(
            url: url,
            config: config,
            isInline: isInline,
            altText: altText
        )
        registry.setObject(attachment, forKey: key)
        return attachment
    }

    private init(url: String, config: MarkdownStyleConfig, isInline: Bool, altText: String) {
        imageURL = url
        self.isInline = isInline
        cachedHeight = isInline
            ? (config.inlineImage.size ?? 20)
            : (config.image.height ?? 200)
        cachedBorderRadius = config.image.borderRadius ?? 0
        super.init(data: nil, ofType: nil)
        accessibilityLabel = altText.isEmpty ? nil : altText
        setupPlaceholder()
        startDownloadingImage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFragmentRect: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        self.textContainer = textContainer
        let height = cachedHeight
        let width = isInline ? height : (lineFragmentRect.width > 0 ? lineFragmentRect.width : height)

        if isInline {
            var appliedFont: UIFont?
            if let textStorage = textStorage(from: textContainer),
               charIndex >= 0,
               charIndex < textStorage.length {
                appliedFont = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
            }

            let verticalOffset: CGFloat
            if let appliedFont {
                verticalOffset = (appliedFont.capHeight - height) / 2
            } else {
                verticalOffset = (lineFragmentRect.height - height) / 2
            }
            return CGRect(x: 0, y: verticalOffset, width: width, height: height)
        }

        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        self.textContainer = textContainer

        if let originalImage, imageBounds.width > 0 {
            bounds = imageBounds
            processAndApplyImage(originalImage, targetWidth: imageBounds.width)
        }

        return loadedImage ?? image
    }

    private func setupPlaceholder() {
        bounds = CGRect(x: 0, y: 0, width: cachedHeight, height: cachedHeight)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        image = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func startDownloadingImage() {
        guard !imageURL.isEmpty else { return }
        ImageDownloader.shared.download(url: imageURL) { [weak self] image in
            self?.handleLoadedImage(image)
        }
    }

    private func handleLoadedImage(_ image: UIImage?) {
        guard let image else { return }
        originalImage = image
        let targetWidth = isInline ? cachedHeight : bounds.width
        if !isInline, targetWidth <= 0 {
            return
        }
        processAndApplyImage(image, targetWidth: targetWidth)
    }

    private func processAndApplyImage(_ image: UIImage, targetWidth: CGFloat) {
        guard targetWidth > 0 else { return }

        let processedKey = "\(imageURL)_w\(targetWidth)_h\(cachedHeight)_r\(cachedBorderRadius)"
        if processedKey == lastProcessedKey { return }
        lastProcessedKey = processedKey

        if let cached = Self.processedImageCache.object(forKey: processedKey as NSString) {
            loadedImage = cached
            if isInline {
                self.image = cached
            }
            refreshDisplay()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let processed = self.createScaledImage(
                image,
                targetWidth: targetWidth,
                targetHeight: self.cachedHeight,
                borderRadius: self.cachedBorderRadius
            )

            if let processed {
                Self.processedImageCache.setObject(processed, forKey: processedKey as NSString)
            }

            DispatchQueue.main.async {
                self.loadedImage = processed
                if self.isInline {
                    self.image = processed
                    self.bounds = CGRect(x: 0, y: 0, width: self.cachedHeight, height: self.cachedHeight)
                } else {
                    self.image = image
                }
                self.refreshDisplay()
            }
        }
    }

    private func createScaledImage(
        _ image: UIImage,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        borderRadius: CGFloat
    ) -> UIImage? {
        let sourceWidth = image.size.width
        let sourceHeight = image.size.height
        guard sourceWidth > 0, sourceHeight > 0 else { return nil }

        let drawingWidth: CGFloat
        let drawingHeight: CGFloat

        if isInline {
            drawingWidth = targetWidth
            drawingHeight = targetHeight
        } else {
            let aspectRatioScale = targetWidth / sourceWidth
            drawingWidth = targetWidth
            drawingHeight = sourceHeight * aspectRatioScale
        }

        let drawingRect = CGRect(
            x: (targetWidth - drawingWidth) / 2,
            y: (targetHeight - drawingHeight) / 2,
            width: drawingWidth,
            height: drawingHeight
        )

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight))
        return renderer.image { _ in
            if borderRadius > 0 {
                let clippingRect = drawingRect.intersection(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                UIBezierPath(roundedRect: clippingRect, cornerRadius: borderRadius).addClip()
            }
            image.draw(in: drawingRect)
        }
    }

    private func refreshDisplay() {
        guard let textContainer,
              let textLayoutManager = textContainer.textLayoutManager,
              let textStorage = textStorage(from: textContainer) else {
            return
        }

        let range = findAttachmentRange(in: textStorage)
        guard range.location != NSNotFound,
              let contentManager = textLayoutManager.textContentManager,
              let textRange = TextLayoutHelpers.textRange(range, in: contentManager) else {
            return
        }

        textLayoutManager.invalidateRenderingAttributes(for: textRange)
        textLayoutManager.invalidateLayout(for: textRange)
    }

    private func textStorage(from textContainer: NSTextContainer?) -> NSTextStorage? {
        guard let contentStorage = textContainer?.textLayoutManager?.textContentManager as? NSTextContentStorage else {
            return nil
        }
        return contentStorage.textStorage
    }

    private func findAttachmentRange(in attributedString: NSAttributedString) -> NSRange {
        var foundRange = NSRange(location: NSNotFound, length: 0)
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, range, stop in
            if (value as AnyObject) === self {
                foundRange = range
                stop.pointee = true
            }
        }
        return foundRange
    }
}
