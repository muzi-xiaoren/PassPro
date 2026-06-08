// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get enterMasterKey => 'Hauptschlüssel eingeben';

  @override
  String get masterKeyLabel => 'Hauptschlüssel';

  @override
  String get unlock => 'Entsperren';

  @override
  String get masterKeyHint =>
      'Der Hauptschlüssel wird nie gespeichert; du musst ihn bei jedem Start erneut eingeben.\nLeer lassen, um ein einzelnes Leerzeichen als Schlüssel zu verwenden (kompatibel mit der alten Version).';

  @override
  String get settings => 'Einstellungen';

  @override
  String get lock => 'Sperren';

  @override
  String get tabQuery => 'Suchen';

  @override
  String get tabAdd => 'Hinzufügen';

  @override
  String get tabList => 'Liste';

  @override
  String get syncIdle => 'Nicht synchronisiert';

  @override
  String get syncWorking => 'Synchronisierung…';

  @override
  String get syncOk => 'Synchronisiert';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncError => 'Synchronisierung fehlgeschlagen';

  @override
  String get queryFieldLabel =>
      'Website (Teilübereinstimmung per Stichwort unterstützt)';

  @override
  String get queryInvalidKey =>
      'Falscher Hauptschlüssel: passende Website gefunden, aber Entschlüsseln nicht möglich';

  @override
  String get queryNoMatch => 'Keine passenden Einträge gefunden';

  @override
  String get queryPrompt => 'Website eingeben und mit Enter suchen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get delete => 'Löschen';

  @override
  String get copyUsername => 'Benutzernamen kopieren';

  @override
  String get hide => 'Verbergen';

  @override
  String get show => 'Anzeigen';

  @override
  String get copyPassword => 'Passwort kopieren';

  @override
  String get usernameCopied => 'Benutzername kopiert';

  @override
  String get passwordCopied => 'Passwort kopiert';

  @override
  String get confirmDelete => 'Löschen bestätigen';

  @override
  String deleteBody(String website) {
    return 'Diesen Eintrag für $website löschen?';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get generatePassword => 'Passwort generieren';

  @override
  String get length => 'Länge';

  @override
  String get generate => 'Generieren';

  @override
  String get charUpper => 'Großbuchstaben';

  @override
  String get charLower => 'Kleinbuchstaben';

  @override
  String get charDigits => 'Ziffern';

  @override
  String get charSpecial => 'Sonderzeichen';

  @override
  String get saveToVault => 'Im Tresor speichern';

  @override
  String get websiteRequired => 'Website *';

  @override
  String get usernameOptional => 'Benutzername (optional)';

  @override
  String get passwordRequired => 'Passwort *';

  @override
  String get save => 'Speichern';

  @override
  String get websitePasswordEmpty =>
      'Website und Passwort dürfen nicht leer sein';

  @override
  String get saved => 'Gespeichert';

  @override
  String get duplicateEntry => 'Ein identischer Eintrag existiert bereits';

  @override
  String get emptyVault =>
      'Der Tresor ist leer. Füge unter „Hinzufügen“ deinen ersten Eintrag hinzu.';

  @override
  String totalCount(int count) {
    return '$count insgesamt';
  }

  @override
  String get sortNameAsc => 'Name A→Z';

  @override
  String get sortNameDesc => 'Name Z→A';

  @override
  String get sortTimeDesc => 'Hinzugefügt (neueste zuerst)';

  @override
  String get sortTimeAsc => 'Hinzugefügt (älteste zuerst)';

  @override
  String get sortTooltip => 'Sortieren';

  @override
  String get decryptFailedCopy =>
      'Mit dem aktuellen Hauptschlüssel nicht entschlüsselbar; Kopieren fehlgeschlagen';

  @override
  String get noUsername => '(kein Benutzername)';

  @override
  String get cannotDecrypt => 'Entschlüsseln nicht möglich';

  @override
  String get cannotDecryptBody =>
      'Dieser Eintrag kann mit dem aktuellen Hauptschlüssel nicht entschlüsselt werden.\nTippe oben links auf Zurück und gib den richtigen Hauptschlüssel erneut ein.';

  @override
  String get website => 'Website';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get updated => 'Aktualisiert';

  @override
  String get sectionLanguage => 'Sprache';

  @override
  String get language => 'Sprache';

  @override
  String get followSystem => 'System folgen';

  @override
  String get sectionCloudSync => 'Cloud-Synchronisierung';

  @override
  String get enableCloudSync => 'Cloud-Synchronisierung aktivieren';

  @override
  String get enableCloudSyncSub =>
      'Wenn aus, bleiben alle Daten nur auf diesem Gerät';

  @override
  String get sectionSyncPrompt => 'Synchronisierungs-Hinweise';

  @override
  String get promptBeforePull => 'Vor Änderungen zum Pull auffordern';

  @override
  String get promptBeforePullSub =>
      'Vor Hinzufügen / Bearbeiten / Löschen einen Hinweis „vom Remote pullen“ anzeigen';

  @override
  String get promptAfterPush => 'Nach Änderungen zum Push auffordern';

  @override
  String get smartSkip => 'Intelligentes Überspringen';

  @override
  String get smartSkipSub =>
      'Den „Pull“-Hinweis automatisch überspringen, wenn der Remote keine Updates hat';

  @override
  String get sectionMaintenance => 'Wartung';

  @override
  String get compactNow => 'Protokoll jetzt verdichten';

  @override
  String get sectionAbout => 'Über';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String compactDone(int count, String size) {
    return 'Verdichtet: $count aktive Einträge, $size gespart';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return 'Aktuell $active aktiv / $total Zeilen (Verstärkung $amp×)';
  }

  @override
  String get backendDisabled => 'Nicht aktiviert';

  @override
  String get enable => 'Aktivieren';

  @override
  String get roleLabel => 'Rolle:';

  @override
  String get repoName => 'Repository-Name';

  @override
  String get branch => 'Branch';

  @override
  String get filePath => 'Dateipfad';

  @override
  String get patHelper =>
      'Im Schlüsselbund des Betriebssystems gespeichert; wird nie in eine Datei geschrieben';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return 'Alle Backends konnten nicht abrufen: $detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return 'Von $backend abgerufen';
  }

  @override
  String get syncNoPrimary => 'Kein nutzbares Primär-Backend konfiguriert';

  @override
  String syncPrimaryOffline(String detail) {
    return 'Primär offline: $detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return 'Primär-Push fehlgeschlagen: $detail';
  }

  @override
  String get syncPushConflictManual =>
      'Push-Konflikt; automatische Zusammenführung fehlgeschlagen – bitte manuell synchronisieren';

  @override
  String get syncPushedPrimary => 'Zum Primär gepusht';

  @override
  String get syncRemoteEmptySkipped =>
      'Remote ist leer; Überschreiben übersprungen (um lokale Daten nicht zu löschen)';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return 'Lokal von $backend überschrieben';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return 'Primär-Überschreiben fehlgeschlagen: $detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging =>
      'Überschreiben fehlgeschlagen: Remote ändert sich ständig, bitte erneut versuchen';

  @override
  String get syncOverwroteRemoteWithLocal => 'Remote mit lokal überschrieben';

  @override
  String syncGenericError(String detail) {
    return 'Fehler: $detail';
  }

  @override
  String get syncMirrorsLabel => 'Spiegel';

  @override
  String get syncMirrorOk => 'ok';

  @override
  String get syncMirrorConflict => 'Konflikt';

  @override
  String get syncMirrorFailed => 'fehlgeschlagen';

  @override
  String syncPrimaryResult(String backend, String outcome) {
    return 'Primär $backend ($outcome)';
  }

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return 'Repository nicht gefunden oder Token hat keinen Zugriff: $repo';
  }

  @override
  String get webdavFolderMissing =>
      'Zielordner existiert nicht. Erstellen Sie ihn zuerst in Ihrem WebDAV-/Nutstore-Konto und passen Sie den Remote-Dateipfad an (z. B. /PassPro/passwords.log).';

  @override
  String get owner => 'Eigentümer';

  @override
  String get personalAccessToken => 'Persönliches Zugriffstoken';

  @override
  String get webdavAccount => 'Konto';

  @override
  String get webdavServer => 'Serveradresse';

  @override
  String get webdavRemotePath => 'Remote-Dateipfad';

  @override
  String get webdavAppPassword => 'App-Passwort';

  @override
  String get webdavAppPasswordHelper =>
      'Nutstore: App-Passwort aus der Drittanbieter-App-Verwaltung eingeben';

  @override
  String get rolePrimary => 'Primär';

  @override
  String get roleMirror => 'Spiegel';

  @override
  String get testOkNoFile =>
      'Verbunden (die Remote-Datei existiert noch nicht; der erste Push erstellt sie)';

  @override
  String testOkSha(String sha) {
    return 'Verbunden (aktueller sha=$sha…)';
  }

  @override
  String testFailHttp(String code, String message) {
    return 'Fehlgeschlagen: HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get pullTitle => 'Zuerst vom Remote pullen?';

  @override
  String get pullMessage =>
      'Der Remote könnte Updates haben. Vor dem Fortfahren pullen?';

  @override
  String get pull => 'Pull';

  @override
  String get skip => 'Überspringen';

  @override
  String get pushTitle => 'Lokal gespeichert';

  @override
  String get pushMessage => 'Zum Remote pushen?';

  @override
  String get push => 'Push';

  @override
  String get later => 'Später';

  @override
  String get dontPromptThisSession => 'In dieser Sitzung nicht mehr fragen';

  @override
  String get syncMenu => 'Synchronisieren';

  @override
  String get syncPull => 'Pullen und zusammenführen';

  @override
  String get syncPush => 'Aktuelle Daten pushen';

  @override
  String get syncOverwriteLocal => 'Lokal mit Cloud überschreiben';

  @override
  String get syncOverwriteRemote => 'Cloud mit Lokal überschreiben';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return 'Dies überschreibt die lokalen Daten mit $file aus der Cloud. Nicht gepushte lokale Änderungen gehen verloren. Fortfahren?';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return 'Dies überschreibt $file in der Cloud mit deinen lokalen Daten. Der aktuelle Cloud-Inhalt wird ersetzt. Fortfahren?';
  }

  @override
  String get continueLabel => 'Fortfahren';

  @override
  String get overwroteLocal => 'Lokale Daten mit Cloud überschrieben';

  @override
  String get overwroteRemote => 'Cloud mit lokalen Daten überschrieben';

  @override
  String get accountMenu => 'Konto';

  @override
  String get changeMasterKey => 'Hauptschlüssel ändern';

  @override
  String get newMasterKey => 'Neuer Hauptschlüssel';

  @override
  String get confirmNewMasterKey => 'Neuen Hauptschlüssel bestätigen';

  @override
  String get masterKeyMismatch =>
      'Die beiden Hauptschlüssel stimmen nicht überein';

  @override
  String get masterKeyChanged => 'Hauptschlüssel geändert';

  @override
  String get changeMasterKeyHint =>
      'Wechselt den in der aktuellen Sitzung verwendeten Hauptschlüssel. Betrifft nur die Ver-/Entschlüsselung ab jetzt und ändert bestehende Einträge nicht.';
}
