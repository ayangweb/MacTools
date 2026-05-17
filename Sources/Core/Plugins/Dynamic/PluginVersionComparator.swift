import Foundation

enum PluginVersionComparator {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue < rightValue {
                return .orderedAscending
            }

            if leftValue > rightValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    static func isVersion(_ version: String, atLeast required: String) -> Bool {
        compare(version, required) != .orderedAscending
    }

    static func isVersion(_ version: String, newerThan current: String) -> Bool {
        compare(version, current) == .orderedDescending
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { component in
                let prefix = component.prefix { $0.isNumber }
                return Int(prefix) ?? 0
            }
    }
}
