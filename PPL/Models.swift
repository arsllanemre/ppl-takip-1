import Foundation
import SwiftUI

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var sets: Int
    var min: Int
    var max: Int
    var start: Double
    var inc: Double
    var bw: Bool?
    var note: String?

    var isBodyweight: Bool { bw ?? false }
}

struct DayPlan: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var ex: [Exercise]
}

struct WorkoutLog: Codable, Identifiable, Hashable {
    var id: String
    var date: String
    var day: String
    var ex: [String: [[Double]]]
    var hrAvg: Int?
    var hrMax: Int?
    var minutes: Int?
}

struct AppData: Codable {
    var rev: Int
    var program: [DayPlan]
    var logs: [WorkoutLog]
}

struct SetEntry: Codable, Hashable {
    var w: String
    var r: String
    var done: Bool
}

struct Draft: Codable {
    var date: Date
    var sets: [String: [SetEntry]]
}

struct SuggestionInfo {
    enum Kind { case start, up, hold, same }
    let weight: Double
    let text: String
    let kind: Kind

    var color: Color {
        switch kind {
        case .start: return .gray
        case .up: return .green
        case .hold: return .orange
        case .same: return .blue
        }
    }
}

struct ProgressPoint: Identifiable {
    let id: String
    let date: Date
    let w: Double
    let r: Double
}

struct HeartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Int
    let kind: String
}

enum Fmt {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    static func date(_ s: String) -> Date { iso.date(from: s) ?? Date() }
    static func isoString(_ d: Date) -> String { iso.string(from: d) }

    static func short(_ s: String) -> String {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return s }
        return "\(p[2]) \(months[p[1] - 1])"
    }

    static func num(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
    }

    static func parse(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    static func sets(_ sets: [[Double]]) -> String {
        sets.map { s -> String in
            guard s.count >= 2 else { return "" }
            return (s[0] > 0 ? num(s[0]) + "×" : "×") + num(s[1])
        }.joined(separator: " · ")
    }
}

final class Store: ObservableObject {
    @Published var data: AppData
    @Published var drafts: [String: Draft] = [:]

    static let order = ["push", "pull", "legs"]
    static let names = ["push": "Push", "pull": "Pull", "legs": "Bacak", "off": "Off"]
    static let heavy: Set<String> = ["bench", "dbinc", "ohp", "dl", "pend", "row", "latpd"]

    private let dataURL: URL
    private let draftURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dataURL = docs.appendingPathComponent("data.json")
        draftURL = docs.appendingPathComponent("drafts.json")

