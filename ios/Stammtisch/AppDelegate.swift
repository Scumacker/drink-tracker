import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Früh setzen, damit auch ein Tipp auf eine Mitteilung beim Kaltstart ankommt
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }

    // MARK: Push (APNs)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Push.shared.tokenErhalten(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Push.shared.registrierungFehlgeschlagen(error)
    }

    // Auch bei offener App als Banner zeigen (z. B. «Pascal ist jetzt eingecheckt»)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // Tipp auf eine Mitteilung: die mitgeschickte Seite öffnen
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let pfad = response.notification.request.content.userInfo["url"] as? String ?? "/"
        if let url = AppKonfig.url(fuer: pfad) {
            DispatchQueue.main.async { WebViewController.shared.oeffne(url) }
        }
        completionHandler()
    }
}
