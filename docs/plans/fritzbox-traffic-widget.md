# Entwicklungskonzept: FRITZ!Box Traffic Widget für DMS 2.0

> **Stand:** 2026-11-02  
> **Status:** Recherche und Architekturplanung; **keine Implementierung und keine Live-Validierung am Zielrouter**  
> **Zielplattform:** CachyOS (Arch Linux), Niri, DankMaterialShell/Dux Shell 2.0 (DMS)  
> **Zielrouter:** FRITZ!Box unter `10.0.0.1`, FRITZ!OS >= 8.20 (exakte Modell-/Buildnummer offen)  
> **Geplantes Plugin:** `fritzTraffic`  
> **Ablage:** Dieses Dokument beschreibt eine **geplante** Erweiterung des bestehenden Monorepos `almighty-atlas/dms-plugins`, keine bereits vorhandene Funktion.

## 1. Zusammenfassung und verbindliche Architekturentscheidung

Ein natives QML-Widget stellt die aktuellen Internet-Upload- und Download-Raten des Routers dar. Ein kleiner lokaler Python-Collector erledigt Authentifizierung, Router-Kommunikation, Parser und Datennormalisierung. Ein **einmalig laufender DMS-Controller** steuert den Collector nach Bedarf; ein eigener systemd-Dienst ist für das MVP nicht nötig.

- **WAN-Gesamtwerte:** bevorzugt über die offiziell dokumentierte TR-064-Aktion `X_AVM-DE_GetOnlineMonitor`; konkretes Datenformat/Verfügbarkeit am Zielrouter noch testen.
- **Daten je Gerät:** primär über die **undokumentierte** FRITZ!Box-REST-Route `GET /api/v0/monitor/online/0`, mit `GET /api/v0/monitor/online/subsets` für Zeitreihen-Metadaten.
- **Darstellung:** DMS-2.0-`PluginComponent` mit horizontaler/vertikaler DankBar-Pill, nativem `PopoutComponent` und `PluginSettings`.
- **Sicherheit:** Kennwort im Freedesktop Secret Service; SID ausschließlich flüchtig im Collector; keine Router-Konfigurationsänderungen.
- **Laststeuerung:** nur ein Poller für alle Widget-Instanzen, keine parallelen Router-Abfragen; Startwerte 15 s in der Bar und 10 s bei offenem Popout, abhängig von den Live-Tests.
- **Releases:** `v0.1.0` als kleiner MVP, `v0.2.0` für Geräte-Aliasse, Filter und Mini-Verläufe.

**Entscheidender Vorbehalt:** Die gerätebezogene Schnittstelle wurde anhand fremder Implementierungen untersucht, **nicht** an der FRITZ!Box unter `10.0.0.1` geprüft. Phase 0 (read-only Validierung) ist ein harter Go/No-Go-Gate für die Anzeige je Gerät.

## 2. Ziele und Nicht-Ziele

### Ziele

1. Aktuellen Internet-Download und -Upload in der DankBar anzeigen, mit eindeutig beschrifteten automatischen Einheiten.
2. In einem Popout die Geräte nach aktueller Auslastung sortieren; Richtung, Name, Datenrate, Auslastungsbalken und Aktualitätsstatus darstellen.
3. Stabil über mehrere Monitore/Widget-Instanzen hinweg funktionieren, ohne den Router mehrfach zu poll'en.
4. Einfache DMS-native Einstellungen für Routeradresse, Benutzer, Aktualisierungsintervall, Einheiten, Layout und später Gerätesichtbarkeit/Aliasse anbieten.
5. Lokales, quelloffenes, ressourcenschonendes Projekt ohne Cloud- oder Telemetrie-Anbindung entwickeln.

### Nicht-Ziele für v0.1

- Kein Mitschnitt, keine LAN-zu-LAN-Verkehrsanalyse, keine Router-Konfiguration, keine Traffic-Shaping-Funktionen.
- Kein dauerhaftes Traffic-Accounting, keine Datenbank, kein gerätespezifischer Gesamtverbrauch über Monate.
- Kein eigenständiger systemd-Dienst, keine Veröffentlichung über Traefik/Cloudflare oder ein extern erreichbares Backend.
- Kein Anspruch auf Unterstützung jeder FRITZ!OS-Version oder jedes FRITZ!Box-Modells.

## 3. Recherche: Evidenz und Quellenlage

### 3.1 Evidenzklassen

| Kennzeichen | Bedeutung | Beispiel |
| --- | --- | --- |
| **A: Offiziell** | Öffentliche, offiziell beschriebene Schnittstelle | AVM-`login_sid.lua`/PBKDF2; TR-064-Aktionsbeschreibung |
| **B: Quellcode bestätigt** | Existenz und tatsächliche Verwendung im untersuchten fremden Code | `monitor/online/0`, `Authorization: AVM-SID`, Datenparser |
| **C: Community-Bericht** | Unabhängige Beschreibung ohne Prüfung am Zielgerät | Legacy-`datasets`/`subset0000` |
| **D: Offen** | Lokal weder getestet noch garantiert | Firmware-API-Kompatibilität, Einheit, Berechtigungen, Polling-Stabilität |
| **E: Entwurfsentscheidung** | Vorgabe dieses Konzepts, **kein** bestehender API-Vertrag | Python-Collector, JSON-Schema, 15-s-Standardintervall |

