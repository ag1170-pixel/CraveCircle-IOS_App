//
//  ShareViewController.swift
//  CraveCircle Share Extension
//
//  Lets users share a cooking video from Instagram / YouTube / TikTok / Facebook straight into
//  CraveCircle. It fires the import on the SERVER and dismisses — the server transcribes in the
//  background whether or not the app is open, then (once APNs is configured) pushes "recipe ready".
//  No app switch, exactly like sharing IG → WhatsApp. The URL is also stashed in the App Group as a
//  fallback so the app still picks it up on next open before push is live.
//

import UIKit
import UniformTypeIdentifiers
import ActivityKit

final class ShareViewController: UIViewController {

    // Must match AppEnvironment.appGroupID / pendingImportKey in the main app.
    private let appGroupID = "group.com.anassyed.AICookBook"
    private let pendingKey = "pending_import_url"
    // The import backend (same as AppConfig.defaultHost). We fire the import SERVER-SIDE and finish —
    // the server transcribes in the background and (once APNs is live) pushes "recipe ready". The
    // user never has to open the app, exactly like sharing IG → WhatsApp.
    private let backendURL = "https://import.cravecircle.cc"

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

    private func deliver(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty else {
            return showError("Couldn't find a video link in this share.")
        }
        
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attrs = CookingImportAttributes(startedAt: Date())
            let content = CookingImportAttributes.ContentState(
                stage: .downloading, recipeTitle: "New recipe", recipeId: nil,
                estimatedEnd: Date().addingTimeInterval(45), message: nil)
            do {
                _ = try Activity.request(
                    attributes: attrs,
                    content: ActivityContent(state: content, staleDate: nil),
                    pushType: .token)
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }
        
        // Fire the import ON THE SERVER and finish. /reels/import returns immediately (job queued);
        // the server transcribes in the background regardless of whether the app is open.
        guard let endpoint = URL(string: "\(backendURL)/reels/import") else {
            return showError("Something went wrong. Please try again.")
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Attribute the import to the signed-in user (written to the App Group by the app) so the
        // "recipe ready" push targets only their devices — never everyone's.
        // Import in the user's chosen Recipe Language (mirrored into the App Group by the app).
        let lang = UserDefaults(suiteName: appGroupID)?.string(forKey: "shared_recipe_language") ?? "en"
        var payload: [String: Any] = ["url": urlString, "target_language": lang]
        if let uid = UserDefaults(suiteName: appGroupID)?.string(forKey: "shared_user_id"), !uid.isEmpty {
            payload["user_id"] = uid
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 25
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if err == nil, (200..<300).contains(code) {
                    // Save the job_id so the main app can fetch the FINISHED recipe instead of re-running on-device!
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let jobId = json["job_id"] as? String,
                       let defaults = UserDefaults(suiteName: self?.appGroupID) {
                        defaults.set(jobId, forKey: "pending_import_job")
                        // Clear the fallback URL since we successfully started a server job
                        defaults.removeObject(forKey: self?.pendingKey ?? "")
                    } else if let defaults = UserDefaults(suiteName: self?.appGroupID) {
                        // Fallback: server succeeded but no job id? Stash URL for on-device run
                        defaults.set(urlString, forKey: self?.pendingKey ?? "")
                    }
                    self?.showReady()
                } else {
                    // Fallback to on-device import if server fails to accept the job
                    if let defaults = UserDefaults(suiteName: self?.appGroupID) {
                        defaults.set(urlString, forKey: self?.pendingKey ?? "")
                    }
                    self?.showReady() // Still say "On it!" so they aren't blocked, app will do it later
                }
            }
        }.resume()
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
                 title: "On it! 🍳",
                 message: "We're turning this reel into a recipe in the background — no need to keep the app open. We'll notify you the moment it's ready, and you'll find it in your CraveCircle library.",
                 systemIcon: "checkmark.circle.fill",
                 iconTint: UIColor(red: 0.42, green: 0.78, blue: 0.44, alpha: 1))
        primaryButton.setTitle("Done", for: .normal)
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
        // Just dismiss the share sheet — the import is already running on the server and will notify
        // when ready. No app switch (that's the whole point: like sharing IG → WhatsApp).
        finish()
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
