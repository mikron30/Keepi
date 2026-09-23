# Keepi

**Keepi knows what you have, what it is worth, and who nearby needs it.**

Keepi is a Flutter + Firebase app for building a private inventory of everything a person owns and, when they choose, turning selected Things into listings that can be sold, rented, lent, or given away.

The model is deliberately broad: a Thing can be a house, car, bicycle, generator, drill, ladder, screwdriver, bottle of wine, carton of milk, or almost anything else.

## Core product rules

- A **Thing** is private inventory by default.
- A **Listing** is a separate public marketplace object.
- The app supports Android, iOS, Web and installable PWA from one Flutter codebase.
- Category-specific behavior is layered on top of the universal Thing model.
- Exact private location is never exposed in a public listing.
- AI recognition, valuation, expiry logic, location search, insurance and transactions are added incrementally.

## Current milestone

Foundation v0.1:

- Flutter application shell
- Home / My Things / Add / Explore / Profile navigation
- Universal Thing, Listing and Need Request domain models
- Camera/gallery photo selection and preview
- Firebase dependencies and security-rule foundation
- Architecture and roadmap documentation
- Automatic generation of Android, iOS and Web platform shells in GitHub Actions

## Local setup

Clone the repository:

```powershell
git clone https://github.com/mikron30/Keepi.git
cd Keepi
flutter pub get
```

If the platform folders have not yet been generated, run:

```powershell
flutter create . --project-name keepi --org com.keepi --platforms=android,ios,web
```

Then configure Firebase:

```powershell
firebase.cmd login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select Android, iOS and Web.

More details: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

## Run

```powershell
flutter run
```

For Web:

```powershell
flutter run -d chrome
```

## Project structure

```text
lib/
  app/
  core/
  features/
    add_thing/
    explore/
    home/
    inventory/
    marketplace/
    profile/
    requests/
    shell/
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/ROADMAP.md](docs/ROADMAP.md).
