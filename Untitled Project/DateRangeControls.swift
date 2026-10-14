import SwiftUI

extension ContentView {
    func periodControls(for section: VSLHealthSection? = nil) -> some View {
        let period: Binding<VSLPeriod>
        let start: Binding<Date>
        let end: Binding<Date>
        if section == .nutrition {
            period = $nutritionPeriod; start = $nutritionCustomStart; end = $nutritionCustomEnd
        } else if section == .weight {
            period = $weightPeriod; start = $weightCustomStart; end = $weightCustomEnd
        } else {
            period = $sleepPeriod; start = $sleepCustomStart; end = $sleepCustomEnd
        }
        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(VSLPeriod.allCases, id: \.self) { item in
                    Button {
                        if section == nil { selectedSleepWakeDate = nil }
                        else { selectedHealthDay = nil }
                        period.wrappedValue = item
                    } label: {
                        Text((section == nil || section == .nutrition) && item == .today ? "LATEST" : item.rawValue)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(period.wrappedValue == item ? VSL.background : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(period.wrappedValue == item ? VSL.lime : VSL.card,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            if period.wrappedValue == .custom {
                DatePicker("From", selection: start, displayedComponents: .date)
                DatePicker("Through", selection: end,
                           in: start.wrappedValue..., displayedComponents: .date)
            }
        }
    }
}
