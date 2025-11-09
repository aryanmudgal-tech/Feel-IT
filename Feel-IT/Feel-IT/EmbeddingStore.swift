//
//  EmbeddingStore.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import Foundation

struct LabeledEmbedding: Codable {
    let label: String
    let vector: [Float]
    let ts: Double
}

final class EmbeddingStore {
    static let shared = EmbeddingStore()
    private let baseURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("embeddings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func append(label: String, vector: [Float]) {
        let rec = LabeledEmbedding(label: label, vector: vector, ts: Date().timeIntervalSince1970)
        let url = baseURL.appendingPathComponent("\(label).jsonl")
        do {
            let data = try JSONEncoder().encode(rec) + Data([0x0A])
            if FileManager.default.fileExists(atPath: url.path) {
                let h = try FileHandle(forWritingTo: url)
                defer { try? h.close() }
                h.seekToEndOfFile()
                h.write(data)
            } else {
                try data.write(to: url)
            }
        } catch {
            print("STORE ⚠️ write failed: \(error)")
        }
    }
}
