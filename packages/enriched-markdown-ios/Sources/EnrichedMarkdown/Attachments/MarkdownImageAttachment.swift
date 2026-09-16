import UIKit

/// Adopted by the view hosting a rendered document, so an attachment whose box
/// settles only after asynchronous work can ask to be measured again: the view
/// was sized, and that size cached, against the earlier guess.
protocol MarkdownAttachmentLayoutObserver: AnyObject {
    func attachmentDidInvalidateLayout()
}

final class MarkdownImageAttachment: NSTextAttachment {
    static let originalImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()

    /// Bitmaps already scaled into a box. Entries are whole decoded images, so
    /// the cache is bounded by bytes rather than by count alone: an inline
    /// square and a full-width block box differ by two orders of magnitude.
    private static let processedImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024
        return cache
    }()

    let imageURL: String
    let requestHeaders: [String: String]
    let isInline: Bool
    /// Inline images are a square of this size. For a block image it is the
    /// box height used until the container width is known.
    let cachedHeight: CGFloat
    let cachedBorderRadius: CGFloat
    /// How this image's box height is derived. Inline images ignore it.
    let sizing: ImageBoxSizing
    /// How the bitmap fills its box; nil is the legacy fill-width drawing.
    let resizeMode: ImageResizeMode?

    weak var layoutObserver: MarkdownAttachmentLayoutObserver?

    private let requestKey: String
    private let downloader: ImageDownloading

    private var originalImage: UIImage?
    private var loadedImage: UIImage?
    private weak var textContainer: NSTextContainer?
    /// The box last handed to the layout manager, so a finishing load can tell
    /// whether the box is about to change, and the drawing has a box to use
    /// before UIKit has asked for one.
    private var lastLaidOutBox: CGSize?
    /// The box `loadedImage` was last scaled into.
    private var lastProcessedBox: CGSize?

    /// Always returns a fresh attachment: an NSTextAttachment carries
    /// per-position layout state (bounds, text container, refresh range), so
    /// instances must never be shared between string positions or views.
    /// Re-renders stay flicker-free through the original/processed image
    /// caches, which hit synchronously.
    static func attachment(
        for url: String,
        config: MarkdownStyleConfig,
        isInline: Bool,
        altText: String,
        requestHeaders: [String: String] = [:],
        downloader: ImageDownloading = ImageDownloader.shared
    ) -> MarkdownImageAttachment {
        MarkdownImageAttachment(
            url: url,
            config: config,
            isInline: isInline,
            altText: altText,
            requestHeaders: requestHeaders,
            requestKey: ImageCacheKey.requestKey(url: url, headers: requestHeaders),
            downloader: downloader
        )
    }

    private init(
        url: String,
        config: MarkdownStyleConfig,
        isInline: Bool,
        altText: String,
        requestHeaders: [String: String],
        requestKey: String,
        downloader: ImageDownloading
    ) {
        imageURL = url
        self.requestHeaders = requestHeaders
        self.requestKey = requestKey
        self.isInline = isInline
        self.downloader = downloader
        let sizing = ImageBoxSizing(style: config.image)
        self.sizing = sizing
        // Inline images fill their square exactly.
        resizeMode = isInline ? .stretch : (config.image.resizeMode ?? sizing.defaultResizeMode)
        cachedHeight = isInline ? (config.inlineImage.size ?? 20) : sizing.placeholderHeight
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

        if isInline {
            let size = cachedHeight
            var appliedFont: UIFont?
            if let textStorage = textStorage(from: textContainer),
               charIndex >= 0,
               charIndex < textStorage.length {
                appliedFont = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
            }

            let verticalOffset: CGFloat
            if let appliedFont {
                verticalOffset = (appliedFont.capHeight - size) / 2
            } else {
                verticalOffset = (lineFragmentRect.height - size) / 2
            }
            return CGRect(x: 0, y: verticalOffset, width: size, height: size)
        }

        let width = lineFragmentRect.width > 0 ? lineFragmentRect.width : cachedHeight
        let box = CGSize(width: width, height: sizing.boxHeight(width: width, intrinsicSize: originalImage?.size))
        lastLaidOutBox = box
        return CGRect(origin: .zero, size: box)
    }

    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        self.textContainer = textContainer

        if let originalImage, imageBounds.width > 0 {
            bounds = imageBounds
            processAndApplyImage(originalImage, box: imageBounds.size)
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
        downloader.download(url: imageURL, headers: requestHeaders) { [weak self] image in
            self?.handleLoadedImage(image)
        }
    }

    /// Callbacks land on the main queue, except a synchronous hit on the
    /// original-image cache, which arrives on the render queue while the
    /// document is still being built — before any layout, hence the
    /// `lastLaidOutBox` guard.
    private func handleLoadedImage(_ image: UIImage?) {
        guard let image else { return }
        originalImage = image

        if isInline {
            processAndApplyImage(image, box: CGSize(width: cachedHeight, height: cachedHeight))
            return
        }

        // Scaling into the placeholder bounds would only cache a wrongly
        // shaped bitmap that nothing would ever look up again.
        guard let lastLaidOutBox else { return }

        if sizing.boxHeight(width: lastLaidOutBox.width, intrinsicSize: image.size) != lastLaidOutBox.height {
            // The box stood at a height the image has now settled.
            refreshDisplay()
            notifyLayoutObserver()
            return
        }

        processAndApplyImage(image, box: lastLaidOutBox)
    }

    private func processAndApplyImage(_ image: UIImage, box: CGSize) {
        guard box.width > 0, box.height > 0 else { return }
        // Every other part of the cache key is fixed for this attachment, so
        // the box alone decides whether the last result still stands. This runs
        // on every layout pass, and building the key would not be free.
        if box == lastProcessedBox { return }
        lastProcessedBox = box

        let key = "\(requestKey)_w\(box.width)_h\(box.height)_r\(cachedBorderRadius)_m\(resizeMode?.rawValue ?? "")"

        if let cached = Self.processedImageCache.object(forKey: key as NSString) {
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
                box: box,
                borderRadius: self.cachedBorderRadius
            )

            if let processed {
                Self.processedImageCache.setObject(processed, forKey: key as NSString, cost: processed.byteCost)
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
        box: CGSize,
        borderRadius: CGFloat
    ) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let drawingRect = ImageDrawing.rect(mode: resizeMode, source: image.size, box: box)
        let renderer = UIGraphicsImageRenderer(size: box)
        return renderer.image { _ in
            if borderRadius > 0 {
                let clippingRect = drawingRect.intersection(CGRect(origin: .zero, size: box))
                UIBezierPath(roundedRect: clippingRect, cornerRadius: borderRadius).addClip()
            }
            image.draw(in: drawingRect)
        }
    }

    private func notifyLayoutObserver() {
        // A load can finish inside a layout pass, by way of a synchronous hit
        // in `image(forBounds:)`; measuring again from there would re-enter the
        // layout manager.
        DispatchQueue.main.async { [weak layoutObserver] in
            layoutObserver?.attachmentDidInvalidateLayout()
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
