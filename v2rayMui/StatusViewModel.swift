import Foundation

@MainActor
final class StatusViewModel: ObservableObject {
    @Published var connected: Bool = false
    @Published var statusText: String = "disconnected"
    @Published var selectedName: String? = nil
    @Published var isLoading: Bool = false
    @Published var goServerRunning: Bool = false

    private let baseURL: URL
    private var timer: Timer?

    init(address: String = AppConfig.serverAddress, port: Int = AppConfig.serverPort) {
        self.baseURL = URL(string: "http://\(address):\(port)/api/v1")!
        Task { await fetchStatus() }
        startPolling()
    }

    deinit { timer?.invalidate() }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { await self?.fetchStatus() }
        }
    }

    func fetchStatus() async {
        do {
            let url = baseURL.appending(path: "status")
            let (data, response) = try await URLSession.shared.data(from: url)
//            if let http = response as? HTTPURLResponse {
//                // print("[Status] GET \(url.absoluteString) -> status=\(http.statusCode)")
//            }
//            if let body = String(data: data, encoding: .utf8) {
//                // print("[Status] body: \(body)")
//            }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.goServerRunning = true
                self.connected = (json["connected"] as? Bool) ?? false
                self.statusText = (json["status"] as? String) ?? "unknown"
                if let selected = json["selected"] as? [String: Any] {
                    self.selectedName = (selected["name"] as? String)
                } else {
                    self.selectedName = nil
                }
            }
        } catch {
            // print("[Status] fetch error: \(error)")
            self.goServerRunning = false
            self.statusText = "unreachable"
        }
    }

    func toggleConnection() async {
        isLoading = true
        defer { isLoading = false }
        let path = connected ? "disconnect" : "connect"
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
//            if let http = response as? HTTPURLResponse {
//                // print("[Status] POST \(request.url?.absoluteString ?? "") -> status=\(http.statusCode)")
//            }
//            if let body = String(data: data, encoding: .utf8) {
//                // print("[Status] body: \(body)")
//            }
            await fetchStatus()
        } catch {
            // print("[Status] toggle error: \(error)")
            // ignore, UI will reflect via status fetch
        }
    }
}


