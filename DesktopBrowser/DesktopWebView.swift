import SwiftUI
import UIKit
import WebKit

/// macOS Safari 桌面版 UA。iOS 上所有浏览器都必须用 WebKit 内核，
/// 所以“桌面端”只能靠 UA + 视口来让网站返回桌面版页面，
/// 不能像 Android 那样换 Chromium 内核。
enum DesktopUA {
    static let desktop = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    static let homepage = URL(string: "https://www.google.com")!
}

final class BrowserModel: NSObject, ObservableObject {
    let webView: WKWebView

    @Published var addressText = ""
    @Published var currentURL: URL?
    @Published var pageTitle = ""
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var desktopMode = true

    private var progressObservation: NSKeyValueObservation?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // 默认持久化 data store，登录态 / Cookie 能保留
        config.websiteDataStore = .default()
        // iOS 17+：允许在需要时播放媒体，不强制全屏
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        // 关键：桌面 UA，网站据此返回桌面版
        webView.customUserAgent = DesktopUA.desktop
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.estimatedProgress = change.newValue ?? 0
            }
        }
        // 监听标题
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)

        load(url: DesktopUA.homepage)
    }

    deinit {
        progressObservation?.invalidate()
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.title) {
            DispatchQueue.main.async { [weak self] in
                self?.pageTitle = self?.webView.title ?? ""
            }
        }
    }

    // MARK: - 导航

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func loadAddress(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url: URL
        if let u = URL(string: trimmed), let scheme = u.scheme, (scheme == "http" || scheme == "https") {
            url = u
        } else if trimmed.contains("."), !trimmed.contains(" ") {
            url = URL(string: "https://" + trimmed)!
        } else {
            // 不是网址就当搜索词
            let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://duckduckgo.com/?q=\(q)")!
        }
        load(url: url)
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }
    func goHome() { load(url: DesktopUA.homepage) }

    /// 桌面 / 手机模式切换：改 UA 后重新加载当前页
    func toggleDesktopMode() {
        desktopMode.toggle()
        webView.customUserAgent = desktopMode ? DesktopUA.desktop : nil
        webView.reload()
    }

    private func syncState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url
        if let url = webView.url {
            addressText = url.absoluteString
        }
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension BrowserModel: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async { self.isLoading = true }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.syncState()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.syncState()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.syncState()
        }
    }

    // target=_blank 的链接在同一个 WebView 里打开，而不是打不开
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    // JS alert / confirm / prompt，用系统弹窗接住，不闪退
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        presentAlert(title: pageTitle, message: message, actions: [UIAlertAction(title: "好", style: .default) { _ in completionHandler() }])
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        presentAlert(title: pageTitle, message: message, actions: [
            UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) },
            UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) },
        ])
    }

    private func presentAlert(title: String, message: String, actions: [UIAlertAction]) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let alert = UIAlertController(title: title.isEmpty ? nil : title, message: message, preferredStyle: .alert)
        actions.forEach { alert.addAction($0) }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(alert, animated: true)
    }
}

// MARK: - SwiftUI 包装

struct DesktopWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
