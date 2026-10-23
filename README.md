# Fayma

Gestion du crédit pour les boutiques de quartier, pensée pour fonctionner hors
connexion (montants en FCFA, interface en français).

## Développement

```bash
flutter pub get
flutter run
flutter test
```

L'application cible Android (API 24 minimum) et iOS (15 minimum). La base
SQLite est stockée dans le dossier privé de l'application (`fayma.db`).

## Version iOS

La compilation iOS se fait obligatoirement sur macOS avec Xcode. Le projet
utilise Swift Package Manager : aucun `pod install` n'est nécessaire.

1. Ouvrir le projet dans Xcode et choisir l'équipe de signature :

   ```bash
   open ios/Runner.xcworkspace
   ```

   Dans la cible **Runner** → **Signing & Capabilities**, sélectionner une
   équipe, puis remplacer `com.example.fayma` par l'identifiant définitif de
   la boutique avant toute publication.

2. Lancer l'application sur un iPhone simulé ou réel :

   ```bash
   flutter run -d iphone
   ```

3. Construire l'IPA signé pour TestFlight ou l'App Store :

   ```bash
   tool/build_ipa.sh
   ```

   Le fichier est écrit dans `build/ios/ipa/`. Pour un simple contrôle de
   compilation sans signature : `flutter build ios --release --no-codesign`.

Spécificités iOS :

- l'import d'un contact demande l'autorisation **Contacts** (la description
  est dans `ios/Runner/Info.plist`) ;
- l'envoi d'un SMS ouvre l'application Messages avec le message pré-rempli ;
  le commerçant appuie ensuite sur « Envoyer » ;
- les factures, rapports et sauvegardes passent par la feuille de partage iOS
  (Fichiers, Mail, WhatsApp, impression, etc.) ;
- le code de récupération est conservé dans le trousseau iOS ;
- l'icône est générée depuis `assets/icon/fayma_icon_ios.png`, sans canal
  alpha, comme l'exige l'App Store.

Lors du premier envoi à App Store Connect, Apple pose une question sur le
chiffrement : Fayma chiffre uniquement ses sauvegardes locales (Argon2id +
AES-GCM) et n'utilise aucun serveur. Vérifiez la déclaration d'exportation
applicable avant de valider l'envoi.

## Créer un APK release léger

L'APK par défaut embarque les trois architectures (arm64-v8a, armeabi-v7a,
x86_64) et pèse environ 64 Mo. Pour obtenir un fichier par architecture
(~22 Mo pour les téléphones récents) :

```bash
tool/build_apk.sh
```

Le script produit des APK obfusqués dans `build/app/outputs/flutter-apk/` :

- `app-arm64-v8a-release.apk` : téléphones récents, à distribuer en priorité ;
- `app-armeabi-v7a-release.apk` : téléphones plus anciens ;
- `app-x86_64-release.apk` : émulateurs uniquement.

Les symboles de crash sont écrits dans `build/symbols/` : les conserver pour
pouvoir décoder les stack traces. Pour le Play Store, préférer
`flutter build appbundle --release`, qui ne livre à chaque appareil que
l'architecture nécessaire.

## Factures et rapport PDF

Les documents sont générés hors connexion, directement dans l'application.

- Sur la fiche d'un client, l'icône PDF de chaque opération crée une **facture
  d'achat à crédit** ou un **reçu de dépôt / remboursement**, puis ouvre la
  feuille de partage du téléphone (WhatsApp, e-mail, impression, etc.).
- Depuis l'accueil, **Rapport général PDF** produit un document complet :
  synthèse de la boutique, situation de chaque client et journal des
  opérations. Les opérations annulées restent visibles pour l'historique.

## Rappel de crédit par SMS

Sur la fiche d'un client endetté, le bouton **Envoyer un rappel** (ou la
cloche sur sa carte à l'accueil) ouvre l'application SMS avec un message
prérempli indiquant le reste à payer et la date de la dette la plus ancienne.
Le commerçant garde la main sur l'envoi : rien ne part sans son accord, et le
rappel n'apparaît pas dans l'historique des opérations.

## Plafond de crédit et SMS

- Le **plafond de crédit** est commun à tous les clients. Il se règle dans
  **Ma boutique**, ouverte par l'icône réglages de l'accueil. Laissez le champ
  vide pour ne pas limiter les achats à crédit.
- La fiche d'un client rappelle le plafond en vigueur ; touchez la ligne
  « Plafond de crédit » pour ouvrir **Ma boutique** et le modifier.
- Le nom saisi dans **Ma boutique** apparaît en signature des SMS envoyés
  après chaque achat, remboursement ou dépôt.

## Sauvegarde chiffrée

Depuis l'écran d'accueil, le bouton en haut à droite ouvre **Sauvegarde**.

- Au premier affichage, l'application génère un **code de récupération** de
  24 caractères (120 bits). Il est stocké de façon chiffrée, avec une clé
  protégée par le Keystore Android ou le trousseau iOS, et doit être noté par
  le commerçant.
- **Exporter une sauvegarde** crée un fichier `.fayma` chiffré avec
  Argon2id + AES-256-GCM, puis ouvre la feuille de partage du téléphone. Le
  fichier peut être envoyé vers Google Drive, Files, un e-mail, etc.
- **Restaurer une sauvegarde** demande le code de récupération, vérifie le
  fichier, puis remplace toutes les données dans une transaction SQLite. En
  cas d'erreur, les données existantes restent intactes.
- Sans le code de récupération, une sauvegarde est définitivement illisible :
  il n'existe aucun serveur ni clé de secours chez Fayma.

La sauvegarde automatique Android est désactivée (`android:allowBackup="false"`)
pour éviter des copies non maîtrisées et des erreurs de Keystore. Seuls les
exports chiffrés explicites servent à restaurer l'application après une
désinstallation ou sur un nouveau téléphone. Sur iOS, les données restent
incluses dans la sauvegarde iCloud de l'iPhone si l'utilisateur l'a activée ;
l'export `.fayma` reste la seule sauvegarde portable vers un autre appareil.

## Google Drive automatique (à venir)

La sauvegarde manuelle peut déjà être envoyée vers Google Drive via le partage
Android. La synchronisation automatique nécessitera encore :

1. un `applicationId` définitif (actuellement `com.example.fayma`, un
   placeholder de développement) ;
2. un projet Google Cloud avec l'API Drive activée et un écran de consentement
   OAuth ;
3. un client OAuth Android avec les empreintes SHA-1 de debug et de release ;
4. l'implémentation du fournisseur Drive dans un dossier visible
   **Sauvegardes Fayma** (scope `drive.file`), de la planification et de la
   politique de rétention.

Le dossier masqué `appDataFolder` n'est pas retenu : Google le supprime quand
l'application est désinstallée, ce qui empêcherait justement de restaurer les
données après une désinstallation. Un dossier visible créé par l'application
avec le scope `drive.file` reste dans le Drive de l'utilisateur et survit à la
désinstallation.

Changer l'`applicationId` après la création du client OAuth invalide ce client :
il faut le choisir avant l'étape Google Cloud. Comme Android considère un
nouvel `applicationId` comme une autre application, exporter d'abord les
données déjà saisies dans la version de développement si nécessaire.
