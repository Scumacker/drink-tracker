import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = AppKonfig.hintergrund
        window.rootViewController = WebViewController.shared
        self.window = window
        window.makeKeyAndVisible()

        // App wurde über einen Link auf drink-tracker.app gestartet (Einladung, Admin-Link)
        for activity in connectionOptions.userActivities {
            linkOeffnen(activity)
        }
    }

    // Universal Link, während die App schon läuft
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        linkOeffnen(userActivity)
    }

    private func linkOeffnen(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL,
              AppKonfig.istEigene(url) else { return }
        WebViewController.shared.oeffne(url)
    }
}
