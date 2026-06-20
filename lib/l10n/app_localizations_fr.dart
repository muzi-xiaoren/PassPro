// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get enterMasterKey => 'Saisissez la clé maître';

  @override
  String get masterKeyLabel => 'Clé maître';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get masterKeyHint =>
      'La clé maître n\'est jamais enregistrée ; vous devez la ressaisir à chaque lancement.\nLaissez le champ vide pour utiliser une espace simple comme clé.';

  @override
  String get checkUpdate => 'Rechercher des mises à jour';

  @override
  String get checkingUpdate => 'Recherche de mises à jour…';

  @override
  String updateUpToDate(String version) {
    return 'Vous avez la dernière version ($version)';
  }

  @override
  String updateAvailable(String version) {
    return 'Nouvelle version $version disponible — appuyez pour télécharger';
  }

  @override
  String get updateCheckFailed => 'Échec de la recherche de mise à jour';

  @override
  String get websiteCopied => 'Site copié';

  @override
  String get sectionBackup => 'Sauvegarde locale';

  @override
  String get exportBackup => 'Exporter la sauvegarde chiffrée (.log)';

  @override
  String get exportBackupSub =>
      'Les mots de passe restent chiffrés ; réimportez-les sur un autre appareil avec la même clé maître';

  @override
  String get importBackup => 'Importer une sauvegarde chiffrée (.log)';

  @override
  String get importBackupSub =>
      'Fusionnée dans le coffre actuel par enregistrement — rien n\'est perdu';

  @override
  String get exportCsvTitle => 'Exporter en CSV (texte clair)';

  @override
  String get exportCsvSub =>
      'Site / identifiant / mot de passe en clair — risque de fuite';

  @override
  String get importCsvTitle => 'Importer depuis un CSV';

  @override
  String get importCsvSub => 'Lit les colonnes site, identifiant, mot de passe';

  @override
  String get exportCsvWarnTitle => 'Exporter les mots de passe en clair ?';

  @override
  String get exportCsvWarnBody =>
      'Les mots de passe du fichier CSV sont en clair et lisibles par tous. Continuer ?';

  @override
  String exportDone(int count) {
    return '$count enregistrements exportés';
  }

  @override
  String exportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String importDone(int added, int total) {
    return 'Import terminé : $added ajoutés, $total au total';
  }

  @override
  String importFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String get nothingToExport => 'Aucun enregistrement à exporter';

  @override
  String get sectionSearch => 'Règle de recherche';

  @override
  String get searchExact => 'Exacte';

  @override
  String get searchContains => 'Inclusion';

  @override
  String get searchFuzzy => 'Approximative';

  @override
  String get searchCustom => 'Personnalisée';

  @override
  String get searchExactDesc =>
      'Découpe par « . » ; si un site correspond exactement, n\'afficher que lui';

  @override
  String get searchContainsDesc =>
      'Découpe par « . » ; afficher toutes les entrées liées, classées par pertinence';

  @override
  String get searchFuzzyDesc =>
      'Afficher tout site contenant la chaîne recherchée';

  @override
  String get searchCustomDesc =>
      'Découper avec un séparateur défini, puis rechercher';

  @override
  String get searchDelimiterLabel => 'Séparateur';

  @override
  String get searchMatchTypeLabel => 'Type de correspondance';

  @override
  String get settings => 'Paramètres';

  @override
  String get lock => 'Verrouiller';

  @override
  String get tabQuery => 'Rechercher';

  @override
  String get tabAdd => 'Ajouter';

  @override
  String get tabList => 'Liste';

  @override
  String get syncIdle => 'Non synchronisé';

  @override
  String get syncWorking => 'Synchronisation…';

  @override
  String get syncOk => 'Synchronisé';

  @override
  String get syncOffline => 'Hors ligne';

  @override
  String get syncError => 'Échec de la synchronisation';

  @override
  String get queryFieldLabel =>
      'Site (correspondance partielle par mot-clé prise en charge)';

  @override
  String get queryInvalidKey =>
      'Clé maître incorrecte : site correspondant trouvé mais déchiffrement impossible';

  @override
  String get queryNoMatch => 'Aucun enregistrement correspondant trouvé';

  @override
  String get queryPrompt =>
      'Saisissez un site et appuyez sur Entrée pour rechercher';

  @override
  String get edit => 'Modifier';

  @override
  String get delete => 'Supprimer';

  @override
  String get copyUsername => 'Copier le nom d\'utilisateur';

  @override
  String get hide => 'Masquer';

  @override
  String get show => 'Afficher';

  @override
  String get copyPassword => 'Copier le mot de passe';

  @override
  String get usernameCopied => 'Nom d\'utilisateur copié';

  @override
  String get passwordCopied => 'Mot de passe copié';

  @override
  String get confirmDelete => 'Confirmer la suppression';

  @override
  String deleteBody(String website) {
    return 'Supprimer cet enregistrement pour $website ?';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get deleted => 'Supprimé';

  @override
  String get generatePassword => 'Générer un mot de passe';

  @override
  String get length => 'Longueur';

  @override
  String get generate => 'Générer';

  @override
  String get charUpper => 'Majuscules';

  @override
  String get charLower => 'Minuscules';

  @override
  String get charDigits => 'Chiffres';

  @override
  String get charSpecial => 'Spéciaux';

  @override
  String get saveToVault => 'Enregistrer dans le coffre';

  @override
  String get websiteRequired => 'Site *';

  @override
  String get usernameOptional => 'Nom d\'utilisateur (facultatif)';

  @override
  String get passwordRequired => 'Mot de passe *';

  @override
  String get save => 'Enregistrer';

  @override
  String get websitePasswordEmpty =>
      'Le site et le mot de passe ne peuvent pas être vides';

  @override
  String get saved => 'Enregistré';

  @override
  String get duplicateEntry => 'Une entrée identique existe déjà';

  @override
  String get emptyVault =>
      'Le coffre est vide. Ajoutez votre première entrée dans « Ajouter ».';

  @override
  String totalCount(int count) {
    return '$count au total';
  }

  @override
  String get sortNameAsc => 'Nom A→Z';

  @override
  String get sortNameDesc => 'Nom Z→A';

  @override
  String get sortTimeDesc => 'Date d\'ajout (du plus récent)';

  @override
  String get sortTimeAsc => 'Date d\'ajout (du plus ancien)';

  @override
  String get sortTooltip => 'Trier';

  @override
  String get decryptFailedCopy =>
      'Impossible de déchiffrer avec la clé maître actuelle ; échec de la copie';

  @override
  String get noUsername => '(aucun nom d\'utilisateur)';

  @override
  String get cannotDecrypt => 'Déchiffrement impossible';

  @override
  String get cannotDecryptBody =>
      'Cet enregistrement ne peut pas être déchiffré avec la clé maître actuelle.\nAppuyez sur Retour en haut à gauche et ressaisissez la bonne clé maître.';

  @override
  String get website => 'Site';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get updated => 'Mis à jour';

  @override
  String get sectionLanguage => 'Langue';

  @override
  String get language => 'Langue';

  @override
  String get followSystem => 'Suivre le système';

  @override
  String get sectionCloudSync => 'Synchronisation cloud';

  @override
  String get enableCloudSync => 'Activer la synchronisation cloud';

  @override
  String get enableCloudSyncSub =>
      'Si désactivée, toutes les données restent uniquement sur cet appareil';

  @override
  String get sectionSyncPrompt => 'Invites de synchronisation';

  @override
  String get promptBeforePull => 'Proposer de tirer avant les modifications';

  @override
  String get promptBeforePullSub =>
      'Afficher une invite « tirer depuis le distant » avant ajout / modification / suppression';

  @override
  String get promptAfterPush => 'Proposer de pousser après les modifications';

  @override
  String get smartSkip => 'Saut intelligent';

  @override
  String get smartSkipSub =>
      'Ignorer automatiquement l\'invite « tirer » lorsque le distant n\'a aucune mise à jour';

  @override
  String get sectionMaintenance => 'Maintenance';

  @override
  String get compactNow => 'Compacter le journal maintenant';

  @override
  String get sectionAbout => 'À propos';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutAuthorLabel => 'Auteur';

  @override
  String get aboutRepoLabel => 'Dépôt';

  @override
  String compactDone(int count, String size) {
    return 'Compacté : $count enregistrements actifs, $size économisés';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return 'Actuellement $active actifs / $total lignes (amplification $amp×)';
  }

  @override
  String get backendDisabled => 'Non activé';

  @override
  String get enable => 'Activer';

  @override
  String get roleLabel => 'Rôle :';

  @override
  String get repoName => 'Nom du dépôt';

  @override
  String get branch => 'Branche';

  @override
  String get filePath => 'Chemin du fichier';

  @override
  String get patHelper =>
      'Stocké dans le trousseau du système ; jamais écrit dans un fichier';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return 'Échec de la récupération sur tous les backends : $detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return 'Récupéré depuis $backend';
  }

  @override
  String get syncNoPrimary => 'Aucun backend principal utilisable configuré';

  @override
  String syncPrimaryOffline(String detail) {
    return 'Principal hors ligne : $detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return 'Échec de l\'envoi vers le principal : $detail';
  }

  @override
  String get syncPushConflictManual =>
      'Conflit d\'envoi ; la fusion automatique a échoué — synchronisez manuellement';

  @override
  String get syncPushedPrimary => 'Envoyé vers le principal';

  @override
  String get syncRemoteEmptySkipped =>
      'Le distant est vide ; écrasement ignoré (pour ne pas effacer le local)';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return 'Local écrasé depuis $backend';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return 'Échec de l\'écrasement du principal : $detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging =>
      'Échec de l\'écrasement : le distant change sans cesse, réessayez';

  @override
  String get syncOverwroteRemoteWithLocal => 'Distant écrasé avec le local';

  @override
  String syncGenericError(String detail) {
    return 'Erreur : $detail';
  }

  @override
  String get syncMirrorsLabel => 'Miroirs';

  @override
  String get syncMirrorOk => 'ok';

  @override
  String get syncMirrorConflict => 'conflit';

  @override
  String get syncMirrorFailed => 'échec';

  @override
  String syncPrimaryResult(String backend, String outcome) {
    return 'Principal $backend ($outcome)';
  }

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return 'Dépôt introuvable ou le jeton n\'a pas accès : $repo';
  }

  @override
  String get webdavFolderMissing =>
      'Le dossier cible n\'existe pas. Créez-le d\'abord dans votre compte WebDAV/Nutstore et faites correspondre le chemin du fichier distant (par ex. /PassPro/passwords.log).';

  @override
  String get owner => 'Propriétaire';

  @override
  String get personalAccessToken => 'Jeton d\'accès personnel';

  @override
  String get webdavAccount => 'Compte';

  @override
  String get webdavServer => 'Adresse du serveur';

  @override
  String get webdavRemotePath => 'Chemin du fichier distant';

  @override
  String get webdavAppPassword => 'Mot de passe d\'application';

  @override
  String get webdavAppPasswordHelper =>
      'Nutstore : saisissez le mot de passe d\'application généré dans la gestion des applications tierces';

  @override
  String get rolePrimary => 'Principal';

  @override
  String get roleMirror => 'Miroir';

  @override
  String get testOkNoFile =>
      'Connexion réussie (le fichier distant n\'existe pas encore ; le premier envoi le créera)';

  @override
  String testOkSha(String sha) {
    return 'Connexion réussie (sha actuel=$sha…)';
  }

  @override
  String testFailHttp(String code, String message) {
    return 'Échec : HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return 'Échec : $error';
  }

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get pullTitle => 'Tirer d\'abord depuis le distant ?';

  @override
  String get pullMessage =>
      'Le distant peut contenir des mises à jour. Tirer avant de continuer ?';

  @override
  String get pull => 'Tirer';

  @override
  String get skip => 'Ignorer';

  @override
  String get pushTitle => 'Enregistré localement';

  @override
  String get pushMessage => 'Pousser vers le distant ?';

  @override
  String get push => 'Pousser';

  @override
  String get later => 'Plus tard';

  @override
  String get dontPromptThisSession => 'Ne plus demander pendant cette session';

  @override
  String get syncMenu => 'Synchroniser';

  @override
  String get syncPull => 'Tirer et fusionner';

  @override
  String get syncPush => 'Pousser les données actuelles';

  @override
  String get syncOverwriteLocal => 'Écraser le local avec le cloud';

  @override
  String get syncOverwriteRemote => 'Écraser le cloud avec le local';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return 'Cela écrasera les données locales avec $file du cloud. Les modifications locales non poussées seront perdues. Continuer ?';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return 'Cela écrasera $file dans le cloud avec vos données locales. Le contenu actuel du cloud sera remplacé. Continuer ?';
  }

  @override
  String get continueLabel => 'Continuer';

  @override
  String get overwroteLocal => 'Données locales écrasées par le cloud';

  @override
  String get overwroteRemote => 'Cloud écrasé par les données locales';

  @override
  String get accountMenu => 'Compte';

  @override
  String get changeMasterKey => 'Changer la clé maître';

  @override
  String get newMasterKey => 'Nouvelle clé maître';

  @override
  String get confirmNewMasterKey => 'Confirmer la nouvelle clé maître';

  @override
  String get masterKeyMismatch => 'Les deux clés maîtres ne correspondent pas';

  @override
  String get masterKeyChanged => 'Clé maître modifiée';

  @override
  String get changeMasterKeyHint =>
      'Change la clé maître utilisée par la session actuelle. N\'affecte que le chiffrement/déchiffrement à partir de maintenant et ne modifie pas les entrées existantes.';
}
