# Murmur

Murmur ist eine native macOS-Menüleisten-App für lokales Diktieren. Halte **⌥ Leertaste** gedrückt, sprich in das aktive Textfeld und lasse die Tasten los: Murmur transkribiert dein Diktat lokal und fügt den Text ein.

> Murmur ist derzeit ein frühes, nicht notarisiertes MVP. Du baust und installierst es selbst; ein fertiger Download und automatische Updates sind noch nicht eingerichtet.

## Voraussetzungen

- macOS 14 oder neuer
- Apple Silicon (M1 oder neuer)
- Xcode Command Line Tools mit Swift 6
- Internetverbindung für den einmaligen Download des Spracherkennungsmodells
- Rund 630 MB freier Speicherplatz für Parakeet Ultra, zusätzlich zum Build-Speicher

Installiere die Command Line Tools bei Bedarf mit:

```sh
xcode-select --install
```

## Bauen und starten

Klone das Repository und baue die App:

```sh
git clone https://github.com/Thrasolt/murmur.git
cd murmur
./build-app.sh
open .build/Murmur.app
```

Das Skript erstellt einen Release-Build in `.build/Murmur.app` und signiert ihn standardmäßig ad hoc. Für eine eigene Code-Signing-Identität kannst du sie beim Build angeben:

```sh
MURMUR_SIGNING_IDENTITY="Developer ID Application: Dein Name (TEAMID)" ./build-app.sh
```

Eine eigene stabile Signatur kann helfen, die macOS-Bedienungshilfen-Freigabe über erneute Builds hinweg beizubehalten. Murmur enthält weder ein Entwicklerzertifikat noch private Signierschlüssel.

Zum reinen Kompilieren ohne App-Bundle:

```sh
swift build
```

## Ersteinrichtung

1. Starte Murmur. Die App erscheint in der Menüleiste.
2. Wähle **Installieren**, um Parakeet Ultra einmalig lokal herunterzuladen. Der Download wird ausdrücklich in der App ausgelöst.
3. Erlaube beim ersten Diktat den Mikrofonzugriff.
4. Erlaube Murmur unter **Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen**, damit es Text in der zuvor aktiven App einfügen kann. Falls macOS die Freigabe nicht übernimmt, entferne Murmur aus der Liste, füge die gebaute App erneut hinzu und starte sie neu.
5. Setze den Cursor in ein Textfeld, halte **⌥ Leertaste** gedrückt und sprich. Beim Loslassen endet die Aufnahme; danach wird der erkannte Text eingefügt.

Alternativ kannst du die Aufnahme über die Schaltfläche im Menüleistenfenster manuell starten und beenden. Wenn automatisches Einfügen nicht klappt, zeigt Murmur eine Textvorschau mit **Kopieren** und **Erneut einfügen**.

## Datenschutz

- Audioaufnahme und Spracherkennung laufen lokal auf dem Mac. Audio und Transkript werden nicht an einen Transkriptionsdienst gesendet.
- Nur der erste Modell-Download benötigt eine Internetverbindung. Nach dem Download lädt Murmur das Modell lokal und schaltet FluidAudio für die Erkennung in den Offline-Modus.
- Die Aufnahme wird vorübergehend als WAV-Datei im temporären Systemordner gespeichert und nach der Verarbeitung oder beim Abbrechen gelöscht.
- Für automatisches Einfügen legt Murmur den erkannten Text kurz in die Zwischenablage, löst **⌘V** in der zuvor aktiven App aus und stellt den vorherigen Zwischenablageinhalt anschließend wieder her.
- Der Text wird absichtlich an die von dir fokussierte Ziel-App übergeben. Diese App verarbeitet ihn gemäß ihren eigenen Datenschutzregeln.

## Technik

- Swift, SwiftUI und AppKit
- AVFoundation für die Mikrofonaufnahme
- FluidAudio und Core ML mit Parakeet Ultra für lokale Spracherkennung
- Globaler Push-to-Talk-Shortcut **⌥ Leertaste** über Carbon

## Bekannte Grenzen

- Das Modell ist groß; Download und erster Modellstart können dauern.
- macOS-Bedienungshilfen sind für automatisches Einfügen erforderlich. Manche Apps oder Web-Editoren verhalten sich anders; dafür gibt es die Vorschau als Rückfall.
- Das Projekt stellt derzeit keine notarisierten Releases, automatische Updates oder Einstellungsoberfläche für den Shortcut bereit.
- Die Signierung des lokalen Builds ist nicht mit Apples Developer-ID-Notarisierung gleichzusetzen.

## Lizenz

Murmur wird unter der [MIT-Lizenz](LICENSE) veröffentlicht.
