import Foundation
import HealthKit

// MARK: - Workout Analyzer

enum VSLAnalyzer {
    static func distanceType(
        _ activity: HKWorkoutActivityType
    ) -> HKQuantityTypeIdentifier? {
        switch activity {
        case .running, .walking, .hiking:
            return .distanceWalkingRunning
        case .cycling:
            return .distanceCycling
        case .swimming:
            return .distanceSwimming
        default:
            return nil
        }
    }

    static func records(
        _ data: VSLWorkoutData,
        _ identifier: HKQuantityTypeIdentifier
    ) -> [HKQuantitySample] {
        let all = data.samples[identifier.rawValue] ?? []

        let source = data.workout.sourceRevision
            .source.bundleIdentifier

        let matching = all.filter {
            $0.sourceRevision.source.bundleIdentifier == source
        }

        if !matching.isEmpty { return matching }

        let groups = Dictionary(
            grouping: all,
            by: { $0.sourceRevision.source.bundleIdentifier }
        )

        return groups.values.max {
            $0.count < $1.count
        } ?? []
    }

    static func hasOverlap(
        _ samples: [HKQuantitySample],
        start: Date,
        end: Date
    ) -> Bool {
        let intervals = samples.compactMap {
            sample -> (Date, Date)? in
            let a = max(start, sample.startDate)
            let b = min(end, sample.endDate)
            return b > a ? (a, b) : nil
        }.sorted { $0.0 < $1.0 }

        var previous: Date?

        for (a, b) in intervals {
            if let previous,
               a.timeIntervalSince(previous) < -0.5 {
                return true
            }
            previous = max(previous ?? b, b)
        }

        return false
    }

    static func total(
        _ samples: [HKQuantitySample],
        start: Date,
        end: Date,
        unit: HKUnit
    ) -> Double? {
        guard !samples.isEmpty,
              !hasOverlap(samples, start: start, end: end)
        else { return nil }

        var total = 0.0
        var found = false

        for sample in samples {
            let a = max(start, sample.startDate)
            let b = min(end, sample.endDate)
            let original = sample.endDate.timeIntervalSince(
                sample.startDate
            )

            guard b > a, original > 0 else { continue }

            let fraction = b.timeIntervalSince(a) / original
            total += sample.quantity.doubleValue(for: unit) * fraction
            found = true
        }

        return found ? total : nil
    }

    static func averageHR(
        _ samples: [HKQuantitySample],
        start: Date,
        end: Date
    ) -> Double? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        var weighted = 0.0
        var duration = 0.0

        for sample in samples {
            let a = max(start, sample.startDate)
            let b = min(end, sample.endDate)
            guard b > a else { continue }

            let weight = b.timeIntervalSince(a)
            weighted += sample.quantity.doubleValue(for: unit) * weight
            duration += weight
        }

        return duration > 0 ? weighted / duration : nil
    }

    static func crossing(
        _ target: Double,
        data: VSLWorkoutData
    ) -> Date? {
        if target == 0 { return data.workout.startDate }

        guard target > 0,
              let type = distanceType(
                data.workout.workoutActivityType
              ) else { return nil }

        let samples = records(data, type).sorted {
            $0.startDate < $1.startDate
        }

        guard !hasOverlap(
            samples,
            start: data.workout.startDate,
            end: data.workout.endDate
        ) else { return nil }

        var accumulated = 0.0

        for sample in samples {
            let a = max(sample.startDate, data.workout.startDate)
            let b = min(sample.endDate, data.workout.endDate)
            let original = sample.endDate.timeIntervalSince(
                sample.startDate
            )

            guard b > a, original > 0 else { continue }

            let meters = sample.quantity.doubleValue(
                for: .meter()
            ) * b.timeIntervalSince(a) / original

            guard meters > 0 else { continue }

            if accumulated + meters >= target {
                let fraction = (target - accumulated) / meters
                return a.addingTimeInterval(
                    b.timeIntervalSince(a) * fraction
                )
            }

            accumulated += meters
        }

        return nil
    }

    static func pauseDuration(
        workout: HKWorkout,
        start: Date,
        end: Date
    ) -> (seconds: Double, complete: Bool) {
        let events = (workout.workoutEvents ?? [])
            .filter {
                ($0.type == .pause || $0.type == .resume) &&
                $0.dateInterval.start <= end
            }
            .sorted {
                $0.dateInterval.start < $1.dateInterval.start
            }

        var openPause: Date?
        var paused = 0.0
        var complete = true

        for event in events {
            let date = event.dateInterval.start

            if event.type == .pause {
                if openPause == nil {
                    openPause = date
                } else {
                    complete = false
                }
            } else if let pauseStart = openPause {
                paused += max(
                    0,
                    min(end, date).timeIntervalSince(
                        max(start, pauseStart)
                    )
                )
                openPause = nil
            } else {
                complete = false
            }
        }

        if openPause != nil { complete = false }

        return (paused, complete)
    }

    static func analyze(
        _ data: VSLWorkoutData,
        start: Date,
        end: Date
    ) -> VSLAnalysis {
        let workout = data.workout
        let duration = end.timeIntervalSince(start)

        let full =
            abs(start.timeIntervalSince(workout.startDate)) < 0.001 &&
            abs(end.timeIntervalSince(workout.endDate)) < 0.001

        let distanceSamples = distanceType(
            workout.workoutActivityType
        ).map { records(data, $0) } ?? []

        var distance = total(
            distanceSamples,
            start: start,
            end: end,
            unit: .meter()
        )

        if full, let official = workout.totalDistance {
            distance = official.doubleValue(for: .meter())
        }

        let energy = total(
            records(data, .activeEnergyBurned),
            start: start,
            end: end,
            unit: .kilocalorie()
        )

        let steps = total(
            records(data, .stepCount),
            start: start,
            end: end,
            unit: .count()
        )

        let strokes = total(
            records(data, .swimmingStrokeCount),
            start: start,
            end: end,
            unit: .count()
        )

        var swimTime: Double?
        var restTime: Double?
        var pausedTime: Double?
        var swimPace: Double?

        if workout.workoutActivityType == .swimming,
           !distanceSamples.isEmpty,
           !hasOverlap(
                distanceSamples,
                start: start,
                end: end
           ) {

            let intervals = distanceSamples.compactMap {
                sample -> (Date, Date)? in
                let a = max(start, sample.startDate)
                let b = min(end, sample.endDate)
                return b > a ? (a, b) : nil
            }

            let rawSwim = intervals.reduce(0.0) {
                $0 + $1.1.timeIntervalSince($1.0)
            }

            let pauses = pauseDuration(
                workout: workout,
                start: start,
                end: end
            )

            if pauses.complete,
               rawSwim + pauses.seconds <= duration + 1 {
                swimTime = rawSwim
                pausedTime = pauses.seconds
                restTime = max(
                    0,
                    duration - rawSwim - pauses.seconds
                )

                if let distance, distance > 0 {
                    swimPace = rawSwim / distance * 100
                }
            }
        }

        return VSLAnalysis(
            duration: duration,
            distance: distance,
            heartRate: averageHR(
                records(data, .heartRate),
                start: start,
                end: end
            ),
            energy: energy,
            steps: steps,
            strokes: strokes,
            swimmingTime: swimTime,
            restTime: restTime,
            pausedTime: pausedTime,
            swimmingPace: swimPace
        )
    }
}
