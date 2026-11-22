# Stammtisch für Android und iOS

Beide Apps sind dünne Hüllen um https://drink-tracker.app; Inhalte, Funktionen und Updates kommen von der
Web-App (Repo `Scumacker/stammtisch`). Android: Abschnitte unten. iOS: [Abschnitt «iOS»](#ios).

## Android

Die Android-App ist eine dünne Hülle um https://drink-tracker.app, erzeugt mit
[Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap). Dieses Repo enthält nur die Beschreibung
`twa-manifest.json`; das Gradle-Projekt erzeugt Bubblewrap daraus neu. Inhalte, Push und Updates kommen
von der Web-App, ein Store-Update braucht es nur, wenn sich hier etwas ändert.

### Einmalig auf dem eigenen Rechner

1. Node.js 18 oder neuer, dann `npm i -g @bubblewrap/cli`. Beim ersten Aufruf lädt Bubblewrap auf Wunsch
   ein passendes JDK und das Android-SDK selbst herunter.
2. **Upload-Schlüssel erzeugen** (nur einmal, gut aufbewahren, nie ins Repo; für GitHub Actions nur als Secret):

   ```sh
   # im Wurzelordner dieses Repos
   keytool -genkeypair -v -keystore upload-key.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   Datei und Passwort sicher ablegen (Passwortmanager). Geht der Schlüssel verloren, kann Google ihn
   zurücksetzen, weil die eigentliche App-Signatur bei Play App Signing liegt.

### Bauen über GitHub Actions

Workflow `.github/workflows/android.yml`: startet bei jedem Push auf `main`, der `twa-manifest.json` ändert, oder von Hand unter Actions → «Android-App» → «Run workflow».
Er baut die App mit Bubblewrap, legt AAB und APK als Artefakt ab und lädt das AAB als Entwurf in den
gewählten Track (Standard: interner Test). Der Versionscode ist die Laufnummer des Workflows.

Secrets im Repo (Settings → Secrets and variables → Actions):

| Secret | Inhalt |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON des Dienstkontos (dasselbe wie beim English Coach geht); in der Play Console unter «Nutzer und Berechtigungen» Zugriff auf diese App geben |
| `ANDROID_UPLOAD_KEYSTORE_B64` | `base64 -i upload-key.jks` (macOS) bzw. `base64 -w0 upload-key.jks` (Linux) |
| `ANDROID_KEYSTORE_PASSWORD` | Passwort des Keystores |
| `ANDROID_KEY_PASSWORD` | Passwort des Schlüssels `upload` |

Die Play Developer API kann keine neue App anlegen. Deshalb in dieser Reihenfolge:

1. Die drei Android-Secrets setzen, `PLAY_SERVICE_ACCOUNT_JSON` noch nicht. Ohne dieses Secret baut der
   Workflow nur und lädt nichts hoch.
2. Workflow laufen lassen, das AAB aus den Artefakten herunterladen.
3. In der Play Console die App anlegen und dieses AAB von Hand in den internen Test hochladen.
4. Dem Dienstkonto Zugriff auf die App geben und `PLAY_SERVICE_ACCOUNT_JSON` setzen. Ab jetzt lädt der
   Workflow neue Versionen selbst hoch.

### Bauen auf dem eigenen Rechner

```sh
# im Wurzelordner dieses Repos
bubblewrap update      # erzeugt das Gradle-Projekt aus twa-manifest.json
bubblewrap build       # fragt nach dem Schlüssel-Passwort, erzeugt app-release-bundle.aab
```

Das `.aab` wird in der Play Console hochgeladen. Für jede neue Version `appVersionCode` (um 1) und
`appVersionName` in `twa-manifest.json` erhöhen.

### Verknüpfung mit der Domain

Damit die App ohne Adressleiste startet, muss `https://drink-tracker.app/.well-known/assetlinks.json` den
Fingerabdruck der Signatur nennen. Ihn liefert der Worker aus zwei Variablen (Cloudflare-Dashboard → Worker
`stammtisch` → Settings → Variables):

- `ANDROID_PACKAGE` = `app.drinktracker`
- `ANDROID_SHA256` = SHA-256-Fingerabdruck aus der Play Console (Test und Release → App-Integrität →
  App-Signaturschlüssel). Für Tests mit einer selbst signierten APK zusätzlich, mit Komma getrennt, den
  Fingerabdruck des Upload-Schlüssels: `keytool -list -v -keystore upload-key.jks -alias upload`.

Prüfen: `bubblewrap validate --url=https://drink-tracker.app` und nach der Installation, ob eine
Adressleiste erscheint.

### Festgelegt

- Paketname `app.drinktracker`: nach dem ersten Upload in die Play Console nicht mehr änderbar.
- Benachrichtigungen laufen über den bestehenden Web Push (Notification Delegation), kein Firebase.
- Ohne Chrome auf dem Gerät öffnet die App die Seite in einem Custom Tab (`fallbackType`).

### Zusammenhang mit der Web-App

Die Web-App liegt im Repo `Scumacker/stammtisch` und läuft unter https://drink-tracker.app. Icons, Name im
Manifest, `/.well-known/assetlinks.json` sowie Datenschutz und Impressum kommen von dort. Dieses Repo ändert
sich nur, wenn sich die Hülle selbst ändert (Paket, Farben, Version, Shortcuts).

## iOS

Die iOS-App (`ios/`) ist eine kleine Swift-App mit einer WKWebView, die drink-tracker.app zeigt. Dazu kommt,
was eine Webseite im iPhone nicht kann oder was Apple für eine App erwartet:

| Was | Wie |
|---|---|
| Mitteilungen | Natives APNs. Die Web-App fragt über die Brücke (`window.StammtischNative`, Gegenstück `src/lib/nativ.ts` im Repo stammtisch) nach Erlaubnis und Token und meldet das Token mit `POST /api/push/apns` an; der Worker schickt an Apple (`worker/apns.ts`). Tipp auf die Mitteilung öffnet die passende Seite. |
| Haptik | `navigator.vibrate` (Joker, Chicago, Themen) wird auf die Taptic Engine umgeleitet. |
| Teilen | `navigator.share` (Einladung, Admin-Link) öffnet das Teilen-Menü von iOS. |
| Links | Einladungs- und Admin-Links auf drink-tracker.app öffnen die App (Universal Links, `/.well-known/apple-app-site-association` vom Worker). Fremde Links öffnen in einem Safari-Fenster über der App, Mail und Telefon in der passenden App. |
| Offline | App-Bound Domain: der Service Worker der Web-App läuft auch in der App. Ohne Netz beim Start erscheint eine native Meldung mit «Nochmal versuchen». |
| Dialoge | `alert`/`confirm`/`prompt` der Web-App erscheinen als iOS-Dialoge (WKWebView würde sie sonst verschlucken). |
| Sonst | Wischen vom linken Rand = Zurück (schliesst offene Dialoge wie die Android-Zurück-Taste), Profilfoto per Kamera oder Mediathek, dunkles Design, nur Hochformat, keine Werbung. |

Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `ios/project.yml` erzeugt
und nicht eingecheckt. Gebaut wird auf macOS-Runnern von GitHub (`.github/workflows/ios.yml`), ein Mac ist
nicht nötig. Auf einem Mac geht es auch lokal: `brew install xcodegen && cd ios && xcodegen generate &&
open Stammtisch.xcodeproj`.

### Was es von Apple braucht (einmalig)

1. **Apple Developer Program** (99 USD pro Jahr): https://developer.apple.com/programs/enroll/ mit deiner
   Apple-ID, als Einzelperson. Die Freischaltung dauert meist einen bis zwei Tage.
2. **Team-ID**: developer.apple.com → Account → Membership details (10 Zeichen, z. B. `AB12CD34EF`).
3. **App Store Connect API-Schlüssel**: https://appstoreconnect.apple.com/access/integrations/api →
   «Team Keys» → «+», Name «GitHub», Zugriff **Admin** (nötig, damit der Workflow Zertifikat und Profil
   anlegen darf). Datei `AuthKey_….p8` herunterladen (geht nur einmal), Key ID und Issuer ID notieren.
4. **APNs-Schlüssel** für die Mitteilungen: https://developer.apple.com/account/resources/authkeys/list →
   «+», Name «Stammtisch Push», Haken bei «Apple Push Notifications service (APNs)», Umgebung «Sandbox &
   Production». Datei `AuthKey_….p8` herunterladen, Key ID notieren.

### Secrets und Variablen

GitHub, dieses Repo (Settings → Secrets and variables → Actions):

| Secret | Inhalt |
|---|---|
| `IOS_TEAM_ID` | Team-ID aus Schritt 2 |
| `ASC_KEY_ID` | Key ID aus Schritt 3 |
| `ASC_ISSUER_ID` | Issuer ID aus Schritt 3 |
| `ASC_KEY_P8` | Inhalt der .p8-Datei aus Schritt 3 (ganzer Text inklusive BEGIN/END) |
| `IOS_DIST_PRIVATE_KEY` | Privater Schlüssel für das Verteilungszertifikat (PEM). Liegt im Projektordner unter `ios/schluessel/`; neu erzeugen: `openssl genrsa 2048` |

Cloudflare, Worker `stammtisch` → Settings → Variables and Secrets (Production):

| Name | Art | Inhalt |
|---|---|---|
| `IOS_TEAM_ID` | Variable | Team-ID |
| `APNS_KEY_ID` | Variable | Key ID aus Schritt 4 |
| `APNS_PRIVATE_KEY` | Secret | Inhalt der .p8-Datei aus Schritt 4 |
| `IOS_BUNDLE_ID` | Variable, optional | nur falls nicht `app.drinktracker` |

Ohne diese drei bekommen iPhones mit der App keine Mitteilungen, und Universal Links öffnen den Browser.
Web Push für Browser und Android läuft davon unabhängig weiter.

### Erste Version zu TestFlight

Wie bei Google kann die API keine neue App anlegen, deshalb:

1. Secrets setzen, dann Actions → «iOS-App» → «Run workflow» mit **«Zu TestFlight laden» aus**. Der Lauf
   registriert die App-ID `app.drinktracker` (mit Push und Associated Domains), legt Zertifikat und Profil
   an und baut eine signierte .ipa.
2. https://appstoreconnect.apple.com/apps → «+» → «Neue App»: Plattform iOS, Name (muss im ganzen App Store
   einmalig sein; «Stammtisch» ist vermutlich vergeben, z. B. «Stammtisch – Drink-Tracker». Unter dem Icon
   auf dem iPhone steht trotzdem «Stammtisch»), Sprache Deutsch, Bundle-ID `app.drinktracker`, SKU
   `drinktracker`.
