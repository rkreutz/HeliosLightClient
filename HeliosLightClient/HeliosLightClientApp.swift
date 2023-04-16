import Combine
import HeliosKit
import SwiftUI

class Model: ObservableObject {
    @Published var icon: String = "ethereum"
    @Published var isRunning: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    var progres: Int = 0
    var timer: AnyCancellable? {
        willSet {
            timer?.cancel()
            progres = 0
        }
    }
}

@main
struct HeliosLightClientApp: App {

    @AppStorage("rpc") var rpc: String = ""
    @StateObject var model = Model()

    var body: some Scene {
        MenuBarExtra("", image: model.icon) {
            ContentView(rpc: $rpc)
                .environmentObject(model)
        }.menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model

    let rpc: Binding<String>
    var timer: AnyCancellable?


    var body: some View {
        VStack {
            TextField("Mainnet RPC URL", text: rpc)

            HStack(spacing: 8) {
                Button(action: model.isRunning ? stop : start, label: { Label(model.isRunning ? "Stop" : "Start", systemImage: model.isRunning ? "stop.fill" : "play.fill") })
                    .disabled(model.isLoading)

                Button(action: { NSApplication.shared.terminate(nil) }, label: { Label("Close", systemImage: "xmark.circle.fill") })
            }

            Divider()

            switch (model.errorMessage, model.isLoading, model.isRunning) {
            case let (.some(errorMessage), _, _):
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            case let (_, true, isRuning):
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)

                    Text(isRuning ? "Shutting down client" : "Starting client...")
                }
            case let (_, _, isRunning):
                Label(
                    isRunning ? "Client listening on \(Helios.shared.clientURL.absoluteString)" : "Waiting for client to start",
                    systemImage: isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
                )
            }
        }
        .padding()
    }

    func start() {
        guard let url = URL(string: rpc.wrappedValue) else {
            model.errorMessage = "Invalid RPC URL"
            return
        }
        model.isLoading = true
        model.timer = Timer.publish(every: 0.75, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: { _ in
                model.progres = (model.progres + 1) % 4
                switch model.progres {
                case 0:
                    model.icon = "ethereum"
                case 1:
                    model.icon = "ethereum.fill.1"
                case 2:
                    model.icon = "ethereum.fill.2"
                case 3:
                    model.icon = "ethereum.fill"
                default:
                    break
                }
            })
        model.errorMessage = nil
        Task {
            do {
                try await Helios.shared.start(rpcURL: url)
                model.timer = nil
                model.isRunning = true
                model.icon = "ethereum.fill"
            } catch {
                model.timer = nil
                model.errorMessage = error.localizedDescription
                model.icon = "ethereum"
            }
            model.isLoading = false
        }
    }

    func stop() {
        model.isLoading = true
        model.timer = Timer.publish(every: 0.75, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: { _ in
                model.progres = (model.progres + 1) % 4
                switch model.progres {
                case 0:
                    model.icon = "ethereum.fill"
                case 1:
                    model.icon = "ethereum.fill.2"
                case 2:
                    model.icon = "ethereum.fill.1"
                case 3:
                    model.icon = "ethereum"
                default:
                    break
                }
            })
        Task {
            await Helios.shared.shutdown()
            model.timer = nil
            model.isRunning = false
            model.isLoading = false
            model.icon = "ethereum"
        }
    }
}
