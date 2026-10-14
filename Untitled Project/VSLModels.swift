import SwiftUI
import HealthKit

// MARK: - Navigation

enum VSLTab: String, CaseIterable {
    case focus = "FOCUS"
    case performance = "PERFORMANCE"
    case health = "HEALTH"
    case sleep = "SLEEP"
    case journal = "JOURNAL"

    var icon: String {
        switch self {
        case .performance: return "figure.run"
        case .health: return "heart.fill"
        case .sleep: return "moon.fill"
        case .journal: return "book.closed.fill"
        case .focus: return "chart.bar.xaxis"
        }
    }
}

enum VSLPeriod: String, CaseIterable {
    case today = "TODAY"
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case custom = "CUSTOM"
}

struct VSLMetric: Identifiable {
    let id: String
    let value: String
    let unit: String
}

struct VSLWorkoutData {
    let workout: HKWorkout
    let samples: [String: [HKQuantitySample]]
}

struct VSLAnalysis {
    let duration: Double
    let distance: Double?
    let heartRate: Double?
    let energy: Double?
    let steps: Double?
    let strokes: Double?
    let swimmingTime: Double?
    let restTime: Double?
    let pausedTime: Double?
    let swimmingPace: Double?
}

// MARK: - Local Lists (stored on this iPhone)

struct VSLMedication: Identifiable, Codable {
    var id = UUID()
    var name: String
    var details: String
}

struct VSLMedicationLog: Identifiable, Codable {
    var id = UUID()
    var medicationID: UUID
    var date: Date
}


enum VSLHealthSection: String, CaseIterable {
    case weight = "WEIGHT"
    case bloodPressure = "BLOOD PRESSURE"
    case heart = "HEART RATE"
    case nutrition = "NUTRITION"
    case medications = "MEDS"
}
