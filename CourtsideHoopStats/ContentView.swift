import SwiftUI

/// Placeholder "dummy" screen used to validate the build + device-install
/// pipeline before real features are added. The full app scaffold lives in
/// the repo's `Staged/` folder and will be reintroduced (with the WWDC-aligned
/// design pass) once this first install is confirmed working on device.
struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.18, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color(red: 0.30, green: 0.78, blue: 0.31))

                Text("Courtside Hoop Stats")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Build test successful 🏀")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
