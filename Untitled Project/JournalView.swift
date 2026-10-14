import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

extension ContentView {
    var journalContent: some View {
        VSLJournalScreen(store: journalStore, selectedDay: $journalDay, displayedMonth: $journalMonth)
    }
}

private struct VSLJournalScreen: View {
    @ObservedObject var store: VSLJournalStore
    @Binding var selectedDay: Date
    @Binding var displayedMonth: Date
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFiles = false
    @State private var confirmingDelete = false
    @State private var selectedPreview: URL?
    @State private var showPreview = false
    @FocusState private var editing: Bool

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    private let moods: [(String, String)] = [
        ("Great", "face.smiling"), ("Good", "face.smiling.inverse"),
        ("Okay", "minus.circle"), ("Low", "cloud"), ("Anxious", "wind"),
        ("Difficult", "cloud.rain")
    ]
    private var entry: VSLJournalEntry? { store.entry(on: selectedDay) }
    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }.map(Optional.some)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("JOURNAL").font(.system(size: 25, weight: .bold))
            calendarCard
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    if entry != nil {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Image(systemName: "trash").foregroundStyle(VSL.muted)
                        }
                    }
                }
                Text("MOOD").font(.system(size: 10, weight: .semibold)).foregroundStyle(VSL.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 8) {
                    ForEach(moods, id: \.0) { mood in
                        let active = entry?.mood == mood.0
                        Button {
                            store.update(day: selectedDay, mood: active ? "" : mood.0)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: mood.1).font(.system(size: 20))
                                Text(mood.0).font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(active ? VSL.lime.opacity(0.15) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(active ? VSL.lime : Color.white.opacity(0.08)))
                            .foregroundStyle(active ? VSL.lime : .white)
                        }.buttonStyle(.plain)
                    }
                }
                Text("ENTRY").font(.system(size: 10, weight: .semibold)).foregroundStyle(VSL.muted)
                TextEditor(text: Binding(
                    get: { store.entry(on: selectedDay)?.text ?? "" },
                    set: { store.update(day: selectedDay, text: $0) }
                ))
                .focused($editing)
                .scrollContentBackground(.hidden)
                .font(.system(size: 15))
                .frame(minHeight: 180)
                .padding(9)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if (entry?.text ?? "").isEmpty && !editing {
                        Text("What happened today?")
                            .foregroundStyle(VSL.muted)
                            .font(.system(size: 15))
                            .padding(.top, 17).padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Photo", systemImage: "photo").font(.system(size: 13, weight: .medium))
                    }
                    Button { showingFiles = true } label: {
                        Label("File", systemImage: "paperclip").font(.system(size: 13, weight: .medium))
                    }
                    Spacer()
                    Text("Saved locally").font(.system(size: 10)).foregroundStyle(VSL.muted)
                }
                .tint(VSL.lime)
                if let attachments = entry?.attachments, !attachments.isEmpty {
                    VStack(spacing: 9) {
                        ForEach(attachments) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.isImage ? "photo" : "doc").foregroundStyle(VSL.lime)
                                ShareLink(item: store.attachmentURL(item)) {
                                    Text(item.name).lineLimit(1).font(.system(size: 12)).foregroundStyle(.white)
                                }
                                Spacer()
                                Button { store.removeAttachment(day: selectedDay, id: item.id) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(VSL.muted)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(VSL.card, in: RoundedRectangle(cornerRadius: 15))
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            let day = selectedDay
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                    store.addAttachment(day: day, data: data, name: "Photo-\(UUID().uuidString.prefix(8)).jpg", isImage: true)
                } else { store.errorMessage = "Could not load that photo." }
                selectedPhoto = nil
            }
        }
        .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        store.addAttachment(day: selectedDay, data: data, name: url.lastPathComponent, isImage: (UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false))
                    } catch { store.errorMessage = "Could not import \(url.lastPathComponent)." }
                }
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .alert("Delete this day's entry?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.delete(day: selectedDay) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This also deletes attachments saved with this entry.") }
        .alert("Journal", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var calendarCard: some View {
        VStack(spacing: 15) {
            HStack {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            .tint(.white)
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[(i + calendar.firstWeekday - 1) % 7])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VSL.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
                        Button {
                            editing = false
                            selectedDay = date
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 13, weight: selected ? .bold : .medium))
                                Circle().fill(store.hasEntry(on: date) ? VSL.lime : .clear).frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(selected ? VSL.lime.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(selected ? VSL.lime : .white)
                        }.buttonStyle(.plain)
                    } else { Color.clear.frame(height: 42) }
                }
            }
            HStack {
                Spacer()
                Button("Today") {
                    selectedDay = calendar.startOfDay(for: .now)
                    displayedMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
                }.font(.system(size: 12, weight: .semibold)).tint(VSL.lime)
            }
        }
        .padding(16)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 15))
    }
    private func changeMonth(_ offset: Int) {
        if let new = calendar.date(byAdding: .month, value: offset, to: displayedMonth) { displayedMonth = new }
    }
}
