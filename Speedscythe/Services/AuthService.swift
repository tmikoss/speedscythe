import AppKit
import Network
import Observation

enum AuthError: LocalizedError {
    case noHarvestAccount
    case listenerFailed(NWError)

    var errorDescription: String? {
        switch self {
        case .noHarvestAccount:
            "Your Harvest login has no Harvest account."
        case .listenerFailed(let error):
            "Speedscythe cannot receive the Harvest response on \(HarvestOAuth.redirectURI.absoluteString): \(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class AuthService {
    private(set) var session: AuthSession?
    private(set) var isConnecting = false
    private(set) var errorMessage: String?

    @ObservationIgnored var onSessionChange: (() -> Void)?
    @ObservationIgnored private var listener: OAuthLoopbackListener?
    private let keychain = KeychainStore(service: Bundle.main.bundleIdentifier!, account: "harvest-oauth")

    func restore() {
        do {
            guard let data = try keychain.load() else { return }
            let storedSession = try JSONDecoder().decode(AuthSession.self, from: data)
            guard storedSession.expiresAt > .now else {
                try keychain.delete()
                return
            }
            session = storedSession
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect() {
        stopListener()
        errorMessage = nil
        let state = UUID().uuidString
        do {
            let listener = try OAuthLoopbackListener(
                redirectURI: HarvestOAuth.redirectURI,
                onCallback: { [weak self] url in
                    self?.handleCallback(url, expectedState: state) ?? ""
                },
                onFailure: { [weak self] error in
                    self?.stopListener()
                    self?.errorMessage = AuthError.listenerFailed(error).localizedDescription
                }
            )
            listener.start()
            self.listener = listener
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        isConnecting = true
        NSWorkspace.shared.open(authorizeURL(state: state))
    }

    func disconnect() {
        stopListener()
        session = nil
        do {
            try keychain.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
        onSessionChange?()
    }

    private func authorizeURL(state: String) -> URL {
        var components = URLComponents(string: "https://id.getharvest.com/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: HarvestOAuth.clientID),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: HarvestOAuth.redirectURI.absoluteString),
        ]
        return components.url!
    }

    private func stopListener() {
        listener?.stop()
        listener = nil
        isConnecting = false
    }

    private func handleCallback(_ url: URL, expectedState: String) -> String {
        stopListener()
        do {
            let callback = try OAuthCallbackParser.parse(url, expectedState: expectedState)
            Task { await complete(callback) }
            return "Speedscythe is connected to Harvest. You can close this tab."
        } catch {
            errorMessage = error.localizedDescription
            return "Speedscythe could not connect to Harvest. \(error.localizedDescription)"
        }
    }

    private func complete(_ callback: OAuthCallback) async {
        do {
            let accountID: Int
            switch callback.accountScope {
            case .account(let id):
                accountID = id
            case .allAccounts:
                let accounts = try await HarvestClient.accounts(accessToken: callback.accessToken)
                guard let account = accounts.first(where: { $0.product == "harvest" }) else {
                    throw AuthError.noHarvestAccount
                }
                accountID = account.id
            }
            let newSession = AuthSession(accessToken: callback.accessToken, expiresAt: .now + callback.expiresIn, accountID: accountID)
            try keychain.save(JSONEncoder().encode(newSession))
            session = newSession
            onSessionChange?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class OAuthLoopbackListener {
    private let listener: NWListener
    private let callbackPath: String
    private let onCallback: (URL) -> String
    private let onFailure: (NWError) -> Void

    init(redirectURI: URL, onCallback: @escaping (URL) -> String, onFailure: @escaping (NWError) -> Void) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: UInt16(redirectURI.port!))!)
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters)
        callbackPath = redirectURI.path
        self.onCallback = onCallback
        self.onFailure = onFailure
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated {
                self?.accept(connection)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                switch state {
                case .failed(let error), .waiting(let error):
                    self?.onFailure(error)
                default:
                    break
                }
            }
        }
        listener.start(queue: .main)
    }

    func stop() {
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else {
                    connection.cancel()
                    return
                }
                var buffer = buffer
                if let data {
                    buffer.append(data)
                }
                if let request = HTTPRequest(buffer) {
                    self.respond(to: request, on: connection)
                } else if isComplete || error != nil || buffer.count > 65_536 {
                    connection.cancel()
                } else {
                    self.receive(on: connection, buffer: buffer)
                }
            }
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let path = request.target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
        switch (request.method, path) {
        case ("GET", callbackPath):
            send(status: "200 OK", contentType: "text/html; charset=utf-8", body: Self.callbackPage, on: connection)
        case ("POST", "/token"):
            guard let text = String(data: request.body, encoding: .utf8), let url = URL(string: text) else {
                send(status: "400 Bad Request", contentType: "text/plain; charset=utf-8", body: "", on: connection)
                return
            }
            send(status: "200 OK", contentType: "text/plain; charset=utf-8", body: onCallback(url), on: connection)
        default:
            send(status: "404 Not Found", contentType: "text/plain; charset=utf-8", body: "", on: connection)
        }
    }

    private func send(status: String, contentType: String, body: String, on connection: NWConnection) {
        let bodyData = Data(body.utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + bodyData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static let callbackPage = """
        <!doctype html>
        <meta charset="utf-8">
        <title>Speedscythe</title>
        <p id="message">Connecting Speedscythe to Harvest…</p>
        <script>
        const message = document.getElementById("message");
        fetch("/token", { method: "POST", body: location.href })
          .then((response) => response.text())
          .then((text) => { message.textContent = text; })
          .catch(() => { message.textContent = "Speedscythe did not respond. Open Speedscythe Settings and connect again."; });
        </script>
        """
}

private struct HTTPRequest {
    let method: String
    let target: String
    let body: Data

    init?(_ data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else {
            return nil
        }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        let contentLength = lines.dropFirst().lazy.compactMap { line -> Int? in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].lowercased() == "content-length" else { return nil }
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0

        let body = data[headerEnd.upperBound...]
        guard body.count >= contentLength else { return nil }

        method = String(requestLine[0])
        target = String(requestLine[1])
        self.body = Data(body.prefix(contentLength))
    }
}
