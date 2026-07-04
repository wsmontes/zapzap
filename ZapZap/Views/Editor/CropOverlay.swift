import SwiftUI

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scaleX = geometry.size.width / imageSize.width
            let scaleY = geometry.size.height / imageSize.height
            let scale = min(scaleX, scaleY)

            let displayWidth = imageSize.width * scale
            let displayHeight = imageSize.height * scale

            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(
                                        width: cropRect.width * scale,
                                        height: cropRect.height * scale
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )

                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, lineWidth: 2)
                    .frame(
                        width: cropRect.width * scale,
                        height: cropRect.height * scale
                    )
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
