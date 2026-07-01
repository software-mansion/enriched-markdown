import UIKit

final class ImageDownloader {
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

    func download(url: String, completion: @escaping (UIImage?) -> Void) {
        guard !url.isEmpty else {
            completion(nil)
            return
        }

        if let cached = MarkdownImageAttachment.originalImageCache.object(forKey: url as NSString) {
            completion(cached)
            return
        }

        lock.lock()
        if var existing = inFlightRequests[url] {
            existing.append(completion)
            inFlightRequests[url] = existing
            lock.unlock()
            return
        }
        inFlightRequests[url] = [completion]
        lock.unlock()

        guard let requestURL = URL(string: url) else {
            dispatchCallbacks(for: url, image: nil)
            return
        }

        session.dataTask(with: requestURL) { [weak self] data, _, error in
            let image = (data != nil && error == nil) ? UIImage(data: data!) : nil
            if let image {
                MarkdownImageAttachment.originalImageCache.setObject(
                    image,
                    forKey: url as NSString,
                    cost: Self.byteCost(for: image)
                )
            }
            self?.dispatchCallbacks(for: url, image: image)
        }.resume()
    }

    private func dispatchCallbacks(for url: String, image: UIImage?) {
        lock.lock()
        let callbacks = inFlightRequests.removeValue(forKey: url) ?? []
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
