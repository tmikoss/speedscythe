import XCTest
@testable import Speedscythe

final class ElapsedFormatTests: XCTestCase {
    func testHoursMinutes() {
        XCTAssertEqual(ElapsedFormat.hoursMinutes(0), "0:00")
        XCTAssertEqual(ElapsedFormat.hoursMinutes(75 * 60), "1:15")
        XCTAssertEqual(ElapsedFormat.hoursMinutes(2.11 * 3600), "2:06")
        XCTAssertEqual(ElapsedFormat.hoursMinutes(12 * 3600 + 59), "12:00")
    }

    func testHoursMinutesSeconds() {
        XCTAssertEqual(ElapsedFormat.hoursMinutesSeconds(42 * 60 + 10), "0:42:10")
        XCTAssertEqual(ElapsedFormat.hoursMinutesSeconds(3600 + 5), "1:00:05")
    }

    func testNegativeIntervalsShowZero() {
        XCTAssertEqual(ElapsedFormat.hoursMinutes(-30), "0:00")
        XCTAssertEqual(ElapsedFormat.hoursMinutesSeconds(-30), "0:00:00")
    }
}
