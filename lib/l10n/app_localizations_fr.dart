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
      'La clé maître n\'est jamais enregistrée ; vous devez la ressaisir à chaque lancement.\nLaissez le champ vide pour utiliser une espace simple comme clé (compatible avec l\'ancienne version).';

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
      'Version 0.2.0 · Compatible Fernet avec les anciens fichiers chiffrés';

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
}
