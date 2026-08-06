import Testing
import Foundation
@testable import CourtsideHoopStats

/// Tests for the game date formatting (#67).
///
/// Locale-dependent by nature, so these assert on the *parts* that must be
/// present rather than an exact string — an en_US-only assertion would fail on
/// any other device region for no good reason.
struct GameDateFormatTests {

    /// 2026-08-04 was a Tuesday.
    private var tuesday: Date {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 8; parts.day = 4
        parts.hour = 11; parts.minute = 40
        return Calendar.current.date(from: parts)!
    }

    @Test func gameDayIncludesAbbreviatedWeekday() {
        let formatted = tuesday.gameDay
        let weekday = tuesday.formatted(.dateTime.weekday(.abbreviated))
        #expect(formatted.contains(weekday),
                "\(formatted) should contain the weekday \(weekday)")
    }

    @Test func gameDayIncludesMonthDayAndYear() {
        let formatted = tuesday.gameDay
        #expect(formatted.contains("2026"))
        #expect(formatted.contains("4"))
        // Abbreviated month, not the full name — rows are tight.
        #expect(formatted.contains(tuesday.formatted(.dateTime.month(.abbreviated))))
    }

    /// The weekday leads: a trailing weekday collides with the time.
    @Test func weekdayComesBeforeTheMonth() throws {
        let formatted = tuesday.gameDay
        let weekday = tuesday.formatted(.dateTime.weekday(.abbreviated))
        let month = tuesday.formatted(.dateTime.month(.abbreviated))
        let weekdayIndex = try #require(formatted.range(of: weekday)?.lowerBound)
        let monthIndex = try #require(formatted.range(of: month)?.lowerBound)
        #expect(weekdayIndex < monthIndex)
    }

    @Test func dayAndTimeAddsTheStartTime() {
        let formatted = tuesday.gameDayAndTime
        #expect(formatted.hasPrefix(tuesday.gameDay))
        #expect(formatted.contains(tuesday.formatted(date: .omitted, time: .shortened)))
    }
}

/// The compact list-row form (#67 follow-up).
struct GameDateCompactTests {

    private func date(year: Int) -> Date {
        var parts = DateComponents()
        parts.year = year; parts.month = 8; parts.day = 4
        parts.hour = 11; parts.minute = 40
        return Calendar.current.date(from: parts)!
    }

    /// The row also carries a location, so the year is dropped in-season to
    /// keep the tip-off time from truncating.
    @Test func currentYearOmitsTheYear() {
        let thisYear = Calendar.current.component(.year, from: Date())
        let formatted = date(year: thisYear).gameDayCompact
        #expect(!formatted.contains("\(thisYear)"))
        #expect(formatted.contains(date(year: thisYear)
            .formatted(.dateTime.weekday(.abbreviated))))
    }

    /// A game from a past season keeps its year so it's never ambiguous.
    @Test func pastYearKeepsTheYear() {
        let past = Calendar.current.component(.year, from: Date()) - 2
        #expect(date(year: past).gameDayCompact.contains("\(past)"))
    }

    @Test func compactAlwaysKeepsTheTime() {
        let thisYear = Calendar.current.component(.year, from: Date())
        let sample = date(year: thisYear)
        #expect(sample.gameDayCompact
            .contains(sample.formatted(date: .omitted, time: .shortened)))
    }
}

/// The "last updated" wording shown on a followed team (#57).
struct UpdatedLabelTests {

    @Test func withinAMinuteReadsJustNow() {
        #expect(Date().updatedLabel == "Updated Just Now")
        #expect(Date().addingTimeInterval(-30).updatedLabel == "Updated Just Now")
    }

    /// Rounded to the minute: the sync isn't accurate to the second, and a
    /// string that ticks every second reads as anxious precision.
    @Test func pastAMinuteReadsRelative() {
        let label = Date().addingTimeInterval(-300).updatedLabel
        #expect(label.hasPrefix("Updated "))
        #expect(label != "Updated Just Now")
        #expect(!label.contains("second"))
    }

    @Test func theBoundaryIsAMinute() {
        #expect(Date().addingTimeInterval(-59).updatedLabel == "Updated Just Now")
        #expect(Date().addingTimeInterval(-61).updatedLabel != "Updated Just Now")
    }
}
