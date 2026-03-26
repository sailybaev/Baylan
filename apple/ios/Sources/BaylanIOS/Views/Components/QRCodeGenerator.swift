import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeGenerator: View {
    let data: Data
    let size: CGFloat

    var body: some View {
        if let image = generateQRCode() {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "qrcode")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func generateQRCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // False-color: accent on black background
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = output
        colorFilter.color0 = CIColor(red: 0.722, green: 1.0, blue: 0.0)  // #B8FF00 neon lime
        colorFilter.color1 = CIColor(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A background

        guard let coloredOutput = colorFilter.outputImage else { return nil }

        let scale = size / coloredOutput.extent.width
        let scaledImage = coloredOutput.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
