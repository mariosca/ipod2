import PhotosUI
import SwiftUI
import UIKit

/// La foto tonda accanto al titolo. Toccandola si sceglie una foto dalla
/// galleria; resta salvata nell'app. Tenendola premuta si può rimuovere.
@MainActor
struct ProfilePhotoButton: View {
    @AppStorage("profilePhoto") private var photoData = Data()
    @State private var selection: PhotosPickerItem?

    private let size: CGFloat = 34

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            avatar
        }
        .accessibilityLabel(photoData.isEmpty ? "Scegli la tua foto" : "Cambia la tua foto")
        .contextMenu {
            if !photoData.isEmpty {
                Button("Rimuovi foto", systemImage: "trash", role: .destructive) {
                    photoData = Data()
                }
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let small = Self.thumbnail(from: data) {
                    photoData = small
                }
                selection = nil
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.brand, lineWidth: 1.5))
        } else {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 22))
                .foregroundStyle(Color.brand)
                .frame(width: size, height: size)
                .background(Color.brand.opacity(0.1), in: Circle())
        }
    }

    /// Riduce la foto a un quadrato di 240 pixel, per non appesantire l'app.
    private static func thumbnail(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 240
        let scale = max(side / image.size.width, side / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let square = renderer.image { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: 0.85)
    }
}
