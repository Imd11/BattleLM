import SwiftUI
import BattleLMShared
import CoreText

@main
struct BattleLMiOSApp: App {
    @StateObject private var connection = RemoteConnection()

    init() {
        registerCustomFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connection)
        }
    }
}

private func registerCustomFonts() {
    let fontNames = ["Orbitron-VariableFont"]
    for fontName in fontNames {
        guard let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
            print("⚠️ Font not found in bundle: \(fontName).ttf")
            continue
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            print("⚠️ Failed to register font \(fontName): \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
        } else {
            print("✅ Registered font: \(fontName)")
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base content
                if connection.hasEverConnected {
                    AIListView()
                } else {
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

                // Overlay: keep navigation stable during transient reconnects.
                if connection.hasEverConnected {
                    switch connection.state {
                    case .connecting, .authenticating:
                        ReconnectingBannerView(text: connection.state == .authenticating ? "Authenticating..." : "Reconnecting...")
                            .transition(.opacity)
                    case .error(let message):
                        ErrorOverlayView(message: message)
                            .transition(.opacity)
                    default:
                        EmptyView()
                    }
                }
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

private struct ReconnectingBannerView: View {
    let text: String

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.secondary)
                Text(text)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private struct ErrorOverlayView: View {
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

            NavigationLink(destination: ScannerView()) {
                Label("Scan Again", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(.borderedProminent)

            Button("Back to Home") {
                connection.disconnect()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
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
            
            NavigationLink(destination: ScannerView()) {
                Label(
                    (message.contains("unauthorized") || message.contains("not authorized")) ? "Scan to Pair" : "Scan Again",
                    systemImage: "qrcode.viewfinder"
                )
            }
            .buttonStyle(.borderedProminent)
            
            Button("Back to Home") {
                connection.disconnect()
            }
            .buttonStyle(.bordered)
        }
    }
}
