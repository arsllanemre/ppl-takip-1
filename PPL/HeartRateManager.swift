import Foundation
import HealthKit

/// iOS 26+: iPhone üzerinde HKWorkoutSession başlatır. AirPods Pro 3 (veya Apple Watch)
/// antrenman süresince nabzı Apple Sağlık'a yazar; HKLiveWorkoutBuilder bunu canlı verir.
final class HeartRateManager: NSObject, ObservableObject {
    @Published var bpm: Int?
    @Published var avg: Int?
    @Published var maxBpm: Int?
    @Published var running = false
    @Published var startDate: Date?
    @Published var message: String?

    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let hrType = HKQuantityType(.heartRate)
    private let unit = HKUnit.count().unitDivided(by: .minute())

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func start() {
        guard available else {
            message = "Bu cihazda Apple Sağlık kullanılamıyor."
            return
        }
        guard !running else { return }
        message = nil
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [hrType, HKObjectType.workoutType()]
        health.requestAuthorization(toShare: share, read: read) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.message = "Sağlık izni alınamadı: \(error.localizedDescription)"
                    return
                }
                self.beginSession()
            }
        }
    }

    private func beginSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        do {
            let s = try HKWorkoutSession(healthStore: health, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            builder = b
            let now = Date()
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { [weak self] ok, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if ok {
                        self.running = true
                        self.startDate = now
                        self.bpm = nil
                        self.avg = nil
                        self.maxBpm = nil
                    } else {
                        self.message = "Nabız takibi başlamadı: \(error?.localizedDescription ?? "bilinmeyen hata")"
                        self.session?.end()
                        self.session = nil
                        self.builder = nil
                    }
                }
            }
        } catch {
            message = "Antrenman başlatılamadı: \(error.localizedDescription)"
        }
    }

    /// Antrenmanı bitirir, Apple Sağlık'a kaydeder ve (ortalama, maks, dakika) döner.
    func stop(completion: @escaping (Int?, Int?, Int?) -> Void) {
        guard let s = session, let b = builder, let start = startDate else {
            completion(nil, nil, nil)
            return
        }
        let avgValue = avg
        let maxValue = maxBpm
        let end = Date()
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
        s.end()
        b.endCollection(withEnd: end) { _, _ in
            b.finishWorkout { _, _ in }
        }
        running = false
        session = nil
        builder = nil
        startDate = nil
        completion(avgValue, maxValue, minutes)
    }

    func cancel() {
        session?.end()
        builder?.discardWorkout()
        running = false
        session = nil
        builder = nil
        startDate = nil
        bpm = nil
        avg = nil
        maxBpm = nil
    }
}

extension HeartRateManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.message = "Antrenman oturumu hatası: \(error.localizedDescription)"
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(hrType), let st = workoutBuilder.statistics(for: hrType) else { return }
        let current = st.mostRecentQuantity()?.doubleValue(for: unit)
        let average = st.averageQuantity()?.doubleValue(for: unit)
        let maximum = st.maximumQuantity()?.doubleValue(for: unit)
        DispatchQueue.main.async {
            if let c = current { self.bpm = Int(c.rounded()) }
            if let a = average { self.avg = Int(a.rounded()) }
            if let m = maximum { self.maxBpm = Int(m.rounded()) }
        }
    }
}
