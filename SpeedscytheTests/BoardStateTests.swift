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
        for event in [BoardEvent.digit(1), .escape, .stopShortcut, .columnClicked(1), .tileClicked(column: 1, task: 0), .editToggled] {
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

    func testProjectDigitFollowsSlotNumberAcrossEmptySlots() {
        let gappedBoard = BoardModel(
            assignments: [
                ProjectAssignment(id: 1, isActive: true, project: Project(id: 100, name: "A", code: nil), client: Client(id: 1, name: "C"), taskAssignments: []),
                ProjectAssignment(id: 2, isActive: true, project: Project(id: 200, name: "B", code: nil), client: Client(id: 1, name: "C"), taskAssignments: []),
            ],
            slots: [100, nil, 200]
        )

        XCTAssertTrue(BoardState.reduce(.idle, .digit(3), board: gappedBoard) == (.projectSelected(column: 1), nil))
        XCTAssertTrue(BoardState.reduce(.idle, .digit(2), board: gappedBoard) == (.idle, nil))
    }

    func testEditToggleEntersEditModeFromOpenStates() {
        XCTAssertTrue(BoardState.reduce(.idle, .editToggled, board: board) == (.editing, nil))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 1), .editToggled, board: board) == (.editing, nil))
    }

    func testEditToggleAndEscapeLeaveEditMode() {
        XCTAssertTrue(BoardState.reduce(.editing, .editToggled, board: board) == (.idle, nil))
        XCTAssertTrue(BoardState.reduce(.editing, .escape, board: board) == (.idle, nil))
    }

    func testEditModeIgnoresStartInput() {
        for event in [BoardEvent.digit(1), .columnClicked(0), .tileClicked(column: 0, task: 0)] {
            XCTAssertTrue(BoardState.reduce(.editing, event, board: board) == (.editing, nil), "\(event)")
        }
    }

    func testStopShortcutStopsInEditMode() {
        XCTAssertTrue(BoardState.reduce(.editing, .stopShortcut, board: board) == (.editing, .stop))
    }

    func testNotesShortcutOpensNotesFieldFromOpenStates() {
        XCTAssertTrue(BoardState.reduce(.idle, .notesShortcut, board: board) == (.editingNotes, nil))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 1), .notesShortcut, board: board) == (.editingNotes, nil))
    }

    func testNotesShortcutIsIgnoredInEditModeAndWhileStarting() {
        XCTAssertTrue(BoardState.reduce(.editing, .notesShortcut, board: board) == (.editing, nil))
        XCTAssertTrue(BoardState.reduce(.starting(column: 0, task: 0), .notesShortcut, board: board) == (.starting(column: 0, task: 0), nil))
    }

    func testLastTaskShortcutStartsTheTileOnTheBoard() {
        XCTAssertTrue(BoardState.reduce(.idle, .lastTaskShortcut(projectID: 300, taskID: 305), board: board) == (.starting(column: 2, task: 4), .start(projectID: 300, taskID: 305)))
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 0), .lastTaskShortcut(projectID: 200, taskID: 201), board: board) == (.starting(column: 1, task: 0), .start(projectID: 200, taskID: 201)))
    }

    func testLastTaskShortcutStartsATaskThatIsNotOnTheBoard() {
        XCTAssertTrue(BoardState.reduce(.idle, .lastTaskShortcut(projectID: 900, taskID: 901), board: board) == (.startingOffBoard, .start(projectID: 900, taskID: 901)))
        XCTAssertTrue(BoardState.reduce(.idle, .lastTaskShortcut(projectID: 100, taskID: 999), board: board) == (.startingOffBoard, .start(projectID: 100, taskID: 999)))
    }

    func testLastTaskShortcutIsIgnoredInEditModeNotesAndWhileStarting() {
        let event = BoardEvent.lastTaskShortcut(projectID: 100, taskID: 101)
        for state in [BoardState.editing, .editingNotes, .savingNotes, .starting(column: 0, task: 0), .startingOffBoard] {
            XCTAssertTrue(BoardState.reduce(state, event, board: board) == (state, nil), "\(state)")
        }
    }

    func testStartingOffBoardIgnoresInput() {
        for event in [BoardEvent.digit(1), .escape, .stopShortcut, .columnClicked(1), .tileClicked(column: 1, task: 0), .editToggled, .notesShortcut] {
            XCTAssertTrue(BoardState.reduce(.startingOffBoard, event, board: board) == (.startingOffBoard, nil), "\(event)")
        }
    }

    func testStartingOffBoardClosesOnSuccessAndReturnsToIdleOnFailure() {
        XCTAssertTrue(BoardState.reduce(.startingOffBoard, .startSucceeded, board: board) == (.idle, .close))
        XCTAssertTrue(BoardState.reduce(.startingOffBoard, .startFailed, board: board) == (.idle, nil))
    }

    func testEscapeCancelsNotes() {
        XCTAssertTrue(BoardState.reduce(.editingNotes, .escape, board: board) == (.idle, nil))
    }

    func testSubmitSavesNotes() {
        XCTAssertTrue(BoardState.reduce(.editingNotes, .submit, board: board) == (.savingNotes, .saveNotes))
    }

    func testEditingNotesIgnoresOtherInput() {
        for event in [BoardEvent.digit(1), .stopShortcut, .columnClicked(0), .tileClicked(column: 0, task: 0), .editToggled, .notesShortcut] {
            XCTAssertTrue(BoardState.reduce(.editingNotes, event, board: board) == (.editingNotes, nil), "\(event)")
        }
    }

    func testSavedNotesClose() {
        XCTAssertTrue(BoardState.reduce(.savingNotes, .notesSaved, board: board) == (.idle, .close))
    }

    func testFailedNotesReturnToEditingNotes() {
        XCTAssertTrue(BoardState.reduce(.savingNotes, .notesFailed, board: board) == (.editingNotes, nil))
    }

    func testSavingNotesIgnoresInput() {
        for event in [BoardEvent.digit(1), .escape, .submit, .stopShortcut, .columnClicked(1), .tileClicked(column: 1, task: 0), .editToggled, .notesShortcut] {
            XCTAssertTrue(BoardState.reduce(.savingNotes, event, board: board) == (.savingNotes, nil), "\(event)")
        }
    }

    func testSubmitIsIgnoredOutsideNotes() {
        XCTAssertTrue(BoardState.reduce(.idle, .submit, board: board) == (.idle, nil))
    }

    func testSelectedColumnThatDisappearedIgnoresDigits() {
        let smallerBoard = TestData.board(taskCounts: [3])
        XCTAssertTrue(BoardState.reduce(.projectSelected(column: 2), .digit(1), board: smallerBoard) == (.projectSelected(column: 2), nil))
    }
}
