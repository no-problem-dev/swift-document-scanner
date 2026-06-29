import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

/// 検出された矩形の透視変換補正を行い、正面向きの書類画像を抽出するユーティリティ。
public enum PerspectiveCorrection {
    /// 画像内の検出矩形に透視変換補正を適用する。
    ///
    /// - Parameters:
    ///   - cgImage: 書類を含むソース画像。
    ///   - observation: Vision が検出した矩形観察結果。
    /// - Returns: 透視変換補正済み画像。補正に失敗した場合は nil。
    public static func correct(cgImage: CGImage, observation: VNRectangleObservation) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = ciImage.extent.size

        let topLeft = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: observation.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: observation.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: observation.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: observation.bottomRight.y * imageSize.height
        )

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = topLeft
        filter.topRight = topRight
        filter.bottomLeft = bottomLeft
        filter.bottomRight = bottomRight

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}
