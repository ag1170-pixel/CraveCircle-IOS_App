//
//  WebImportScreen.swift
//  CraveCircle (AICookBook)
//
//  In-app browser. Starts on Google. The save bar turns on only when the open page
//  publishes a recipe. Safari View cannot read the page, so this is a web view.
//

import Combine
import SwiftUI
import WebKit

struct WebImportScreen: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model = WebImportModel()
    @State private var saving = false

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            WebImportRepresentable(model: model)
            bottomBar
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { model.ownerId = environment.currentUser?.id ?? "" }
    }

    private var addressBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Button { Haptics.tap(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Text(model.address)
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.sm)
                .frame(height: 36)
                .background(AppTheme.surface, in: Capsule())
            Button { Haptics.tap(); model.reload() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button { model.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(model.canGoBack ? AppTheme.textPrimary : AppTheme.textTertiary)
                    .frame(width: 36, height: 44)
            }
            .disabled(!model.canGoBack)
            .buttonStyle(.plain)
            Button { model.goForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(model.canGoForward ? AppTheme.textPrimary : AppTheme.textTertiary)
                    .frame(width: 36, height: 44)
            }
            .disabled(!model.canGoForward)
            .buttonStyle(.plain)
            Button {
                guard let recipe = model.recipe, !saving else { return }
                saving = true
                Haptics.tap()
                model.stop()
                environment.saveWebRecipe(recipe)
                onSaved()
            } label: {
                Text(saving ? "Saving…" : (model.recipe == nil ? "Open a recipe to import" : "Save this recipe"))
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(model.recipe == nil ? AppTheme.textTertiary : AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(model.recipe == nil ? AppTheme.accentSoft : AppTheme.accent, in: Capsule())
            }
            .disabled(model.recipe == nil || saving)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppTheme.background)
    }
}

@MainActor
final class WebImportModel: ObservableObject {
    let webView: WKWebView
    @Published var address = "https://www.google.com/"
    @Published var recipe: Recipe?
    @Published var canGoBack = false
    @Published var canGoForward = false
    var ownerId = ""
    private var readTask: Task<Void, Never>?

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        view.allowsBackForwardNavigationGestures = true
        webView = view
    }

    private var didStart = false
    func start() {
        guard !didStart else { return }
        didStart = true
        webView.load(URLRequest(url: URL(string: "https://www.google.com/")!))
    }

    func reload() { webView.reload() }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }

    func stop() {
        readTask?.cancel()
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    fileprivate func noteNavigation() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let url = webView.url { address = url.absoluteString }
    }

    /// One read per pause. Ad frames finish many times; parsing each of them is what makes the page hitch.
    fileprivate func scheduleRead() {
        noteNavigation()
        readTask?.cancel()
        readTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.readPage()
        }
    }

    private func readPage() {
        guard let page = webView.url, !WebRecipeParser.isSearchHost(page) else {
            recipe = nil
            return
        }
        let owner = ownerId
        webView.evaluateJavaScript(Self.script) { [weak self] result, _ in
            let blocks = Self.blocks(from: result)
            Task.detached {
                let found = WebRecipeParser.recipe(blocks: blocks, pageURL: page, ownerId: owner)
                await MainActor.run { [weak self] in
                    guard let self, self.webView.url == page else { return }
                    self.recipe = found
                }
            }
        }
    }

    private static let script = """
    (function() {
      var out = [];
      var nodes = document.querySelectorAll('script[type="application/ld+json"]');
      for (var i = 0; i < nodes.length && out.length < 4; i++) {
        var text = nodes[i].textContent || "";
        if (text.indexOf("Recipe") === -1) continue;
        if (text.length > 80000) text = text.slice(0, 80000);
        out.push(text);
      }
      return JSON.stringify(out);
    })()
    """

    private static func blocks(from result: Any?) -> [String] {
        guard let text = result as? String, let data = text.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return list
    }
}

private struct WebImportRepresentable: UIViewRepresentable {
    @ObservedObject var model: WebImportModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView.navigationDelegate = context.coordinator
        model.start()
        return model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: WebImportModel
        init(model: WebImportModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.model.recipe = nil
                self.model.noteNavigation()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.model.scheduleRead() }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
