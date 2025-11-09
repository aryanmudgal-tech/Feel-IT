import UIKit
import AVFAudio
import SwiftUI

final class ViewController: UIViewController {
    
    // Create and own the BLE and SoundBridge instances
    let ble = BLEClient()
    var sound: SoundBridge?

    // UI
    let status = UILabel()
    let topLabel = UILabel()
    
    // --- REMOVED: All buttons and isListening var ---
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // --- MODIFIED: Setup Navigation Bar ---
        self.title = "Listening..." // Set the title
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        // (The rest of viewDidLoad is for setting up the UI)
        sound = SoundBridge(ble: ble)
        sound?.confidenceThreshold = 0.20

        status.text = "Ready to connect"
        status.textColor = .secondaryLabel
        status.textAlignment = .center
        status.numberOfLines = 2

        topLabel.text = "—"
        topLabel.textAlignment = .center
        topLabel.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        topLabel.numberOfLines = 1

        // --- MODIFIED: Simplified layout ---
        let stack = UIStackView(arrangedSubviews: [topLabel, status])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // BLE status updates the status label
        ble.onStatus = { [weak self] text, connected in
            DispatchQueue.main.async {
                self?.status.text = text
            }
        }
        
        // SoundBridge updates the topLabel
        sound?.onTopK = { [weak self] label, conf in
            DispatchQueue.main.async {
                // Make the text bigger
                self?.topLabel.font = .monospacedSystemFont(ofSize: 34, weight: .bold)
                self?.topLabel.text = "\(label.uppercased()) \(Int(conf * 100))%"
            }
        }
    }
    
    // --- NEW LOGIC ---
    // Start listening when the view appears
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("VC: View appeared, starting listener.")
        
        // Ask for permission *every time* it appears, just in case
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    self.sound?.start()
                    self.status.text = "Listening..."
                } else {
                    self.status.text = "Microphone permission denied"
                    self.topLabel.text = "Permission Denied"
                }
            }
        }
    }
    
    // --- NEW LOGIC ---
    // Stop listening when the view disappears
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("VC: View disappearing, stopping listener.")
        sound?.stop()
        topLabel.text = "—"
        topLabel.font = .monospacedSystemFont(ofSize: 22, weight: .medium) // Reset font
        status.text = "Stopped"
    }

    deinit {
        // Ensure it's stopped if VC is destroyed
        sound?.stop()
    }
}
