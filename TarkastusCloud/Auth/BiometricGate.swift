import SwiftUI
import LocalAuthentication

struct BiometricGate<Content: View>: View {
    @AppStorage("biometricPromptShown") private var prompted = false
    @State private var offer = false
    @AppStorage("biometricLock") private var enabled = false
    @Environment(\.scenePhase) private var phase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var message = ""
    @ViewBuilder var content: () -> Content
    var body: some View {
        Group {
            if !enabled || unlocked { content() }
            else {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield").font(.largeTitle)
                    Button("Unlock Tarkastus Cloud") { unlock() }.disabled(authenticating)
                    Text(message).font(.footnote)
                }.padding()
            }
        }
        .onAppear {
            if enabled { unlock() }
            else if !prompted {
                var error: NSError?
                if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { offer = true }
            }
        }
        .alert("Biometric protection", isPresented: $offer) {
            Button("Not now", role: .cancel) { prompted = true }
            Button("Enable") { prompted = true; enabled = true; unlock() }
        } message: {
            Text("Protect access to Tarkastus Cloud with Face ID or Touch ID. You can change this later in Settings.")
        }
        .onChange(of: enabled) { value in
            if value && !unlocked { unlock() }
            if !value { unlocked = false }
        }
        .onChange(of: phase) { value in
            if value == .background { unlocked = false }
            if value == .active && enabled && !unlocked { unlock() }
        }
    }
    private func unlock() {
        guard !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = AppMessage.text("Device authentication unavailable.")
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: AppMessage.text("Unlock inspection reports")) { success, error in
            DispatchQueue.main.async {
                authenticating = false
                unlocked = success
                message = success ? "" : AppMessage.text("Authentication failed.")
            }
        }
    }
}
