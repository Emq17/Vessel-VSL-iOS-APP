import SwiftUI
import HealthKit

// MARK: - Main App

struct ContentView: View {
    @StateObject var health = VSLHealthStore()
    @StateObject var focusStore = VSLFocusStore()
    @StateObject var journalStore = VSLJournalStore()
    @Environment(\.scenePhase) var scenePhase
    @State var newFocusTask = ""
    @State var selectedFocusDay = Calendar.current.startOfDay(for: Date())
    @State var focusCalendarMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State var focusCalendarExpanded = true
    @State var editingFocusTask = false
    @State var editingFocusTaskID: UUID?
    @State var editedFocusTaskTitle = ""

    @State var tab: VSLTab = .focus
    @State var journalDay = Calendar.current.startOfDay(for: .now)
    @State var journalMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State var healthSection: VSLHealthSection = .weight
        @State var selectedWorkoutID: UUID?

    @State var workoutData: VSLWorkoutData?
    @State var analysis: VSLAnalysis?
    @State var loadingWorkout = false
    @State var analysisError: String?

    @State var custom = false
    @State var byDistance = true
    @State var distanceUnit = "m"
    @State var startText = "0"
    @State var endText = "400"
    @State var appliedRange = "FULL WORKOUT"

    @State var milestones: Set<Double> = [
        400, 800, 1000, 1600, 1609.344
    ]
    @State var editingMilestones = false
    @State var milestoneUnit = "m"
    @State var newMilestone = ""

    @State var nutritionPeriod: VSLPeriod = .today
    @State var weightPeriod: VSLPeriod = .today
    @State var sleepPeriod: VSLPeriod = .today
    @State var selectedSleepWakeDate: Date? = nil
    @State var sleepCalendarMonth: Date = .now
    @State var sleepCalendarExpanded = true
    @State var healthCalendarExpanded = true
    @State var healthCalendarMonth: Date = .now
    @State var selectedHealthDay: Date? = nil
    @State var nutritionCustomStart =
        Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: .now
        ) ?? .now
    @State var nutritionCustomEnd = Date()
    @State var weightCustomStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State var weightCustomEnd = Date()
    @State var sleepCustomStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State var sleepCustomEnd = Date()

    @State var nutrition:
        [HKQuantityTypeIdentifier: [HKQuantitySample]] = [:]
    @State var sleepSamples: [HKCategorySample] = []
    @State var weightSamples: [HKQuantitySample] = []
    @State var weightNutrition: [HKQuantityTypeIdentifier: [HKQuantitySample]] = [:]

    @State var medications: [VSLMedication] = []
    @State var medicationLogs: [VSLMedicationLog] = []
    @State var medicationName = ""
    @State var medicationDetails = ""
    @State var healthMedicationNames: [String] = []
    @State var medicationSyncError: String?
    @State var medicationSyncLoading = false


    @FocusState var focusedField: String?

    let metersPerMile = 1609.344

    var sportIDs: [UInt] {
        Array(
            Set(
                health.workouts.map {
                    $0.workoutActivityType.rawValue
                }
            )
        ).sorted()
    }

    var selectedWorkout: HKWorkout? {
        health.workouts.first { $0.uuid == selectedWorkoutID }
    }

    func range(for section: VSLHealthSection? = nil) -> (Date, Date) {
        let choice: VSLPeriod
        let from: Date
        let through: Date
        if section == .nutrition {
            choice = nutritionPeriod; from = nutritionCustomStart; through = nutritionCustomEnd
        } else if section == .weight {
            choice = weightPeriod; from = weightCustomStart; through = weightCustomEnd
        } else {
            choice = sleepPeriod; from = sleepCustomStart; through = sleepCustomEnd
        }
        let calendar = Calendar.current
        if choice == .custom {
            let start = calendar.startOfDay(for: from)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: through)) ?? through
            return (start, end)
        }
        if choice == .today {
            let today = calendar.startOfDay(for: .now)
            // A night's sleep often begins yesterday and ends this morning.
            let start = section == nil ? today.addingTimeInterval(-12 * 3600) : today
            return (start, .now)
        }
        let days = choice == .week ? 7 : choice == .month ? 30 : 90
        let start = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: .now)) ?? .now
        return (start, .now)
    }

    var dateRange: (Date, Date) {
        range(for: tab == .sleep ? nil : healthSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    brandHeader

                    switch tab {
                    case .performance:
                        performanceContent
                    case .health:
                        healthContent
                    case .sleep:
                        sleepContent
                    case .journal:
                        journalContent
                    case .focus:
                        focusContent
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 16)
                .padding(.bottom, 35)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomNavigation
        }
        .background(VSL.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .tint(VSL.lime)
            }
        }
        .onAppear {
            restoreLocalData()
            if selectedWorkoutID == nil {
                selectedWorkoutID = health.workouts.first?.uuid
            }
            if !health.connected && !health.loading {
                health.connect()
            }
        }
        .onChange(of: health.connected) { _, connected in
            if connected { loadLifestyle() }
        }
        .onChange(of: health.workouts) { _, workouts in
            if selectedWorkoutID == nil {
                selectedWorkoutID = workouts.first?.uuid
            }
        }
        .onChange(of: selectedWorkoutID) { _, _ in
            loadWorkout()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .health || newTab == .sleep {
                loadLifestyle()
            }
        }
        .onChange(of: healthSection) { _, _ in
            if tab == .health { loadLifestyle() }
        }
        .onChange(of: nutritionPeriod) { _, _ in loadLifestyle() }
        .onChange(of: weightPeriod) { _, _ in loadLifestyle() }
        .onChange(of: sleepPeriod) { _, _ in loadLifestyle() }
        .onChange(of: nutritionCustomStart) { _, _ in loadLifestyle() }
        .onChange(of: nutritionCustomEnd) { _, _ in loadLifestyle() }
        .onChange(of: weightCustomStart) { _, _ in loadLifestyle() }
        .onChange(of: weightCustomEnd) { _, _ in loadLifestyle() }
        .onChange(of: sleepCustomStart) { _, _ in loadLifestyle() }
        .onChange(of: sleepCustomEnd) { _, _ in loadLifestyle() }
    }


}

#Preview {
    ContentView()
}
