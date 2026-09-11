//
//  ShareViewController.swift
//  CraveCircle Share Extension
//
//  Lets users share a cooking video from Instagram / YouTube / TikTok / Facebook straight into
//  CraveCircle. It grabs the shared link and hands it to the app, which imports it ON-DEVICE
//  (Apple Neural Engine) — the fast path (seconds), with live progress, filed in the user's own
//  library. The URL is also stashed in the App Group so the app picks it up on next open if the
//  system didn't switch apps.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    // Must match AppEnvironment.appGroupID / pendingImportKey in the main app.
    private let appGroupID = "group.com.anassyed.AICookBook"
    private let pendingKey = "pending_import_url"
    private let hostAppURL = "cravecircle://import"

    // MARK: UI
    private let card = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let primaryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setState(loading: true, title: "Adding to CraveCircle…", message: "Grabbing the recipe from this reel.")
        extractSharedURL()
    }

    // MARK: Extraction

    private func extractSharedURL() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let providers = item.attachments
        else { return showError("Nothing to import from this share.") }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] data, _ in
                let url = (data as? URL)?.absoluteString ?? (data as? String)
                DispatchQueue.main.async { self?.deliver(url) }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] data, _ in
                DispatchQueue.main.async { self?.deliver(self?.firstURL(in: data as? String)) }
            }
            return
        }

        showError("Couldn't find a video link in this share.")
    }

    private func firstURL(in text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }

    private var sharedURL: String?

    private func deliver(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty else {
            return showError("Couldn't find a video link in this share.")
        }
        sharedURL = urlString
        // Hand the URL to the APP so IT runs the import on-device (Apple Neural Engine) — that's the
        // FAST path (seconds, not minutes) and it files the recipe in the user's own library with
        // live progress. Stash in the App Group too so the app also picks it up on next open if the
        // system didn't switch apps. Auto-attempt the open; the button is the reliable fallback.
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(urlString, forKey: pendingKey)
        }
        openHostApp()
        showReady()
    }

    /// Open CraveCircle with the reel URL embedded so the app imports it on-device (fast, live
    /// progress, owned by the user). Walk the responder chain to UIApplication and call openURL:.
    private func openHostApp() {
        guard let urlString = sharedURL else { return }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowed) ?? urlString
        guard let url = URL(string: "\(hostAppURL)?url=\(encoded)") else { return }
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

    // MARK: UI state

    private func setState(loading: Bool, title: String, message: String, systemIcon: String? = nil, iconTint: UIColor = .white) {
        titleLabel.text = title
        messageLabel.text = message
        if loading {
            spinner.startAnimating()
            iconView.isHidden = true
            primaryButton.isHidden = true
        } else {
            spinner.stopAnimating()
            iconView.isHidden = systemIcon == nil
            if let systemIcon {
                iconView.image = UIImage(systemName: systemIcon)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 44, weight: .bold))
                iconView.tintColor = iconTint
            }
            primaryButton.isHidden = false
        }
    }

    private func showReady() {
        setState(loading: false,
                 title: "Import this reel",
                 message: "Tap below to open CraveCircle and turn this reel into a recipe — it only takes a few seconds.",
                 systemIcon: "checkmark.circle.fill",
                 iconTint: UIColor(red: 0.42, green: 0.78, blue: 0.44, alpha: 1))
        primaryButton.setTitle("Open CraveCircle", for: .normal)
    }

    private func showError(_ message: String) {
        setState(loading: false,
                 title: "Couldn't import",
                 message: message,
                 systemIcon: "exclamationmark.triangle.fill",
                 iconTint: UIColor(red: 0.90, green: 0.35, blue: 0.30, alpha: 1))
        primaryButton.setTitle("Close", for: .normal)
    }

    @objc private func primaryTapped() {
        // User-initiated open into the app (best-effort). Delay completeRequest so dismissing the
        // extension doesn't cancel the pending openURL. The import is already running server-side,
        // so even if the switch doesn't happen, the recipe still shows up on next open.
        if sharedURL != nil { openHostApp() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.finish() }
    }

    // MARK: UI build

    private func buildUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        card.backgroundColor = UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = true
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        primaryButton.setTitle("Done", for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        primaryButton.setTitleColor(.black, for: .normal)
        primaryButton.backgroundColor = .white
        primaryButton.layer.cornerRadius = 22
        primaryButton.layer.cornerCurve = .continuous
        primaryButton.isHidden = true
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [spinner, iconView, titleLabel, messageLabel, primaryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

            iconView.heightAnchor.constraint(equalToConstant: 48),
            primaryButton.heightAnchor.constraint(equalToConstant: 44),
            primaryButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }
}
