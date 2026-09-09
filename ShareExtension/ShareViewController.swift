//
//  ShareViewController.swift
//  CraveCircle Share Extension
//
//  Lets users share a cooking video from Instagram / YouTube / TikTok / Facebook straight into
//  CraveCircle. It grabs the shared link, stashes it in the shared App Group, opens the host app
//  via the cravecircle:// URL scheme, and finishes — the app then runs the import.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    // Must match AppEnvironment.appGroupID / pendingImportKey in the main app.
    private let appGroupID = "group.com.anassyed.AICookBook"
    private let pendingKey = "pending_import_url"
    private let hostAppURL = "cravecircle://import"
    // The reel-import backend (same as AppConfig.defaultHost). The extension imports DIRECTLY here so
    // sharing works with no App Group and no fragile openURL hand-off (free teams + App Store alike).
    private let backendURL = "https://import.cravecircle.cc"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extractSharedURL()
    }

    private func extractSharedURL() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let providers = item.attachments
        else { return finish() }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        // Prefer an actual URL attachment (what Instagram / YouTube share sheets hand over).
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] data, _ in
                let url = (data as? URL)?.absoluteString ?? (data as? String)
                self?.deliver(url)
            }
            return
        }

        // Fallback: plain text that contains a link.
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] data, _ in
                self?.deliver(self?.firstURL(in: data as? String))
            }
            return
        }

        finish()
    }

    private func firstURL(in text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }

    private func deliver(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty else { return finish() }
        // Import the reel DIRECTLY on the backend from the extension — reliable on any signing team
        // (no App Group needed, no openURL hand-off needed). The recipe is created server-side and
        // appears in the app on next open/refresh. Then best-effort nudge the app to the foreground.
        postImport(urlString) { [weak self] in
            self?.openHostApp(with: nil)   // just bring the app forward to refresh (no ?url= → no dup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.finish() }
        }
    }

    /// POST the reel URL to the import backend so the recipe is built server-side.
    private func postImport(_ urlString: String, completion: @escaping () -> Void) {
        guard let endpoint = URL(string: "\(backendURL)/reels/import") else {
            DispatchQueue.main.async(execute: completion); return
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["url": urlString, "target_language": "en"])
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async(execute: completion)
        }.resume()
    }

    /// Extensions can't call UIApplication.shared.open, so walk the responder chain to openURL:.
    private func openHostApp(with urlString: String?) {
        var link = hostAppURL
        if let urlString, !urlString.isEmpty {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")   // strict: encode :/?=& so the link stays one query value
            let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowed) ?? urlString
            link = "\(hostAppURL)?url=\(encoded)"
        }
        guard let url = URL(string: link) else { return }
        // Walk the responder chain to UIApplication and call openURL: on IT specifically. Calling
        // perform(openURL:) on an arbitrary responder is flaky on iOS 18/26 — casting to
        // UIApplication first is the reliable form for an extension opening its host app.
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication, app.responds(to: selector) {
                app.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
