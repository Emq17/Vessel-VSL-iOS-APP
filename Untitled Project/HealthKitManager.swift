import Foundation
import HealthKit
import Combine

// MARK: - HealthKit Store

@MainActor
final class VSLHealthStore: ObservableObject {
    @Published var workouts: [HKWorkout] = []
    @Published var connected = false
    @Published var loading = false
    @Published var error: String?

    let store = HKHealthStore()
    var cache: [UUID: VSLWorkoutData] = [:]

    static let quantities: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .activeEnergyBurned,
        .stepCount,
        .swimmingStrokeCount,
        .distanceWalkingRunning,
        .distanceCycling,
        .distanceSwimming,
        .dietaryEnergyConsumed,
        .dietaryCarbohydrates,
        .dietaryProtein,
        .dietaryFatTotal,
        .bodyMass
    ]

    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "Apple Health is unavailable on this device."
            return
        }

        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        for identifier in Self.quantities {
            if let type = HKObjectType.quantityType(
                forIdentifier: identifier
            ) {
                readTypes.insert(type)
            }
        }

        loading = true
        error = nil

        store.requestAuthorization(
            toShare: [],
            read: readTypes
        ) { [weak self] _, requestError in
            Task { @MainActor in
                guard let self else { return }
                self.loading = false

                if let requestError {
                    self.error = requestError.localizedDescription
                    return
                }

                self.connected = true
                self.refresh()
            }
        }
    }

    func refresh() {
        loading = true

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [
                NSSortDescriptor(
                    key: HKSampleSortIdentifierEndDate,
                    ascending: false
                )
            ]
        ) { [weak self] _, samples, queryError in
            Task { @MainActor in
                guard let self else { return }
                self.loading = false

                if let queryError {
                    self.error = queryError.localizedDescription
                    return
                }

                self.workouts = (samples as? [HKWorkout]) ?? []
            }
        }

        store.execute(query)
    }

    func loadWorkout(
        _ workout: HKWorkout,
        completion: @escaping (Result<VSLWorkoutData, Error>) -> Void
    ) {
        if let cached = cache[workout.uuid] {
            completion(.success(cached))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()

        var collected: [String: [HKQuantitySample]] = [:]
        var failure: Error?

        for identifier in Self.quantities.prefix(7) {
            guard let type = HKObjectType.quantityType(
                forIdentifier: identifier
            ) else { continue }

            group.enter()

            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: []
            )

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                lock.lock()
                collected[type.identifier] =
                    (samples as? [HKQuantitySample]) ?? []
                if failure == nil { failure = error }
                lock.unlock()
                group.leave()
            }

            store.execute(query)
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }

            if let failure {
                completion(.failure(failure))
                return
            }

            let result = VSLWorkoutData(
                workout: workout,
                samples: collected
            )

            self.cache[workout.uuid] = result
            completion(.success(result))
        }
    }

    func queryQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        completion: @escaping ([HKQuantitySample]) -> Void
    ) {
        guard let type = HKObjectType.quantityType(
            forIdentifier: identifier
        ) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )

        store.execute(
            HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                DispatchQueue.main.async {
                    completion((samples as? [HKQuantitySample]) ?? [])
                }
            }
        )
    }

    func querySleep(
        start: Date,
        end: Date,
        completion: @escaping ([HKCategorySample]) -> Void
    ) {
        let type = HKObjectType.categoryType(
            forIdentifier: .sleepAnalysis
        )!

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )

        store.execute(
            HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                DispatchQueue.main.async {
                    completion((samples as? [HKCategorySample]) ?? [])
                }
            }
        )
    }
}

@available(iOS 26.0, *)
extension VSLHealthStore {
    func requestMedicationReadAccess() async throws {
        try await store.requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate: nil)
    }

    func readMedicationNames() async throws -> [String] {
        let descriptor = HKUserAnnotatedMedicationQueryDescriptor()
        let results = try await descriptor.result(for: store)
        return Array(Set(results.filter { !$0.isArchived }.map {
            let nickname = $0.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return nickname.isEmpty ? $0.medication.displayText : nickname
        })).sorted()
    }
}