Die vollständige, zuvor erarbeitete API-Dokumentation befindet sich im privaten Repository `almighty-atlas/notes` unter [`docs/network/fritzbox-online-monitor-api.md`](https://github.com/almighty-atlas/notes/blob/main/docs/network/fritzbox-online-monitor-api.md) (Stand 2026-11-01). Sie wurde vor dieser Planung gelesen. Darin enthaltene JSON-Antworten sind **synthetisch**.

### 3.2 DMS 2.0: Technische Grundlagen (B, Quellcode überprüft)

Das Projekt heißt nach der Umstellung **Dux Shell**, während DMS-Namen und CLI-Kompatibilität teilweise fortbestehen. Für neue Plugins sollten die aktuellen DMS-2.0-Komponenten aus `qs.DCommon.Widgets` (beispielsweise `DIcon`, `DButton`, `DTextField`, `DToggle`) bevorzugt werden; ältere `Dank*`-Komponenten sind nicht die langfristige Grundlage.

| Fähigkeit | Konkreter Mechanismus |
| --- | --- |
| Widget-Hülle | `PluginComponent` aus `qs.Modules.Plugins` |
| Bar horizontal/vertikal | `horizontalBarPill`, `verticalBarPill` |
| Klick-Popout | `popoutContent`, `PopoutComponent`, `popoutWidth`/`popoutHeight` |
| Standard-Einstellungen | `PluginSettings`, `StringSetting`, `ToggleSetting`, `SelectionSetting` |
| Persistente Plugin-Vorgaben | `pluginService.savePluginData(id,key,value)` / `loadPluginData(...)` |
| Flüchtige gemeinsame Daten | `PluginGlobalVar` oder `PluginService.getGlobalVar/setGlobalVar` |
| Separate Laufzeitdatei | `savePluginState/loadPluginState` – **nicht** für Geheimnisse |
| Externe Programme | Quickshell `Process`, `SplitParser`/`StdioCollector` |
| Multi-Surface | Manifest `type: "composite"` und `components.daemon`/`components.widget` |
| Installation | `~/.config/dms/plugins/` bzw. der vom DMS-`PluginService` ermittelte Pfad |

**Im Quellcode geprüft:** `quickshell/Services/PluginService.qml`, `quickshell/Modules/Plugins/PluginComponent.qml`, `quickshell/PLUGINS/plugin-schema.json`, `ExampleCompositePlugin` und `ColorDemoPlugin` sowie die offiziellen Plugin-Entwicklungsreferenzen. `PluginService` instanziiert Daemon-Oberflächen einmalig und stellt Signale sowie persistente/temporäre Settings bereit. Ein DMS-`daemon` ist hier eine QML-Komponente im Shell-Prozess, **kein** externer systemd-Dienst.

**Wichtige Konsequenz:** Weil mehrere Widget-Instanzen möglich sind, darf das Polling **nicht** in jeder `TrafficWidget.qml` separat erfolgen. Ein zentraler Controller verteilt einen Snapshot an alle Instanzen. Die DMS-Global-Var-API kann als reaktiver Transport für bereits bereinigte Ergebnisse dienen.

Referenzen:
- [Dux Shell – Quellcode](https://github.com/duxlabs-dev/dux-shell)
- [Plugin-System-README](https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/README.md)
- [Widget-Guide](https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/widget-plugin-guide.md)
- [Settings-Guide](https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/settings-components-reference.md)
- [Data-Persistence-Guide](https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/data-persistence-guide.md)
- [Composite-Referenz](https://github.com/duxlabs-dev/dux-shell/tree/master/quickshell/PLUGINS/ExampleCompositePlugin)
- [Plugin-JSON-Schema](https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/plugin-schema.json)

### 3.3 Bestehende Lösungen (B/C)

| Projekt | Prüfergebnis | Verwendung für dieses Projekt |
| --- | --- | --- |
| [FRITZ!Box Netzwerk / Home Assistant](https://github.com/Meine-smarte-Welt/fritzbox_netzwerk) | Fremdimplementierung von Login, Monitor-Endpunkten und Zeitreihenparser. Kein DMS-Widget. | Primärreferenz für HTTP- und Parser-Verhalten. Nicht blind übernehmen. |
| [Network Indicator](https://github.com/gemb0-0/Network-Indicator) | DMS-Widget für Netzwerktraffic **des lokalen Linux-Systems**, nicht pro Router-Endgerät. | Gute UX-/Polling-/Bar-Referenz. |
| [Proxy Traffic](https://github.com/Lemon-mon-254/dms-proxy-traffic) | Lokale Proxy-Messwerte über `nftables`. | Monitoring-/Darstellungsreferenz. |
| [DMS-Plugin-Registry](https://github.com/duxlabs-dev/dux-plugin-registry) | Verzeichnet mehrere Netzwerk-/Monitor-Plugins; bei der Untersuchung kein direkt passendes FRITZ!Box-Geräteraten-Widget festgestellt. | Packaging und Veröffentlichung. |

Die Feststellung „kein direkt passendes Plugin“ bezieht sich auf die **untersuchten Registry-Einträge**, nicht auf alle denkbaren GitHub-Projekte.

### 3.4 FRITZ!Box: Offizielle Gesamtwerte und experimentelle Gerätedaten

**Offizielle Ebene (A, lokale Verfügbarkeit D):** TR-064 bietet WAN-Funktionen einschließlich `X_AVM-DE_GetOnlineMonitor`. Diese Datenquelle ist für die **tatsächliche WAN-Gesamtauslastung** zu bevorzugen; die Aktion und ihr konkretes Antwortformat werden am Zielgerät validiert. TR-064 benötigt eine eigene Authentifizierung und ist nicht identisch mit dem HTTP-`AVM-SID`-Mechanismus der internen API.

**Experimentelle Ebene (B, lokale Verfügbarkeit D):**

| Methode/Route | Erwarteter Zweck | Evidenz |
| --- | --- | --- |
| `GET /login_sid.lua?version=2` / Login-POST | AVM-Session starten | A |
| `GET /api/v0/monitor/online/subsets` | Messintervall und Subset-IDs; `sampleInterval` wahrscheinlich ms | B |
| `GET /api/v0/monitor/online/0` | Geräte- und Kategorien-Zeitreihen | B |
| `GET /api/v0/monitor/datasets` | Legacy-Datenquellen | B/C |
| `GET /api/v0/monitor/macaddrs/subset0000` | Legacy-Messreihen | B/C |
| `GET /api/v0/generic/monitor/...` | Alternativer Legacy-Pfad | B/C |
| `GET /query.lua?...hosts=landevice...` | Optionaler Geräte-/Namensabgleich | B, intern und undokumentiert |

In `webui.py` der HA-Integration werden für Monitor-Aufrufe unter anderem `Authorization: AVM-SID <SID>`, `Accept`, `Content-Type` und `Referer` gesetzt; ob alle Header auf unserer Box notwendig sind, ist offen. Der Code prüft zunächst `online/subsets`, liest `online/0` und versucht bei Bedarf Legacy-Pfade.

Das erwartete Grundschema enthält `lastSampleTime`, `devices[]` mit `UID`/`landeviceUid`, `downstream[]`/`upstream[]` sowie `categories[]`. Eine typische `UID` entspricht `mac` plus zwölf Hex-Zeichen. **Einheiten, Array-Richtung, Zeitstempel und Umfang der Kategorien sind nicht endgültig belegt.**

Fremde Parser verwenden teilweise den letzten numerischen Wert und nehmen zunächst **Byte/s** an; alternativ wäre eine Umrechnung von Bit/s mit Faktor `1/8` erforderlich. Wir dürfen dies erst nach einer Kalibrierung mit der tatsächlichen Router-Oberfläche als korrekt übernehmen.

**Summen dürfen nicht vermischt werden:** `sum(devices)` ist höchstens die Summe **erfasster** Geräte; sie ist nicht zwangsläufig WAN gesamt. Kategorien können überlappen. Die Differenz zwischen TR-064-WAN und Gerätesumme ist nicht automatisch ein „unbekanntes Gerät“.

Quellcode:
- [`webui.py` – Login/HTTP/REST-Fallback](https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/webui.py)
- [`traffic.py` – Geräte-/Zeitreihenparser](https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/traffic.py)
- [`online_monitor.py` – aktuelle Werte/Kategorien](https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/online_monitor.py)
- [AVM Session-ID Technical Note](https://avm.de/fileadmin/user_upload/Global/Service/Schnittstellen/AVM_Technical_Note_-_Session_ID_deutsch_2021-05-03.pdf)
- [AVM/FRITZ!-Schnittstellen](https://fritz.com/en/pages/interfaces)

## 4. Architekturvergleich

| Ansatz | CPU/RAM | Sicherheit & Authentifizierung | Pflege/Packaging | Bewertung |
| --- | --- | --- | --- | --- |
| QML/JavaScript-only | Keine zusätzliche Runtime, aber Krypto/HTTP im Shell-Prozess | PBKDF2, XML, TLS, TR-064 und Secret Handling aufwendiger | Wenige Dateien; stärkere Kopplung | Nicht für MVP |
| QML + Python pro Poll | Python startet wiederholt, kein langlebiger Prozess | Einfach testbarer Auth-Code; Session pro Aufruf schwieriger wiederzuverwenden | Einfacher Prototyp | Nur Validierungswerkzeug |
| **QML + langlebiger Python-Collector** | Kleiner zusätzlicher Prozess, keine Starts bei jedem Sample | Secret Storage, SID-Reuse, Parser-Testbarkeit | Python-Standardbibliothek, gute Portabilität | **Gewählt** |
| QML + Go-Collector | Eigenständiges Binary, geringer Speicher möglich | Gute Krypto-/HTTP-Bibliotheken | Build-/Release-Matrix, Cross-Compile | Option bei nachgewiesenem Bedarf |
| Separater systemd-Service | Daten außerhalb von DMS verfügbar | Eigene IPC-/Rechte-/Lifecycle-Fragen | Mehr Installation/Fehlerpunkte | Nicht im MVP |

**Begründung:** Python 3 bringt mit `hashlib`, `ssl`, `urllib.request`, `xml.etree.ElementTree`, `json` und `subprocess` die benötigten Grundlagen ohne externe Python-Runtime-Pakete mit. Das Sicherheitsproblem bleibt kleiner, wenn nur der Collector Router-Sessions und Secrets kennt.

### 4.1 Datenfluss

~~~text
DMS / Dux Shell 2.0
  ├─ TrafficWidget.qml (Bar / Popout; N Instanzen)
  └─ TrafficController.qml (Composite-Daemon; 1 Instanz)
        ├─ verwaltet Abonnenten / Polling / Backoff
        ├─ verteilt bereinigte Snapshots via PluginService
        └─ Quickshell.Io.Process <---- JSON Lines / stdin + stdout ---->
             Python-Collector (lokaler Kindprozess)
               ├─ Secret Service (Passwort aus Schlüsselbund)
               ├─ Session-Manager (SID nur im RAM)
               ├─ REST-Adapter (/api/v0/monitor/online/...)
               ├─ TR-064-Adapter (WAN)
               ├─ Geräte-Namensauflösung
               └─ Validierung + Normalisierung
                         |
                   FRITZ!Box 10.0.0.1
~~~

**Keine HTTP-API auf localhost erforderlich.** Der Kindprozess kann über newline-delimited JSON angesprochen werden, zum Beispiel `start`, `poll`, `set_config`, `stop`, `ping`; Antworten `snapshot`, `status`, `error` jeweils mit Schema-Version und optionaler Request-ID. Secrets und SIDs erscheinen **nie** in Antwortnachrichten.

Für das einmalige Speichern des Kennworts darf ein maskiertes QML-Setup-Feld das Passwort kurzzeitig im Speicher halten und ausschließlich über **stdin** an einen vertrauenswürdigen Helper übergeben. Es wird **nicht** als CLI-Argument, Shell-String, Log, Global-Variable oder DMS-Setting gespeichert. Im regulären Betrieb sieht QML das Kennwort nicht.

### 4.2 Mehrfachinstanzen und Polling

Der zentrale QML-Controller verwaltet aktive Instanzen anhand einer stabilen `widgetInstanceId` und ihres `surfaceLive`-/Popout-Status. Aktivitätsereignisse werden zusammengefasst: **ein** Collector, **eine** aktive Router-Abfrage. Beim Schließen/Verbergen der letzten relevanten Oberfläche wird Polling gestoppt und der Collector nach kurzer Idle-Frist beendet.

| Zustand | Geplantes Abrufintervall | Anmerkung |
| --- | --- | --- |
| Kein aktiver Abonnent | Kein Polling | Kein Dauerbetrieb |
| Bar sichtbar | 15 s | Vorläufiger Startwert |
| Popout geöffnet | 10 s | Vorläufiger Startwert |
| Bar verborgen, kein Popout | Pause | Auf DMS-Lifecycle abstellen |
| Fehler/Überlast | Exponentieller Backoff | Kein Retry-Sturm |
| DMS/Plugin beendet | Prozess kontrolliert stoppen | Kein verwaister Collector |

`sampleInterval` (Auflösung der Messreihe) und Pollingintervall (Abruffrequenz) sind **verschiedene Größen**. Mehrfachpolls desselben Messzeitpunkts dürfen nicht als neue Datenpunkte gezählt werden. Zeitstempel und `fetched_at` getrennt verfolgen.

Metadaten wie Anzeigenamen deutlich seltener abrufen (Startwert maximal einmal pro 15 Minuten). Vorläufiger Stale-Schwellwert: `max(30 s, 3 × sampleInterval)`, nach Live-Kalibrierung anpassen.

### 4.3 Normalisierter Vertrag (Entwurf; vollständig synthetische Werte)

~~~json
{
  "schema_version": 1,
  "type": "snapshot",
  "status": "partial",
  "fetched_at": "2026-11-02T12:00:00+01:00",
  "sample_age_seconds": 3,
  "total": {
    "state": "ok",
    "source": "tr064",
    "download_bytes_per_second": 12400000,
    "upload_bytes_per_second": 2400000
  },
  "devices_state": "ok",
  "devices": [
    {
      "id": "mac020000000001",
      "name": "Beispiel-PC",
      "download_bytes_per_second": 9200000,
      "upload_bytes_per_second": 840000,
      "state": "ok"
    }
  ],
  "device_coverage": {
    "recorded_count": 1,
    "complete": false
  }
}
~~~

Festlegungen:
- Intern **Byte/s**, kein mehrdeutiges `bps`; dezimales `KB/s` = B/s ÷ 1000, `MB/s` = B/s ÷ 1 000 000; Binärdarstellung explizit `KiB/s`/`MiB/s`.
- Fehlende Messungen als **`null`**, nicht als `0`; `stale` separat ausweisen.
- Werte nur als Zahlen akzeptieren, nichtnegative und endliche Werte validieren; keine `NaN`/`Infinity`.
- `UID` nach Prüfung normieren; `landeviceUid` ausschließlich als zusätzliche Zuordnung.
- Messreihenposition und fehlende Samples erhalten: nicht einfach das letzte „irgendwie gültige“ Element zu „jetzt“ erklären.
- WAN-Status und Gerätestatus separat halten; `partial` erlaubt, wenn nur eine Datenquelle arbeitet.
- `device_coverage.complete` nur nach echter Abdeckungsprüfung `true` setzen.
- Router-Namen/Aliasse werden nur lokal verwendet; Geräte-IDs nicht in öffentliche Logs schreiben.

### 4.4 Statusmodell

| Status | Ursache | UI/Collector-Verhalten |
| --- | --- | --- |
| `ok` | Frische, valide Werte | Regulär darstellen |
| `partial` | WAN oder Geräte nur teilweise verfügbar | Verfügbare Daten separat darstellen |
| `stale` | Messzeitpunkt älter als Schwellwert | Nicht als live darstellen |
| `router_unreachable` | Timeout, DNS, Netzwerkfehler | Backoff; letzten Erfolg optional mit Alter markieren |
| `auth_error` | Login abgelehnt | Nicht unendlich neu anmelden |
| `secret_unavailable` | Schlüsselbund nicht erreichbar/gesperrt | Einrichtungshinweis |
| `unsupported` | Pfad oder Schema inkompatibel | Firmware-/Schemahinweis |
| `not_recorded` | Gerät wird nicht aufgezeichnet | Kein fiktiver Nullwert |
| `unresolved` | Messreihe nicht eindeutig zuordenbar | Kein falscher Anzeigename |

Bei HTTP 200 mit HTML-/Login-Seite muss der Parser einen Auth-/Schemafehler erkennen, statt blind `JSON.parse` zu versuchen.

## 5. Sicherheits- und Datenschutzkonzept

### 5.1 Authentifizierung

1. Passwort aus dem **Freedesktop Secret Service** lesen (empfohlen: `secret-tool`/libsecret; verfügbarer entsperrter Secret-Service-Anbieter erforderlich).
2. `GET /login_sid.lua?version=2` lesen; `Challenge`, `SID`, `BlockTime` aus XML parsen.
3. Für `2$iter1$salt1$iter2$salt2`: zweimal PBKDF2-HMAC-SHA256 gemäß AVM Technical Note; Login-POST mit `username`/`response`.
4. Gültige SID ausschließlich im Collector-RAM behalten und soweit möglich wiederverwenden.
5. Bei ungültiger SID kontrolliert erneuern; maximal ein Reauth-Versuch pro Fehlerserie und `BlockTime` beachten.
6. Alte MD5-Variante erst als expliziten Legacy-Fallback einführen, wenn der Kompatibilitätsbedarf belegt ist.

TR-064 ist ein **separater Protokoll-/Auth-Pfad** (SOAP, typischerweise HTTP-POST auch für lesende Aktionen). „Read-only“ bedeutet keine mutierenden Routeraktionen, nicht ein vollständiges Verbot von HTTP-POST.

### 5.2 Speicherrichtlinie

| Datentyp | Speicher | Persistenz |
| --- | --- | --- |
| Routerhost/-schema, Benutzername, Displayvorgaben | DMS PluginSettings | Dauerhaft |
| Routerpasswort | Secret Service | Geschützt, dauerhaft |
| SID | Python-Prozessspeicher | Flüchtig |
| Live-Snapshots/kurzer Verlauf | DMS Runtime/RAM | Flüchtig |
| Gerätesichtbarkeit/Aliasse | DMS Settings | Dauerhaft, lokal |
| Debug-Logs | Redigierte Status-/Fehlercodes | Ohne Secrets/Identifikatoren |

**Niemals** Passwort/SID in Git, DMS-Settings, Prozessargumenten, Terminal-History, URLs von öffentlichen Services, Crashlogs oder GitHub-Issues übernehmen. Bei Konfigurationsfehlern keine vollständigen HTTP-Antworten ausgeben.

### 5.3 Netzwerk/Transport

- Zugriffe auf die **konfigurierte private LAN-Routeradresse** begrenzen. Keine externe Telemetrie.
- Redirects weg von dieser Adresse verbieten; Proxy-Umgebungsvariablen für Routerverkehr deaktivieren.
- HTTPS nur mit geprüfter Zertifikatskette oder einem bewusst eingerichteten Trust/Pinning; niemals pauschal TLS-Verifikation ausschalten.
- Bei selbstsignierten FRITZ!Box-Zertifikaten Zertifikatsvertrauen explizit konfigurieren; hostname/IP-Mismatch prüfen.
- Vorübergehendes HTTP im **vertrauenswürdigen LAN** kann als dokumentierte Entwicklungsoption dienen, ist jedoch transportseitig weniger sicher.
- Dedizierten FRITZ!Box-Benutzer mit **minimalen funktionierenden Rechten** testen. „Dediziert“ garantiert keine read-only-Rechte.
- Im Collector eine Allowlist für unterstützte **lesende** REST-/TR-064-Operationen pflegen; keine Routerkonfiguration ändern.

Hinweis: Ein DMS-Plugin läuft grundsätzlich mit Benutzerrechten der Desktop-Session; Manifest-Permissions allein sind keine vollständige Isolation.

## 6. UI-/UX-Spezifikation

### 6.1 DankBar

**Standard:** Download-Icon + Rate, Upload-Icon + Rate; kompakte Anzeige ohne Animation. Beispiele mit **erfundenen Werten**:

~~~text
Standard:  ↓ 12,4 MB/s   ↑ 2,4 MB/s
Kompakt:  ↓ 850 KB/s    ↑ 2,1 MB/s
Erweitert: ↓ 12,4 MB/s ↑ 2,4 MB/s · Desktop-PC (optional)
~~~

Auf schmalen/vertikalen Bars gesonderte `verticalBarPill` mit Icons und ggf. Werten. Bei `stale` dezente Kennzeichnung statt scheinbar live fortgeschriebener Zahlen; keine dauernden Error-Toasts. Theme, Schrift, Abstände und Hell-/Dunkelmodus von `Theme`/`qs.DCommon.Widgets` übernehmen.

### 6.2 Popout (Wireframe, synthetische Daten)

~~~text
┌─────────────────────────────────────────┐
│ FRITZ!Box Traffic                   ⚙    │
│                                         │
│  Download WAN          Upload WAN       │
│  12,4 MB/s             2,4 MB/s         │
│                                         │
│  Geräte          Sortiert: Gesamt ▼     │
│  Desktop-PC       ↓ 9,2  ↑ 0,84 MB/s    │
│  ███████████████████                    │
│  Smart-TV         ↓ 2,1  ↑ 0,12 MB/s    │
│  ████                                   │
│  Smartphone       ↓ 0,63 ↑ 0,08 MB/s    │
│  ██                                     │
│  NAS              ↓ 0,04 ↑ 1,22 MB/s    │
│  ███                                    │
│                                         │
│  ✓ Aktualisiert vor 3 s · 4 erfasst     │
└─────────────────────────────────────────┘
~~~

- Ausgangsbreite etwa 400 px; responsive Größen, begrenzte und scrollbar gerenderte Geräteliste.
- Geräte defaultmäßig nach `download + upload`, alternativ nach Download, Upload oder Name.
- Auslastungsbalken auf **gemeinsamer Skala** für die angezeigten Geräte; keine unbelegten WAN-Prozentwerte.
- Ausgeblendete Geräte bleiben Teil des tatsächlichen WAN-Traffics; keine irreführenden Summen.
- Zunächst keine aufwendigen Diagramme; kleine RAM-basierte Sparkline-Verläufe erst nach MVP.

### 6.3 Einstellungen

Drei Bereiche:
1. **Verbindung:** Routeradresse (Vorgabe `10.0.0.1` nur für lokale Entwicklung), Benutzername, maskierte Secret-Service-Passworteingabe, Verbindungstest, Status und ggf. TLS-Trust.
2. **Aktualisierung/Anzeige:** Intervall (nach validierter Firmware begrenzen), automatische Dezimal-/Binäreinheiten, kompakt/standard, Sortierung.
3. **Geräte:** Sichtbarkeit und Aliasse (v0.2), originalen Router-Namen weiterhin verfügbar halten.

Die Passwort-Eingabe darf **nicht** die Standard-`StringSetting`-Persistenz verwenden; der Setup-Helfer schreibt direkt in den Secret Service. In UI-Fehlern niemals das Secret spiegeln.

## 7. Projektaufteilung und geplante Dateien

Das Repository `almighty-atlas/dms-plugins` ist bereits ein **Monorepo mit eigener Plugin-Registry**. Dieses Konzept bleibt zunächst unter `docs/plans/`. Erst bei Implementierungsbeginn ein neues Plugin-Verzeichnis samt Registry-Eintrag einführen, ohne die vorhandenen Plugins anzufassen.

~~~text
dms-plugins/
├── docs/
│   └── plans/
│       └── fritzbox-traffic-widget.md    # dieses Konzept
├── FritzTraffic/                         # erst in späterem Implementierungs-PR
│   ├── plugin.json
│   ├── TrafficWidget.qml
│   ├── TrafficController.qml
│   ├── TrafficSettings.qml
│   ├── components/
│   │   ├── TrafficBar.qml
│   │   ├── TrafficPanel.qml
│   │   ├── DeviceRow.qml
│   │   └── StatusIndicator.qml
│   ├── collector/
│   │   ├── main.py
│   │   ├── auth.py
│   │   ├── client.py
│   │   ├── parsers.py
│   │   ├── tr064.py
│   │   ├── secrets.py
│   │   └── models.py
│   ├── translations/
│   │   └── de.json
│   ├── tests/
│   │   ├── fixtures/
│   │   ├── test_auth.py
│   │   ├── test_parsers.py
│   │   ├── test_sessions.py
│   │   └── test_errors.py
│   ├── README.md
│   └── CHANGELOG.md
├── plugins/
│   └── fritzbox-traffic.json             # erst nach funktionalem MVP
└── README.md
~~~

Die Aufteilung bleibt anpassbar; wichtiger als viele Dateien sind ein separater testbarer Parser, ein einziger Collector und eine kleine, übersichtliche UI.

**Geplantes Manifest:** `id: fritzTraffic`, `type: composite`, `components: { daemon, widget }`, `requires_dms: >=2.0.0`, `settings`, `capabilities: [daemon, dankbar-widget, monitoring]`, deklarierte Settings-/Netzwerk-/Prozessrechte und benötigte Tools `python3`/`secret-tool`. **Exakte Keys und erlaubte Permissions bei Umsetzung erneut gegen das dann aktuelle JSON-Schema prüfen.**

## 8. Entwicklungs-Roadmap mit Akzeptanzkriterien

### Phase 0 – Read-only Geräte-/API-Validierung (**Voraussetzung**)

Noch **keine** Collector-Implementierung; zunächst Browser-Netzwerkmonitor am Zielrouter verwenden.

1. Modell, FRITZ!OS-Build und Monitor-Konfiguration feststellen.
2. Im Browser FRITZ!Box → **Internet → Online-Monitor → Einzelne Geräte** öffnen; Entwicklerwerkzeuge/Netzwerk/Fetch-XHR beobachten.
3. Tatsächlich genutzte GET-Pfade, HTTP-Status, Felder, Gerätelisten, Arrays, Intervall und Zeitstempel notieren.
4. Mit kontrollierter Dateiübertragung Werte und **Einheiten** gegen die FRITZ!Box-Oberfläche vergleichen.
5. Eingeschränkten Benutzer und TR-064-Verfügbarkeit sicher testen.
6. Einige Minuten mit 10–15-s-Abfragen testen – erst nach Beurteilung der Routerreaktion.

**Abnahme:** Route+Auth bestätigt; mindestens ein eindeutig zuordenbares Gerät mit plausiblen Down-/Upload-Raten; Messreihenreihenfolge, Einheiten, Sample-Zeit und Rechteumfang bekannt; sauberer Umgang mit nicht erfassten Geräten.

**Go/No-Go:** Funktioniert die experimentelle Geräte-API nicht, zunächst **nur WAN-Gesamtwerte** über TR-064 planen; keine vermeintlichen Gerätedaten simulieren.

**Datenschutz:** Keine unbereinigten HAR-Dateien, Cookies, SIDs, Hostnamen, MACs oder privaten/öffentlichen IPs veröffentlichen.

### Phase 1 – Projektgerüst und Datenvertrag

Geplanter PR: `chore: initialize fritzbox traffic plugin structure and data contracts`

- Manifest, QML-Startstruktur, synthetische Fixtures und versioniertes Snapshot-Schema.
- Reine Modell-/Parser-Unit-Tests und CI-Grundlage.
- Noch keine echten Router-Credentials.

**Abnahme:** Schema-valides Manifest, ladbares Mock-Widget, reproduzierbare Unit-Tests.

### Phase 2 – Authentifizierung und Collector

Kleine PRs:
- `feat: implement fritzbox authentication and secret storage`
- `feat: add read-only device traffic collector`
- optional `feat: add tr064 wan monitor adapter`

**Abnahme:** Gültige Session wird wiederverwendet; Authfehler verursachen keine Login-Schleife; 401/403/HTML, Timeout, fehlerhafte Zahlen, Nullwerte und Schemaänderungen sind getestet; stdout enthält ausschließlich bereinigte Snapshots.

### Phase 3 – DMS-Integration

Kleine PRs:
- `feat: add single-instance traffic controller`
- `feat: add dankbar widget and device popout`

**Abnahme:** Zwei Monitore/Bar-Instanzen lösen **einen** Pollingstrom aus; horizontale und vertikale Bar funktionieren; Popout und Themes bleiben responsiv; Deaktivierung stoppt den Prozess.

### Phase 4 – Einstellungen, Härtung, `v0.1.0`

Kleine PRs:
- `feat: add native connection and display settings`
- `test: add resilience and integration coverage`
- `chore: prepare v0.1.0 release`

**Abnahme:** Einrichtungsworkflow ohne Klartext-Persistenz; sichere Fehlermeldungen; CI grün; dokumentierter manueller Live-Test; Version und Changelog vorhanden; keine Debug-Geheimnisse.

### Phase 5 – `v0.2.0` und später

- Geräte ausblenden/umbenennen, zusätzliche Sortierung und Anzeigevarianten.
- Kleine RAM-basierte Verlaufsgrafiken, aktivstes Gerät optional in der Bar.
- Später: gezielter Legacy-Fallback, weitere Routermodelle, langfristiges Traffic-Accounting nur bei echtem Bedarf.

## 9. Test- und Performanceplan

| Ebene | Fälle |
| --- | --- |
| Auth | PBKDF2-Referenzvektoren, `BlockTime`, abgelaufene SID, erneute Anmeldung, falsche Credentials, gesperrter Keyring |
| Parsing | Online-/Legacy-Schema, fehlende Arrays, `null`, `NaN`, falsche Einheiten, Timestamp s/ms, unterschiedliche Arraylängen und Reihenfolge |
| Geräte | UID/MAC-Normalisierung, wechselnde Namen, fehlende Erfassung, gleiche UID, verspätete Namensauflösung |
| HTTP/IPC | Timeouts, Redirects, 401/403, 404, 429/5xx, HTML statt JSON, gekappte JSON-Zeilen, Prozessabbruch |
| UI | Formatierte KB/s/MB/s, Bar-Ausrichtungen, Sortierung, Dark/Light, kleine Panels, 40 Geräte, mehrere Instanzen |
| Sicherheit | Keine Secrets in Logs/Settings/Args/Debug-Snapshots; keine externen Router-Requests; nur erlaubte Endpunkte |

**Ressourcenbudgets (Ziele, noch nicht gemessen):**
- Collector RSS möglichst unter **40 MiB**.
- CPU im Leerlauf im Mittel unter **1 % eines Kerns**.
- Maximal **eine** gleichzeitige Router-Monitor-Abfrage.
- Metadaten nicht häufiger als ungefähr alle **15 Minuten**.
- Verlauf im RAM zunächst auf **60 Proben je Gerät** begrenzen.
- Keine blockierenden Netzwerk-/Krypto-Operationen im QML-UI-Thread.

**Testprofile:** (1) Widget installiert/inaktiv, (2) eine Bar sichtbar, (3) zwei Monitore + Popout + bis zu 40 Geräte. Router-Latenz, CPU/RSS, HTTP-Requests/min, UI-Reaktionszeit und Verhalten nach langen Offline-Phasen dokumentieren.

**GitHub Actions:** Manifest-JSON-Schema, Python-Syntax/Unit-Tests, Ruff als *Entwicklungs*-Abhängigkeit, QML-Prüfung gegen gepinnte DMS-Version, Secret-Scan. CI darf **nie** die private FRITZ!Box kontaktieren; Integrationstests nutzen Mock-Server und anonymisierte synthetische Fixtures.

## 10. Lizenz, Distribution und Wartung

- **Lizenzempfehlung:** MIT für eigenständig geschriebenen Code. Bei Übernahme von Teilen fremder Projekte vorher deren Lizenzen/Attribution prüfen.
- **Distribution:** zunächst im bestehenden Monorepo `almighty-atlas/dms-plugins`, dessen `plugins/`-Ordner bereits als eigene Registry dient. Ein separates öffentliches Repository `almighty-atlas/dux-fritzbox-traffic` wäre langfristig optional, aber für den MVP nicht nötig.
- **Installation:** nach Implementierung über die DMS-Registry des Monorepos; Python 3 und `secret-tool` als dokumentierte Systemvoraussetzungen. Kein AUR-Paket für v0.1 erforderlich.
- **Offizielles Plugin-Verzeichnis:** optional später PR an [dux-plugin-registry](https://github.com/duxlabs-dev/dux-plugin-registry) mit passendem Manifest/ID, Screenshots, unterstützten Distributionen/Compositors und Release.
- **Wartung:** unterstützte FRITZ!Box-Modelle/FRITZ!OS-Builds dokumentieren, Adapter versionieren, neue Firmware vor Freigabe prüfen, anonyme Fehlerdiagnostik ermöglichen, DMS-/Quickshell-Brüche regelmäßig testen.
- **Rechtliches:** Kein offizielles FRITZ!-Produkt; keine Zusicherung von Kompatibilität mit zukünftiger Firmware.

## 11. Noch offene Fragen / Entscheidungslog

| Thema | Derzeitige Entscheidung | Bis wann zu klären |
| --- | --- | --- |
| REST-`online/0` auf Zielbox | Primärweg, **nicht live bestätigt** | Phase 0 |
| WAN TR-064 | Bevorzugte Gesamtrate, Verfügbarkeit testen | Phase 0 |
| Routermodell/Build | Noch unbekannt | Phase 0 |
| Raten-Einheiten/Array-Richtung | Keine unbewiesenen Parser-Annahmen | Phase 0 |
| Geräte-Namen | Zunächst bevorzugt TR-064-Hosts, später ggf. intern | Phase 0/2 |
| Minimalrechte eigener FRITZ!Box-Benutzer | Testen, nicht als read-only voraussetzen | Phase 0/2 |
| HTTPS / Zertifikat-Pinning | Sichere Verbindung bevorzugen; kein `verify=False` | Phase 0/2 |
| Legacy-Fallback | Nicht im MVP, außer Phase 0 erzwingt ihn | Phase 2+ |
| Externer systemd-Service | Nicht nötig, vorerst verworfen | Nur bei erweitertem Anwendungsfall |
| Multi-Widget-Poller | Ein QML-Controller + ein Collector | Phase 3 |
| Eigenständiges GitHub-Repository | Optional, zunächst vorhandenes Monorepo | Nach v0.1 |
| Release-Intervall | Kleine PRs, SemVer, dokumentierte Tests | Ab Phase 1 |

## 12. Quellen (Stand der Planung)

**DMS / Dux Shell**
- https://github.com/duxlabs-dev/dux-shell
- https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/README.md
- https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/plugin-schema.json
- https://github.com/duxlabs-dev/dux-shell/tree/master/quickshell/PLUGINS/ExampleCompositePlugin
- https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/widget-plugin-guide.md
- https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/settings-components-reference.md
- https://github.com/duxlabs-dev/dux-shell/blob/master/.agents/skills/dms-plugin-dev/references/data-persistence-guide.md
- https://github.com/duxlabs-dev/dux-plugin-registry

**FRITZ!Box und Protokolle**
- https://avm.de/fileadmin/user_upload/Global/Service/Schnittstellen/AVM_Technical_Note_-_Session_ID_deutsch_2021-05-03.pdf
- https://fritz.com/en/pages/interfaces
- https://github.com/Meine-smarte-Welt/fritzbox_netzwerk
- https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/webui.py
- https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/traffic.py
- https://github.com/Meine-smarte-Welt/fritzbox_netzwerk/blob/main/custom_components/fritzbox_netzwerk/online_monitor.py
- https://forum.iobroker.net/topic/82093/fritz-box-daten-auslesen-ger%C3%A4tetraffic-und-filter-setzen

**Referenz-Widgets und Secret Storage**
- https://github.com/gemb0-0/Network-Indicator
- https://github.com/Lemon-mon-254/dms-proxy-traffic
- https://man.archlinux.org/man/core/libsecret/secret-tool.1.en
- https://quickshell.org/docs/v0.2.1/types/Quickshell.Io/Process/
- https://quickshell.org/docs/v0.2.1/types/Quickshell.Io/SplitParser/

**Bisherige interne Vorarbeit (privat)**
- https://github.com/almighty-atlas/notes/blob/main/docs/network/fritzbox-online-monitor-api.md

---

## Nächste konkrete Aktion

**Phase 0 durchführen:** An der FRITZ!Box unter `10.0.0.1` im Browser die Entwicklerwerkzeuge öffnen, `Internet → Online-Monitor → Einzelne Geräte` aufrufen und nur **Endpunktpfade, Status, Top-Level-Felder und Datentypen** festhalten. Noch keine Implementierung beginnen und keine unbereinigten Antworten/HAR-Dateien veröffentlichen.