        if let d = try? Data(contentsOf: dataURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: d) {
            data = decoded
        } else if let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
                  let d = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(AppData.self, from: d) {
            data = decoded
        } else {
            data = AppData(rev: 0, program: [], logs: [])
        }
        if UserDefaults.standard.bool(forKey: "demoHR") {
            let demo: [(Int, Int)] = [(124, 158), (121, 151), (119, 154), (116, 149), (117, 147), (113, 144)]
            let recent = Array(data.logs.sorted { $0.date < $1.date }.suffix(demo.count))
            for (n, l) in recent.enumerated() {
                if let i = data.logs.firstIndex(where: { $0.id == l.id }) {
                    data.logs[i].hrAvg = demo[n].0
                    data.logs[i].hrMax = demo[n].1
                    data.logs[i].minutes = 62 + n * 3
                }
            }
        }
        if let d = try? Data(contentsOf: draftURL),
           let decoded = try? JSONDecoder().decode([String: Draft].self, from: d) {
            drafts = decoded
        }
    }

    // MARK: Persistence

    func save() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: dataURL, options: .atomic) }
    }

    func saveDrafts() {
        if let d = try? JSONEncoder().encode(drafts) { try? d.write(to: draftURL, options: .atomic) }
    }

    // MARK: Lookup

    func plan(_ day: String) -> DayPlan? { data.program.first { $0.id == day } }

    func exercise(_ id: String) -> Exercise? {
        for d in data.program { if let e = d.ex.first(where: { $0.id == id }) { return e } }
        return nil
    }

    var allExercises: [Exercise] { data.program.flatMap { $0.ex }.filter { !$0.isBodyweight } }

    func sortedLogs() -> [WorkoutLog] { data.logs.sorted { $0.date < $1.date } }

    func lastFor(_ id: String) -> (date: String, sets: [[Double]])? {
        for l in sortedLogs().reversed() {
            if let s = l.ex[id], !s.isEmpty { return (l.date, s) }
        }
        return nil
    }

    func orderedKeys(_ log: WorkoutLog) -> [String] {
        let order = (plan(log.day)?.ex.map { $0.id }) ?? []
        let known = order.filter { log.ex[$0] != nil }
        let rest = log.ex.keys.filter { !order.contains($0) }.sorted()
        return known + rest
    }

    // MARK: Logic

    func working(_ sets: [[Double]], _ e: Exercise) -> (w: Double, reps: [Double]) {
        var by: [Double: [Double]] = [:]
        var weights: [Double] = []
        for s in sets where s.count >= 2 {
            if by[s[0]] == nil { weights.append(s[0]) }
            by[s[0], default: []].append(s[1])
        }
        guard var best = weights.first else { return (0, []) }
        for w in weights {
            let a = by[w]?.count ?? 0
            let b = by[best]?.count ?? 0
            let top = by[w]?.max() ?? 0
            if a > b || (a == b && w > best && top >= Double(e.min)) { best = w }
        }
        return (best, by[best] ?? [])
    }

    func suggest(_ e: Exercise) -> SuggestionInfo {
        guard let last = lastFor(e.id) else {
            return SuggestionInfo(weight: e.start, text: "Başlangıç", kind: .start)
        }
        if e.isBodyweight {
            let best = last.sets.map { $0.count > 1 ? $0[1] : 0 }.max() ?? 0
            return SuggestionInfo(weight: 0, text: "Hedef: \(Fmt.num(best + 1))+ tekrar", kind: .same)
        }
        let wk = working(last.sets, e)
        let enough = wk.reps.count >= Swift.min(e.sets, 2)
        let allMax = enough && wk.reps.allSatisfy { $0 >= Double(e.max) }
        if allMax {
            return SuggestionInfo(weight: wk.w + e.inc, text: "+\(Fmt.num(e.inc)) kg ekle", kind: .up)
        }
        if wk.reps.contains(where: { $0 < Double(e.min) }) {
            return SuggestionInfo(weight: wk.w, text: "Kiloyu koru", kind: .hold)
        }
        return SuggestionInfo(weight: wk.w, text: "Aynı kilo, +1 tekrar", kind: .same)
    }

    func nextInfo() -> (day: String, rest: Bool, last: WorkoutLog?) {
        guard let last = sortedLogs().last else { return ("push", false, nil) }
        let days = Calendar.current.dateComponents([.day],
                                                   from: Calendar.current.startOfDay(for: Fmt.date(last.date)),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if last.day == "legs" { return ("push", days <= 1, last) }
        let i = Store.order.firstIndex(of: last.day) ?? -1
        let next = (i >= 0 && i + 1 < Store.order.count) ? Store.order[i + 1] : "push"
        return (next, false, last)
    }

    func progress(_ id: String) -> [ProgressPoint] {
        guard let e = exercise(id) else { return [] }
        return sortedLogs().compactMap { l in
            guard let s = l.ex[id], !s.isEmpty else { return nil }
            let wk = working(s, e)
            return ProgressPoint(id: l.id, date: Fmt.date(l.date), w: wk.w, r: wk.reps.max() ?? 0)
        }
    }

    func heartPoints() -> [HeartPoint] {
        var out: [HeartPoint] = []
        for l in sortedLogs() {
            if let a = l.hrAvg { out.append(HeartPoint(id: l.id + "a", date: Fmt.date(l.date), value: a, kind: "Ortalama")) }
            if let m = l.hrMax { out.append(HeartPoint(id: l.id + "m", date: Fmt.date(l.date), value: m, kind: "Maks")) }
        }
        return out
    }

    // MARK: Drafts

    func ensureDraft(_ day: String) {
        guard let p = plan(day) else { return }
        var d = drafts[day] ?? Draft(date: Date(), sets: [:])
        var changed = drafts[day] == nil
        for e in p.ex where d.sets[e.id] == nil {
            let s = suggest(e)
            let w = e.isBodyweight ? "" : Fmt.num(s.weight)
            d.sets[e.id] = Array(repeating: SetEntry(w: w, r: "", done: false), count: Swift.max(1, e.sets))
            changed = true
        }
        if changed {
            drafts[day] = d
            saveDrafts()
        }
    }

    func entries(_ day: String, _ ex: String) -> [SetEntry] { drafts[day]?.sets[ex] ?? [] }

    func update(_ day: String, _ ex: String, _ i: Int, _ change: (inout SetEntry) -> Void) {
        guard var d = drafts[day], var arr = d.sets[ex], arr.indices.contains(i) else { return }
        change(&arr[i])
        d.sets[ex] = arr
        drafts[day] = d
        saveDrafts()
    }

    func addSet(_ day: String, _ ex: String) {
        guard var d = drafts[day], var arr = d.sets[ex] else { return }
        let w = arr.last?.w ?? ""
        arr.append(SetEntry(w: w, r: "", done: false))
        d.sets[ex] = arr
        drafts[day] = d
        saveDrafts()
    }

    func removeSet(_ day: String, _ ex: String) {
        guard var d = drafts[day], var arr = d.sets[ex], arr.count > 1 else { return }
        arr.removeLast()
        d.sets[ex] = arr
        drafts[day] = d
        saveDrafts()
    }

    func draftDate(_ day: String) -> Date { drafts[day]?.date ?? Date() }

    func setDraftDate(_ day: String, _ date: Date) {
        guard var d = drafts[day] else { return }
        d.date = date
        drafts[day] = d
        saveDrafts()
    }

    func filledSetCount(_ day: String) -> Int {
        guard let d = drafts[day] else { return 0 }
        return d.sets.values.reduce(0) { acc, arr in
            acc + arr.filter { (Fmt.parse($0.r) ?? 0) > 0 }.count
        }
    }

    @discardableResult
    func saveWorkout(day: String, hrAvg: Int?, hrMax: Int?, minutes: Int?) -> Int {
        guard let d = drafts[day] else { return 0 }
        var ex: [String: [[Double]]] = [:]
        var n = 0
        for (id, arr) in d.sets {
            guard let e = exercise(id) else { continue }
            let sets: [[Double]] = arr.compactMap { s in
                guard let r = Fmt.parse(s.r), r > 0 else { return nil }
                let w = e.isBodyweight ? 0 : (Fmt.parse(s.w) ?? 0)
                return [w, r]
            }
            if !sets.isEmpty {
                ex[id] = sets
                n += sets.count
            }
        }
        guard n > 0 else { return 0 }
        let log = WorkoutLog(id: "l\(Int(Date().timeIntervalSince1970 * 1000))",
                             date: Fmt.isoString(d.date), day: day, ex: ex,
                             hrAvg: hrAvg, hrMax: hrMax, minutes: minutes)
        data.logs.append(log)
        data.rev += 1
        drafts[day] = nil
        save()
        saveDrafts()
        return n
    }

    func delete(_ id: String) {
        data.logs.removeAll { $0.id == id }
        data.rev += 1
        save()
    }
}

final class RestTimer: ObservableObject {
    @Published var end: Date?
    @Published var visible = false

    func start(_ seconds: Int) {
        end = Date().addingTimeInterval(Double(seconds))
        visible = true
    }

    func add(_ seconds: Int) {
        let base = Swift.max(end ?? Date(), Date())
        end = base.addingTimeInterval(Double(seconds))
    }

    func close() {
        visible = false
        end = nil
    }
}
