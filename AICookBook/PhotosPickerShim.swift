#if XTOOL_WSL
import SwiftUI
import UniformTypeIdentifiers

/// Stubs PhotosUI types so xtool can compile without a working Photos picker (actool/PhotosUI gap).
struct PhotosPickerItem: Identifiable, Equatable {
    let id = UUID()
    func loadTransferable<T>(type: T.Type) async throws -> T? { nil }
}

struct PhotosPicker<Label: View>: View {
    var label: Label
    init(
        selection: Binding<PhotosPickerItem?>,
        matching: PHPickerFilter = .images,
        photoLibrary: PHPickerPhotoLibrary = .shared(),
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
    }
    init(
        selection: Binding<[PhotosPickerItem]>,
        maxSelectionCount: Int = 1,
        matching: PHPickerFilter = .images,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
    }
    var body: some View { label }
}

struct PHPickerFilter {
    static let images = PHPickerFilter()
    static let videos = PHPickerFilter()
}

struct PHPickerPhotoLibrary {
    static func shared() -> PHPickerPhotoLibrary { PHPickerPhotoLibrary() }
}
#endif
