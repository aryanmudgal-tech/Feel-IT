import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Feel-IT")
                    .font(.largeTitle.bold())
                    .padding(.top, 50)
                    .padding(.bottom, 40)
                
                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.bottom, 50)

                // 1. LISTEN BUTTON
                NavigationLink(destination: ListeningViewWrapper().edgesIgnoringSafeArea(.all)) {
                    Text("Start Listening")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }

                // 2. ADD/EDIT SOUND BUTTON
                NavigationLink(destination: SoundSelectionView()) {
                    Text("Add/Edit Sounds")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
}
