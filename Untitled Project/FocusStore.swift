import Foundation
import Combine
import UserNotifications

enum VSLFocusMode: String, Codable, CaseIterable {
    case focus = "FOCUS"
    case shortBreak = "SHORT BREAK"
    case longBreak = "LONG BREAK"

    var next: VSLFocusMode {
        self == .focus ? .shortBreak : .focus
    }
}

struct VSLFocusTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var completed: Bool = false
    var day: Date = Calendar.current.startOfDay(for: .now)

    enum CodingKeys: String, CodingKey { case id, title, completed, day }

    init(id: UUID = UUID(), title: String, completed: Bool = false, day: Date = .now) {
        self.id = id
        self.title = title
        self.completed = completed
        self.day = Calendar.current.startOfDay(for: day)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        completed = try container.decode(Bool.self, forKey: .completed)
        // Older VSL tasks had no date; preserve them by assigning today on migration.
        day = Calendar.current.startOfDay(for:
            try container.decodeIfPresent(Date.self, forKey: .day) ?? .now)
    }
}

@MainActor
final class VSLFocusStore: ObservableObject {
    @Published var mode: VSLFocusMode = .focus
    @Published var focusMinutes = 25
    @Published var shortBreakMinutes = 5
    @Published var longBreakMinutes = 15
    @Published var remainingSeconds = 25 * 60
    @Published var deadline: Date?
    @Published var tasks: [VSLFocusTask] = []
    @Published var completedToday = 0
    @Published var completedDate = Calendar.current.startOfDay(for: .now)
    @Published var finishedMessage: String?
    @Published var isPaused = false

    private let storageKey = "vsl.focus.state.v1"
    private let notificationID = "vsl.focus.session.finished"

    private struct Saved: Codable {
        var mode: VSLFocusMode
        var focusMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var remainingSeconds: Int
        var deadline: Date?
        var tasks: [VSLFocusTask]
        var completedToday: Int
        var completedDate: Date
        var isPaused: Bool
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            mode = saved.mode
            focusMinutes = saved.focusMinutes
            shortBreakMinutes = saved.shortBreakMinutes
            longBreakMinutes = saved.longBreakMinutes
            remainingSeconds = saved.remainingSeconds
            deadline = saved.deadline
            tasks = saved.tasks
            completedToday = saved.completedToday
            completedDate = saved.completedDate
            isPaused = saved.isPaused
        }
        tick()
    }

    var duration: Int {
        switch mode {
        case .focus: return focusMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    var timeLabel: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var isRunning: Bool { deadline != nil }
    var completedTaskCount: Int { tasks.filter(\.completed).count }

    func tasks(on day: Date) -> [VSLFocusTask] {
        tasks.filter { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func completedCount(on day: Date) -> Int {
        tasks(on: day).filter(\.completed).count
    }

    func tick() {
        if !Calendar.current.isDate(completedDate, inSameDayAs: .now) {
            completedToday = 0
            completedDate = Calendar.current.startOfDay(for: .now)
        }
        guard let deadline else { save(); return }
        let left = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if left == 0 {
            finish()
        } else if remainingSeconds != left {
            remainingSeconds = left
            save()
        }
    }

    func start() {
        guard deadline == nil else { return }
        finishedMessage = nil
        if remainingSeconds <= 0 { remainingSeconds = duration }
        deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isPaused = false
        scheduleNotification(seconds: remainingSeconds)
        save()
    }

    func pause() {
        guard let deadline else { return }
        remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        self.deadline = nil
        isPaused = true
        cancelNotification()
        save()
    }

    func reset() {
        deadline = nil
        remainingSeconds = duration
        isPaused = false
        finishedMessage = nil
        cancelNotification()
        save()
    }

    func choose(_ nextMode: VSLFocusMode) {
        mode = nextMode
        reset()
    }

    func updateDurations(focus: Int, short: Int, long: Int) {
        focusMinutes = min(180, max(1, focus))
        shortBreakMinutes = min(60, max(1, short))
        longBreakMinutes = min(90, max(1, long))
        reset()
    }

    func addTask(_ title: String, on day: Date = .now) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(VSLFocusTask(title: trimmed, day: day))
        save()
    }

    func toggleTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed.toggle()
        save()
    }

    func editTask(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = trimmed
        save()
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    private func finish() {
        guard deadline != nil else { return }
        deadline = nil
        remainingSeconds = 0
        isPaused = false
        cancelNotification()
        if mode == .focus {
            if !Calendar.current.isDate(completedDate, inSameDayAs: .now) {
                completedToday = 0
                completedDate = Calendar.current.startOfDay(for: .now)
            }
            completedToday += 1
        }
        finishedMessage = mode == .focus
            ? "Focus complete. Choose a break and press Start when ready."
            : "Break complete. Press Start when you're ready to focus."
        save()
    }

    private func save() {
        let saved = Saved(mode: mode,
                          focusMinutes: focusMinutes,
                          shortBreakMinutes: shortBreakMinutes,
                          longBreakMinutes: longBreakMinutes,
                          remainingSeconds: remainingSeconds,
                          deadline: deadline,
                          tasks: tasks,
                          completedToday: completedToday,
                          completedDate: completedDate,
                          isPaused: isPaused)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private func scheduleNotification(seconds: Int) {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        cancelNotification()
        let content = UNMutableNotificationContent()
        content.title = mode == .focus ? "Focus session complete" : "Break complete"
        content.body = "VSL is ready whenever you are. Your next session won't start automatically."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        )
        center.add(request)
    }
}
