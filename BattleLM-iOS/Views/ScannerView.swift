import SwiftUI
import AVFoundation
import BattleLMShared

/// QR Scanner View
struct ScannerView: View {
    @EnvironmentObject var connection: RemoteConnection
    @Environment(\.dismiss) private var dismiss
    
    @State private var isScanning = true
    @State private var permissionDenied = false
    
    var body: some View {
        ZStack {
            if permissionDenied {
                permissionDeniedView
            } else {
                QRScannerRepresentable(
                    isScanning: $isScanning,
                    onCodeScanned: handleScannedCode
                )
                .ignoresSafeArea()
                
                // Overlay
                scannerOverlay
            }
        }
        .navigationTitle("Scan QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkCameraPermission()
        }
    }
    
    private var scannerOverlay: some View {
        VStack {
            Spacer()
            
            // Scan frame
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 250)
                .background(Color.clear)
            
            Text("Point camera at the QR code on Mac")
                .foregroundColor(.white)
                .padding(.top, 24)
            
            Spacer()
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Camera Access Required")
                .font(.title2)
            
            Text("Please allow BattleLM to access your camera in Settings")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        default:
            permissionDenied = true
        }
    }
    
    private func handleScannedCode(_ code: String) {
        isScanning = false
        
        guard let payload = try? PairingQRPayload.from(base64: code) else {
            // 尝试解析为 JSON
            if let data = code.data(using: .utf8),
               let payload = try? JSONDecoder().decode(PairingQRPayload.self, from: data) {
                connectWith(payload)
            } else {
                connection.state = .error(AuthError.invalidQRCode.localizedDescription)
            }
            return
        }
        
        connectWith(payload)
    }
    
    private func connectWith(_ payload: PairingQRPayload) {
        // 立即关闭扫码页，让用户看到连接状态
        dismiss()
        
        Task {
            do {
                try await connection.connectWithPairing(payload)
            } catch {
                connection.state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - QR Scanner UIKit Wrapper

struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeScanned: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession,
              captureSession.canAddInput(videoInput) else {
            return
        }
        
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        startScanning()
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }
}
