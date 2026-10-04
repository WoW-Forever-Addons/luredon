# Luredon 1.0.0 (WoW Forever)

Angelhilfe für World of Warcraft: Forever (Client "Camelot", Interface 16001).
Ein Klick von dir pro Aktion, alles drumherum erledigt das Addon. Kein automatisches Einholen, keine Bisserkennung.

## Installation
Ordner `Luredon` nach `World of Warcraft\_classic_beta_\Interface\AddOns\` kopieren
(nach dem Release in den dann gültigen Forever-Ordner). Im Spiel `/reload`.
Beim allerersten Login (noch keine Würfe erfasst) erklärt eine Chatzeile das Auswerfen und verweist auf `/ld help`.
Ein Charakter, der Angeln noch nicht erlernt hat, bekommt sie erst, sobald er es gelernt hat.

## Auswerfen
- **Doppel-Rechtsklick** in die Welt (mit Angel in der Hand) wirft aus.
- Hat die Angel keinen Köder, bringt derselbe Klick zuerst den besten Köder an, den dein Skill erlaubt.
  Ein Köder derselben Sorte wird schon erneuert, wenn er in den nächsten 20 Sekunden abläuft. Ein Köder einer anderen Sorte läuft erst ab,
  danach kommt der neue dran (sonst würde das Spiel fragen, ob die Verzauberung ersetzt werden soll).
  Bekannte Classic-Köder sind hinterlegt, unbekannte (z. B. Camp-Köder) erkennt das Addon am Tooltip.
  Der nächste Klick wirft aus; dauert das Anbringen länger, wartet der Doppelklick, bis der Köder dran ist, und nimmt keinen zweiten.
- Alternativ per Taste: Tastaturbelegung > AddOns > Luredon > "Auswerfen / Köder anbringen".
- Anbeißen: Schwimmer anklicken (oder Interaktionstaste, Option "Größere Interaktionsreichweite beim Angeln").
  Ein Doppelklick auf den Schwimmer holt den Fang ein und wirft nicht sofort neu aus (auch mit Autoplündern).
- Der Doppelklick pausiert im Kampf, beritten, beim Schwimmen, im Flug und tot; die rechte Maustaste bleibt dann unberührt.
  Ohne Angel (anderer Gegenstand in der Hand) und ohne erlerntes Angeln tut er nichts. Das Fenster sagt unten, warum.
- Eine rechte Taste, die länger als 0,3 Sekunden gehalten wird (Kamera-Drehung), zählt nicht als Klick eines Doppelklicks.
- Ein Rechtsklick auf eine Einheit (NPC, Mob, Leiche, Spieler) behält immer seine normale Bedeutung. Danach zählen Klicks in die Welt
  eine Sekunde lang nicht für einen Doppelklick: Wer mit einem Doppel-Rechtsklick einen NPC anspricht oder eine Leiche plündert,
  die danach verschwindet, wirft nie versehentlich aus.
- Ein Doppel-Rechtsklick auf ein Luredon-Fenster wirft nie aus. Auch ein Ladebildschirm (Portal, Instanz, `/reload`) trennt zwei Klicks.
- Die Belegung der rechten Maustaste wird bei Kampfbeginn entfernt: Ein Rechtsklick im Kampf greift normal an.
- Liefert das Spiel den Namen des Angelzaubers nicht lesbar (geheimer Wert), wirft der Knopf über die Zauber-ID des
  höchsten bekannten Rangs aus. In jeder Client-Sprache gilt sonst der Name, den das Spiel selbst liefert.
- Läuft Fishing Buddy, Fishing Ace oder Better Fishing, überlässt Luredon diesem Addon Klick und Sound.

## Funktionen
- Lauteres Platschen: Musik und Umgebung stumm, Effekte laut, solange die Angel ausgerüstet ist. Mit "Auch im Hintergrund" läuft der Ton
  weiter, wenn ein anderes Fenster im Vordergrund ist (Platschen auch beim Wechsel in ein anderes Programm hörbar). Deine Werte kommen beim Ablegen der Angel,
  beim Ausloggen und nach `/reload` zurück. Nach einem Absturz des Spiels kann die Sicherung fehlen (das Spiel speichert Addon-Daten nur beim Ausloggen).
- Warnungen: ohne Köder ausgeworfen, Taschen voll oder fast voll (2 freie Plätze oder weniger).
- Ausrüstungswechsel per Ausrüstungsset (Optionen oder `/ld set fishing <Set>` / `/ld set normal <Set>`), Taste oder `/ld gear`.
- Fische aufspüren wird beim Anlegen der Angel eingeschaltet (falls bekannt). Schaltet das Spiel dabei ein anderes Aufspüren aus
  (z. B. Kräuter suchen), kommt es beim Ablegen der Angel zurück, außer du hast das Aufspüren inzwischen selbst geändert.
  Im Kampf wird nichts umgeschaltet, sondern danach.
- Hinweis bei seltenen Fängen: Chatzeile mit Link und Ton ab der gewählten Qualität (Standard: selten, wählbar ungewöhnlich/selten/episch).
  Die Qualität wird auch an der Linkfarbe erkannt, wenn der Gegenstand noch nicht geladen ist.
- Fangziel: Anzahl Fische dieser Sitzung (Plunder zählt nicht) per Regler in den Optionen oder `/ld goal 100`,
  oder eine Anzahl eines Gegenstands in den Taschen per `/ld goal 20 <Gegenstandslink>` (z. B. für ein Rezept oder eine Quest).
  Das Fenster zeigt den Fortschritt, beim Erreichen gibt es Chatzeile, Hinweis und Ton (nur durch einen Fang, nicht durch das Laden der Taschen nach dem Login).
  `/ld reset` startet ein Sitzungsziel neu.
- Fenster im gemeinsamen Stil (dunkel, flach, eine Akzentfarbe, wie Questdon und Vitaldon).
  Verschieben an der Titelzeile, Knöpfe rechts oben: Optionen, Einklappen, Schließen (`/ld` zeigt es wieder).
  Linksklicks bleiben im Fenster. Die rechte Maustaste geht durch das Fenster in die Welt: gedrückt halten dreht die Kamera
  wie gewohnt. Das gilt auch für das Fangbuch sowie das Export- und das Diagnosefenster.
  Erscheint automatisch nur mit Angel in der Hand (abschaltbar). Abschnitte erscheinen nur, wenn sie etwas zu sagen haben:
  - Angeln: Skill mit Bonus und dünner Fortschrittsleiste, Würfe pro Skillpunkt (Tooltip: geschätzte Würfe bis nächste Zonenstufe,
    Camp-Objekt, Maximum; erst ab 3 erfassten Skillpunkten; Kommazahlen in der Schreibweise des Spiels, also "9,0" im deutschen Client),
    Köder-Restzeit mit Vorrat (wie viele des besten Köders für deinen Skill noch in den Taschen sind), Taschen (nur wenn fast voll),
    Hinweis auf den nächsten Lehrer-Meilenstein (75, 150, 225 Nat Pagle)
  - Sitzung: Fänge, Fangquote, Fische/h, Wert (Händlerpreis), Fangziel mit Leiste. Ein Klick auf die Zahlen öffnet das Fangbuch. Die Sitzung übersteht `/reload` und ein
    erneutes Einloggen innerhalb von 15 Minuten mit demselben Charakter. Tooltip: Fänge dieser Sitzung, Würfe, Entkommen,
    Plunder, zu früh angeklickte Schwimmer, Gold/h. Mit Auctionator (optional) kommt die Zeile "AH-Wert" dazu, siehe unten.
  - Zone: Mindestskill, damit nichts entkommt (Werte laut Wowhead-Angelguide für Forever, inkl. Zephras-Insel 25; Zonen ohne gesicherte
    Daten wie Riverglades, Hyjal, Shen'dralas zeigen "unbekannt", der Tooltip nennt sie als neues Forever-Gebiet ohne veröffentlichten Wert),
    Teilgebiete mit höherem Bedarf (Jaguero-Insel 300, Bucht der Stürme 425, Jademirsee 425), gemessene Entkommen-Quote.
    Tooltip: Abschnitt "Fische" mit deinen häufigsten Fängen der Zone und Anteil (seltene markiert), Abschnitt "Selten" mit den seltenen
    Fängen der Zone (auch außerhalb der Top-Liste) und ihrem Anteil
  - Camp: Timer für Fischregal und Fischerhütte (startet beim Aufstellen, nicht beim Herstellen), Fischglas-Buff (läuft im Kampf weiter),
    nächstes Camp-Objekt nach Grundskill (Fischglas ab 20, Fischregal ab 140, Fischerhütte ab 300; ab 300 entfällt die Zeile).
    Camping ist in Forever eine eigene Mechanik; ein Lagerfeuer-Timer ist bewusst nicht dabei (keine gesicherten Spell- oder Aura-IDs).
    Die Dauer von Regal und Hütte (eine Stunde) ist laut Wowhead-Text angesetzt und im Spiel noch zu prüfen.
    Per `/ld camp rack|hut` lässt sich ein Timer von Hand starten.
  - Wettbewerb: Angelwettbewerb im Schlingendorntal (Sonntag 14-16 Uhr Realmzeit wie in Classic, so auch in den Spieldaten des
    Forever-Clients hinterlegt; änderbar mit `/ld derby <Tag> <Stunde>`, falls Blizzard es anders ankündigt),
    Restzeit und Leckerfisch-Zähler mit Leiste. Solange Blizzard die Zeit nicht angekündigt hat, steht darunter leise
    "Zeit laut Spieldaten, für Forever unbestätigt."; der Tooltip nennt Zeit und Quelle. Mit eigener Zeit entfällt der Hinweis.
    Mit 40 Leckerfischen während des Wettbewerbs kommt einmal Hinweis und Ton: In Forever gewinnen die ersten 50.
  - Ganz unten als leiser Hinweis: was der nächste Doppelklick tut, oder warum er gerade ruht (Kampf, beritten, Schwimmen, Flug,
    Doppelklick aus, anderes Angel-Addon).
  - Ohne erlerntes Angeln zeigt das Fenster (falls eingeblendet) nur eine ruhige Zeile "Angeln noch nicht erlernt. Ein Angellehrer
    bringt es dir bei." und sonst nichts. Einen konkreten Lehrer nennt es nicht, weil es dafür keine gesicherten Forever-Daten gibt.
  - Leerlauf: Ohne Angel und ohne erlerntes Angeln läuft kein Timer, das Fenster rechnet nur bei Ereignissen (Angel angelegt, Angeln gelernt,
    Taschen, Ladebildschirm). Die sekündliche Aktualisierung ruht, solange das Fenster ausgeblendet oder eingeklappt ist; die Köderprüfung
    alle 3 Sekunden läuft nur mit Angel, erlerntem Angeln und "Zuerst Köder anbringen".
  - Leere Zustände: ohne Würfe zeigt die Sitzung nur "Noch keine Würfe in dieser Sitzung.", ohne Angel entfällt die Köderzeile,
    liefert das Spiel noch keinen Skill, steht dort "unbekannt" statt "0 / 0".

  Farben bedeuten immer einen Zustand: gelb = bald handeln (Köder unter 1 Minute, Taschen fast voll, Lehrer nötig), rot = Problem
  (kein Köder, Taschen voll, Skill zu niedrig für die Zone), grün = erreicht (Skill reicht, Ziel erreicht, 40 Leckerfische).
  Einklappen zeigt nur die Titelzeile, Sperren verhindert das Verschieben, im Kampf kann das Fenster auf 40 % abdunkeln.
- Fangbuch (`/ld log`, Klick auf die Sitzungszahlen im Fenster oder Werkzeug in den Optionen): dauerhaftes Protokoll je Fischart über alle
  Sitzungen und Charaktere des Accounts. Kompaktes Fenster im gemeinsamen Stil mit der Zahl der Arten, zwei Rekorden (längste Serie Fänge
  ohne Entkommen, beste Sitzung in Fischen pro Stunde ab 10 Minuten Angelzeit, Plunder zählt nicht) und einer Liste aller gefangenen Arten,
  meist gefangene zuerst, zehn pro Seite. Der Tooltip einer Art nennt Anzahl, erstes und letztes Fangdatum und die Zone.
  Gespeichert wird nur die Gegenstands-ID mit Zählern (keine Namen, kein Charakter), höchstens 150 Arten: ist das Buch voll,
  fliegt die Art mit dem ältesten letzten Fang zuerst raus. Plunder (graue Gegenstände) kommt nicht hinein, zählt aber für die Serie.
  Die aktuelle Serie gilt nur für die Sitzung. Das Buch bleibt beim Löschen der Angelstatistik erhalten (eigenes Werkzeug "Fangbuch löschen").
  Ausgewertet werden nur Fangmeldungen, die der Spielclient lesbar liefert. Eine geheime Beutezeile oder ein geheimer Link wird übersprungen und
  gezählt (`/ld diag`, Zeile "catch log", und im Fenster). Ein Fangbuch mit höherem Schema (aus einer neueren Luredon-Version) bleibt unverändert.
  Export: `/ld log export` oder der Eintrag "Als Text kopieren" im Fenster,
  Format `fish;Item-ID;Anzahl;erster Fang;letzter Fang;Karten-ID erster;Karten-ID letzter` plus Zeilen `record;...` (Zeiten als Serverzeit in Sekunden seit 1970).
- Fenster beim Angeln (Option, Standard aus): Solange die Angel ausgeworfen ist, wird das Luredon-Fenster (und das Fangbuch, falls offen) auf die Titelzeile
  verkleinert ("Kompakt") oder verliert seinen Hintergrund ("Ohne Hintergrund"). Es kommt vier Sekunden nach dem Einholen zurück (ein Neuwurf
  davor behält die Ansicht), sofort beim Ablegen der Angel, beim Ladebildschirm und im Kampf. Gespeichert wird dabei nichts: deine eigenen
  Einstellungen (Einklappen, Deckkraft) bleiben unverändert. Angefasst werden nur eigene Fenster, nie die Oberfläche des Spiels.
- Sitzungsbilanz im Chat, wenn du die Angel ablegst (Würfe, Fänge, Entkommen, Wert, Fische/h; abschaltbar).
- AH-Preise mit Auctionator (optional, Option "AH-Preise (Auctionator)", an): Ist Auctionator installiert, zeigt das Fenster unter "Wert" die Zeile
  "AH-Wert", der Tooltip dazu AH-Gold/h, das Fangbuch den AH-Preis je Fisch (Maus auf die Art) und die Bilanz im Chat den AH-Wert. Gezählt werden nur Items mit
  gescanntem Preis; Items ohne Preis stehen als "(n ohne Preis)" daneben und fließen nicht als null in die Summe ein, graue Gegenstände zählen nicht
  (sie lassen sich nicht versteigern). Ohne Auctionator, ohne Scan oder bei ausgeschalteter Option ändert sich nichts. Luredon nutzt nur die öffentliche
  Preisfunktion von Auctionator (`Auctionator.API.v1.GetAuctionPriceByItemID`), jeder Aufruf ist abgesichert, und Preise werden nur wenige Sekunden zwischengespeichert.
  Hinweis: Weil der Beta-Client gespeicherte Daten nicht wieder lädt, sind Auctionators Preise nach jedem Einloggen weg, bis du das Auktionshaus neu gescannt hast.
  Alle Chatzeilen beginnen mit der Wortmarke, die Überschrift (Sitzung, Seltener Fang, Ziel erreicht, Angelwettbewerb) steht in Blau, Details in Grau.
- Zonen für deinen Skill (`/ld zones` oder Werkzeug in den Optionen): Chatzeilen mit den Zonen der höchsten Stufe, die dein Skill
  samt Köder und Ausrüstung erreicht (dort entkommt nichts), und der nächsten Stufe mit fehlenden Punkten. Grundlage ist dieselbe
  Zonentabelle wie beim Zonen-Check (Wowhead-Angelguide für Forever); Teilgebiete mit höherem Bedarf stehen in Klammern. Zonen ohne
  veröffentlichten Wert fehlen. Ist dein Skill für die aktuelle Zone zu niedrig, verweist der Zonen-Tooltip darauf.
- Export der Fangdaten (`/ld export` oder Werkzeug in den Optionen): Fänge pro Zone als Text zum Kopieren, ohne Charakter- und Realmnamen.
  Format: `zone;Karten-ID;Würfe;Fänge;Entkommen;Plunder` und `fish;Karten-ID;Item-ID;Anzahl`.
- Diagnose (`/ld diag` oder Werkzeug "Diagnose" in den Optionen): technischer Bericht zum Kopieren für die Fehlersuche, ohne Charakter- und Realmnamen.
  Enthält Addon- und Client-Version, Sprache, welche Spielfunktionen und Texte vorhanden sind (Funktionen mit Ersatz, z. B.
  GetMouseFoci statt des alten GetMouseFocus, stehen in der Zeile "api alternatives" und gelten nur als fehlend, wenn keine Variante da ist),
  Herkunft der Wettbewerbszeit (Zeile "derby source"), welche Timer laufen (Zeile "tickers"), Live-Werte (Angeln erlernt je Prüfweg,
  Skill, Angel, Köder mit Restzeit und Verzauberungs-ID, Mouseover lesbar, Ton-Einstellungen, Tastenbelegung der rechten Maustaste,
  wie die Fenster die rechte Maustaste behandeln: Zeile "mouse"), die Zeilen "catch log" (Schema, Arten, Fänge, Rekorde, Serie,
  übersprungene Zeilen) und "fishing view", die letzten 10 Doppelklick-Entscheidungen mit Grund, die letzten 12 Einhol-, Beute- und
  Fangereignisse (Quelle Chat oder Beutefenster) und aufgetretene Fehler (auch Fehler in Fenster-Tooltips und Klicks als `ui ...`).
  Gründe der Entscheidungen: `cast`, `lure` (ausgeführt), `clicked` (Klick ist am Knopf angekommen), `ui`, `unit`, `unit-quiet` (Weltklick kurz nach einem Klick auf eine Einheit),
  `too-fast`, `hold` (rechte Taste länger als 0,3 s gehalten: Kamera-Drehung, kein Klick), `bobber`, `off`, `conflict`,
  `combat`, `mounted`, `swimming`, `flying`, `taxi`, `dead`, `no-pole`, `not-known`, `lure-wait` (ignoriert), `combat-disarm`,
  `combat-locked`, `disarm-timeout`, `loading-disarm` (Belegung entfernt bzw. nicht entfernbar), `lure-unit-s` (Restzeit kommt in Sekunden),
  `pole-swapped` (Angel während des Köderns gewechselt).
- Fehlerschutz: Ein Fehler in einem Teil des Addons stoppt die anderen nicht. Die ersten verschiedenen Fehler werden gesammelt,
  einmal pro Sitzung erscheint im Chat ein Hinweis auf `/ld diag`. Geschützt sind Ereignisse, Timer, Befehle, Tastenbelegungen,
  das AddOn-Menü, Optionsänderungen und Werkzeuge. Beschädigte Tabellen oder Werte in den gespeicherten Daten werden verworfen,
  und absurd große Fangziele werden begrenzt.

## Optionen
Esc > Optionen > Reiter "AddOns" > Luredon (oder `/ld options`, oder über das AddOn-Menü an der Minimap).
- Startseite: Status (Version, "Insgesamt (Stand beim Login)", Hinweis auf `/ld help`), Knöpfe zu den Unterseiten und Werkzeuge:
  Angelausrüstung wechseln, Sitzung zurücksetzen, Position zurücksetzen, Zonen für deinen Skill, Fangbuch, Fangbuch exportieren,
  Fangbuch löschen, Fangdaten exportieren, Diagnose, Angelstatistik löschen.
- Auswerfen und Köder: "Doppel-Rechtsklick zum Angeln", "Zuerst Köder anbringen", "Fenster beim Angeln" (Aus, Kompakt, Ohne Hintergrund; Standard Aus),
  "Ohne Köder warnen", "Bei vollen Taschen warnen".
- Platschen: "Lauteres Platschen", "Auch im Hintergrund", "Größere Interaktionsreichweite beim Angeln".
- Ausrüstung und Aufspüren: "Angel-Ausrüstungsset", "Normales Ausrüstungsset", "Fische automatisch aufspüren".
- Sitzung und Ziel: "Sitzungsbilanz im Chat", "AH-Preise (Auctionator)", "Hinweis bei seltenen Fängen" mit "Hinweis ab Qualität", "Fangziel" (Regler 0 bis 500, 0 = aus),
  "Angelwettbewerb-Timer".
- Darstellung (gleiche Seite in allen unseren Addons): "Fenster anzeigen", "Nur mit Angel", "Fenster sperren", "Größe" (0,6 bis 1,6),
  "Hintergrund-Deckkraft" (0 bis 1), "Im Kampf abdunkeln" (auf 40 %), "Position zurücksetzen".
- Tastenbelegung (Tastaturbelegung > AddOns > Luredon): "Auswerfen / Köder anbringen", "Angelausrüstung wechseln", "Fenster ein-/ausblenden".

## Befehle
`/ld help` (alle Befehle, je eine Zeile), `/ld` Fenster ein/aus, `/ld options`, `/ld zones` (Zonen für deinen Skill), `/ld gear`, `/ld reset` (Sitzung), `/ld resetpos`,
`/ld set fishing|normal <Set>`, `/ld camp rack|hut` (Timer manuell starten),
`/ld goal <Anzahl> [Gegenstandslink oder Item-ID]` bzw. `/ld goal off` (Fangziel),
`/ld derby <Tag> <Stunde>` (Wettbewerbsbeginn in Realmzeit, Tag als `so`/`sun`, `mo`, ... oder 1-7 mit 1 = Sonntag) bzw. `/ld derby reset`,
`/ld log` (Fangbuch ein/aus) bzw. `/ld log export` (Fangbuch als Text), `/ld export` (Fangdaten), `/ld diag` (Diagnose),
`/ld debug` (zeigt im Chat, wie Fänge erkannt werden). `/luredon` funktioniert wie `/ld`. Ein unbekannter Befehl verweist kurz auf `/ld help`.

## Im Spiel prüfen
Bei jedem Problem zuerst `/ld diag` öffnen und den Text kopieren.
- Fangbuch: Ein paar Fische angeln, dann `/ld log`: die Arten stehen mit Anzahl in der Liste, "Arten" und "Gefangen" stimmen mit der Sitzung überein,
  Plunder (graue Gegenstände) fehlt; Maus auf eine Art zeigt erstes und letztes Fangdatum und die Zone.
- Fangbuch-Export ("Als Text kopieren" im Fangbuch): Das Export-Fenster öffnet sich mit Zeilen `fish;...` und `record;...`, ohne Namen.
- `/ld diag`: Zeile "catch log" zeigt "ok" und "skipped unreadable 0". Steht dort eine Zahl über 0, meldet der Client Beutezeilen als geheimen Wert.
- Auctionator (nur wenn installiert): Auktionshaus öffnen und scannen, dann Fische angeln: im Fenster erscheint "AH-Wert", im Tooltip AH-Gold/h; Maus auf eine Art im Fangbuch zeigt den AH-Preis.
  `/ld diag`, Zeile "auction prices", zeigt, ob die Schnittstelle gefunden wurde und was sie für ein Beispiel-Item liefert (Preis in Kupfer oder "none").
- Fisch entkommen lassen: die Serie im Fangbuch (Rekord "Längste Serie") wächst erst wieder mit neuen Fängen; `/ld diag` zeigt "streak now" 0.
- `/reload` oder neu einloggen: Fangbuch und Rekorde sind noch da. Der Beta-Client lädt gespeicherte Daten teils nicht; dann ist das Buch
  nach dem Einloggen leer, das ist kein Luredon-Fehler.
- Optionen > Auswerfen und Köder > "Fenster beim Angeln" auf "Kompakt": Angel auswerfen, das Fenster schrumpft auf die Titelzeile; nach dem Einholen kommt es
  nach etwa vier Sekunden zurück. Mit "Ohne Hintergrund" bleibt der Text sichtbar, der Hintergrund verschwindet. Im Kampf bleibt das Fenster normal.
- "Fenster beim Angeln" an, Fenster vorher von Hand eingeklappt: nach dem Fischen ist es wieder eingeklappt, nicht aufgeklappt.
- Doppel-Rechtsklick auf Luredon-Fenster (auch Fangbuch, Export, Diagnose) wirft nie aus, die rechte Taste dreht darüber die Kamera
  (`/ld diag`: Entscheidung `ui`, Zeile "mouse: right button passthrough"). Zeigt "mouse" `clickthrough` oder `error`, lässt das Fenster alle Klicks durch.
- Rechte Taste kurz gedrückt halten und die Kamera drehen, dann sofort noch einmal klicken: kein Wurf (`/ld diag`: `hold`);
  ein normaler Doppel-Rechtsklick wirft weiter aus.
- Doppel-Rechtsklick auf einen Händler bzw. eine Leiche plündern und sofort weiter doppelt klicken, während die Leiche verschwindet:
  kein Wurf (`/ld diag`: `unit`, danach ggf. `unit-quiet`); eine Sekunde später wirft ein Doppelklick normal aus.
- Köder: Angel ohne Köder, Doppelklick bringt den Köder an, der nächste wirft aus (kein zweiter Köder, auch nicht bei schnellem Klicken).
  Köder einer anderen Sorte kurz vor Ablauf: kein Ersetzen-Dialog, Fenster zeigt "Nächster Klick: auswerfen (neuer Köder, sobald ...)".
- Seltener Fang (z. B. Fischregal, Fischerhütte, Truhe): Chatzeile mit Link und Ton; mit Qualität "Ungewöhnlich" prüfen, ob es zu oft kommt.
- Doppelklick pausiert: aufsitzen, schwimmen oder in den Kampf gehen zeigt unten im Fenster "Doppelklick pausiert: ..." (`mounted`, `swimming`, `combat`),
  danach wieder "Nächster Klick: ...". Doppelklick auf den Schwimmer: Entscheidung `bobber`, kein neuer Wurf.
- `/reload` im Kampf, Kampf beenden, Doppelklick in die Welt: wirft aus (bzw. bringt den Köder an), kein Fehler "Aktion blockiert".
- Camp-Objekt aufstellen: Timer erscheint; die Dauer (Wowhead: eine Stunde) mit der Spielzeit vergleichen und Abweichung melden.
  Auch prüfen, ob Fischglas-Buff (Aura 1230098) und Timer nach dem Aufstellen eines Fischglases erscheinen und ob sich die Objekte ab 20/140/300 herstellen lassen.
- `/ld goal 3` und drei Fische fangen: Fenster zeigt "Ziel: 3/3 Fische" grün, Ton; `/ld goal 5` + Shift-Klick auf einen Fisch: Ziel zählt die Taschen.
  Nach dem Login mit erreichtem Gegenstandsziel kommt kein Ton.
- Charakter ohne Angeln, ohne Angel: kein Fenster, keine Chatzeile beim Login; `/ld` zeigt nur "Angeln noch nicht erlernt. ...",
  Doppel-Rechtsklick in die Welt tut nichts (`/ld diag`: `no-pole`), Zeile "tickers": `window no, lure check no`.
  Mit Angel in der Hand und erlerntem Angeln: `window yes, lure check yes`.
- Angelwettbewerb (Sonntag vor 16 Uhr): unter "Beginnt in" bzw. "Endet in" steht "Zeit laut Spieldaten, für Forever unbestätigt.";
  `/ld diag`, Zeile "derby source": nach `/ld derby sa 20` steht dort "/ld derby", nach `/ld derby reset` wieder die Spieldaten.

## Hinweise
- Bekannter Fehler des Beta-Clients (Pfad `_classic_beta_`): Er lädt gespeicherte Addon-Daten teils nicht. Dann beginnt nach dem Einloggen oder `/reload`
  eine neue Sitzung, Einstellungen, Statistik und Fangbuch erscheinen leer, und die Chatzeile "Bereit. Angel anlegen ..." kommt bei jedem Login,
  bis ein Wurf gespeichert ist. Das ist kein Fehler von Luredon.
- Geheime Werte: Gibt der Client Werte als geheim zurück, vergleicht Luredon sie nie. Ein geheimer Zaubername wird durch die Zauber-ID ersetzt,
  geheime Beutezeilen und Beutelinks werden übersprungen und gezählt, geheime Kartennamen, Ausrüstungssets und Aufspür-Einträge werden übersprungen,
  Taschenzahlen und freie Plätze gelten dann als 0, ein geheimer Realm-Kalender macht den Wettbewerb "unbekannt".
- Bewusst nicht enthalten: ein Lagerfeuer-Timer (keine gesicherten Spell- oder Aura-IDs), die Nennung eines konkreten Angellehrers,
  Skillwerte für Zonen ohne veröffentlichten Wert, automatisches Einholen und Bisserkennung.
- Unbestätigt für Forever: die Zeit des Angelwettbewerbs (Spieldaten des Clients: Sonntag 14 Uhr, 2 Stunden), die Dauer von Fischregal und
  Fischerhütte sowie die Aura des Fischglas-Buffs.
- Fischregal und Fischerhütte starten ihren Timer beim Aufstellen (Spell-IDs 1307247 und 1307246 laut Wowhead Forever), nicht beim Herstellen.

## Lizenz
MIT, siehe `LICENSE.txt`.
