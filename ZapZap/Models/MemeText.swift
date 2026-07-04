import Foundation

struct MemeText: Codable, Equatable {
    var topText: String
    var bottomText: String
    var fontSize: CGFloat
    var textColorHex: String
    var outlineColorHex: String

    init(
        topText: String = "",
        bottomText: String = "",
        fontSize: CGFloat = 48,
        textColorHex: String = "#FFFFFF",
        outlineColorHex: String = "#000000"
    ) {
        self.topText = topText
        self.bottomText = bottomText
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.outlineColorHex = outlineColorHex
    }
}
