import Foundation

enum BoardState: Equatable {
    case idle
    case projectSelected(column: Int)
    case starting(column: Int, task: Int)
    case editing

    var selectedColumn: Int? {
        switch self {
        case .idle, .editing:
            nil
        case .projectSelected(let column), .starting(let column, _):
            column
        }
    }

    var isEditing: Bool {
        self == .editing
    }
}

enum BoardEvent: Equatable {
    case digit(Int)
    case escape
    case stopShortcut
    case columnClicked(Int)
    case tileClicked(column: Int, task: Int)
    case editToggled
    case startSucceeded
    case startFailed
}

enum BoardEffect: Equatable {
    case start(projectID: Int, taskID: Int)
    case stop
    case close
}

extension BoardState {
    static func reduce(_ state: BoardState, _ event: BoardEvent, board: BoardModel) -> (BoardState, BoardEffect?) {
        switch (state, event) {
        case (.starting, .startSucceeded):
            return (.idle, .close)
        case (.starting, .startFailed):
            return (.idle, nil)
        case (.starting, _), (_, .startSucceeded), (_, .startFailed):
            return (state, nil)
        case (_, .stopShortcut):
            return (state, .stop)
        case (.editing, .editToggled), (.editing, .escape):
            return (.idle, nil)
        case (_, .editToggled):
            return (.editing, nil)
        case (.editing, _):
            return (state, nil)
        case (.idle, .escape):
            return (.idle, .close)
        case (.projectSelected, .escape):
            return (.idle, nil)
        case (.idle, .digit(let digit)):
            return board.columnIndex(forNumber: digit).map { (.projectSelected(column: $0), nil) } ?? (state, nil)
        case (.projectSelected(let column), .digit(let digit)):
            guard digit <= 9 else { return (state, nil) }
            return start(column: column, task: digit - 1, from: state, board: board)
        case (_, .columnClicked(let column)):
            return board.columns.indices.contains(column) ? (.projectSelected(column: column), nil) : (state, nil)
        case (_, .tileClicked(let column, let task)):
            return start(column: column, task: task, from: state, board: board)
        }
    }

    private static func start(column: Int, task: Int, from state: BoardState, board: BoardModel) -> (BoardState, BoardEffect?) {
        guard board.columns.indices.contains(column), board.columns[column].tasks.indices.contains(task) else {
            return (state, nil)
        }
        let selected = board.columns[column]
        return (.starting(column: column, task: task), .start(projectID: selected.project.id, taskID: selected.tasks[task].id))
    }
}
