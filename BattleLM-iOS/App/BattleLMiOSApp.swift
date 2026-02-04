import SwiftUI
import BattleLMShared

@main
struct BattleLMiOSApp: App {
    @StateObject private var connection = RemoteConnection()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connection)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        NavigationStack {
            switch connection.state {
            case .disconnected:
                WelcomeView()
            case .connecting, .authenticating:
                ConnectingView()
            case .connected:
                AIListView()
            case .error(let message):
                ErrorView(message: message)
            }
        }
    }
}

struct ConnectingView: View {
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(connection.state == .authenticating ? "Authenticating..." : "Connecting...")
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if message.contains("unauthorized") || message.contains("not authorized") {
                NavigationLink(destination: ScannerView()) {
                    Label("Scan to Pair", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button("Back to Home") {
                connection.disconnect()
            }
            .buttonStyle(.bordered)
        }
    }
}
