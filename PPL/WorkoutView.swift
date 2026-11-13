import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var hr: HeartRateManager
    @StateObject private var timer = RestTimer()
    @State private var day: String = "push"
    @State private var didInit = false
    @State private var toast: String?
    @State private var confirmCancel = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NextDayHeader()

                    Picker("Gün", selection: $day) {
                        ForEach(Store.order, id: \.self) { k in
                            Text(Store.names[k] ?? k).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    HeartCard(onCancel: { confirmCancel = true })

                    if let p = store.plan(day) {
                        ForEach(p.ex) { e in
                            ExerciseCard(day: day, ex: e, timer: timer)
                        }
                    }

                    finishSection
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("PPL Takip")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { hideKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if timer.visible {
                    RestTimerBar(timer: timer)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
            }
            .confirmationDialog("Nabız takibi iptal edilsin mi?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("İptal et, kaydetme", role: .destructive) { hr.cancel() }
                Button("Devam et", role: .cancel) {}
            }
        }
        .onAppear {
            if !didInit {
                day = store.nextInfo().day
                didInit = true
            }
            store.ensureDraft(day)
        }
        .onChange(of: day) { _, newValue in
            store.ensureDraft(newValue)
        }
    }

    private var finishSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Tarih",
                       selection: Binding(get: { store.draftDate(day) },
                                          set: { store.setDraftDate(day, $0) }),
                       displayedComponents: .date)
            Button(action: save) {
                Text("\(Store.names[day] ?? "") antrenmanını kaydet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let t = toast {
                Text(t).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func save() {
        hideKeyboard()
        guard store.filledSetCount(day) > 0 else {
            toast = "Kaydetmek için en az bir sete tekrar sayısı yaz."
            return
        }
        let savedDay = day
        let finish: (Int?, Int?, Int?) -> Void = { avg, mx, mins in
            let n = store.saveWorkout(day: savedDay, hrAvg: avg, hrMax: mx, minutes: mins)
            var text = "Kaydedildi: \(n) set"
            if let a = avg { text += " · ort. nabız \(a)" }
            if let m = mx { text += " · maks \(m)" }
            toast = text
            timer.close()
            day = store.nextInfo().day
            store.ensureDraft(day)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if hr.running {
            hr.stop(completion: finish)
        } else {
            finish(nil, nil, nil)
        }
    }
}

struct NextDayHeader: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let n = store.nextInfo()
        let active = n.rest ? "off" : n.day
        VStack(alignment: .leading, spacing: 6) {
            Text(n.rest ? "Bugün off günü, sonra Push" : "Sıradaki gün: \(Store.names[n.day] ?? "")")
                .font(.title3.bold())
            if let l = n.last {
                Text("Son antrenman \(Fmt.short(l.date)) (\(Store.names[l.day] ?? ""))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(["push", "pull", "legs", "off"], id: \.self) { k in
                    Text(Store.names[k] ?? k)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(k == active ? Color(.systemBackground) : Color.secondary)
                        .background(k == active ? Color.primary : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separator)))
                }
            }
        }
    }
}

struct HeartCard: View {
    @EnvironmentObject var hr: HeartRateManager
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hr.running {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                    Text(hr.bpm.map { String($0) } ?? "--")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM").foregroundStyle(.secondary)
                    Spacer()
                    if let s = hr.startDate {
                        TimelineView(.periodic(from: s, by: 1)) { ctx in
                            Text(elapsed(from: s, to: ctx.date))
                                .font(.title3.monospacedDigit())
                        }
                    }
                }
                HStack {
                    Text("Ort. \(hr.avg.map { String($0) } ?? "--")")
                    Text("Maks \(hr.maxBpm.map { String($0) } ?? "--")")
                    Spacer()
                    Button("İptal", role: .destructive, action: onCancel)
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text("Antrenmanı kaydedince nabız takibi de biter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button { hr.start() } label: {
                    Label("Antrenmanı başlat · nabız takibi", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                Text("AirPods Pro 3'ü tak. Nabız Apple Sağlık üzerinden canlı okunur, antrenman Sağlık'a da kaydedilir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let m = hr.message {
                Text(m).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func elapsed(from s: Date, to now: Date) -> String {
        let t = Swift.max(0, Int(now.timeIntervalSince(s)))
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}

struct ExerciseCard: View {
    @EnvironmentObject var store: Store
    let day: String
    let ex: Exercise
    @ObservedObject var timer: RestTimer

    var body: some View {
        let s = store.suggest(ex)
        let last = store.lastFor(ex.id)
        let entries = store.entries(day, ex.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name).font(.headline)
                    Text(target).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(s.text)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(s.color)
                    .background(s.color.opacity(0.15), in: Capsule())
            }
            Text(last.map { "Geçen sefer (\(Fmt.short($0.date))): \(Fmt.sets($0.sets))" } ?? "Henüz kayıt yok")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(entries.indices), id: \.self) { i in
                SetRow(day: day, ex: ex, index: i, timer: timer)
            }

            HStack {
                Button("+ Set ekle") { store.addSet(day, ex.id) }
                Button("− Set çıkar") { store.removeSet(day, ex.id) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var target: String {
        var t = "\(ex.sets) set × \(ex.min)–\(ex.max) tekrar"
        if let n = ex.note { t += " · \(n)" }
        return t
    }
}

struct SetRow: View {
    @EnvironmentObject var store: Store
    let day: String
    let ex: Exercise
    let index: Int
    @ObservedObject var timer: RestTimer

    var body: some View {
        let entry = store.entries(day, ex.id)[safe: index] ?? SetEntry(w: "", r: "", done: false)
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20)
            if ex.isBodyweight {
                Text("Vücut ağırlığı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                field(text: binding(\.w), placeholder: "kg", unit: "kg", done: entry.done)
            }
            field(text: binding(\.r), placeholder: "\(ex.min)–\(ex.max)", unit: "tekrar", done: entry.done)
            Button {
                let nowDone = !entry.done
                store.update(day, ex.id, index) { $0.done = nowDone }
                if nowDone {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    timer.start(Store.heavy.contains(ex.id) ? 120 : 90)
                }
            } label: {
                Image(systemName: entry.done ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(entry.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set \(index + 1) tamamlandı")
        }
    }

    private func binding(_ key: WritableKeyPath<SetEntry, String>) -> Binding<String> {
        Binding(
            get: { store.entries(day, ex.id)[safe: index]?[keyPath: key] ?? "" },
            set: { v in store.update(day, ex.id, index) { $0[keyPath: key] = v } }
        )
    }

    private func field(text: Binding<String>, placeholder: String, unit: String, done: Bool) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.body.weight(.semibold).monospacedDigit())
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(done ? Color.green : Color(.separator), lineWidth: 1.5))
    }
}

struct RestTimerBar: View {
    @ObservedObject var timer: RestTimer
    @State private var buzzed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let left = Swift.max(0, Int(((timer.end ?? ctx.date).timeIntervalSince(ctx.date)).rounded(.up)))
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(left == 0 ? "Dinlenme bitti" : "Dinlenme")
                        .font(.caption)
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.title.bold().monospacedDigit())
                }
                Spacer()
                Button("+30 sn") { timer.add(30); buzzed = false }
                    .buttonStyle(.bordered)
                Button { timer.close() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Sayacı kapat")
            }
            .padding(12)
            .background(left == 0 ? AnyShapeStyle(Color.green.opacity(0.9)) : AnyShapeStyle(.regularMaterial),
                        in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: left) { _, newValue in
                if newValue == 0 && !buzzed {
                    buzzed = true
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } else if newValue > 0 {
                    buzzed = false
                }
            }
        }
    }
}
