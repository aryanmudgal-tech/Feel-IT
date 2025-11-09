import Foundation
import Combine

// The model for a single sound
struct SoundCategory: Identifiable, Hashable {
    let id: String        // The raw ID from SoundAnalysis (e.g., "clapping")
    let displayName: String
    let emoji: String
}

final class SoundStore: ObservableObject {
    
    static let shared = SoundStore()
    private let userDefaultsKey = "SelectedSoundIDs"
    
    @Published private(set) var selectedSoundIDs: Set<String> = []
    
    // The master list of all sounds
    let allSounds: [SoundCategory] = [
        // --- Your 5 Requested Sounds (with canonical IDs) ---
        SoundCategory(id: "baby_crying", displayName: "Baby Crying", emoji: "👶"),
        SoundCategory(id: "clapping", displayName: "Clapping", emoji: "👏"),
        SoundCategory(id: "dog_bark", displayName: "Dog Bark", emoji: "🐶"),
        SoundCategory(id: "car_horn", displayName: "Car Horn", emoji: "🚗"),
        SoundCategory(id: "fire_alarm", displayName: "Fire Alarm", emoji: "🔥"),
        
        // --- Other Sounds ---
        SoundCategory(id: "speech", displayName: "Speech", emoji: "💬"),
        SoundCategory(id: "laughter", displayName: "Laughter", emoji: "😂"),
        SoundCategory(id: "cough", displayName: "Cough", emoji: "🗣️"),
        SoundCategory(id: "sneezing", displayName: "Sneeze", emoji: "🤧"),
        SoundCategory(id: "snoring", displayName: "Snoring", emoji: "😴"),
        SoundCategory(id: "cheering", displayName: "Cheering", emoji: "🎉"),
        SoundCategory(id: "whispering", displayName: "Whispering", emoji: "🤫"),
        SoundCategory(id: "screaming", displayName: "Screaming", emoji: "😱"),
        SoundCategory(id: "whistling", displayName: "Whistling", emoji: "🌬️"),
        SoundCategory(id: "breathing", displayName: "Breathing", emoji: "😮‍💨"),
        SoundCategory(id: "singing", displayName: "Singing", emoji: "🎤"),
        SoundCategory(id: "baby_laughter", displayName: "Baby Laughter", emoji: "😄"),
        SoundCategory(id: "baby_talk", displayName: "Baby Talk", emoji: "👶"),
        SoundCategory(id: "alarm_clock", displayName: "Alarm Clock", emoji: "⏰"),
        SoundCategory(id: "police_siren", displayName: "Police Siren", emoji: "🚓"),
        SoundCategory(id: "ambulance_siren", displayName: "Ambulance Siren", emoji: "🚑"),
        SoundCategory(id: "fire_truck_siren", displayName: "Fire Truck Siren", emoji: "🚒"),
        SoundCategory(id: "civil_defense_siren", displayName: "Warning Siren", emoji: "🚨"),
        SoundCategory(id: "buzzer", displayName: "Buzzer", emoji: "📟"),
        SoundCategory(id: "beep", displayName: "Beep", emoji: "📟"),
        SoundCategory(id: "door_bell", displayName: "Doorbell", emoji: "🔔"),
        SoundCategory(id: "knock", displayName: "Knock", emoji: "🚪"),
        SoundCategory(id: "door", displayName: "Door Open/Close", emoji: "🚪"),
        SoundCategory(id: "telephone_bell", displayName: "Telephone Ring", emoji: "☎️"),
        SoundCategory(id: "microwave_oven", displayName: "Microwave", emoji: "📟"),
        SoundCategory(id: "blender", displayName: "Blender", emoji: "🌪️"),
        SoundCategory(id: "vacuum_cleaner", displayName: "Vacuum Cleaner", emoji: "🧹"),
        SoundCategory(id: "hair_dryer", displayName: "Hair Dryer", emoji: "💨"),
        SoundCategory(id: "washing_machine", displayName: "Washing Machine", emoji: "🧺"),
        SoundCategory(id: "toilet_flush", displayName: "Toilet Flush", emoji: "🚽"),
        SoundCategory(id: "water_tap", displayName: "Running Water", emoji: "🚰"),
        SoundCategory(id: "keyboard", displayName: "Keyboard Typing", emoji: "⌨️"),
        SoundCategory(id: "writing", displayName: "Writing (Pen/Pencil)", emoji: "✏️"),
        SoundCategory(id: "snip", displayName: "Scissors", emoji: "✂️"),
        SoundCategory(id: "cat", displayName: "Cat Meow", emoji: "🐱"),
        SoundCategory(id: "bird", displayName: "Bird", emoji: "🐦"),
        SoundCategory(id: "rooster", displayName: "Rooster", emoji: "🐔"),
        SoundCategory(id: "chicken", displayName: "Chicken", emoji: "🐔"),
        SoundCategory(id: "cow", displayName: "Cow", emoji: "🐮"),
        SoundCategory(id: "horse", displayName: "Horse", emoji: "🐴"),
        SoundCategory(id: "sheep", displayName: "Sheep", emoji: "🐑"),
        SoundCategory(id: "pig", displayName: "Pig", emoji: "🐷"),
        SoundCategory(id: "frog", displayName: "Frog", emoji: "🐸"),
        SoundCategory(id: "cricket", displayName: "Cricket", emoji: "🦗"),
        SoundCategory(id: "insect", displayName: "Insect", emoji: "🐝"),
        SoundCategory(id: "car", displayName: "Car", emoji: "🚙"),
        SoundCategory(id: "bus", displayName: "Bus", emoji: "🚌"),
        SoundCategory(id: "truck", displayName: "Truck", emoji: "🚚"),
        SoundCategory(id: "train", displayName: "Train", emoji: "🚆"),
        SoundCategory(id: "motorcycle", displayName: "Motorcycle", emoji: "🏍️"),
        SoundCategory(id: "airplane", displayName: "Airplane", emoji: "✈️"),
        SoundCategory(id: "helicopter", displayName: "Helicopter", emoji: "🚁"),
        SoundCategory(id: "boat", displayName: "Boat", emoji: "🚤"),
        SoundCategory(id: "bicycle", displayName: "Bicycle", emoji: "🚲"),
        SoundCategory(id: "music", displayName: "Music", emoji: "🎶"),
        SoundCategory(id:"guitar", displayName: "Guitar", emoji: "🎸"),
        SoundCategory(id: "piano", displayName: "Piano", emoji: "🎹"),
        SoundCategory(id: "violin", displayName: "Violin", emoji: "🎻"),
        SoundCategory(id: "trumpet", displayName: "Trumpet", emoji: "🎺"),
        SoundCategory(id: "drum", displayName: "Drum", emoji: "🥁"),
        SoundCategory(id: "cello", displayName: "Cello", emoji: "🎻"),
        SoundCategory(id: "flute", displayName: "Flute", emoji: "🎶"),
        SoundCategory(id: "thunder", displayName: "Thunder", emoji: "⛈️"),
        SoundCategory(id: "rain", displayName: "Rain", emoji: "🌧️"),
        SoundCategory(id: "wind", displayName: "Wind", emoji: "💨"),
        SoundCategory(id: "water", displayName: "Water", emoji: "🌊"),
        SoundCategory(id: "fire", displayName: "Fire", emoji: "🔥"),
        SoundCategory(id: "explosion", displayName: "Explosion", emoji: "💥"),
        SoundCategory(id: "glass", displayName: "Glass Breaking", emoji: "🧊"),
        SoundCategory(id: "tools", displayName: "Tools", emoji: "🛠️"),
        SoundCategory(id: "clock", displayName: "Clock", emoji: "🕰️"),
        SoundCategory(id: "sound_effect", displayName: "Sound Effect", emoji: "🔊"),
    ]

    init() {
        loadSelection()
    }
    
    // Check if a sound is selected
    func isSoundSelected(id: String) -> Bool {
        selectedSoundIDs.contains(id)
    }
    
    // Toggle a sound's selection state
    // Returns 'true' if the limit was exceeded
    func toggleSelection(id: String, limit: Int = 20) -> Bool {
        var didExceedLimit = false
        if selectedSoundIDs.contains(id) {
            selectedSoundIDs.remove(id)
        } else {
            if selectedSoundIDs.count < limit {
                selectedSoundIDs.insert(id)
            } else {
                didExceedLimit = true
            }
        }
        saveSelection()
        return didExceedLimit
    }

    // Load the saved set from UserDefaults
    func loadSelection() {
        let savedArray = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] ?? []
        self.selectedSoundIDs = Set(savedArray)
    }

    // Save the set to UserDefaults
    private func saveSelection() {
        UserDefaults.standard.set(Array(self.selectedSoundIDs), forKey: userDefaultsKey)
    }
}
