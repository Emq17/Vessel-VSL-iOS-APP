import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Header & Bottom Navigation

    var brandHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("VSL")
                .font(.system(
                    size: 39,
                    weight: .black,
                    design: .rounded
                ))
                .italic()
                .tracking(-2)

            Spacer()

            Text("EVERY EFFORT. EVERY DETAIL.")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(VSL.lime)
        }
    }

    var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(VSLTab.allCases, id: \.self) { item in
                Button {
                    focusedField = nil
                    tab = item
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))

                        Text(item.rawValue)
                            .font(.system(
                                size: 9,
                                weight: .bold
                            ))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Capsule()
                            .fill(
                                tab == item
                                    ? VSL.lime
                                    : Color.clear
                            )
                            .frame(width: 23, height: 2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.black)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
    }


}
