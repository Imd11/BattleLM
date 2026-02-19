import SwiftUI

/// Welcome view / Disconnected state
struct WelcomeView: View {
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            VStack(spacing: 16) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue.gradient)
                
                Text("Not Connected to Mac")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Scan button
            NavigationLink(destination: ScannerView()) {
                Label("Scan to Connect", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            
            // Paired devices
            if !connection.pairedDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paired Devices")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(connection.pairedDevices) { device in
                            PairedDeviceRow(device: device)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                connection.removePairedDevice(connection.pairedDevices[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(connection.pairedDevices.count) * 80)
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
        .navigationTitle("BattleLM")
    }
}

struct PairedDeviceRow: View {
    let device: RemoteConnection.PairedDevice
    @EnvironmentObject var connection: RemoteConnection
    
    var body: some View {
        Button {
            Task {
                try? await connection.reconnect(to: device)
            }
        } label: {
            HStack {
                Image(systemName: "laptopcomputer")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timeAgo(device.lastConnected))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last connected: " + formatter.localizedString(for: date, relativeTo: Date())
    }
}
