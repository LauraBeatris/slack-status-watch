import SwiftUI

/*
 The app's colours, taken from the website so the two read as one product.
 Plum is the only accent and it means "live": the status that is set right now,
 or the choice being made. Everything else stays ink, grey and paper
 */
extension Color {
  static let brandPaper = Color(hex: 0xFBFBFA)
  static let brandCard = Color(hex: 0xF2F2F0)
  static let brandLine = Color.black.opacity(0.08)
  static let brandInk = Color(hex: 0x111113)
  static let brandMuted = Color(hex: 0x6E6E73)
  static let brandFaint = Color(hex: 0x8E8E93)
  static let brandPlum = Color(hex: 0x6D2A71)
  static let brandPlumTint = Color(hex: 0xF3EEF5)
  static let brandMist = Color(hex: 0xEFE4F2)
  static let brandLilac = Color(hex: 0xDCC4E5)
  static let brandLive = Color(hex: 0x34C759)
  static let brandDanger = Color(hex: 0xD70015)

  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

extension ShapeStyle where Self == LinearGradient {
  /*
   The mist-to-lilac glow behind the brand moments: sign-in and the live status
   */
  static var brandGlow: LinearGradient {
    LinearGradient(colors: [.brandMist, .brandLilac], startPoint: .top, endPoint: .bottom)
  }
}

/*
 Small caps label that sits above a group, like WORKSPACE or PRESETS
 */
struct SectionLabel: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .tracking(0.5)
      .textCase(.uppercase)
      .foregroundStyle(Color.brandFaint)
  }
}
