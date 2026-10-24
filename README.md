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
   équipe. Le bundle identifier est déjà `com.fayma.app` ; s'il est changé, il
   doit l'être aussi dans le client OAuth iOS avant toute publication.

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

### Signature de release Android

Les APK release sont signés avec le keystore
`android/app/upload-keystore.jks`. L'alias et les mots de passe sont dans
`android/key.properties`. Ces deux fichiers sont ignorés par Git et doivent
être **sauvegardés ensemble, hors du dépôt** : sans eux, il devient impossible
de signer une mise à jour avec la même clé, et le client OAuth Android devra
être recréé.

L'application utilise l'identifiant `com.fayma.app` sur Android et iOS. Il peut
encore être changé avant la première publication, mais il doit alors être
modifié partout (Android, iOS, clients OAuth) avant de générer les APK.

L'ancienne version de développement utilisait `com.example.fayma` : Android la
considère comme une application différente. Pour récupérer ses données,
exportez une sauvegarde `.fayma` depuis l'ancienne version, puis restaurez-la
dans la nouvelle avec son code de récupération. Les deux versions peuvent
coexister pendant la migration.

Pour afficher les empreintes SHA-1 des clés release et debug au format attendu
par Google Cloud :

```bash
tool/android_sha1.sh
```

La clé release actuelle a l'empreinte :

```text
BE:8F:B9:C0:6C:75:32:F3:61:4B:07:4F:87:90:16:B0:4D:88:D9:C0
```

Pour distribuer sur le Play Store, conservez aussi le keystore chez un
prestataire sûr ou dans un gestionnaire de secrets. Ne le versionnez jamais.

Si vous activez **Play App Signing**, Google re-signe l'application avec sa
propre clé. Ajoutez alors également le SHA-1 de la clé de signature Google
(Play Console → **Intégrité de l'application**) dans un client OAuth Android,
sinon la connexion Drive échouera sur les versions installées depuis le Play
Store.

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

## Moyens de paiement

Chaque **dépôt** et chaque **remboursement** indique le moyen utilisé par le
client :

- **Espèces** — billets et pièces remis à la boutique ;
- **Orange Money** — paiement reçu sur le compte Orange Money de la boutique ;
- **Wave** — paiement reçu sur le compte Wave de la boutique.

Le sélecteur apparaît dans les écrans **Nouveau dépôt** et **Remboursement**,
avec les logos Orange Money et Wave embarqués dans l'application (aucune
connexion nécessaire). **Espèces** est sélectionné par défaut ; touchez une
tuile pour changer de moyen avant d'enregistrer.

Le moyen choisi est ensuite visible :

- dans l'historique de la fiche client, à côté de la date, avec le logo
  correspondant ;
- sur les reçus PDF de dépôt et de remboursement ;
- dans le journal du **Rapport général PDF**.

Un achat à crédit n'a pas de moyen de paiement. Les opérations enregistrées
avant cette version restent affichées normalement, simplement sans moyen
précisé. La base SQLite passe automatiquement en version 2 au premier
lancement : aucune action n'est demandée et aucune donnée n'est perdue.

## Sauvegarde chiffrée

Depuis l'écran d'accueil, le bouton en haut à droite ouvre **Sauvegarde**.

- Au premier affichage, l'application génère un **code de récupération** de
  24 caractères (120 bits). Il est stocké de façon chiffrée, avec une clé
  protégée par le Keystore Android ou le trousseau iOS, et doit être noté par
  le commerçant.
- **Exporter une sauvegarde** crée un fichier `.fayma` chiffré avec
  Argon2id + AES-256-GCM, puis ouvre la feuille de partage du téléphone. Le
  fichier peut être envoyé vers Files, un e-mail, etc.
- La sauvegarde contient **toutes les données de la boutique** : clients,
  opérations (avec leur moyen de paiement) et **nom de la boutique**. Ce nom
  est restauré en même temps que les données ; s'il est vide dans une ancienne
  sauvegarde, le nom déjà saisi sur le téléphone est conservé.
- **Sauvegarde Google Drive** envoie automatiquement le même fichier chiffré
  une fois par 24 h, et permet de restaurer une sauvegarde déjà présente dans
  le Drive du commerçant.
- **Restaurer une sauvegarde** importée depuis un fichier demande le code de
  récupération, vérifie le fichier, puis remplace toutes les données dans une
  transaction SQLite. Depuis Drive, le code enregistré sur le téléphone est
  utilisé automatiquement. En cas d'erreur, les données existantes restent
  intactes.
- Sans le code de récupération, une sauvegarde est définitivement illisible :
  il n'existe aucun serveur ni clé de secours chez Fayma.
