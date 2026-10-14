import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Medications

    var medicationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VSLSection(title: "MEDICATIONS", number: "01", color: VSL.lime)
            Text("STAY CONSISTENT.")
                .font(.system(size: 27, weight: .black))
            let today = Calendar.current.startOfDay(for: .now)
            let takenToday = medications.filter { medication in
                medicationLogs.contains {
                    $0.medicationID == medication.id && Calendar.current.isDate($0.date, inSameDayAs: today)
                }
            }.count
            VSLMetricGrid(metrics: [
                VSLMetric(id: "Marked today", value: "\(takenToday)", unit: "of \(medications.count)"),
                VSLMetric(id: "Recorded check-ins", value: "\(medicationLogs.count)", unit: "")
            ])
            if #available(iOS 26.0, *) {
                Button {
                    syncAppleHealthMedications()
                } label: {
                    HStack {
                        Image(systemName: "heart.text.square")
                        Text("SYNC FROM APPLE HEALTH")
                        Spacer()
                        if medicationSyncLoading { ProgressView().tint(VSL.lime) }
                    }
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(VSL.lime)
                    .padding(15)
                    .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                if let medicationSyncError { notice(medicationSyncError) }
                ForEach(healthMedicationNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "heart.fill").foregroundStyle(VSL.lime)
                        Text(name).font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("APPLE HEALTH").font(.system(size: 9, weight: .black))
                            .foregroundStyle(VSL.muted)
                    }
                    .padding(15)
                    .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            notice("Apple Health medications are read-only in VSL. Local check-offs are separate and do not update Apple Health dose logs. Follow your prescribed instructions.")
            ForEach(medications) { medication in
                let checked = medicationLogs.contains {
                    $0.medicationID == medication.id && Calendar.current.isDateInToday($0.date)
                }
                HStack(spacing: 12) {
                    Button { toggleMedication(medication.id) } label: {
                        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checked ? VSL.lime : VSL.muted)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(medication.name).font(.system(size: 15, weight: .bold))
                        if !medication.details.isEmpty {
                            Text(medication.details).font(.caption).foregroundStyle(VSL.muted)
                        }
                        Text(checked ? "MARKED TODAY" : "NOT MARKED TODAY")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(checked ? VSL.lime : VSL.muted)
                    }
                    Spacer()
                    Button {
                        medications.removeAll { $0.id == medication.id }
                        medicationLogs.removeAll { $0.medicationID == medication.id }
                        saveLocalData()
                    } label: {
                        Image(systemName: "trash").foregroundStyle(VSL.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(15)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
            }
            VSLSection(title: "ADD A MEDICATION", number: "02", color: VSL.lime)
            TextField("Medication name", text: $medicationName)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: "medicationName")
                .padding(14)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 10))
            TextField("Optional notes (e.g. prescribed dose)", text: $medicationDetails)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: "medicationDetails")
                .padding(14)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 10))
            Button {
                let name = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                medications.append(VSLMedication(name: name, details: medicationDetails))
                medicationName = ""
                medicationDetails = ""
                focusedField = nil
                saveLocalData()
            } label: {
                Text("ADD MEDICATION")
                    .font(.system(size: 12, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .foregroundStyle(VSL.background)
                    .background(VSL.lime, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            VSLSection(title: "RECENT CHECK-INS", number: "03", color: VSL.lime)
            if medicationLogs.isEmpty {
                notice("Your check-in history will appear here.")
            }
            ForEach(medicationLogs.sorted { $0.date > $1.date }.prefix(15)) { log in
                if let medication = medications.first(where: { $0.id == log.medicationID }) {
                    HStack {
                        Text(medication.name)
                        Spacer()
                        Text(log.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(VSL.muted)
                    }
                    .font(.system(size: 12))
                    .padding(13)
                    .background(VSL.card, in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    func toggleMedication(_ id: UUID) {
        if let index = medicationLogs.firstIndex(where: {
            $0.medicationID == id && Calendar.current.isDateInToday($0.date)
        }) {
            medicationLogs.remove(at: index)
        } else {
            medicationLogs.append(VSLMedicationLog(medicationID: id, date: .now))
        }
        saveLocalData()
    }

    func restoreLocalData() {
        if let data = UserDefaults.standard.data(forKey: "vsl.medications"),
           let decoded = try? JSONDecoder().decode([VSLMedication].self, from: data) {
            medications = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "vsl.medicationLogs"),
           let decoded = try? JSONDecoder().decode([VSLMedicationLog].self, from: data) {
            medicationLogs = decoded
        }
    }

    func saveLocalData() {
        if let data = try? JSONEncoder().encode(medications) {
            UserDefaults.standard.set(data, forKey: "vsl.medications")
        }
        if let data = try? JSONEncoder().encode(medicationLogs) {
            UserDefaults.standard.set(data, forKey: "vsl.medicationLogs")
        }
    }


}

@available(iOS 26.0, *)
extension ContentView {
    func syncAppleHealthMedications() {
        medicationSyncLoading = true
        medicationSyncError = nil
        Task { @MainActor in
            do {
                try await health.requestMedicationReadAccess()
                healthMedicationNames = try await health.readMedicationNames()
                if healthMedicationNames.isEmpty {
                    medicationSyncError = "No shared medications found. In Apple Health, allow VSL access to the medications you want to display."
                }
            } catch {
                medicationSyncError = error.localizedDescription
            }
            medicationSyncLoading = false
        }
    }
}
