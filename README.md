# Fayma

Gestion du crédit pour les boutiques de quartier, pensée pour fonctionner hors
connexion (montants en FCFA, interface en français).

## Développement

```bash
flutter pub get
flutter run
flutter test
```

L'application cible Android (API 24 minimum). La base SQLite est stockée dans
le dossier privé de l'application (`fayma.db`).

## Sauvegarde chiffrée

Depuis l'écran d'accueil, le bouton en haut à droite ouvre **Sauvegarde**.

- Au premier affichage, l'application génère un **code de récupération** de
  24 caractères (120 bits). Il est stocké de façon chiffrée, avec une clé
  protégée par le Keystore Android, et doit être noté par le commerçant.
- **Exporter une sauvegarde** crée un fichier `.fayma` chiffré avec
  Argon2id + AES-256-GCM, puis ouvre le partage Android. Le fichier peut être
  envoyé vers Google Drive, Files, un e-mail, etc.
- **Restaurer une sauvegarde** demande le code de récupération, vérifie le
  fichier, puis remplace toutes les données dans une transaction SQLite. En
  cas d'erreur, les données existantes restent intactes.
- Sans le code de récupération, une sauvegarde est définitivement illisible :
  il n'existe aucun serveur ni clé de secours chez Fayma.

La sauvegarde automatique Android est désactivée (`android:allowBackup="false"`)
pour éviter des copies non maîtrisées et des erreurs de Keystore. Seuls les
exports chiffrés explicites servent à restaurer l'application après une
désinstallation ou sur un nouveau téléphone.

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
