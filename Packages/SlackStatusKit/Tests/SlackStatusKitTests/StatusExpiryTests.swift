import Foundation
import Testing

@testable import SlackStatusKit

struct StatusExpiryTests {
  let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
  }()

  func date(_ hour: Int, _ minute: Int, day: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
  }

  @Test func `never has no expiration`() {
    #expect(StatusExpiry.never.expirationDate(from: date(9, 0), calendar: calendar) == nil)
  }

  @Test func `duration counts from now`() {
    let expiration = StatusExpiry.duration(minutes: 90).expirationDate(from: date(9, 0), calendar: calendar)
    #expect(expiration == date(10, 30))
  }

  @Test func `time of day later today stays today`() {
    let expiration = StatusExpiry.timeOfDay(hour: 18, minute: 0).expirationDate(from: date(9, 0), calendar: calendar)
    #expect(expiration == date(18, 0))
  }

  @Test func `time of day already passed rolls to tomorrow`() {
    let expiration = StatusExpiry.timeOfDay(hour: 18, minute: 0).expirationDate(from: date(19, 30), calendar: calendar)
    #expect(expiration == date(18, 0, day: 11))
  }

  @Test func `time of day equal to now rolls to tomorrow`() {
    let expiration = StatusExpiry.timeOfDay(hour: 18, minute: 0).expirationDate(from: date(18, 0), calendar: calendar)
    #expect(expiration == date(18, 0, day: 11))
  }

  @Test func `survives a JSON round trip`() throws {
    let cases: [StatusExpiry] = [.never, .duration(minutes: 45), .timeOfDay(hour: 17, minute: 30)]
    let data = try JSONEncoder().encode(cases)
    #expect(try JSONDecoder().decode([StatusExpiry].self, from: data) == cases)
  }
}
