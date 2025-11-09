//
//  OnlineStats.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import Foundation

enum OnlineStats {
    /// Updates centroid and radius online (Welford-style)
    static func update(centroid: inout [Float], radius: inout Float, count: inout Int, new v: [Float]) {
        if centroid.isEmpty {
            // first sample initializes centroid to v and tiny radius
            centroid = v
            count = 1
            radius = 1e-6
            return
        }

        guard centroid.count == v.count else {
            // dimensions mismatched; reset to new
            centroid = v
            count = 1
            radius = 1e-6
            return
        }

        count += 1
        let n = Float(count)

        // Δ = v - centroid
        var delta = [Float](repeating: 0, count: v.count)
        v.withUnsafeBufferPointer { vb in
            centroid.withUnsafeMutableBufferPointer { cb in
                for i in 0..<v.count { delta[i] = vb[i] - cb[i] }
                for i in 0..<v.count { cb[i] += delta[i] / n } // centroid update
            }
        }

        // Δ2 = v - newCentroid
        var delta2 = [Float](repeating: 0, count: v.count)
        for i in 0..<v.count { delta2[i] = v[i] - centroid[i] }

        // increment for variance proxy
        var inc: Float = 0
        for i in 0..<v.count { inc += delta[i] * delta2[i] }

        let varN = (radius * (n - 1) + inc) / n
        radius = max(varN, 1e-6)
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        if a.isEmpty || b.isEmpty || a.count != b.count { return -1 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        let denom = (sqrt(na) * sqrt(nb))
        if denom == 0 { return -1 }
        return dot / denom
    }
}

