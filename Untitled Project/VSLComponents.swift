import SwiftUI

// MARK: - Reusable UI

struct VSLSection: View {
    let title: String
    let number: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
            Spacer()
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.8)
        .foregroundStyle(VSL.muted)
        .padding(.vertical, 5)
    }
}

struct VSLMetricGrid: View {
    let metrics: [VSLMetric]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 9
        ) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 12) {
                    Text(metric.id.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VSL.muted)

                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: 4
                    ) {
                        Text(metric.value)
                            .font(.system(
                                size: 25,
                                weight: .black,
                                design: .default
                            ))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(metric.unit)
                            .font(.system(
                                size: 10,
                                weight: .bold
                            ))
                            .foregroundStyle(VSL.muted)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(15)
                .background(
                    VSL.card,
                    in: RoundedRectangle(cornerRadius: 13)
                )
            }
        }
    }
}
