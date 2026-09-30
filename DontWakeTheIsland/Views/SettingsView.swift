import SwiftUI

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var isConfirmingReset = false

    var body: some View {
        @Bindable var settings = dependencies.settings

        Form {
            Section("Audio") {
                Toggle("Effets sonores", isOn: $settings.soundEnabled)
                Toggle("Musique", isOn: $settings.musicEnabled)
            }

            Section("Retours haptiques") {
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
            }

            Section {
                Toggle("Live Activity & Dynamic Island", isOn: $settings.liveActivityEnabled)
            } footer: {
                Text(liveActivityFooter(authorized: settings.liveActivitiesAuthorized))
            }

            Section {
                Button("Réinitialiser les scores", role: .destructive) {
                    isConfirmingReset = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Effacer tous les scores et statistiques ?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { settings.resetStats() }
        }
    }

    private func liveActivityFooter(authorized: Bool) -> String {
        guard authorized else {
            return "Les Live Activities sont désactivées pour cette app dans Réglages. Le jeu reste entièrement jouable."
        }
        return "Quand tu quittes l'app en pleine partie, la créature continue de dormir (ou de te guetter) dans la Dynamic Island et sur l'écran verrouillé."
    }
}
