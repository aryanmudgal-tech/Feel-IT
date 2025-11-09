//
//  CustomSound.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import Foundation

struct CustomSound: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var centroid: [Float]   // “embedding” vector we’ll learn from user recordings
    var count: Int          // how many samples taught so far
    var radius: Float       // spread (used later for thresholding)
    var lastTriggeredAt: TimeInterval?
}
