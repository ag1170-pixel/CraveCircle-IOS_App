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
        if let urlString, let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(urlString, forKey: pendingKey)
        }
        DispatchQueue.main.async { [weak self] in
            self?.openHostApp()
            self?.finish()
        }
    }

    /// Extensions can't call UIApplication.shared.open, so walk the responder chain to openURL:.
    private func openHostApp() {
        guard let url = URL(string: hostAppURL) else { return }
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selector) {
                _ = r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
