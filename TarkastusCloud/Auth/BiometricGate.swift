import SwiftUI
import LocalAuthentication

struct BiometricGate<Content: View>: View {
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
        .onAppear { if enabled { unlock() } }
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
            message = error?.localizedDescription ?? "Device authentication unavailable."
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock inspection reports") { success, error in
            DispatchQueue.main.async {
                authenticating = false
                unlocked = success
                message = success ? "" : (error?.localizedDescription ?? "Authentication failed.")
            }
        }
    }
}
