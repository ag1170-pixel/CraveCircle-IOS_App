//
//  LocalLegalDocumentView.swift
//  CraveCircle
//
//  Displays the bundled legal document directly in the app. This deliberately
//  avoids a web URL, account check, or external browser for Privacy and Terms.
//

import PDFKit
import SwiftUI

enum LocalLegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Notice"
        case .terms: return "Terms of Service"
        }
    }

    /// The bundled document places the Terms at the third PDF page.
    var initialPageIndex: Int {
        switch self {
        case .privacy: return 0
        case .terms: return 2
        }
    }
}

struct LocalLegalDocumentView: View {
    let document: LocalLegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BundledPDFView(initialPageIndex: document.initialPageIndex)
                .background(AppTheme.background)
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
    }
}

private struct BundledPDFView: UIViewRepresentable {
    let initialPageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground

        guard let url = Bundle.main.url(
            forResource: "CraveCircle Privacy Notice and Terms Draft",
            withExtension: "pdf",
            subdirectory: "Legal"
        ) ?? Bundle.main.url(
            forResource: "CraveCircle Privacy Notice and Terms Draft",
            withExtension: "pdf"
        ), let document = PDFDocument(url: url) else {
            return view
        }

        view.document = document
        if let page = document.page(at: min(initialPageIndex, max(0, document.pageCount - 1))) {
            view.go(to: page)
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
