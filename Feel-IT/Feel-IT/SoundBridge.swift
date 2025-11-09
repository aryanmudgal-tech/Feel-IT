import Foundation
import AVFAudio
import SoundAnalysis
import CoreMedia

final class SoundBridge: NSObject, SNResultsObserving {
    
    private(set) var isRunning = false
    var confidenceThreshold: Double = 0.50
    var onTopK: ((String, Double) -> Void)? // This will now send the displayName

    // MARK: - Global Cooldown
    private var cooldown: TimeInterval = 1.5 // 1.5 seconds
    private var lastSendTime: [String: Date] = [:] // Cooldown is per-ID

    // MARK: - Audio/analysis plumbing
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer!
    private let q = DispatchQueue(label: "sound.analysis.q")
    private let ble: BLEClient

    init(ble: BLEClient) {
        self.ble = ble
        super.init()
    }

    // MARK: - Lifecycle
    func start() {
        guard !isRunning else { return }
        print("SB: Starting SoundBridge...")
        startAudio()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        print("SB: Stopping SoundBridge...")
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        if let analyzer = analyzer {
            analyzer.removeAllRequests()
        }
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }

    // MARK: - Audio setup
    private func startAudio() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.record, options: [.mixWithOthers])
            try session.setMode(.measurement)
            try session.setPreferredSampleRate(session.sampleRate)
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("SB: session error ->", error)
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        analyzer = SNAudioStreamAnalyzer(format: format)

        do {
            let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
            req.windowDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: Int32(format.sampleRate))
            req.overlapFactor  = 0.9
            try analyzer.add(req, withObserver: self)
        } catch {
            print("SB: add classifier error ->", error)
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, when in
            guard let self = self else { return }
            self.q.async {
                try? self.analyzer.analyze(buf, atAudioFramePosition: when.sampleTime)
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("SB: engine start error ->", error)
        }
    }

    // MARK: - SNResultsObserving (The CRITICAL Change)
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let r = result as? SNClassificationResult else { return }
        guard let best = r.classifications.first else { return }
        
        // Debug: Print all sounds
        let debugLabel = norm(best.identifier)
        let debugConf = Int(best.confidence * 100)
        print("SB-Debug: '\(debugLabel)' (\(debugConf)%)")
        
        // 1. Check confidence
        guard best.confidence >= self.confidenceThreshold else {
            return
        }

        // 2. NORMALIZE ID (e.g., "finger_snapping" -> "clapping")
        // This is the aliasing you asked for.
        let normalizedID = norm(best.identifier)
        let conf  = Double(best.confidence)
        
        // 3. CHECK IF SELECTED
        // --- THIS IS THE FIX ---
        guard SoundStore.shared.isSoundSelected(id: normalizedID) else {
            // print("SB: Ignoring '\(normalizedID)' (not in user's list)")
            return
        }
        
        // 4. GET DISPLAY NAME (This is the fix for Problem 1)
        // Find the full SoundCategory object from the store
        guard let soundCategory = SoundStore.shared.allSounds.first(where: { $0.id == normalizedID }) else {
            print("SB: Error! Normalized ID '\(normalizedID)' not found in SoundStore!")
            return
        }
        let displayName = soundCategory.displayName // e.g., "Clapping"
        
        // 5. Update UI (with the user-friendly DisplayName)
        DispatchQueue.main.async {
            self.onTopK?(displayName, conf)
        }
        
        // 6. Check Cooldown (cooldown is by ID, not display name)
        if !ready(label: normalizedID) {
            return
        }

        // 7. Send DISPLAY NAME to ESP32
        let confidenceInt = UInt8(max(0, min(100, Int(round(conf * 100)))))
        let dataString = "\(displayName):\(confidenceInt)" // e.g., "Clapping:80"
        
        print("SB: Sending display name: \(dataString)")
        send(data: dataString)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundAnalysis error:", error)
        DispatchQueue.main.async {
            self.stop()
        }
    }

    // MARK: - Helpers
    private func send(data: String) {
        DispatchQueue.main.async {
            self.ble.send(data: data)
        }
    }

    private func ready(label: String) -> Bool {
        let now = Date()
        let lastTime = lastSendTime[label] ?? .distantPast
        
        guard now.timeIntervalSince(lastTime) >= cooldown else {
            return false // On cooldown
        }
        
        lastSendTime[label] = now // Update the timestamp
        return true
    }

    // --- THIS FUNCTION IS NOW THE ALIASING HUB ---
    private func norm(_ id: String) -> String {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased()
                            .replacingOccurrences(of: " ", with: "_")
        
        // --- Aliases ---
        // This is where we group sounds.
        // We map all variations to the *canonical ID* from SoundStore.swift
        switch normalized {
        
        // Group baby sounds
        case "baby_cry", "infant_cry", "crying_sobbing":
            return "baby_crying" // Canonical ID
            
        // Group clapping sounds
        case "clapping", "applause", "finger_snapping":
            return "clapping" // Canonical ID
            
        // Group dog sounds
        case "dog", "bark":
            return "dog_bark" // Canonical ID
            
        // Group fire alarms
        case "fire_alarm", "smoke_detector":
            return "fire_alarm" // Canonical ID
        
        // Group roosters
        case "rooster", "rooster_crow":
            return "rooster" // Canonical ID
            
        case "car_horn", "truck", "air_horn", "beep":
            return "car_horn" // Canonical ID
            
        default:
            // Return the normalized string if no alias matches
            return normalized
        }
    }
}
