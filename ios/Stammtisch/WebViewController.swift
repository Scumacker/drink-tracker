import SafariServices
import UIKit
import WebKit

/// Zeigt drink-tracker.app im Vollbild. Eigene Seiten bleiben in der App, alles andere (Nachrichten-
/// Links, Mail, Telefon) öffnet Safari bzw. die passende App.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let shared = WebViewController()

    private var webView: WKWebView!
    private var ausstehend: URL?
    private var geladen = false
    private let offline = OfflineAnsicht()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: Aufbau

    override func loadView() {
        let config = WKWebViewConfiguration()
        // App-Bound Domain (Info.plist WKAppBoundDomains): Service Worker und Skript-Brücke erlaubt
        config.limitsNavigationsToAppBoundDomains = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "StammtischApp/\(AppKonfig.version.split(separator: " ").first ?? "1")"
        config.websiteDataStore = .default()

        let inhalt = WKUserContentController()
        inhalt.addUserScript(WKUserScript(source: Bruecke.skript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        inhalt.add(SchwacheNachricht(self), name: Bruecke.handlerName)
        config.userContentController = inhalt

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = AppKonfig.hintergrund
        webView.scrollView.backgroundColor = AppKonfig.hintergrund
        // Abstände für Notch und Home-Leiste macht die Seite selbst (viewport-fit=cover, env(safe-area-inset-*))
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Wischen vom linken Rand = Zurück (wie die Zurück-Taste unter Android, schliesst offene Dialoge)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        let container = UIView()
        container.backgroundColor = AppKonfig.hintergrund
        webView.translatesAutoresizingMaskIntoConstraints = false
        offline.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        container.addSubview(offline)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            offline.topAnchor.constraint(equalTo: container.topAnchor),
            offline.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            offline.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            offline.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        offline.isHidden = true
        offline.nochmal = { [weak self] in self?.neuLaden() }
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let ziel = ausstehend ?? AppKonfig.startURL
        ausstehend = nil
        webView.load(URLRequest(url: ziel))
    }

    /// Seite der Web-App öffnen (Mitteilung, Universal Link)
    func oeffne(_ url: URL) {
        guard AppKonfig.istEigene(url) else { return }
        guard isViewLoaded, webView != nil else {
            ausstehend = url
            return
        }
        offline.isHidden = true
        webView.load(URLRequest(url: url))
    }

    private func neuLaden() {
        offline.isHidden = true
        if webView.url == nil || !geladen {
            webView.load(URLRequest(url: AppKonfig.startURL))
        } else {
            webView.reload()
        }
    }

    // MARK: Navigation

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let schema = url.scheme?.lowercased() ?? ""
        if ["about", "blob", "data"].contains(schema) || AppKonfig.istEigene(url) {
            decisionHandler(.allow)
            return
        }
        // Eingebettete fremde Inhalte (z. B. Werbung, sofern je aktiv) nicht umleiten
        if let ziel = navigationAction.targetFrame, !ziel.isMainFrame {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        extern(url)
    }

    /// Links mit target=_blank oder window.open
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            if AppKonfig.istEigene(url) { webView.load(URLRequest(url: url)) } else { extern(url) }
        }
        return nil
    }

    private func extern(_ url: URL) {
        let schema = url.scheme?.lowercased() ?? ""
        if schema == "http" || schema == "https" {
            // Webseiten im Safari-Fenster über der App; man kommt mit «Fertig» zurück
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(red: 1, green: 0.79, blue: 0.3, alpha: 1)
            safari.preferredBarTintColor = AppKonfig.hintergrund
            praesentieren(safari)
        } else {
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        geladen = true
        offline.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fehlerZeigen(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fehlerZeigen(error)
    }

    private func fehlerZeigen(_ error: Error) {
        let e = error as NSError
        // Abgebrochen (neue Navigation) bzw. von uns umgeleitet: kein Fehler
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && e.code == 102 { return }
        // Hat die Seite schon einmal geladen, zeigt die Web-App selbst «Offline»; nur beim Start einspringen
        if !geladen { offline.isHidden = false }
    }

    /// WebKit wurde vom System beendet (Speicher): neu laden statt weisser Fläche
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: alert / confirm / prompt (sonst ignoriert WKWebView sie stillschweigend)

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        if !praesentieren(a) { completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Abbrechen", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        if !praesentieren(a) { completionHandler(false) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Abbrechen", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        if !praesentieren(a) { completionHandler(nil) }
    }

    @discardableResult
    private func praesentieren(_ vc: UIViewController) -> Bool {
        var oben: UIViewController = self
        while let weiter = oben.presentedViewController { oben = weiter }
        guard oben.viewIfLoaded?.window != nil, !(oben is UIAlertController) else { return false }
        oben.present(vc, animated: true)
        return true
    }

    // MARK: Brücke

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Nur die eigene Seite darf die Brücke benutzen
        guard message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              AppKonfig.istEigenerHost(message.frameInfo.securityOrigin.host),
              let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let name = body["name"] as? String else { return }
        let args = body["args"] as? [String: Any] ?? [:]
        let antworten: (Bool, Any?) -> Void = { [weak self] ok, wert in
            let js = "window.StammtischNative && window.StammtischNative._fertig(\(Bruecke.jsString(id)), \(ok), \(Bruecke.jsWert(wert)));"
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }

        switch name {
        case "pushRegister":
            Push.shared.registrieren { antworten(true, $0) }
        case "pushStatus":
            Push.shared.status { antworten(true, $0) }
        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            antworten(true, nil)
        case "haptic":
            Haptik.spielen(args["style"] as? String ?? "light")
            antworten(true, nil)
        case "share":
            teilen(args) { antworten(true, $0 ? "completed" : "cancelled") }
        default:
            antworten(false, "Unbekannte Funktion: \(name)")
        }
    }

    private func teilen(_ args: [String: Any], fertig: @escaping (Bool) -> Void) {
        var dinge: [Any] = []
        let text = (args["text"] as? String) ?? ""
        if !text.isEmpty { dinge.append(text) }
        if let s = args["url"] as? String, !s.isEmpty, let url = URL(string: s) { dinge.append(url) }
        if dinge.isEmpty, let titel = args["title"] as? String, !titel.isEmpty { dinge.append(titel) }
        guard !dinge.isEmpty else {
            fertig(false)
            return
        }
        let vc = UIActivityViewController(activityItems: dinge, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, erledigt, _, _ in fertig(erledigt) }
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
        if !praesentieren(vc) { fertig(false) }
    }
}

