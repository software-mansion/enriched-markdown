import UIKit

/// Abstraction over image fetching so consumers of attachments can inject
/// a stub in tests and previews instead of hitting the network.
protocol ImageDownloading: AnyObject {
    func download(url: String, headers: [String: String], completion: @escaping (UIImage?) -> Void)
}

final class ImageDownloader: ImageDownloading {
    static let shared = ImageDownloader()

    private let session: URLSession
    private var inFlightRequests: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func download(url: String, headers: [String: String], completion: @escaping (UIImage?) -> Void) {
        guard !url.isEmpty else {
            completion(nil)
            return
        }

        let requestKey = ImageCacheKey.requestKey(url: url, headers: headers)
        if let cached = MarkdownImageAttachment.originalImageCache.object(forKey: requestKey as NSString) {
            completion(cached)
            return
        }

        lock.lock()
        if var existing = inFlightRequests[requestKey] {
            existing.append(completion)
            inFlightRequests[requestKey] = existing
            lock.unlock()
            return
        }
        inFlightRequests[requestKey] = [completion]
        lock.unlock()

        let scheme = URLComponents(string: url)?.scheme?.lowercased()
        guard scheme == "http" || scheme == "https" else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let image = LocalImageLoader.load(url)
                self?.cacheAndDispatch(image, for: requestKey)
            }
            return
        }

        guard let requestURL = URL(string: url) else {
            dispatchCallbacks(for: requestKey, image: nil)
            return
        }

        var request = URLRequest(url: requestURL)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        session.dataTask(with: request) { [weak self] data, _, error in
            let image = (data != nil && error == nil) ? data.flatMap { ImageDecoder.decodeDownsampled($0) } : nil
            self?.cacheAndDispatch(image, for: requestKey)
        }.resume()
    }

    private func cacheAndDispatch(_ image: UIImage?, for requestKey: String) {
        if let image {
            MarkdownImageAttachment.originalImageCache.setObject(
                image,
                forKey: requestKey as NSString,
                cost: Self.byteCost(for: image)
            )
        }
        dispatchCallbacks(for: requestKey, image: image)
    }

    private func dispatchCallbacks(for requestKey: String, image: UIImage?) {
        lock.lock()
        let callbacks = inFlightRequests.removeValue(forKey: requestKey) ?? []
        lock.unlock()
        DispatchQueue.main.async {
            callbacks.forEach { $0(image) }
        }
    }

    private static func byteCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
