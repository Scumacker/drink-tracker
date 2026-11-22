import UIKit
import UserNotifications

/// Native Mitteilungen über APNs. Die Web-App fragt über die Brücke nach Erlaubnis und Token und meldet
/// das Token selbst beim Server an (POST /api/push/apns); der Worker schickt dann direkt an Apple.
@MainActor
final class Push {
    static let shared = Push()

    private var wartende: [(Result<String, Error>) -> Void] = []
    private var token: String?

    /// Aus Xcode installierte Builds sprechen mit der Sandbox, TestFlight und App Store mit Production
    var umgebung: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Aktuelle Erlaubnis, ohne zu fragen
    func status(_ fertig: @escaping ([String: Any]) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let status: String
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: status = "granted"
            case .denied: status = "denied"
            default: status = "notDetermined"
            }
            DispatchQueue.main.async { fertig(["status": status]) }
        }
    }

    /// Erlaubnis holen (fragt nur beim ersten Mal) und das Geräte-Token liefern
    func registrieren(_ fertig: @escaping ([String: Any]) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { erlaubt, fehler in
            DispatchQueue.main.async {
                if let fehler {
                    fertig(["status": "error", "error": fehler.localizedDescription])
                    return
                }
                guard erlaubt else {
                    fertig(["status": "denied"])
                    return
                }
                self.tokenHolen { ergebnis in
                    switch ergebnis {
                    case .success(let token):
                        fertig(["status": "granted", "token": token, "environment": self.umgebung])
                    case .failure(let e):
                        fertig(["status": "error", "error": "Kein Push-Token von Apple: \(e.localizedDescription)"])
                    }
                }
            }
        }
    }

    private func tokenHolen(_ fertig: @escaping (Result<String, Error>) -> Void) {
        wartende.append(fertig)
        // Auch mit bekanntem Token neu registrieren: Apple kann es ändern, die Antwort kommt sofort
        UIApplication.shared.registerForRemoteNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, !self.wartende.isEmpty else { return }
            if let token = self.token {
                self.abschliessen(.success(token))
            } else {
                self.abschliessen(.failure(NSError(domain: "Stammtisch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Zeitüberschreitung"])))
            }
        }
    }

    func tokenErhalten(_ daten: Data) {
        let hex = daten.map { String(format: "%02x", $0) }.joined()
        token = hex
        abschliessen(.success(hex))
    }

    func registrierungFehlgeschlagen(_ fehler: Error) {
        abschliessen(.failure(fehler))
    }

    private func abschliessen(_ ergebnis: Result<String, Error>) {
        let alle = wartende
        wartende = []
        alle.forEach { $0(ergebnis) }
    }
}
