import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var exId = "bench"

    var body: some View {
        let points = store.progress(exId)
        let heart = store.heartPoints()
        let logs = Array(store.sortedLogs().reversed())

        NavigationStack {
            List {
                Section("İlerleme") {
                    Picker("Hareket", selection: $exId) {
                        ForEach(store.allExercises, id: \.id) { e in
                            Text(e.name).tag(e.id)
                        }
                    }
                    if points.count >= 2 {
                        Chart(points) { p in
                            LineMark(x: .value("Tarih", p.date), y: .value("Kilo", p.w))
                                .foregroundStyle(.blue)
                            PointMark(x: .value("Tarih", p.date), y: .value("Kilo", p.w))
                                .foregroundStyle(.blue)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let d = value.as(Date.self) { Text(Fmt.short(Fmt.isoString(d))) }
                                }
                            }
                        }
                        .frame(height: 180)
                        if let l = points.last {
                            Text("Çalışma kilosu. Son: \(Fmt.num(l.w)) kg × \(Fmt.num(l.r)) · \(points.count) antrenman")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Grafik için bu harekette en az 2 kayıt lazım.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nabız") {
                    if heart.isEmpty {
                        Text("Nabız takibiyle kaydettiğin antrenmanlar burada görünecek.")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(heart) { p in
                            LineMark(x: .value("Tarih", p.date), y: .value("Nabız", p.value),
                                     series: .value("Tür", p.kind))
                                .foregroundStyle(by: .value("Tür", p.kind))
                            PointMark(x: .value("Tarih", p.date), y: .value("Nabız", p.value))
                                .foregroundStyle(by: .value("Tür", p.kind))
                        }
                        .chartForegroundStyleScale(["Ortalama": Color.red, "Maks": Color.orange])
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let d = value.as(Date.self) { Text(Fmt.short(Fmt.isoString(d))) }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }

                Section("Geçmiş antrenmanlar") {
                    ForEach(logs) { log in
                        DisclosureGroup {
                            ForEach(store.orderedKeys(log), id: \.self) { id in
                                HStack(alignment: .top) {
                                    Text(store.exercise(id)?.name ?? id)
                                    Spacer()
                                    Text(Fmt.sets(log.ex[id] ?? []))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .font(.subheadline)
                            }
                        } label: {
                            HStack {
                                Text(Fmt.short(log.date)).bold()
                                Text(Store.names[log.day] ?? log.day)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                                Spacer()
                                if let a = log.hrAvg {
                                    Label("\(a)", systemImage: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                if let m = log.minutes {
                                    Text("\(m) dk").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { store.delete(logs[i].id) }
                    }
                }
            }
            .navigationTitle("Geçmiş")
        }
    }
}

struct ProgramView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(store.data.program.enumerated()), id: \.element.id) { i, d in
                    Section("\(i + 1). gün · \(Store.names[d.id] ?? d.name)") {
                        ForEach(d.ex) { e in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name)
                                    if let n = e.note {
                                        Text(n).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(e.sets)×\(e.min)–\(e.max)" + (e.isBodyweight ? "" : " · \(Fmt.num(e.start)) kg"))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("4. gün · Off") {
                    Text("Dinlen. İstersen 20-30 dk hafif yürüyüş.")
                }
                Section("Kurallar") {
                    Text("Bütün setlerde üst tekrara ulaşınca bir sonraki sefer kilo ekle. Uygulama bunu “+ kg ekle” etiketiyle gösterir.")
                    Text("Tekrar alt sınırın altına düşerse kiloyu koru.")
                    Text("Bench ve DB incline’ı her push gününde sırayla ilk harekete koy.")
                    Text("Arka omuz ve leg curl’ü atlama.")
                    Text("Ağır hareketlerde 2 dk, diğerlerinde 90 sn dinlen. ✓ işaretine basınca sayaç başlar.")
                }
                .font(.subheadline)
            }
            .navigationTitle("Program")
        }
    }
}
