import Foundation

final class CustomDetectionPipeline {
    
    var onEmbedding: (([Float]) -> Void)?
    var onMatch: ((CustomSound, Float) -> Void)?

    var similarityThreshold: Float = 0.85
    var minCooldown: TimeInterval = 2.0

    static let shared = CustomDetectionPipeline()

    private let SR = 16_000
    private let WINDOW = Int(0.8 * 16_000)
    private let HOP    = Int(0.8 * 16_000)

    private let extractor = FeatureExtractor()
    private var ring: [Float] = []
    private var chunkCount = 0
    
    // --- NEW: Enable/disable detection ---
    private var isEnabled = false
    
    func start() {
        isEnabled = true
        ring = [] // Clear the ring buffer
        chunkCount = 0
        print("CustomDetection: Started")
    }
    
    func stop() {
        isEnabled = false
        ring = [] // Clear the ring buffer
        print("CustomDetection: Stopped")
    }
    
    // MARK: - NEW Enroll Function
    func enroll(label: String, samples: [Float]) {
        guard !samples.isEmpty else {
            print("Enroll: No samples provided.")
            return
        }
        
        let e = extractor.embed(pcm: samples)
        
        var model = CustomSoundStore.shared.byLabel(label) ?? CustomSound(
            id: UUID(),
            label: label,
            centroid: [],
            count: 0,
            radius: 1e-6,
            lastTriggeredAt: nil
        )

        var centroid = model.centroid
        var radius   = model.radius
        var count    = model.count
        
        OnlineStats.update(centroid: &centroid, radius: &radius, count: &count, new: e)

        model.centroid = centroid
        model.radius   = radius
        model.count    = count

        CustomSoundStore.shared.upsert(model)
        print("Teach: enrolled '\(label)' (count=\(model.count), dim=\(model.centroid.count))")
    }
    
    // MARK: - Ingest/Detect Function

    func ingest(mono16k: [Float], appleLabel: String? = nil, appleConfidence: Double = 0.0) {
        guard isEnabled else { return }
        
        ring.append(contentsOf: mono16k)

        while ring.count >= WINDOW {
            let chunk = Array(ring.prefix(WINDOW))
            ring.removeFirst(HOP)

            let emb = extractor.embed(pcm: chunk)
            chunkCount += 1
            
            onEmbedding?(emb)
            
            let savedSounds = CustomSoundStore.shared.items
            guard !savedSounds.isEmpty else { continue }

            // --- NEW LOGIC: Filter by Apple's label if provided ---
            var candidateSounds = savedSounds
            
            if let appleLabel = appleLabel, !appleLabel.isEmpty {
                // Only check custom sounds with labels similar to what Apple detected
                candidateSounds = savedSounds.filter { customSound in
                    labelsSimilar(customSound.label, appleLabel)
                }
                
                // If no similar labels, skip custom detection entirely
                if candidateSounds.isEmpty {
                    print("CustomDetection: No custom sounds match Apple's '\(appleLabel)' - skipping")
                    continue
                }
            }
            
            // --- Find best match among candidates ---
            var bestMatch: CustomSound? = nil
            var bestSimilarity: Float = -1.0

            for sound in candidateSounds {
                let similarity = OnlineStats.cosine(emb, sound.centroid)
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestMatch = sound
                }
            }
            
            // --- HIGHER THRESHOLD: 0.95 for custom sounds ---
            guard var match = bestMatch, bestSimilarity >= 0.95 else {
                if bestMatch != nil {
                    print("CustomDetection: Best match '\(bestMatch!.label)' only \(String(format: "%.2f", bestSimilarity)) - not confident enough")
                }
                continue
            }
            
            let now = Date().timeIntervalSince1970
            let lastTriggered = match.lastTriggeredAt ?? 0.0
            
            guard (now - lastTriggered) >= minCooldown else {
                continue
            }
            
            match.lastTriggeredAt = now
            CustomSoundStore.shared.upsert(match)
            
            print("CUSTOM MATCH ✅: '\(match.label)' (Similarity: \(String(format: "%.2f", bestSimilarity)))")
            onMatch?(match, bestSimilarity)
        }
    }

    // Helper: Check if two labels are similar enough to compare
    private func labelsSimilar(_ custom: String, _ apple: String) -> Bool {
        let c = custom.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let a = apple.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if c == a { return true }
        
        // One contains the other
        if c.contains(a) || a.contains(c) { return true }
        
        // Add more fuzzy matching as needed
        // e.g., "kettle" vs "boiling_water", "doorbell" vs "door_bell"
        let customWords = c.components(separatedBy: CharacterSet(charactersIn: " _-"))
        let appleWords = a.components(separatedBy: CharacterSet(charactersIn: " _-"))
        
        // Check if any words overlap
        for cw in customWords {
            for aw in appleWords {
                if !cw.isEmpty && !aw.isEmpty && (cw == aw || cw.contains(aw) || aw.contains(cw)) {
                    return true
                }
            }
        }
        
        return false
    }
}
