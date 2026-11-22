import UIKit

enum AppKonfig {
    /// Domain der Web-App, aus Info.plist (Build-Einstellung STAMMTISCH_HOST)
    static let host: String = {
        let wert = Bundle.main.object(forInfoDictionaryKey: "StammtischHost") as? String
        return (wert?.isEmpty == false ? wert! : "drink-tracker.app").lowercased()
    }()

    static var startURL: URL { URL(string: "https://\(host)/")! }

    static let version: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }()

    /// «Bar bei Nacht»: Hintergrund der Web-App, damit beim Laden nichts weiss aufblitzt
    static let hintergrund = UIColor(red: 0x0B / 255, green: 0x09 / 255, blue: 0x14 / 255, alpha: 1)

    /// Gehört die Adresse zur Web-App (inklusive www)?
    static func istEigene(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let h = url.host else { return false }
        return istEigenerHost(h)
    }

    static func istEigenerHost(_ h: String) -> Bool {
        let klein = h.lowercased()
        return klein == host || klein == "www.\(host)"
    }

    /// Pfad wie «/stats» oder volle Adresse zu einer URL der Web-App
    static func url(fuer pfad: String) -> URL? {
        guard let url = URL(string: pfad, relativeTo: startURL)?.absoluteURL, istEigene(url) else { return nil }
        return url
    }
}
