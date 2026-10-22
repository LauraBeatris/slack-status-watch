import Foundation

public enum StatusExpiry: Codable, Hashable, Sendable {
  case never
  case duration(minutes: Int)
  case timeOfDay(hour: Int, minute: Int)

  public static let durationChoices = [15, 30, 45, 60, 120, 240]

  /*
   Resolves the expiry against the moment the status is set. A time of day
   that already passed today rolls over to tomorrow
   */
  public func expirationDate(from now: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .never:
      return nil
    case .duration(let minutes):
      return now.addingTimeInterval(TimeInterval(minutes * 60))
    case .timeOfDay(let hour, let minute):
      let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
      guard let today else { return nil }
      if today > now { return today }
      return calendar.date(byAdding: .day, value: 1, to: today)
    }
  }

  public var label: String {
    switch self {
    case .never:
      return "No expiry"
    case .duration(let minutes):
      return Self.durationLabel(minutes: minutes)
    case .timeOfDay(let hour, let minute):
      return "Until " + Self.timeLabel(hour: hour, minute: minute)
    }
  }

  private static func durationLabel(minutes: Int) -> String {
    if minutes < 60 { return "\(minutes) min" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return "\(minutes / 60)h \(minutes % 60)m"
  }

  private static func timeLabel(hour: Int, minute: Int) -> String {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    guard let date = Calendar.current.date(from: components) else { return "\(hour):\(minute)" }
    return date.formatted(date: .omitted, time: .shortened)
  }
}
