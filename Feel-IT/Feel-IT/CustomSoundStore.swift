//
//  CustomSoundStore.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import Foundation

final class CustomSoundStore {
    static let shared = CustomSoundStore()

    private(set) var items: [CustomSound] = []

    private let url: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("custom_sounds.json")
    }()

    func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        if let arr = try? JSONDecoder().decode([CustomSound].self, from: data) {
            items = arr
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url)
    }

    func upsert(_ cs: CustomSound) {
        if let i = items.firstIndex(where: { $0.id == cs.id }) {
            items[i] = cs
        } else {
            items.append(cs)
        }
        save()
    }

    func byLabel(_ label: String) -> CustomSound? {
        items.first { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }
}
