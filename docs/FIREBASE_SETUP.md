# Firebase setup

Keepi deliberately does not commit Firebase project-specific configuration to the public repository.

## 1. Firebase CLI

Check the CLI:

```powershell
firebase.cmd --version
```

On Windows PowerShell, use `firebase.cmd` if PowerShell blocks `firebase.ps1`.

Login:

```powershell
firebase.cmd login
```

## 2. FlutterFire CLI

```powershell
dart pub global activate flutterfire_cli
```

## 3. Configure Keepi

From the repository root:

```powershell
flutterfire configure
```

Select Android, iOS and Web.

This generates project-specific Firebase files, including `lib/firebase_options.dart`.

## 4. Enable Firebase products

In Firebase Console enable:

- Authentication
- Cloud Firestore
- Cloud Storage

Authentication providers will be configured during the authentication build.

## 5. Deploy rules

```powershell
firebase.cmd deploy --only firestore:rules,storage
```

## Current bootstrap behavior

The app currently catches Firebase initialization failure so the UI can run before configuration is complete.

After FlutterFire configuration, Build 2 will switch initialization to `DefaultFirebaseOptions.currentPlatform` and connect real authentication, Storage and Firestore.