- Les sauvegardes créées par une version antérieure restent restaurables : le
  nom de boutique et le moyen de paiement, absents du fichier, sont simplement
  laissés vides. Le format de données reste en version 1 pour préserver cette
  compatibilité.

La sauvegarde automatique Android est désactivée (`android:allowBackup="false"`)
pour éviter des copies non maîtrisées et des erreurs de Keystore. Seuls les
exports chiffrés explicites servent à restaurer l'application après une
désinstallation ou sur un nouveau téléphone. Sur iOS, les données restent
incluses dans la sauvegarde iCloud de l'iPhone si l'utilisateur l'a activée ;
l'export `.fayma` reste la seule sauvegarde portable vers un autre appareil.

## Sauvegarde Google Drive

L'écran **Sauvegarde** propose, en plus de l'export manuel :

- une **sauvegarde automatique** une fois par 24 h, déclenchée à l'ouverture de
  l'application ou au retour au premier plan, si le réseau est disponible ;
- un bouton **Sauvegarder maintenant** ;
- une **restauration depuis Drive**, avec la liste des sauvegardes du dossier.

Fonctionnement :

- le fichier est chiffré sur le téléphone (Argon2id + AES-256-GCM) **avant**
  l'envoi : Google Drive ne stocke que des octets chiffrés ;
- les fichiers vont dans un dossier visible **Sauvegardes Fayma**, à la racine
  du Drive du commerçant ;
- le scope `drive.file` est utilisé : Fayma ne voit que les fichiers qu'elle a
  créés, jamais le reste du Drive ;
- les **10 dernières sauvegardes de chaque appareil** sont conservées ; les
  plus anciennes sont supprimées automatiquement. Les sauvegardes d'un ancien
  téléphone ne sont pas touchées ;
- le **code de récupération** reste indispensable pour restaurer un fichier ;
  il n'est jamais envoyé sur Drive ;
- sur le même téléphone, la restauration Drive utilise **automatiquement le
  code enregistré** dans le trousseau sécurisé : aucune saisie n'est demandée.
  Le code n'est réclamé que s'il ne correspond pas à la sauvegarde choisie
  (réinstallation, nouveau téléphone) ou pour l'import manuel d'un fichier ;
- la déconnexion de Google Drive désactive la sauvegarde automatique et
  supprime la session locale, sans effacer les fichiers déjà envoyés.

Le dossier masqué `appDataFolder` n'est pas utilisé : Google le supprime quand
l'application est désinstallée, ce qui empêcherait de restaurer les données
après une réinstallation. Un dossier visible créé avec le scope `drive.file`
reste dans le Drive de l'utilisateur et survit à la désinstallation.

### Coût

L'API Google Drive est gratuite dans les quotas d'usage courants. Pour quelques
sauvegardes par jour, aucun frais n'est à prévoir : seuls les quelques Ko de
chaque fichier sont déduits des 15 Go gratuits du compte Google du commerçant.
La création du projet Google Cloud et du client OAuth est également gratuite.

### Créer les identifiants Google (une seule fois)

1. **Vérifier l'identifiant de l'application.** Le projet utilise
   `com.fayma.app` sur Android et iOS. Si vous le changez, faites-le
   **avant** de créer le client OAuth :
   - Android : `namespace` et `applicationId` dans
     `android/app/build.gradle.kts`, puis déplacez `MainActivity.kt` dans le
     package correspondant ;
   - iOS : *Bundle Identifier* de la cible **Runner** dans Xcode.

   Changer l'`applicationId` après la création du client OAuth invalide ce
   client : Android considère le nouvel identifiant comme une autre
   application. Exportez les données de développement avant de changer.

