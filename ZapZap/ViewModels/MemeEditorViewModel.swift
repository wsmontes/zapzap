import SwiftUI
import Observation

@MainActor
@Observable
final class MemeEditorViewModel {
    var topText: String = ""
    var bottomText: String = ""
    var fontSize: CGFloat = 48
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"

    var hasContent: Bool {
        !topText.isEmpty || !bottomText.isEmpty
    }

    func toModel() -> MemeText {
        MemeText(
            topText: topText,
            bottomText: bottomText,
            fontSize: fontSize,
            textColorHex: textColorHex,
            outlineColorHex: outlineColorHex
        )
    }

    func load(from memeText: MemeText) {
        topText = memeText.topText
        bottomText = memeText.bottomText
        fontSize = memeText.fontSize
        textColorHex = memeText.textColorHex
        outlineColorHex = memeText.outlineColorHex
    }
}
