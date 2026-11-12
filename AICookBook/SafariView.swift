//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: SafariView.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the SafariView user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "SafariView is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  SafariView.swift
//  CraveCircle (AICookBook)
//
//  In-app Safari sheet to watch source reels and creator videos.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