2. Dans la [console Google Cloud](https://console.cloud.google.com/), créez un
   projet, puis activez **Google Drive API** dans *API et services*.

3. Configurez l'**écran de consentement OAuth** :
   - type *Externe* (ou *Interne* pour un compte Google Workspace) ;
   - nom de l'application **Fayma**, e-mail d'assistance et e-mail du
     développeur ;
   - ajoutez le scope
     `https://www.googleapis.com/auth/drive.file` ;
   - en mode *Test*, ajoutez le compte Google du commerçant dans **Utilisateurs
     test**, sinon la connexion sera refusée ;
   - publiez l'application avant la distribution. Selon le statut du scope,
     Google peut demander une vérification avant la publication.

4. Créez les **clients OAuth** dans *Identifiants* :
   - **Android** : nom du package `com.fayma.app` et empreinte SHA-1 de la
     clé **release** (celle qui signe les APK distribués). Ajoutez un second
     client Android avec le SHA-1 de debug si vous testez avec un build debug ;
   - **Application Web** : sert de `serverClientId` à Android. Aucun URI de
     redirection n'est nécessaire ;
   - **iOS** (si vous distribuez sur iPhone) : *Bundle ID* `com.fayma.app`,
     puis ajoutez l'URI inversée (`com.googleusercontent.apps...`) dans
     `CFBundleURLTypes` de `ios/Runner/Info.plist`.

   Affichez les empreintes SHA-1 release et debug au format hexadécimal attendu
   par Google Cloud :

   ```bash
   tool/android_sha1.sh
   ```

   La clé release actuelle a l'empreinte
   `BE:8F:B9:C0:6C:75:32:F3:61:4B:07:4F:87:90:16:B0:4D:88:D9:C0`.

5. Renseignez les identifiants dans un fichier local ignoré par Git :

   ```bash
   cp tool/drive_defines.example.json tool/drive_defines.json
   ```

   ```json
   {
     "FAYMA_GOOGLE_SERVER_CLIENT_ID": "1234567890-abc.apps.googleusercontent.com",
     "FAYMA_GOOGLE_IOS_CLIENT_ID": "1234567890-def.apps.googleusercontent.com"
   }
   ```

   `FAYMA_GOOGLE_SERVER_CLIENT_ID` est le client **Web** (obligatoire sur
   Android). `FAYMA_GOOGLE_IOS_CLIENT_ID` est le client **iOS**. Ces
   identifiants ne sont pas des secrets ; ne mettez jamais de client secret
   dans l'application.

   Le client Web actuel est aussi la valeur par défaut dans
   `lib/services/backup/drive/drive_config.dart` : un APK Android compilé sans
   `tool/drive_defines.json` reste donc connectable. La définition
   `FAYMA_GOOGLE_SERVER_CLIENT_ID` reste prioritaire. Le client iOS, lui, doit
   toujours être fourni.

6. Lancez l'application avec les définitions :

   ```bash
   flutter run --dart-define-from-file=tool/drive_defines.json
   ```

   `tool/build_apk.sh` et `tool/build_ipa.sh` utilisent automatiquement
   `tool/drive_defines.json` s'il existe.

   Important : les identifiants sont injectés **à la compilation**, pas à
   l'installation. Sur Android, le client Web est désormais la valeur par
   défaut du code : un APK compilé sans fichier de définitions reste
   fonctionnel. Sur iOS, le client iOS doit être fourni à la compilation.

7. Ouvrez **Sauvegarde** → **Connecter Google Drive**, choisissez le compte,
   puis autorisez l'accès. La sauvegarde automatique est activée après la
   connexion ; elle peut être désactivée par l'interrupteur.

Sans fichier de définitions (ou sans identifiants), l'application reste
utilisable : l'écran de sauvegarde affiche « Google Drive non configuré » et
l'export manuel continue de fonctionner.

### Vérifier l'implémentation

Les tests unitaires couvrent le chiffrement, la rétention, la planification,
l'envoi en deux étapes (métadonnées puis contenu) et la traduction des erreurs
HTTP. Le parcours de connexion Google et l'accès réel au Drive nécessitent un
appareil Android (ou iOS) et les identifiants OAuth ci-dessus :

```bash
flutter test
flutter run --dart-define-from-file=tool/drive_defines.json
```

Points à contrôler sur un appareil réel :

- le dossier **Sauvegardes Fayma** apparaît à la racine du Drive ;
- une sauvegarde manuelle puis automatique créent des fichiers `.fayma` ;
- la restauration depuis Drive **ne demande pas** le code sur le téléphone
  qui a créé la sauvegarde, et le demande sur un autre téléphone ; elle
  remplace bien les données ;
- après une réinstallation, la reconnexion au même compte retrouve les
  sauvegardes du dossier.

### Dépannage de la connexion

- **« Google Drive non configuré »** : sur iOS, l'APK/IPA a été compilé sans
  client OAuth ; sur Android, vérifiez la valeur par défaut de
  `lib/services/backup/drive/drive_config.dart` ou `tool/drive_defines.json`,
  puis reconstruisez.
- **Erreur 10 / `DEVELOPER_ERROR`** : le client OAuth Android est absent, ou
  son package / SHA-1 ne correspond pas à l'APK installé. Vérifiez
  `com.fayma.app` et l'empreinte release donnée par `tool/android_sha1.sh`.
- **Accès refusé** : tant que l'écran de consentement est en mode *Test*, seul
  un compte ajouté dans **Utilisateurs test** peut autoriser l'application.
- **Le client Web et le client Android doivent appartenir au même projet
  Google Cloud.**
- **Connexion annulée** : la fenêtre Google a été fermée ; relancez le bouton
  **Connecter Google Drive**.
