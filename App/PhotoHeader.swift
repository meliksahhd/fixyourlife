import SwiftUI

/// Önbellekteki fotoğraf, alttan zemine kararan degrade ve Unsplash atfı. Fotoğraf yoksa hiçbir şey çizmez.
struct PhotoHeader: View {
    @EnvironmentObject var model: AppModel
    let photoId: String?
    let height: CGFloat

    var body: some View {
        // ponytail: her çizimde diskten okunur; takılma olursa id'ye göre bellekte tut.
        if let id = photoId, let url = model.photos.fileURL(id), let image = UIImage(contentsOfFile: url.path) {
            Color.clear.frame(maxWidth: .infinity).frame(height: height)
                .overlay { Image(uiImage: image).resizable().scaledToFill().accessibilityHidden(true) }
                .clipped()
                .overlay { LinearGradient(colors: [.clear, Theme.bg], startPoint: .center, endPoint: .bottom).allowsHitTesting(false) }
                .overlay(alignment: .bottomTrailing) {
                    if let m = model.photos.meta(id),
                       let link = URL(string: m.profileURL + "?utm_source=fixyourlife&utm_medium=referral") {
                        Link("Foto: \(m.photographer) / Unsplash", destination: link)
                            .font(.caption2).foregroundStyle(Theme.secondary).padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
        }
    }
}
