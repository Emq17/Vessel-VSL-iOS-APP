import Foundation
import Combine

struct VSLJournalAttachment: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var storedName: String
    var isImage: Bool
}

struct VSLJournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var day: Date
    var mood: String = ""
    var text: String = ""
    var attachments: [VSLJournalAttachment] = []
    var updatedAt: Date = .now
}

@MainActor final class VSLJournalStore: ObservableObject {
    @Published private(set) var entries: [VSLJournalEntry] = []
    @Published var errorMessage: String?

    private let calendar = Calendar.current
    private let filename = "vsl-journal.json"
    private var root: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("VSLJournal", isDirectory: true)
    }
    private var attachmentsRoot: URL { root.appendingPathComponent("Attachments", isDirectory: true) }

    init() { load() }

    func entry(on day: Date) -> VSLJournalEntry? {
        entries.first { calendar.isDate($0.day, inSameDayAs: day) }
    }
    func hasEntry(on day: Date) -> Bool {
        guard let e = entry(on: day) else { return false }
        return !e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !e.mood.isEmpty || !e.attachments.isEmpty
    }
    func update(day: Date, mood: String? = nil, text: String? = nil) {
        let idx = index(for: day)
        if let mood { entries[idx].mood = mood }
        if let text { entries[idx].text = text }
        entries[idx].updatedAt = .now
        save()
    }
    func addAttachment(day: Date, data: Data, name: String, isImage: Bool) {
        do {
            try FileManager.default.createDirectory(at: attachmentsRoot, withIntermediateDirectories: true)
            let safeExt = URL(fileURLWithPath: name).pathExtension.lowercased()
            let ext = safeExt.isEmpty ? (isImage ? "jpg" : "bin") : String(safeExt.prefix(12))
            let stored = UUID().uuidString + "." + ext
            try data.write(to: attachmentsRoot.appendingPathComponent(stored), options: .atomic)
            let idx = index(for: day)
            entries[idx].attachments.append(.init(id: UUID(), name: name, storedName: stored, isImage: isImage))
            entries[idx].updatedAt = .now
            save()
        } catch { errorMessage = "Could not save attachment: \(error.localizedDescription)" }
    }
    func removeAttachment(day: Date, id: UUID) {
        guard let idx = entries.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }),
              let item = entries[idx].attachments.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: attachmentURL(item))
        entries[idx].attachments.removeAll { $0.id == id }
        save()
    }
    func attachmentURL(_ item: VSLJournalAttachment) -> URL { attachmentsRoot.appendingPathComponent(item.storedName) }
    func delete(day: Date) {
        guard let e = entry(on: day) else { return }
        for item in e.attachments { try? FileManager.default.removeItem(at: attachmentURL(item)) }
        entries.removeAll { calendar.isDate($0.day, inSameDayAs: day) }
        save()
    }
    private func index(for day: Date) -> Int {
        if let idx = entries.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }) { return idx }
        entries.append(.init(day: calendar.startOfDay(for: day)))
        return entries.count - 1
    }
    private func load() {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(filename)) else { return }
        do { entries = try JSONDecoder().decode([VSLJournalEntry].self, from: data) }
        catch { errorMessage = "Journal data couldn't be read. Existing data was left untouched." }
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: root.appendingPathComponent(filename), options: .atomic)
        } catch { errorMessage = "Could not save journal: \(error.localizedDescription)" }
    }
}
