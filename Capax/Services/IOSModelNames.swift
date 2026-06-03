import Foundation

/// Maps Apple `ProductType` identifiers (e.g. "iPhone15,2") to marketing names. Covers recent
/// iPhones/iPads; unknown identifiers fall back to a readable family guess rather than failing.
enum IOSModelNames {
    static func name(for productType: String) -> String {
        if let exact = table[productType] { return exact }
        // Graceful fallback: "iPhone15,2" -> "iPhone", "iPad13,1" -> "iPad".
        if productType.hasPrefix("iPhone") { return "iPhone" }
        if productType.hasPrefix("iPad") { return "iPad" }
        if productType.hasPrefix("iPod") { return "iPod touch" }
        return productType
    }

    private static let table: [String: String] = [
        // iPhone 12–16 families (representative; extend as needed)
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone14,6": "iPhone SE (3rd gen)",
        // iPad (representative)
        "iPad13,16": "iPad Air (5th gen)", "iPad13,18": "iPad (10th gen)",
        "iPad14,3": "iPad Pro 11\" (4th gen)", "iPad14,5": "iPad Pro 12.9\" (6th gen)",
        "iPad16,3": "iPad Pro 11\" (M4)", "iPad16,5": "iPad Pro 13\" (M4)",
    ]
}
