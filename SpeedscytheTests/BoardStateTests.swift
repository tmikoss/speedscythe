import XCTest
@testable import Speedscythe

final class BoardStateTests: XCTestCase {
    private let board = TestData.board(taskCounts: [3, 1, 12])

    func testProjectDigitSelectsColumn() {
        XCTAssertTrue(BoardState.reduce(.idle, .digit(2), board: board) == (.projectSelected(column: 1), nil))
    }

    func testProjectDigitWithoutColumnIsIgnored() {
        XCTAssertTrue(BoardState.reduce(.idle, .digit(4), board: board) == (.idle, nil))
    }

    func testTaskDigitStartsTimer() {
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .digit(2), board: board) == (.starting(column: 0, task: 1), .start(projectID: 100, taskID: 102)))
    }

    func testSingleTaskProjectStillWaitsForTaskDigit() {
        XCTAssertTrue(BoardState.reduce(.idle, .digit(2), board: board) == (.projectSelected(column: 1), nil))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 1), .digit(1), board: board) == (.starting(column: 1, task: 0), .start(projectID: 200, taskID: 201)))
    }

    func testTaskDigitWithoutTaskIsIgnored() {
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .digit(4), board: board) == (.projectSelected(column: 0), nil))
    }

    func testDigitsInSelectedProjectPickTasksNotProjects() {
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 2), .digit(3), board: board) == (.starting(column: 2, task: 2), .start(projectID: 300, taskID: 303)))
    }

    func testEscapeInIdleCloses() {
        XCTAssertTrue(BoardState.reduce(.idle, .escape, board: board) == (.idle, .close))
    }

    func testEscapeInSelectedProjectGoesBack() {
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .escape, board: board) == (.idle, nil))
    }

    func testStopShortcutStopsInOpenStates() {
        XCTAssertTrue(BoardState.reduce(.idle, .stopShortcut, board: board) == (.idle, .stop))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 1), .stopShortcut, board: board) == (.projectSelected(column: 1), .stop))
    }

    func testStartingIgnoresInput() {
        let starting = BoardState.starting(column: 0, task: 0)
        for event in [BoardEvent.digit(1), .escape, .stopShortcut, .columnClicked(1), .tileClicked(column: 1, task: 0)] {
            XCTAssertTrue(BoardState.reduce(starting, event, board: board) == (starting, nil), "\(event)")
        }
    }

    func testSuccessfulStartCloses() {
        XCTAssertTrue(BoardState.reduce(.starting(column: 0, task: 0), .startSucceeded, board: board) == (.idle, .close))
    }

    func testFailedStartReturnsToIdle() {
        XCTAssertTrue(BoardState.reduce(.starting(column: 0, task: 0), .startFailed, board: board) == (.idle, nil))
    }

    func testTileClickStartsFromAnyOpenState() {
        XCTAssertTrue(BoardState.reduce(.idle, .tileClicked(column: 2, task: 10), board: board) == (.starting(column: 2, task: 10), .start(projectID: 300, taskID: 311)))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .tileClicked(column: 1, task: 0), board: board) == (.starting(column: 1, task: 0), .start(projectID: 200, taskID: 201)))
    }

    func testColumnClickSelectsThatProject() {
        XCTAssertTrue(BoardState.reduce(.idle, .columnClicked(2), board: board) == (.projectSelected(column: 2), nil))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .columnClicked(1), board: board) == (.projectSelected(column: 1), nil))
    }

    func testSelectedColumnThatDisappearedIgnoresDigits() {
        let smallerBoard = TestData.board(taskCounts: [3])
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 2), .digit(1), board: smallerBoard) == (.projectSelected(column: 2), nil))
    }
}
