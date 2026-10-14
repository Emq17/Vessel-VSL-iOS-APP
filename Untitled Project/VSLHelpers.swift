import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Helper

    func notice(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(VSL.muted)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(16)
            .background(
                VSL.card,
                in: RoundedRectangle(cornerRadius: 12)
            )
    }
}
