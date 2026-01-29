// BattleLM/Views/Terminal/XtermTerminalView.swift
import SwiftUI
import WebKit

/// xterm.js 终端视图 - 使用 WKWebView 实现真实终端体验
struct XtermTerminalView: NSViewRepresentable {
    let command: String
    let args: [String]
    @Binding var isConnected: Bool
    var onExit: ((Int32) -> Void)?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = config.userContentController
        
        // 注册 JS 消息处理
        contentController.add(context.coordinator, name: "terminalInput")
        contentController.add(context.coordinator, name: "terminalResize")
        contentController.add(context.coordinator, name: "terminalReady")
        
        // 允许本地文件访问
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        context.coordinator.webView = webView
        context.coordinator.command = command
        context.coordinator.args = args
        context.coordinator.onExit = onExit
        context.coordinator.isConnectedBinding = $isConnected
        
        // 设置导航代理以检测 WebContent 崩溃
        webView.navigationDelegate = context.coordinator
        
        // 加载 xterm.html - 尝试多种路径
        let resourcePath = Bundle.main.resourcePath ?? ""
        let possiblePaths = [
            Bundle.main.url(forResource: "xterm", withExtension: "html"),
            Bundle.main.url(forResource: "xterm", withExtension: "html", subdirectory: "Terminal"),
            URL(fileURLWithPath: resourcePath + "/xterm.html"),
            URL(fileURLWithPath: resourcePath + "/Terminal/xterm.html")
        ]
        
        var loaded = false
        for url in possiblePaths.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: url.path) {
                print("✅ Loading xterm.html from: \(url.path)")
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                loaded = true
                break
            }
        }
        
        if !loaded {
            print("❌ xterm.html not found in any path")
            print("   Bundle path: \(resourcePath)")
            // 列出 Resources 目录内容
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                print("   Resources contents: \(contents)")
            }
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 更新时不需要操作
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var command: String = "/bin/zsh"
        var args: [String] = []
        var onExit: ((Int32) -> Void)?
        var isConnectedBinding: Binding<Bool>?
        
        private let ptyManager = PTYManager()
        private var outputBuffer = Data()
        private var flushTimer: Timer?
        private var terminalSize: (cols: Int, rows: Int) = (80, 24)
        
        func startPTY() {
            // 设置 PTY 输出回调
            ptyManager.onOutput = { [weak self] data in
                self?.handleOutput(data)
            }
            
            ptyManager.onExit = { [weak self] exitCode in
                DispatchQueue.main.async {
                    self?.isConnectedBinding?.wrappedValue = false
                    self?.onExit?(exitCode)
                }
            }
            
            // 启动进程（使用已保存的终端尺寸）
            do {
                try ptyManager.spawn(command: command, args: args, cols: terminalSize.cols, rows: terminalSize.rows)
                DispatchQueue.main.async {
                    self.isConnectedBinding?.wrappedValue = true
                }
            } catch {
                print("❌ PTY spawn failed: \(error)")
            }
        }
        
        private func handleOutput(_ data: Data) {
            // 合并输出，节流刷新（16ms ≈ 60fps）
            outputBuffer.append(data)
            
            if flushTimer == nil {
                flushTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { [weak self] _ in
                    self?.flushOutput()
                }
            }
        }
        
        private func flushOutput() {
            flushTimer = nil
            
            guard !outputBuffer.isEmpty else { return }
            
            let base64 = outputBuffer.base64EncodedString()
            outputBuffer.removeAll()
            
            webView?.evaluateJavaScript("window.writeBase64('\(base64)')") { _, error in
                if let error = error {
                    print("❌ JS error: \(error)")
                }
            }
        }
        
        func close() {
            ptyManager.closeConnection()
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "terminalInput":
                // 用户输入 → 写入 PTY
                if let input = message.body as? String,
                   let data = input.data(using: .utf8) {
                    ptyManager.write(data)
                }
                
            case "terminalResize":
                // 终端尺寸变化
                if let json = message.body as? String,
                   let data = json.data(using: .utf8),
                   let dims = try? JSONDecoder().decode(TerminalDimensions.self, from: data) {
                    ptyManager.updateWindowSize(cols: dims.cols, rows: dims.rows)
                }
                
            case "terminalReady":
                // xterm.js 准备就绪，保存尺寸并启动 PTY
                if let json = message.body as? String,
                   let data = json.data(using: .utf8),
                   let dims = try? JSONDecoder().decode(TerminalDimensions.self, from: data) {
                    // 保存尺寸，spawn 时使用
                    terminalSize = (dims.cols, dims.rows)
                    print("📐 Terminal size: \(dims.cols)x\(dims.rows)")
                }
                // PTY 启动（使用正确的尺寸）
                print("🚀 Starting PTY with size \(terminalSize.cols)x\(terminalSize.rows)...")
                startPTY()
                
            default:
                break
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView didFinish navigation")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView didFail: \(error)")
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("💥 WebContent process terminated!")
        }
        
        deinit {
            close()
        }
    }
}

// MARK: - Models

private struct TerminalDimensions: Codable {
    let cols: Int
    let rows: Int
}

#Preview {
    XtermTerminalView(
        command: "/bin/zsh",
        args: [],
        isConnected: .constant(true)
    )
    .frame(width: 600, height: 400)
}
