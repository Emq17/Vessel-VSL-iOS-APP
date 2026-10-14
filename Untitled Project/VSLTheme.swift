import SwiftUI

// MARK: - VSL Design

enum VSL {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.055)
    static let card = Color(red: 0.105, green: 0.125, blue: 0.145)
    static let lime = Color(red: 0.81, green: 0.99, blue: 0.19)
    static let cyan = lime
    static let orange = lime
    static let purple = lime
    static let muted = Color(red: 0.65, green: 0.70, blue: 0.74)
}

enum VSLFormat {
    static func time(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        let seconds = Int(value.rounded())
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d",
                          seconds / 3600,
                          seconds % 3600 / 60,
                          seconds % 60)
        }
        return String(format: "%02d:%02d",
                      seconds / 60,
                      seconds % 60)
    }

    static func number(_ value: Double?, decimals: Int = 0) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.*f", decimals, value)
    }

    static func seconds(_ text: String) -> Double? {
        let parts = text.split(
            separator: ":",
            omittingEmptySubsequences: false
        )
        guard (1...3).contains(parts.count) else { return nil }

        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count,
              values.allSatisfy({ $0 >= 0 }) else { return nil }

        if values.count == 1 { return Double(values[0]) }
        if values.count == 2 {
            guard values[1] < 60 else { return nil }
            return Double(values[0] * 60 + values[1])
        }

        guard values[1] < 60, values[2] < 60 else { return nil }
        return Double(
            values[0] * 3600 + values[1] * 60 + values[2]
        )
    }
}
