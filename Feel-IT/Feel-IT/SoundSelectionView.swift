import SwiftUI

struct SoundSelectionView: View {
    
    // --- NEW: Gets the environment's presentation mode ---
    @Environment(\.presentationMode) var presentationMode
    
    // Observe the shared store for changes
    @ObservedObject private var store = SoundStore.shared
    @State private var showLimitAlert = false
    
    var body: some View {
        List {
            // Header showing the current count
            Section {
                Text("Select the sounds you want to be notified about. You can select up to 20.")
                    .font(.caption)
                Text("Selected: \(store.selectedSoundIDs.count) / 20")
                    .font(.headline)
                    .foregroundColor(store.selectedSoundIDs.count >= 20 ? .red : .primary)
            }
            
            Section(header: Text("All Sounds")) {
                ForEach(store.allSounds, id: \.self) { sound in
                    HStack {
                        Text(sound.emoji)
                            .font(.title)
                            .frame(width: 40)
                        Text(sound.displayName)
                        Spacer()
                        if store.isSoundSelected(id: sound.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.5))
                                .font(.title2)
                        }
                    }
                    .contentShape(Rectangle()) // Makes the whole row tappable
                    .onTapGesture {
                        let didExceed = store.toggleSelection(id: sound.id, limit: 20)
                        self.showLimitAlert = didExceed
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("Add/Edit Sounds")
        .navigationBarTitleDisplayMode(.inline)
        // --- NEW: Adds the "Done" button ---
        .navigationBarItems(trailing:
            Button("Done") {
                // This dismisses the current view
                self.presentationMode.wrappedValue.dismiss()
            }
        )
        .alert(isPresented: $showLimitAlert) {
            Alert(
                title: Text("Selection Limit Reached"),
                message: Text("You can only select up to 20 sounds."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// A preview provider for Xcode
struct SoundSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store = SoundStore.shared
        _ = store.toggleSelection(id: "clapping")
        _ = store.toggleSelection(id: "dog")
        
        return NavigationView {
            SoundSelectionView()
        }
    }
}