/// WKUserContentController hält seine Handler stark; so entsteht kein Kreis mit dem Controller
private final class SchwacheNachricht: NSObject, WKScriptMessageHandler {
    weak var ziel: WKScriptMessageHandler?
    init(_ ziel: WKScriptMessageHandler) { self.ziel = ziel }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        ziel?.userContentController(c, didReceive: message)
    }
}

/// System-Haptik. Stile kommen von src/lib/haptik.ts (Repo stammtisch): light/medium/heavy für Stösse,
/// selection beim Auswählen, success/warning/error für Ergebnisse (Gewinn, Niete, Verlierer).
enum Haptik {
    static func spielen(_ stil: String) {
        switch stil {
        case "success": benachrichtigen(.success)
        case "warning": benachrichtigen(.warning)
        case "error": benachrichtigen(.error)
        case "selection":
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        case "heavy": stoss(.heavy)
        case "medium": stoss(.medium)
        default: stoss(.light)
        }
    }

    private static func stoss(_ stil: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: stil)
        g.prepare()
        g.impactOccurred()
    }

    private static func benachrichtigen(_ art: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(art)
    }
}

/// Wird nur gezeigt, wenn die App beim Start keine Verbindung bekommt
final class OfflineAnsicht: UIView {
    var nochmal: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppKonfig.hintergrund

        let titel = UILabel()
        titel.text = "Keine Verbindung"
        titel.font = .preferredFont(forTextStyle: .title2)
        titel.textColor = .white

        let text = UILabel()
        text.text = "Der Stammtisch braucht Internet. Prüfe WLAN oder mobile Daten."
        text.font = .preferredFont(forTextStyle: .body)
        text.textColor = UIColor(white: 1, alpha: 0.7)
        text.numberOfLines = 0
        text.textAlignment = .center

        let knopf = UIButton(type: .system)
        knopf.setTitle("Nochmal versuchen", for: .normal)
        knopf.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        knopf.tintColor = UIColor(red: 1, green: 0.79, blue: 0.3, alpha: 1)
        knopf.addTarget(self, action: #selector(tippen), for: .touchUpInside)

        let stapel = UIStackView(arrangedSubviews: [titel, text, knopf])
        stapel.axis = .vertical
        stapel.alignment = .center
        stapel.spacing = 16
        stapel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stapel)
        NSLayoutConstraint.activate([
            stapel.centerYAnchor.constraint(equalTo: centerYAnchor),
            stapel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stapel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    @objc private func tippen() { nochmal?() }
}
