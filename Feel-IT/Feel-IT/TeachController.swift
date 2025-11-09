//
//  TeachController.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//
import Foundation

final class TeachController {
    
    // We will share this instance across the app
    // THIS IS THE LINE THAT FIXES THE ERROR
    static let shared = TeachController()
    
    private var collectedSamples: [Float] = []
    private var isRecording = false
    
    // 16000 samples/sec * 10 seconds = 160,000 floats max
    private let maxSamples = 16000 * 10

    /// Called by other parts of the app (like the detection pipeline) feeding it live audio
    func feed(audio mono16k: [Float]) {
        guard isRecording else { return }
        
        // Append samples, but don't go over the max limit
        if collectedSamples.count < maxSamples {
            let samplesToTake = min(mono16k.count, maxSamples - collectedSamples.count)
            collectedSamples.append(contentsOf: mono16k.prefix(samplesToTake))
        }
    }

    /// Called by TeachView when "Record" is tapped
    func startRecording() {
        collectedSamples = [] // Clear any old audio
        isRecording = true
        print("Teach: recording started...")
    }

    /// Called by TeachView when "Stop & Save" is tapped
    func stopAndEnroll(label: String) {
        guard isRecording else { return }
        isRecording = false

        guard !collectedSamples.isEmpty else {
            print("Teach: ❌ NO AUDIO CAPTURED")
            print("Teach: Collected samples: \(collectedSamples.count)")
            return
        }
        
        print("Teach: ✅ Captured \(collectedSamples.count) samples (~\(Double(collectedSamples.count)/16000.0) seconds)")
        
        // Pass the raw audio to the pipeline for embedding
        CustomDetectionPipeline.shared.enroll(label: label, samples: collectedSamples)
        
        // Clear memory
        collectedSamples = []
    }
}
