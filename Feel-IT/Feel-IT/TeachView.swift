import SwiftUI

struct TeachView: View {
    @State private var label: String = ""
    @State private var isRecording = false
    @State private var log: [String] = []
    
    private let teach = TeachController.shared

    var body: some View {
        VStack(spacing: 16) {

            TextField("Enter name for this sound (e.g., kettle)", text: $label)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Button {
                    guard !isRecording else { return }
                    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        log.append("❗ Please enter a label first.")
                        return
                    }
                    
                    isRecording = true
                    teach.startRecording()
                    log.append("Recording started for '\(trimmed)'…")
                    
                } label: {
                    Text("Record")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRecording)

                Button {
                    guard isRecording else { return }
                    isRecording = false
                    
                    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        log.append("❗ Error: Label was empty.")
                        return
                    }
                    
                    teach.stopAndEnroll(label: trimmed)
                    log.append("Processing and saving '\(trimmed)'...")
                    label = ""
                    
                } label: {
                    Text("Stop & Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isRecording)
            }
            .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Saved Labels:")
                    .font(.subheadline)
                if CustomSoundStore.shared.items.isEmpty {
                    Text("— none yet —").foregroundColor(.secondary)
                } else {
                    ForEach(CustomSoundStore.shared.items) { cs in
                        HStack {
                            Text(cs.label)
                            Spacer()
                            Text("count \(cs.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Teach New Sound")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ NO .onAppear or .onDisappear needed!
    }
}
