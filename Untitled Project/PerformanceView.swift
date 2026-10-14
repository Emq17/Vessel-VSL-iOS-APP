import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Performance

    var performanceContent: some View {
        VStack(alignment: .leading, spacing: 17) {

            if health.workouts.isEmpty {
                notice("No workouts available from Apple Health yet.")
            } else {
                Text("ACTIVITIES")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(VSL.muted)

                // One chronological list, without a separate sport filter.
                Picker("Activity", selection: $selectedWorkoutID) {
                    ForEach(health.workouts, id: \.uuid) { item in
                        Text("\(sportName(item.workoutActivityType.rawValue)) · \(item.startDate.formatted(date: .abbreviated, time: .shortened))")
                            .tag(Optional(item.uuid))
                    }
                }
                .tint(.white)
                .padding(10)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
            }

            if let workout = selectedWorkout {
                VSLMetricGrid(metrics: [
                    VSLMetric(id: "Elapsed", value: VSLFormat.time(workout.endDate.timeIntervalSince(workout.startDate)), unit: "")
                ])
            }

            if selectedWorkout != nil {
                if let activity = selectedWorkout?.workoutActivityType,
                   VSLAnalyzer.distanceType(activity) == nil {
                    Text("Distance and pace are hidden for this activity. Heart rate, energy, and elapsed time remain available.")
                        .font(.caption)
                        .foregroundStyle(VSL.muted)
                }
                if loadingWorkout {
                    ProgressView("Loading workout...")
                        .tint(VSL.lime)
                }

                if let analysisError {
                    notice(analysisError)
                }

                if let analysis {
                    resultSections(analysis)
                    if let activity = selectedWorkout?.workoutActivityType,
                       VSLAnalyzer.distanceType(activity) != nil {
                        milestoneSection
                    }
                }

                intervalControls
            }
        }
    }

    var intervalControls: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("ANALYSIS RANGE")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(VSL.muted)

            HStack(spacing: 8) {
                rangeButton(
                    "FULL WORKOUT",
                    selected: !custom
                ) {
                    focusedField = nil
                    custom = false
                    applyFull()
                }

                rangeButton(
                    "CUSTOM",
                    selected: custom
                ) {
                    focusedField = nil
                    custom = true
                }
            }

            if custom {
                VStack(spacing: 12) {
                    if let workout = selectedWorkout,
                       VSLAnalyzer.distanceType(workout.workoutActivityType) != nil {
                        Picker("Interval type", selection: $byDistance) {
                            Text("Distance").tag(true)
                            Text("Time").tag(false)
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("TIME INTERVAL")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(VSL.muted)
                    }

                    if byDistance && selectedWorkout.map({ VSLAnalyzer.distanceType($0.workoutActivityType) != nil }) == true {
                        Picker("Distance unit", selection: $distanceUnit) {
                            Text("Meters").tag("m")
                            Text("KM").tag("km")
                            Text("Miles").tag("mi")
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 10) {
                        rangeField(
                            "START",
                            value: $startText,
                            focus: "start"
                        )
                        rangeField(
                            "END",
                            value: $endText,
                            focus: "end"
                        )
                    }

                    Button {
                        focusedField = nil
                        applyCustom()
                    } label: {
                        HStack {
                            Spacer()
                            Text("UPDATE ANALYSIS")
                            Image(systemName: "arrow.right")
                            Spacer()
                        }
                        .font(.system(
                            size: 12,
                            weight: .black
                        ))
                        .foregroundStyle(VSL.background)
                        .padding(16)
                        .background(
                            VSL.lime,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    VSL.card,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }

            if analysis != nil {
                Text("SHOWING: \(appliedRange)")
                    .font(.system(
                        size: 10,
                        weight: .bold
                    ))
                    .foregroundStyle(VSL.muted)
            }
        }
    }

    func rangeButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(
                    size: 11,
                    weight: .black
                ))
                .foregroundStyle(
                    selected ? VSL.background : .white
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    selected ? VSL.lime : VSL.card,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
    }

    func rangeField(
        _ title: String,
        value: Binding<String>,
        focus: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(VSL.muted)

            TextField("0", text: value)
                .keyboardType(
                    byDistance
                        ? .decimalPad
                        : .numbersAndPunctuation
                )
                .focused($focusedField, equals: focus)
                .font(.system(
                    size: 22,
                    weight: .heavy,
                    design: .rounded
                ))
                .monospacedDigit()
                .padding(13)
                .background(
                    VSL.background,
                    in: RoundedRectangle(cornerRadius: 9)
                )
        }
        .frame(maxWidth: .infinity)
    }

    func resultSections(
        _ result: VSLAnalysis
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VSLSection(
                title: "PERFORMANCE METRICS",
                number: "02",
                color: VSL.lime
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("ELAPSED TIME")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(VSL.muted)

                Text(VSLFormat.time(result.duration))
                    .font(.system(
                        size: 47,
                        weight: .black,
                        design: .rounded
                    ))
                    .monospacedDigit()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(20)
            .background(
                VSL.card,
                in: RoundedRectangle(cornerRadius: 14)
            )

            VSLMetricGrid(metrics: performanceMetrics(result))

            if selectedWorkout?.workoutActivityType == .swimming {
                firstMileCard
            }

            VSLSection(
                title: "TIME ANALYSIS",
                number: "03",
                color: VSL.lime
            )

            VSLMetricGrid(metrics: timingMetrics(result))

            VSLSection(
                title: "PHYSIOLOGY",
                number: "04",
                color: VSL.lime
            )

            VSLMetricGrid(metrics: physiologyMetrics(result))
        }
    }

    func performanceMetrics(
        _ result: VSLAnalysis
    ) -> [VSLMetric] {
        var metrics: [VSLMetric] = []
        let swimming =
            selectedWorkout?.workoutActivityType == .swimming

        if VSLAnalyzer.distanceType(selectedWorkout?.workoutActivityType ?? .other) != nil,
           let distance = result.distance {
            metrics.append(
                VSLMetric(
                    id: "Distance",
                    value: VSLFormat.number(
                        swimming
                            ? distance
                            : distance / metersPerMile,
                        decimals: swimming ? 0 : 2
                    ),
                    unit: swimming ? "m" : "mi"
                )
            )

            if distance > 0 {
                metrics.append(
                    VSLMetric(
                        id: "Average pace",
                        value: VSLFormat.time(
                            result.duration / distance *
                            (swimming ? 100 : metersPerMile)
                        ),
                        unit: swimming ? "/100m" : "/mi"
                    )
                )
            }
        }

        return metrics
    }

    func timingMetrics(
        _ result: VSLAnalysis
    ) -> [VSLMetric] {
        var metrics = [
            VSLMetric(
                id: "Elapsed",
                value: VSLFormat.time(result.duration),
                unit: ""
            )
        ]

        if selectedWorkout?.workoutActivityType == .swimming {
            metrics += [
                VSLMetric(
                    id: "Swimming time",
                    value: VSLFormat.time(result.swimmingTime),
                    unit: ""
                ),
                VSLMetric(
                    id: "Rest / other",
                    value: VSLFormat.time(result.restTime),
                    unit: ""
                ),
                VSLMetric(
                    id: "Paused",
                    value: VSLFormat.time(result.pausedTime),
                    unit: ""
                ),
                VSLMetric(
                    id: "Swimming pace",
                    value: VSLFormat.time(result.swimmingPace),
                    unit: "/100m"
                )
            ]
        }

        return metrics
    }

    func physiologyMetrics(
        _ result: VSLAnalysis
    ) -> [VSLMetric] {
        var metrics = [
            VSLMetric(
                id: "Avg heart rate",
                value: VSLFormat.number(result.heartRate),
                unit: "BPM"
            ),
            VSLMetric(
                id: "Active energy",
                value: VSLFormat.number(result.energy),
                unit: "kcal"
            )
        ]

        if selectedWorkout?.workoutActivityType == .running {
            let cadence = result.steps.flatMap {
                result.duration > 0
                    ? $0 / result.duration * 60
                    : nil
            }

            metrics.append(
                VSLMetric(
                    id: "Avg cadence",
                    value: VSLFormat.number(
                        cadence,
                        decimals: 1
                    ),
                    unit: "SPM"
                )
            )
        }

        if let steps = result.steps {
            metrics.append(
                VSLMetric(
                    id: "Steps",
                    value: VSLFormat.number(steps),
                    unit: ""
                )
            )
        }

        if selectedWorkout?.workoutActivityType == .swimming {
            metrics.append(
                VSLMetric(
                    id: "Swim strokes",
                    value: VSLFormat.number(result.strokes),
                    unit: ""
                )
            )
        }

        return metrics
    }

    // MARK: - Swimming First Mile

    var firstMileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FIRST MILE")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(VSL.lime)

            let crossing = workoutData.flatMap {
                VSLAnalyzer.crossing(
                    metersPerMile,
                    data: $0
                )
            }

            let elapsed = crossing.flatMap { date in
                workoutData.map {
                    date.timeIntervalSince(
                        $0.workout.startDate
                    )
                }
            }

            Text(VSLFormat.time(elapsed))
                .font(.system(
                    size: 36,
                    weight: .black,
                    design: .rounded
                ))
                .monospacedDigit()

            Text("ELAPSED FROM WORKOUT START")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VSL.muted)

            if elapsed != nil {
                Button("ANALYZE FIRST MILE ↗") {
                    custom = true
                    byDistance = true
                    distanceUnit = "m"
                    startText = "0"
                    endText = "1609.344"
                    applyCustom()
                }
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(VSL.lime)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(18)
        .background(
            VSL.card,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    // MARK: - Milestones

    var milestonePresets: [Double] {
        if selectedWorkout?.workoutActivityType == .swimming {
            return [
                25, 50, 100, 200, 400, 500,
                800, 1000, 1500, 1600, 1609.344, 2000
            ]
        }

        return [
            100, 200, 400, 800, 1000, 1500,
            1600, 1609.344, 3000, 5000,
            10000, 21097.5, 42195
        ]
    }

    var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VSLSection(
                title: "MILESTONES",
                number: "05",
                color: VSL.lime
            )

            if let workoutData,
               VSLAnalyzer.distanceType(
                    workoutData.workout.workoutActivityType
               ) != nil {

                Button {
                    focusedField = nil
                    editingMilestones.toggle()
                } label: {
                    HStack {
                        Text("CUSTOMIZE CHECKPOINTS")
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(VSL.lime)
                }

                if editingMilestones {
                    milestoneEditor
                }

                ForEach(
                    milestones.sorted(),
                    id: \.self
                ) { distance in
                    let date = VSLAnalyzer.crossing(
                        distance,
                        data: workoutData
                    )

                    let elapsed = date?.timeIntervalSince(
                        workoutData.workout.startDate
                    )

                    HStack {
                        Text(milestoneName(distance))
                            .font(.system(
                                size: 12,
                                weight: .black
                            ))

                        Spacer()

                        Text(VSLFormat.time(elapsed))
                            .font(.system(
                                size: 21,
                                weight: .black,
                                design: .rounded
                            ))
                            .monospacedDigit()
                    }
                    .padding(16)
                    .background(
                        VSL.card,
                        in: RoundedRectangle(cornerRadius: 11)
                    )
                }

                Text("Milestone times are estimated from recorded distance samples.")
                    .font(.system(size: 11))
                    .foregroundStyle(VSL.muted)
            } else {
                notice("Distance milestones are unavailable for this workout.")
            }
        }
    }

    var milestoneEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                ForEach(
                    milestonePresets,
                    id: \.self
                ) { distance in
                    let selected = milestones.contains(distance)

                    Button {
                        if selected {
                            milestones.remove(distance)
                        } else {
                            milestones.insert(distance)
                        }
                    } label: {
                        Text(milestoneName(distance))
                            .font(.system(
                                size: 10,
                                weight: .black
                            ))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundStyle(
                                selected
                                    ? VSL.background
                                    : .white
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selected ? VSL.lime : VSL.background,
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Unit", selection: $milestoneUnit) {
                Text("Meters").tag("m")
                Text("KM").tag("km")
                Text("Miles").tag("mi")
            }
            .pickerStyle(.segmented)

            HStack {
                TextField("Other distance", text: $newMilestone)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: "milestone")
                    .padding(12)
                    .background(
                        VSL.background,
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                Button("ADD") {
                    guard let amount = Double(newMilestone),
                          amount > 0 else { return }

                    milestones.insert(
                        amount * multiplier(milestoneUnit)
                    )
                    newMilestone = ""
                    focusedField = nil
                }
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(VSL.lime)
            }
        }
        .padding(14)
        .background(
            VSL.card,
            in: RoundedRectangle(cornerRadius: 13)
        )
    }

    func milestoneName(_ meters: Double) -> String {
        if abs(meters - metersPerMile) < 0.01 {
            return "1 MILE"
        }

        if meters >= 1000 &&
            meters.truncatingRemainder(dividingBy: 1000) == 0 {
            return "\(Int(meters / 1000)) KM"
        }

        return "\(VSLFormat.number(meters, decimals: meters.rounded() == meters ? 0 : 1)) M"
    }

    func multiplier(_ unit: String) -> Double {
        switch unit {
        case "mi": return metersPerMile
        case "km": return 1000
        default: return 1
        }
    }

    // MARK: - Workout Actions

    func loadWorkout() {
        focusedField = nil
        workoutData = nil
        analysis = nil
        analysisError = nil
        custom = false

        guard let workout = selectedWorkout else { return }

        let requestedID = workout.uuid
        loadingWorkout = true

        distanceUnit =
            workout.workoutActivityType == .swimming
                ? "m" : "mi"

        byDistance = VSLAnalyzer.distanceType(
            workout.workoutActivityType
        ) != nil

        startText = "0"
        endText = byDistance ? (distanceUnit == "m" ? "400" : "1") : "5:00"

        health.loadWorkout(workout) { response in
            guard selectedWorkoutID == requestedID else {
                return
            }

            loadingWorkout = false

            switch response {
            case .success(let loaded):
                workoutData = loaded
                applyFull()

            case .failure(let error):
                analysisError = error.localizedDescription
            }
        }
    }

    func applyFull() {
        guard let workoutData else { return }

        analysis = VSLAnalyzer.analyze(
            workoutData,
            start: workoutData.workout.startDate,
            end: workoutData.workout.endDate
        )

        appliedRange = "FULL WORKOUT"
        analysisError = nil
    }

    func applyCustom() {
        guard let workoutData else { return }

        let start: Date
        let end: Date

        if byDistance && VSLAnalyzer.distanceType(workoutData.workout.workoutActivityType) != nil {
            guard VSLAnalyzer.distanceType(
                workoutData.workout.workoutActivityType
            ) != nil,
            let a = Double(startText),
            let b = Double(endText),
            a >= 0,
            b > a,
            let aDate = VSLAnalyzer.crossing(
                a * multiplier(distanceUnit),
                data: workoutData
            ),
            let bDate = VSLAnalyzer.crossing(
                b * multiplier(distanceUnit),
                data: workoutData
            ) else {
                analysisError = "This distance interval isn't available in the recorded samples."
                return
            }

            start = aDate
            end = bDate
        } else {
            guard let a = VSLFormat.seconds(startText),
                  let b = VSLFormat.seconds(endText),
                  a >= 0,
                  b > a else {
                analysisError = "Enter valid start and end times."
                return
            }

            start = workoutData.workout.startDate
                .addingTimeInterval(a)
            end = workoutData.workout.startDate
                .addingTimeInterval(b)
        }

        guard start >= workoutData.workout.startDate,
              end <= workoutData.workout.endDate,
              end > start else {
            analysisError = "The interval must be inside the workout."
            return
        }

        analysis = VSLAnalyzer.analyze(
            workoutData,
            start: start,
            end: end
        )

        appliedRange = (byDistance && VSLAnalyzer.distanceType(workoutData.workout.workoutActivityType) != nil)
            ? "\(startText) – \(endText) \(distanceUnit)"
            : "\(startText) – \(endText) TIME"

        analysisError = nil
    }

    func sportName(_ raw: UInt) -> String {
        guard let type = HKWorkoutActivityType(rawValue: raw) else {
            return "Activity (\(raw))"
        }

        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .cycling: return "Cycling"
        case .hiking: return "Hiking"
        case .jumpRope: return "Jump Rope"
        case .dance: return "Dance"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Rowing"
        case .yoga: return "Yoga"
        case .elliptical: return "Elliptical"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .golf: return "Golf"
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .stairClimbing: return "Stair Climbing"
        case .stairStepper: return "Stair Stepper"
        case .coreTraining: return "Core Training"
        case .flexibility: return "Flexibility"
        case .martialArts: return "Martial Arts"
        case .tennis: return "Tennis"
        case .badminton: return "Badminton"
        case .tableTennis: return "Table Tennis"
        case .other: return "Other Workout"
        default:
            // Don't silently label unfamiliar HealthKit activities as Other.
            // Preserve the system case name and make it readable.
            let rawName = String(describing: type)
            let separated = rawName.replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            return separated.prefix(1).uppercased() + separated.dropFirst()
        }
    }


}
