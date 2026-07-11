import AppKit

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
}