3. Workflow nochmal laufen lassen, diesmal mit Hochladen. Nach 5 bis 15 Minuten erscheint der Build in
   App Store Connect → TestFlight. Dich selbst als internen Tester eintragen, auf dem iPhone die App
   «TestFlight» installieren und die Einladung annehmen.
4. In der App «Benachrichtigungen aktivieren» antippen und einen Check-in testen.

Danach lädt jeder Push auf `main`, der `ios/` ändert, automatisch eine neue Version zu TestFlight. Die
Build-Nummer ist die Laufnummer des Workflows, den Versionsnamen setzt man beim Start von Hand.

### Für den App Store

- Datenschutz-Angaben in App Store Connect («App-Datenschutz»): Name und Foto (vom Nutzer eingegeben, nicht
  verknüpft mit Identität, kein Tracking), Geräte-ID für Mitteilungen. Datenschutz-URL
  `https://drink-tracker.app/datenschutz`.
- Altersfreigabe: Alkohol-Bezug ehrlich angeben (ergibt die höchste Altersstufe). Das Joker-Casino ist
  kein echtes Glücksspiel (kein Geldeinsatz), zählt aber als simuliertes Glücksspiel.
- Screenshots 6,9" (iPhone 16/17 Pro Max) genügen.
- Apple lehnt reine Webseiten-Hüllen manchmal ab (Richtlinie 4.2). Für die Prüfung hilft der Hinweis im
  Feld «Notizen» auf native Mitteilungen, Haptik, Teilen-Menü, Universal Links und Offline-Start sowie ein
  Test-Zugangscode für eine Demo-Gruppe.

### Festgelegt

- Bundle-ID `app.drinktracker` wie das Android-Paket; nach dem ersten Upload nicht mehr änderbar.
- Keine Fremdbibliotheken in der App, kein Firebase: Push direkt über APNs, Signieren über die App Store
  Connect API (`ios/fastlane/Fastfile`). Das Verteilungszertifikat gehört zum Schlüssel im Secret
  `IOS_DIST_PRIVATE_KEY`; der Workflow findet es bei jedem Lauf wieder statt ein neues anzulegen.
- Mindestversion iOS 16.
