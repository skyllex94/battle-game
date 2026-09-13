import SpriteKit
import SwiftUI

/// Loads art imported from the InvaderPush Unity project.
/// Files live in `Art/Imported/...` (filesystem-synced group, copied as bundle resources).
/// Tries `UIImage(named:)` first, then falls back to an explicit bundle-path lookup so
/// subdirectory structure never breaks image loading.
///
/// NOTE: SpriteKit's `SKTexture(imageNamed:)` fails on loose JPGs in the bundle
/// (verified: `SKTexture: Error loading image resource: "MapBG"`), so all scene
/// textures must go through `skTexture(named:)` (UIImage-backed) instead.
enum ImportedArt {
    static func uiImage(named name: String, extensions: [String] = ["png", "jpg"]) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                if let img = UIImage(contentsOfFile: url.path) { return img }
            }
            // Search inside Art/Imported subfolders by filename scan (cheap, cached by system).
            if let url = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil)?
                .first(where: { $0.deletingPathExtension().lastPathComponent == name }),
               let img = UIImage(contentsOfFile: url.path) {
                return img
            }
        }
        return nil
    }

    static func image(named name: String) -> Image {
        if let img = uiImage(named: name) { return Image(uiImage: img) }
        return Image(systemName: "photo")
    }

    /// UIImage-backed SpriteKit texture. Always use this instead of
    /// `SKTexture(imageNamed:)` for imported art.
    static func skTexture(named name: String) -> SKTexture {
        if let img = uiImage(named: name) {
            return SKTexture(image: img)
        }
        // Loud fallback: magenta square so a missing asset is obvious on screen.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let img = renderer.image { ctx in
            UIColor.magenta.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return SKTexture(image: img)
    }
}
