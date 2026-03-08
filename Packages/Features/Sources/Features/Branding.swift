import AppKit
import SwiftUI

public enum DeployBarBrand {
    public static let iconResourceName = "AppIcon"
    private static let cachedMainIcon: NSImage? = {
        guard let path = Bundle.main.path(forResource: iconResourceName, ofType: "icns") else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }()

    public static func appIconImage(bundle: Bundle = .main) -> NSImage? {
        if bundle == .main {
            return cachedMainIcon
        }

        guard let path = bundle.path(forResource: iconResourceName, ofType: "icns") else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }

    public static func menuBarSymbolImage(pointSize: CGFloat = 256) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return NSImage(systemSymbolName: "triangle.fill", accessibilityDescription: "DeployBar")
            .flatMap { $0.withSymbolConfiguration(configuration) }
    }
}

public struct DeployBarBrandMark: View {
    let size: CGFloat

    public init(size: CGFloat = 24) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let icon = DeployBarBrand.appIconImage() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "triangle.fill")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.20))
                    .padding(size * 0.16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}
