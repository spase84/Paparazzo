import Foundation
import ImageIO
import MobileCoreServices
import AvitoDesignKit

public final class UrlImageSource: ImageSource {
    private static let processingQueue = dispatch_queue_create("ru.avito.AvitoMediaPicker.UrlImageSource.processingQueue",
                                                               dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0))

    private let url: NSURL

    public init(url: NSURL) {
        self.url = url
    }

    // MARK: - ImageSource
    
    public func fullResolutionImage<T : InitializableWithCGImage>(deliveryMode _: ImageDeliveryMode, resultHandler: T? -> ()) {
        
        dispatch_async(UrlImageSource.processingQueue) { [url] in
         
            let source = CGImageSourceCreateWithURL(url, nil)
            
            let options = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as Dictionary?
            let orientation = options?[kCGImagePropertyOrientation] as? Int

            var cgImage = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, options) }
            
            if let exifOrientation = orientation.flatMap({ ExifOrientation(rawValue: $0) }) {
                cgImage = cgImage?.imageFixedForOrientation(exifOrientation)
            }
            
            let image = cgImage.flatMap { T(CGImage: $0) }
            
            dispatch_async(dispatch_get_main_queue()) {
                resultHandler(image)
            }
        }
    }
    
    public func fullResolutionImageData(completion: NSData? -> ()) {
        dispatch_async(UrlImageSource.processingQueue) { [url] in
            let data = NSData(contentsOfURL: url)
            dispatch_async(dispatch_get_main_queue()) {
                completion(data)
            }
        }
    }
    
    public func imageSize(completion: CGSize? -> ()) {
        
        dispatch_async(UrlImageSource.processingQueue) { [url] in
            
            let source = CGImageSourceCreateWithURL(url, nil)
            let options = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as Dictionary?
            let width = options?[kCGImagePropertyPixelWidth] as? Int
            let height = options?[kCGImagePropertyPixelHeight] as? Int
            let orientation = options?[kCGImagePropertyOrientation] as? Int
            
            var size: CGSize? = nil
            
            if let width = width, height = height {
                
                let exifOrientation = orientation.flatMap { ExifOrientation(rawValue: $0) }
                let dimensionsSwapped = exifOrientation.flatMap { $0.dimensionsSwapped } ?? false
                
                size = CGSize(
                    width: dimensionsSwapped ? height : width,
                    height: dimensionsSwapped ? width : height
                )
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(size)
            }
        }
    }

    public func imageFittingSize<T: InitializableWithCGImage>(
        size: CGSize,
        contentMode: ImageContentMode,
        deliveryMode: ImageDeliveryMode,
        resultHandler: T? -> ()
    ) {
        dispatch_async(UrlImageSource.processingQueue) { [url] in

            let source = CGImageSourceCreateWithURL(url, nil)

            let options: [NSString: NSObject] = [
                kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true
            ]

            let cgImage = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }
            let image = cgImage.flatMap { T(CGImage: $0) }

            dispatch_async(dispatch_get_main_queue()) {
                resultHandler(image)
            }
        }
    }
    
    public func isEqualTo(other: ImageSource) -> Bool {
        if let other = other as? UrlImageSource {
            return other.url == url
        } else {
            return false
        }
    }
}
