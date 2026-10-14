import SwiftUI

extension ContentView {
    var healthContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 7) {
                ForEach(VSLHealthSection.allCases, id: \.self) { section in
                    Button {
                        focusedField = nil
                        healthSection = section
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 10, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(healthSection == section ? VSL.background : .white)
                            .background(healthSection == section ? VSL.lime : VSL.card,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            switch healthSection {
            case .nutrition: nutritionContent
            case .weight: weightContent
            case .medications: medicationsContent
            }
        }
    }
}
