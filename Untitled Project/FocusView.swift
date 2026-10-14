import SwiftUI
import Combine

extension ContentView {
    var focusContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VSLSection(title: "FOCUS", number: "01", color: VSL.lime)
            Text("MAKE TIME COUNT.")
                .font(.system(size: 27, weight: .black))

            focusTimerCard
            focusTasksCard
            focusCalendarCard
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            focusStore.tick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { focusStore.tick() }
        }
        .alert("Edit task", isPresented: $editingFocusTask) {
            TextField("Task", text: $editedFocusTaskTitle)
            Button("Save") {
                if let id = editingFocusTaskID {
                    focusStore.editTask(id, title: editedFocusTaskTitle)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var focusTimerCard: some View {
        VStack(spacing: 17) {
            HStack {
                Text("POMODORO TIMER")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(VSL.muted)
                Spacer()
                Text("\(focusStore.completedToday) COMPLETED TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VSL.lime)
            }

            HStack(spacing: 7) {
                focusModeButton(.focus)
                focusModeButton(.shortBreak)
                focusModeButton(.longBreak)
            }

            Text(focusStore.timeLabel)
                .font(.system(size: 61, weight: .black, design: .default))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())

            if let message = focusStore.finishedMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(VSL.muted)
                    .multilineTextAlignment(.center)
            } else {
                Text(focusStore.isRunning ? "SESSION IN PROGRESS" :
                        (focusStore.isPaused ? "PAUSED" : "READY WHEN YOU ARE"))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(VSL.muted)
            }

            HStack(spacing: 9) {
                Button {
                    if focusStore.isRunning { focusStore.pause() }
                    else { focusStore.start() }
                } label: {
                    Label(focusStore.isRunning ? "PAUSE" :
                            (focusStore.isPaused ? "RESUME" : "START"),
                          systemImage: focusStore.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(VSL.lime, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(VSL.background)
                }

                Button {
                    focusStore.reset()
                } label: {
                    Label("RESET", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(VSL.background, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            }
            .font(.system(size: 11, weight: .black))
            .buttonStyle(.plain)

            DisclosureGroup("CUSTOMIZE DURATIONS") {
                VStack(spacing: 12) {
                    focusDurationStepper("Focus", value: focusStore.focusMinutes, range: 1...180) {
                        focusStore.updateDurations(focus: $0,
                                                   short: focusStore.shortBreakMinutes,
                                                   long: focusStore.longBreakMinutes)
                    }
                    focusDurationStepper("Short break", value: focusStore.shortBreakMinutes, range: 1...60) {
                        focusStore.updateDurations(focus: focusStore.focusMinutes,
                                                   short: $0,
                                                   long: focusStore.longBreakMinutes)
                    }
                    focusDurationStepper("Long break", value: focusStore.longBreakMinutes, range: 1...90) {
                        focusStore.updateDurations(focus: focusStore.focusMinutes,
                                                   short: focusStore.shortBreakMinutes,
                                                   long: $0)
                    }
                    Text("Changing durations resets the current session.")
                        .font(.caption)
                        .foregroundStyle(VSL.muted)
                }
                .padding(.top, 12)
            }
            .font(.system(size: 11, weight: .heavy))
            .tint(VSL.lime)
        }
        .padding(18)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func focusModeButton(_ mode: VSLFocusMode) -> some View {
        Button {
            focusStore.choose(mode)
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 9, weight: .heavy))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(focusStore.mode == mode ? VSL.background : .white)
                .background(focusStore.mode == mode ? VSL.lime : VSL.background,
                            in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func focusDurationStepper(_ title: String,
                                      value: Int,
                                      range: ClosedRange<Int>,
                                      change: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button {
                change(max(range.lowerBound, value - 1))
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
            }
            .disabled(value <= range.lowerBound)
            Text("\(value)m")
                .frame(width: 42)
                .monospacedDigit()
            Button {
                change(min(range.upperBound, value + 1))
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
            }
            .disabled(value >= range.upperBound)
        }
        .buttonStyle(.plain)
    }

    private var focusTasksCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(Calendar.current.isDateInToday(selectedFocusDay) ? "TODAY'S TASKS" : "TASKS · \(selectedFocusDay.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 12, weight: .black))
                Spacer()
                Text("\(focusStore.completedCount(on: selectedFocusDay)) / \(focusStore.tasks(on: selectedFocusDay).count) DONE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VSL.muted)
            }

            HStack(spacing: 8) {
                TextField("Add a task", text: $newFocusTask)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($focusedField, equals: "focusTask")
                    .onSubmit { addFocusTask() }
                    .padding(12)
                    .background(VSL.background, in: RoundedRectangle(cornerRadius: 9))

                Button {
                    addFocusTask()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(VSL.background)
                        .frame(width: 44, height: 44)
                        .background(VSL.lime, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add task")
            }

            if focusStore.tasks(on: selectedFocusDay).isEmpty {
                Text("No tasks yet. Add one to get started.")
                    .font(.subheadline)
                    .foregroundStyle(VSL.muted)
                    .padding(.vertical, 12)
            }

            ForEach(focusStore.tasks(on: selectedFocusDay)) { task in
                HStack(spacing: 12) {
                    Button {
                        focusStore.toggleTask(task.id)
                    } label: {
                        Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(task.completed ? VSL.lime : VSL.muted)
                    }
                    .buttonStyle(.plain)
                    Text(task.title)
                        .font(.system(size: 14))
                        .strikethrough(task.completed)
                        .foregroundStyle(task.completed ? VSL.muted : .white)
                    Spacer(minLength: 4)
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            editingFocusTaskID = task.id
                            editedFocusTaskTitle = task.title
                            editingFocusTask = true
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            focusStore.deleteTask(task.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(VSL.muted)
                            .padding(7)
                    }
                }
                .padding(.vertical, 7)
            }
        }
        .padding(18)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 14))
    }


    private var focusCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TASK CALENDAR")
                    .font(.system(size: 12, weight: .black))
                Spacer()
                Text("\(selectedFocusDay.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VSL.muted)
            }

            Group {
                HStack {
                    Button {
                        shiftFocusMonth(-1)
                    } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(focusCalendarMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Button {
                        shiftFocusMonth(1)
                    } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                let calendar = Calendar.current
                let weekdays = calendar.veryShortStandaloneWeekdaySymbols
                let offset = (calendar.component(.weekday, from: focusCalendarMonth) - calendar.firstWeekday + 7) % 7
                let count = calendar.range(of: .day, in: .month, for: focusCalendarMonth)?.count ?? 30
                let cells = Array(repeating: 0, count: offset) + Array(1...count)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdays[(index + calendar.firstWeekday - 1) % 7])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VSL.muted)
                    }
                    ForEach(cells.indices, id: \.self) { index in
                        let number = cells[index]
                        if number == 0 {
                            Color.clear.frame(height: 42)
                        } else if let day = calendar.date(byAdding: .day, value: number - 1, to: focusCalendarMonth) {
                            let selected = calendar.isDate(day, inSameDayAs: selectedFocusDay)
                            let dayTasks = focusStore.tasks(on: day)
                            Button {
                                selectedFocusDay = day
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(number)")
                                        .font(.system(size: 12, weight: selected ? .black : .medium))
                                    Circle()
                                        .fill(dayTasks.isEmpty ? Color.clear : VSL.lime)
                                        .frame(width: 4, height: 4)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .foregroundStyle(selected ? VSL.background : .white)
                                .background(selected ? VSL.lime : VSL.background,
                                            in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(dayTasks.count) tasks")
                        }
                    }
                }

                HStack {
                    Text("Dots indicate days with saved tasks")
                        .font(.system(size: 10))
                        .foregroundStyle(VSL.muted)
                    Spacer()
                    Button("TODAY") {
                        selectedFocusDay = Calendar.current.startOfDay(for: .now)
                        focusCalendarMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
                    }
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(VSL.lime)
                }
            }
        }
        .padding(18)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func shiftFocusMonth(_ offset: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: focusCalendarMonth) {
            focusCalendarMonth = next
        }
    }

    private func addFocusTask() {
        focusStore.addTask(newFocusTask, on: selectedFocusDay)
        newFocusTask = ""
        focusedField = nil
    }
}
