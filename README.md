# Stammtisch für Android

Die Android-App ist eine dünne Hülle um https://drink-tracker.app, erzeugt mit
[Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap). Dieses Repo enthält nur die Beschreibung
`twa-manifest.json`; das Gradle-Projekt erzeugt Bubblewrap daraus neu. Inhalte, Push und Updates kommen
von der Web-App, ein Store-Update braucht es nur, wenn sich hier etwas ändert.

## Einmalig auf dem eigenen Rechner

1. Node.js 18 oder neuer, dann `npm i -g @bubblewrap/cli`. Beim ersten Aufruf lädt Bubblewrap auf Wunsch
   ein passendes JDK und das Android-SDK selbst herunter.
2. **Upload-Schlüssel erzeugen** (nur einmal, gut aufbewahren, nie ins Repo; für GitHub Actions nur als Secret):

   ```sh
   # im Wurzelordner dieses Repos
   keytool -genkeypair -v -keystore upload-key.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   Datei und Passwort sicher ablegen (Passwortmanager). Geht der Schlüssel verloren, kann Google ihn
   zurücksetzen, weil die eigentliche App-Signatur bei Play App Signing liegt.

## Bauen über GitHub Actions

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

## Bauen auf dem eigenen Rechner

```sh
# im Wurzelordner dieses Repos
bubblewrap update      # erzeugt das Gradle-Projekt aus twa-manifest.json
bubblewrap build       # fragt nach dem Schlüssel-Passwort, erzeugt app-release-bundle.aab
```

Das `.aab` wird in der Play Console hochgeladen. Für jede neue Version `appVersionCode` (um 1) und
`appVersionName` in `twa-manifest.json` erhöhen.

## Verknüpfung mit der Domain

Damit die App ohne Adressleiste startet, muss `https://drink-tracker.app/.well-known/assetlinks.json` den
Fingerabdruck der Signatur nennen. Ihn liefert der Worker aus zwei Variablen (Cloudflare-Dashboard → Worker
`stammtisch` → Settings → Variables):

- `ANDROID_PACKAGE` = `app.drinktracker`
- `ANDROID_SHA256` = SHA-256-Fingerabdruck aus der Play Console (Test und Release → App-Integrität →
  App-Signaturschlüssel). Für Tests mit einer selbst signierten APK zusätzlich, mit Komma getrennt, den
  Fingerabdruck des Upload-Schlüssels: `keytool -list -v -keystore upload-key.jks -alias upload`.

Prüfen: `bubblewrap validate --url=https://drink-tracker.app` und nach der Installation, ob eine
Adressleiste erscheint.

## Festgelegt

- Paketname `app.drinktracker`: nach dem ersten Upload in die Play Console nicht mehr änderbar.
- Benachrichtigungen laufen über den bestehenden Web Push (Notification Delegation), kein Firebase.
- Ohne Chrome auf dem Gerät öffnet die App die Seite in einem Custom Tab (`fallbackType`).

## Zusammenhang mit der Web-App

Die Web-App liegt im Repo `Scumacker/stammtisch` und läuft unter https://drink-tracker.app. Icons, Name im
Manifest, `/.well-known/assetlinks.json` sowie Datenschutz und Impressum kommen von dort. Dieses Repo ändert
sich nur, wenn sich die Hülle selbst ändert (Paket, Farben, Version, Shortcuts).
